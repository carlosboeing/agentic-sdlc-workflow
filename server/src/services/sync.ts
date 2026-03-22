import { eq, and, asc, inArray, sql } from "drizzle-orm";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import * as schema from "../db/schema";
import type { SyncOperation } from "../types";
import type {
  ExternalPmAdapter,
  SyncPayload,
  SyncCreatePayload,
  SyncUpdatePayload,
  SyncClosePayload,
  SyncSetStatusPayload,
  SyncCommentPayload,
  SyncLinkChildPayload,
} from "../types/sync";

type Db = ReturnType<typeof drizzle>;

/** Row type returned from sync_queue table queries. */
export type SyncQueueRow = typeof schema.syncQueue.$inferSelect;

/** Options for enqueuing a sync operation. */
export interface EnqueueOptions {
  /** Item ID for per-item ordered processing. */
  itemId?: number;
  /** Custom idempotency key. Auto-generated if not provided. */
  idempotencyKey?: string;
}

/** Options for the SyncService. */
export interface SyncServiceOptions {
  /** Maximum retry attempts before dead-lettering. Default: 5. */
  maxRetries?: number;
  /** Override current time for testing backoff. Returns epoch ms. */
  nowMs?: () => number;
}

/** Queue status counts by status value. */
export interface QueueStatus {
  pending: number;
  in_flight: number;
  success: number;
  failed: number;
  dead_letter: number;
}

/**
 * Service that manages the sync queue for external PM operations.
 *
 * Operations are enqueued with a status of "pending" and processed in
 * insertion order per item_id. Failed operations use exponential backoff
 * and are dead-lettered after exceeding the max retry count.
 */
export class SyncService {
  private readonly maxRetries: number;
  private readonly nowMs: () => number;

  constructor(
    private readonly db: Db,
    private readonly adapter: ExternalPmAdapter,
    options: SyncServiceOptions = {}
  ) {
    this.maxRetries = options.maxRetries ?? 5;
    this.nowMs = options.nowMs ?? (() => Date.now());
  }

  /**
   * Compute exponential backoff delay in milliseconds.
   * Formula: min(2^retryCount * 1000, 60000)
   */
  static computeBackoff(retryCount: number): number {
    return Math.min(Math.pow(2, retryCount) * 1000, 60_000);
  }

  /**
   * Enqueue a sync operation for external processing.
   *
   * If an idempotency key is provided and a matching entry already exists,
   * the existing entry is returned without creating a duplicate.
   */
  async enqueue(
    operation: SyncOperation,
    payload: SyncPayload,
    options: EnqueueOptions = {}
  ): Promise<SyncQueueRow> {
    const idempotencyKey =
      options.idempotencyKey ?? `${operation}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;

    // Check for existing entry with same idempotency key
    if (options.idempotencyKey) {
      const existing = this.db
        .select()
        .from(schema.syncQueue)
        .where(eq(schema.syncQueue.idempotencyKey, idempotencyKey))
        .all();

      if (existing.length > 0) {
        return existing[0];
      }
    }

    const now = new Date().toISOString();
    const rows = this.db
      .insert(schema.syncQueue)
      .values({
        operation,
        payload: JSON.stringify(payload),
        status: "pending",
        retryCount: 0,
        lastError: null,
        idempotencyKey,
        itemId: options.itemId ?? null,
        createdAt: now,
        processedAt: null,
      })
      .returning()
      .all();

    return rows[0];
  }

  /**
   * Process all pending operations in the queue.
   *
   * Operations are processed in insertion order per item_id. If an earlier
   * operation for the same item_id fails, later operations for that item
   * are skipped to preserve ordering guarantees.
   *
   * Returns the number of successfully processed operations.
   */
  async processQueue(): Promise<number> {
    const now = this.nowMs();

    // Fetch all pending operations ordered by id (insertion order)
    const pending = this.db
      .select()
      .from(schema.syncQueue)
      .where(
        and(
          eq(schema.syncQueue.status, "pending")
        )
      )
      .orderBy(asc(schema.syncQueue.id))
      .all();

    if (pending.length === 0) return 0;

    // Track which item_ids have a failed operation (to skip later ops)
    const failedItemIds = new Set<number | null>();
    let successCount = 0;

    for (const entry of pending) {
      // Skip if an earlier op for the same item failed in this pass
      if (entry.itemId !== null && failedItemIds.has(entry.itemId)) {
        continue;
      }

      // Check backoff period for retried operations
      if (entry.retryCount > 0) {
        const backoffMs = SyncService.computeBackoff(entry.retryCount - 1);
        const lastAttemptTime = entry.processedAt
          ? new Date(entry.processedAt).getTime()
          : new Date(entry.createdAt).getTime();

        if (now - lastAttemptTime < backoffMs) {
          // Still in backoff period - skip
          if (entry.itemId !== null) {
            failedItemIds.add(entry.itemId);
          }
          continue;
        }
      }

      // Mark as in_flight
      this.db
        .update(schema.syncQueue)
        .set({ status: "in_flight" })
        .where(eq(schema.syncQueue.id, entry.id))
        .run();

      try {
        await this.executeOperation(entry);
        this.markSuccess(entry.id);
        successCount++;
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : String(err);
        const newRetryCount = entry.retryCount + 1;

        if (newRetryCount >= this.maxRetries) {
          this.markDeadLetter(entry.id, errorMessage, newRetryCount);
        } else {
          this.markFailed(entry.id, errorMessage, newRetryCount);
        }

        if (entry.itemId !== null) {
          failedItemIds.add(entry.itemId);
        }
      }
    }

    return successCount;
  }

  /** Get all pending operations ordered by insertion time. */
  async getPendingOperations(): Promise<SyncQueueRow[]> {
    return this.db
      .select()
      .from(schema.syncQueue)
      .where(eq(schema.syncQueue.status, "pending"))
      .orderBy(asc(schema.syncQueue.id))
      .all();
  }

  /** Get all operations regardless of status. */
  async getAllOperations(): Promise<SyncQueueRow[]> {
    return this.db
      .select()
      .from(schema.syncQueue)
      .orderBy(asc(schema.syncQueue.id))
      .all();
  }

  /** Get queue status counts grouped by status. */
  async getQueueStatus(): Promise<QueueStatus> {
    const rows = this.db
      .select({
        status: schema.syncQueue.status,
        count: sql<number>`count(*)`,
      })
      .from(schema.syncQueue)
      .groupBy(schema.syncQueue.status)
      .all();

    const status: QueueStatus = {
      pending: 0,
      in_flight: 0,
      success: 0,
      failed: 0,
      dead_letter: 0,
    };

    for (const row of rows) {
      if (row.status in status) {
        status[row.status as keyof QueueStatus] = row.count;
      }
    }

    return status;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  private async executeOperation(entry: SyncQueueRow): Promise<void> {
    const payload = JSON.parse(entry.payload);
    const op = entry.operation as SyncOperation;

    switch (op) {
      case "create":
        await this.adapter.createItem(payload as SyncCreatePayload);
        break;
      case "update":
        await this.adapter.updateItem(payload as SyncUpdatePayload);
        break;
      case "close":
        await this.adapter.closeItem(payload as SyncClosePayload);
        break;
      case "set_status":
        await this.adapter.setStatus(payload as SyncSetStatusPayload);
        break;
      case "comment":
        await this.adapter.addComment(payload as SyncCommentPayload);
        break;
      case "link_child":
        await this.adapter.linkChild(payload as SyncLinkChildPayload);
        break;
      default: {
        const _exhaustive: never = op;
        throw new Error(`Unknown sync operation: ${entry.operation}`);
      }
    }
  }

  private markSuccess(id: number): void {
    this.db
      .update(schema.syncQueue)
      .set({
        status: "success",
        processedAt: new Date().toISOString(),
      })
      .where(eq(schema.syncQueue.id, id))
      .run();
  }

  private markFailed(id: number, error: string, retryCount: number): void {
    this.db
      .update(schema.syncQueue)
      .set({
        status: "pending",
        lastError: error,
        retryCount,
        processedAt: new Date().toISOString(),
      })
      .where(eq(schema.syncQueue.id, id))
      .run();
  }

  private markDeadLetter(id: number, error?: string, retryCount?: number): void {
    const values: Record<string, unknown> = {
      status: "dead_letter",
      processedAt: new Date().toISOString(),
    };
    if (error !== undefined) values.lastError = error;
    if (retryCount !== undefined) values.retryCount = retryCount;

    this.db
      .update(schema.syncQueue)
      .set(values)
      .where(eq(schema.syncQueue.id, id))
      .run();
  }
}
