import { eq, and, inArray, type SQL } from "drizzle-orm";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import * as schema from "../db/schema";
import type { ItemType, BoardStatus, ItemState } from "../types";
import type { EventService } from "../api/websocket";

type Db = ReturnType<typeof drizzle>;

/** Row type returned from items table queries. */
export type Item = typeof schema.items.$inferSelect;

/** Input for creating a new item. */
export interface CreateItemInput {
  id: number;
  title: string;
  type: ItemType;
  body?: string;
  status?: BoardStatus;
  state?: ItemState;
  parentId?: number;
  externalId?: string;
  externalUrl?: string;
  createdBy?: string;
}

/** Input for updating an existing item. */
export interface UpdateItemInput {
  title?: string;
  body?: string;
  externalId?: string;
  externalUrl?: string;
}

/** Filters for listing items. */
export interface ListItemsFilter {
  type?: ItemType;
  status?: BoardStatus;
  state?: ItemState;
  label?: string;
  limit?: number;
}

/**
 * Service for CRUD operations on work items.
 * Accepts a Drizzle database connection via constructor for testability.
 * Optionally accepts an EventService to broadcast real-time events.
 */
export class ItemService {
  constructor(
    private readonly db: Db,
    private readonly eventService?: EventService
  ) {}

  /** Create a new work item with defaults for status/state. */
  async create(input: CreateItemInput): Promise<Item> {
    const now = new Date().toISOString();

    const rows = this.db
      .insert(schema.items)
      .values({
        id: input.id,
        title: input.title,
        type: input.type,
        status: input.status ?? "backlog",
        state: input.state ?? "open",
        body: input.body ?? null,
        parentId: input.parentId ?? null,
        externalId: input.externalId ?? null,
        externalUrl: input.externalUrl ?? null,
        createdBy: input.createdBy ?? null,
        createdAt: now,
        updatedAt: now,
      })
      .returning()
      .all();

    const item = rows[0];

    // Log item:created activity
    this.db
      .insert(schema.activityLog)
      .values({
        itemId: item.id,
        eventType: "item:created",
        payload: JSON.stringify({
          title: input.title,
          type: input.type,
          createdBy: input.createdBy ?? null,
        }),
        createdAt: now,
      })
      .run();

    // Broadcast real-time event (no re-persist — activity log already written above)
    this.eventService?.broadcast(
      {
        type: "item:created",
        data: { id: item.id, title: input.title, type: input.type, createdBy: input.createdBy ?? null },
        itemId: item.id,
      },
      { persistToDb: false }
    );

    return item;
  }

  /** Get a single item by ID. Returns null if not found. */
  async get(id: number): Promise<Item | null> {
    const rows = this.db
      .select()
      .from(schema.items)
      .where(eq(schema.items.id, id))
      .all();

    return rows.length > 0 ? rows[0] : null;
  }

  /** List items with optional filtering and limit. */
  async list(filter: ListItemsFilter): Promise<Item[]> {
    // When filtering by label, resolve matching item IDs first via the
    // junction table, then restrict the main query with inArray().
    if (filter.label) {
      const labelRows = this.db
        .select()
        .from(schema.labels)
        .where(eq(schema.labels.name, filter.label))
        .all();

      if (labelRows.length === 0) return [];

      const assocRows = this.db
        .select({ itemId: schema.itemLabels.itemId })
        .from(schema.itemLabels)
        .where(eq(schema.itemLabels.labelId, labelRows[0].id))
        .all();

      if (assocRows.length === 0) return [];

      const matchingIds = assocRows.map((r) => r.itemId);
      return this.listWithConditions(filter, [
        inArray(schema.items.id, matchingIds),
      ]);
    }

    return this.listWithConditions(filter, []);
  }

  private listWithConditions(
    filter: ListItemsFilter,
    extraConditions: SQL[]
  ): Item[] {
    const conditions: SQL[] = [...extraConditions];

    if (filter.type) {
      conditions.push(eq(schema.items.type, filter.type));
    }
    if (filter.status) {
      conditions.push(eq(schema.items.status, filter.status));
    }
    if (filter.state) {
      conditions.push(eq(schema.items.state, filter.state));
    }

    let query = this.db
      .select()
      .from(schema.items)
      .$dynamic();

    if (conditions.length > 0) {
      query = query.where(and(...conditions));
    }

    if (filter.limit) {
      query = query.limit(filter.limit);
    }

    return query.all();
  }

  /** Update an existing item's title and/or body. Returns null if not found. */
  async update(id: number, input: UpdateItemInput): Promise<Item | null> {
    const existing = await this.get(id);
    if (!existing) return null;

    const now = new Date().toISOString();
    const values: Partial<typeof schema.items.$inferInsert> = { updatedAt: now };

    if (input.title !== undefined) values.title = input.title;
    if (input.body !== undefined) values.body = input.body;
    if (input.externalId !== undefined) values.externalId = input.externalId;
    if (input.externalUrl !== undefined) values.externalUrl = input.externalUrl;

    const rows = this.db
      .update(schema.items)
      .set(values)
      .where(eq(schema.items.id, id))
      .returning()
      .all();

    if (rows.length === 0) return null;

    // Log item:updated activity
    const changes: Record<string, string | null> = {};
    if (input.title !== undefined) changes.title = input.title;
    if (input.body !== undefined) changes.body = input.body ?? null;
    if (input.externalId !== undefined) changes.externalId = input.externalId ?? null;
    if (input.externalUrl !== undefined) changes.externalUrl = input.externalUrl ?? null;

    this.db
      .insert(schema.activityLog)
      .values({
        itemId: id,
        eventType: "item:updated",
        payload: JSON.stringify({ changes }),
        createdAt: now,
      })
      .run();

    // Broadcast real-time event
    this.eventService?.broadcast(
      {
        type: "item:updated",
        data: { id, changes },
        itemId: id,
      },
      { persistToDb: false }
    );

    return rows[0];
  }

  /** Close an item (set state to "closed"). Returns null if not found. */
  async close(id: number): Promise<Item | null> {
    const existing = await this.get(id);
    if (!existing) return null;

    const previousState = existing.state;
    const now = new Date().toISOString();
    const rows = this.db
      .update(schema.items)
      .set({ state: "closed", updatedAt: now })
      .where(eq(schema.items.id, id))
      .returning()
      .all();

    if (rows.length === 0) return null;

    // Log item:closed activity
    this.db
      .insert(schema.activityLog)
      .values({
        itemId: id,
        eventType: "item:closed",
        payload: JSON.stringify({ previousState }),
        createdAt: now,
      })
      .run();

    // Broadcast real-time event
    this.eventService?.broadcast(
      {
        type: "item:closed",
        data: { id, previousState },
        itemId: id,
      },
      { persistToDb: false }
    );

    return rows[0];
  }
}
