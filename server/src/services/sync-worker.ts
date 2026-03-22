import type { drizzle } from "drizzle-orm/bun-sqlite";
import { SyncService } from "./sync";
import type { ExternalPmAdapter, SyncWorkerOptions } from "../types/sync";

type Db = ReturnType<typeof drizzle>;

/**
 * Background worker that polls the sync queue at a configurable interval
 * and processes pending operations via the SyncService.
 *
 * Supports clean start/stop for tests and graceful shutdown.
 */
export class SyncWorker {
  private readonly syncService: SyncService;
  private readonly pollIntervalMs: number;
  private running = false;
  private timer: ReturnType<typeof setTimeout> | null = null;
  private processingPromise: Promise<void> | null = null;

  constructor(
    db: Db,
    adapter: ExternalPmAdapter,
    options: SyncWorkerOptions = {}
  ) {
    this.pollIntervalMs = options.pollIntervalMs ?? 5000;
    this.syncService = new SyncService(db, adapter, {
      maxRetries: options.maxRetries ?? 5,
    });
  }

  /** Start the polling loop. No-op if already running. */
  start(): void {
    if (this.running) return;
    this.running = true;
    this.schedulePoll();
  }

  /**
   * Stop the polling loop and wait for any in-flight processing to complete.
   * Returns a promise that resolves when the worker is fully stopped.
   */
  async stop(): Promise<void> {
    this.running = false;

    if (this.timer !== null) {
      clearTimeout(this.timer);
      this.timer = null;
    }

    // Wait for any in-flight processing
    if (this.processingPromise) {
      await this.processingPromise;
      this.processingPromise = null;
    }
  }

  /** Check if the worker is currently running. */
  isRunning(): boolean {
    return this.running;
  }

  /** Get the underlying SyncService (for enqueuing from outside). */
  getSyncService(): SyncService {
    return this.syncService;
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  private schedulePoll(): void {
    if (!this.running) return;

    this.timer = setTimeout(async () => {
      if (!this.running) return;

      this.processingPromise = this.poll();
      await this.processingPromise;
      this.processingPromise = null;

      this.schedulePoll();
    }, this.pollIntervalMs);
  }

  private async poll(): Promise<void> {
    try {
      await this.syncService.processQueue();
    } catch (err) {
      // Log but don't crash the worker - it will retry on next poll
      process.stderr.write(
        `[SyncWorker] Error processing queue: ${err instanceof Error ? err.message : String(err)}\n`
      );
    }
  }
}
