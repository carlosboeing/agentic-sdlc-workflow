import { asc, eq } from "drizzle-orm";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import * as schema from "../db/schema";
import type { TelemetryModel } from "../types";
import type { Item } from "./items";

type Db = ReturnType<typeof drizzle>;

/** Row type returned from telemetry table queries. */
export type TelemetryRow = typeof schema.telemetry.$inferSelect;

/** Input for starting work on an item. */
export interface StartWorkInput {
  agent: string;
  model: string;
}

/** Input for completing work on an item. */
export interface CompleteWorkInput {
  commitHash: string;
}

/** Input for posting telemetry data. */
export interface PostTelemetryInput {
  model: TelemetryModel;
  durationMs: number;
  tokens: number;
  toolUses?: number;
  costEstimate?: number;
  commitHash?: string;
  metadata?: Record<string, unknown>;
}

/**
 * Service for lifecycle transitions and telemetry recording.
 * Handles start_work, complete_work, and telemetry posting with
 * activity log broadcasting.
 */
export class LifecycleService {
  constructor(private readonly db: Db) {}

  /** Start work on an item: set status to in-progress and log the transition. */
  async startWork(itemId: number, input: StartWorkInput): Promise<Item | null> {
    const existing = this.db
      .select()
      .from(schema.items)
      .where(eq(schema.items.id, itemId))
      .all();

    if (existing.length === 0) return null;

    const previousStatus = existing[0].status;
    const now = new Date().toISOString();

    const rows = this.db
      .update(schema.items)
      .set({ status: "in-progress", updatedAt: now })
      .where(eq(schema.items.id, itemId))
      .returning()
      .all();

    if (rows.length === 0) return null;

    // Log the status change with agent/model metadata
    this.db
      .insert(schema.activityLog)
      .values({
        itemId,
        eventType: "status:changed",
        payload: JSON.stringify({
          from: previousStatus,
          to: "in-progress",
          agent: input.agent,
          model: input.model,
        }),
        createdAt: now,
      })
      .run();

    return rows[0];
  }

  /** Complete work on an item: set status to in-review and log the transition. */
  async completeWork(
    itemId: number,
    input: CompleteWorkInput
  ): Promise<Item | null> {
    const existing = this.db
      .select()
      .from(schema.items)
      .where(eq(schema.items.id, itemId))
      .all();

    if (existing.length === 0) return null;

    const previousStatus = existing[0].status;
    const now = new Date().toISOString();

    const rows = this.db
      .update(schema.items)
      .set({ status: "in-review", updatedAt: now })
      .where(eq(schema.items.id, itemId))
      .returning()
      .all();

    if (rows.length === 0) return null;

    // Log the status change with commit hash
    this.db
      .insert(schema.activityLog)
      .values({
        itemId,
        eventType: "status:changed",
        payload: JSON.stringify({
          from: previousStatus,
          to: "in-review",
          commitHash: input.commitHash,
        }),
        createdAt: now,
      })
      .run();

    return rows[0];
  }

  /** Get all telemetry rows for an item, ordered by creation time. */
  async getTelemetry(itemId: number): Promise<TelemetryRow[]> {
    return this.db
      .select()
      .from(schema.telemetry)
      .where(eq(schema.telemetry.itemId, itemId))
      .orderBy(asc(schema.telemetry.createdAt))
      .all();
  }

  /** Post telemetry data for an item and broadcast an activity event. */
  async postTelemetry(
    itemId: number,
    input: PostTelemetryInput
  ): Promise<TelemetryRow> {
    const now = new Date().toISOString();

    const rows = this.db
      .insert(schema.telemetry)
      .values({
        itemId,
        model: input.model,
        durationMs: input.durationMs,
        tokens: input.tokens,
        toolUses: input.toolUses ?? null,
        costEstimate: input.costEstimate ?? null,
        commitHash: input.commitHash ?? null,
        metadata: input.metadata ? JSON.stringify(input.metadata) : null,
        createdAt: now,
      })
      .returning()
      .all();

    const telemetryRow = rows[0];

    // Broadcast activity event
    this.db
      .insert(schema.activityLog)
      .values({
        itemId,
        eventType: "telemetry:posted",
        payload: JSON.stringify({
          telemetryId: telemetryRow.id,
          model: input.model,
          durationMs: input.durationMs,
          tokens: input.tokens,
        }),
        createdAt: now,
      })
      .run();

    return telemetryRow;
  }
}
