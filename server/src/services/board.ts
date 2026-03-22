import { eq } from "drizzle-orm";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import * as schema from "../db/schema";
import type { BoardStatus } from "../types";
import type { Item } from "./items";
import type { EventService } from "../api/websocket";

type Db = ReturnType<typeof drizzle>;

const VALID_STATUSES: ReadonlySet<string> = new Set([
  "backlog",
  "ready",
  "in-progress",
  "in-review",
  "done",
]);

/**
 * Service for board status transitions on work items.
 * Validates status values and logs transitions to the activity log.
 * Optionally accepts an EventService to broadcast real-time events.
 */
export class BoardService {
  constructor(
    private readonly db: Db,
    private readonly eventService?: EventService
  ) {}

  /** Set the board status on an item. Validates the status enum. */
  async setStatus(itemId: number, status: BoardStatus): Promise<Item | null> {
    if (!VALID_STATUSES.has(status)) {
      throw new Error(`Invalid board status: "${status}". Valid values: ${[...VALID_STATUSES].join(", ")}`);
    }

    // Get current status for activity log
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
      .set({ status, updatedAt: now })
      .where(eq(schema.items.id, itemId))
      .returning()
      .all();

    if (rows.length === 0) return null;

    // Log status change
    this.db
      .insert(schema.activityLog)
      .values({
        itemId,
        eventType: "status:changed",
        payload: JSON.stringify({
          from: previousStatus,
          to: status,
        }),
        createdAt: now,
      })
      .run();

    // Broadcast real-time event
    this.eventService?.broadcast(
      {
        type: "status:changed",
        data: { itemId, from: previousStatus, to: status, timestamp: now },
        itemId,
      },
      { persistToDb: false }
    );

    return rows[0];
  }

  /** Get the current board status of an item. Returns null if not found. */
  async getStatus(itemId: number): Promise<BoardStatus | null> {
    const rows = this.db
      .select({ status: schema.items.status })
      .from(schema.items)
      .where(eq(schema.items.id, itemId))
      .all();

    if (rows.length === 0) return null;

    return rows[0].status as BoardStatus;
  }
}
