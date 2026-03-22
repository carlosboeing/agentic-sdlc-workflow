import { eq } from "drizzle-orm";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import * as schema from "../db/schema";
import type { Item } from "./items";

type Db = ReturnType<typeof drizzle>;

/**
 * Service for parent-child hierarchy operations on work items.
 * Manages the three-level hierarchy: backlog -> epic -> story.
 */
export class HierarchyService {
  constructor(private readonly db: Db) {}

  /** Link a child item to a parent by setting parent_id. Returns the updated child, or null if either item is missing. */
  async linkChild(parentId: number, childId: number): Promise<Item | null> {
    // Verify parent exists
    const parentRows = this.db
      .select()
      .from(schema.items)
      .where(eq(schema.items.id, parentId))
      .all();

    if (parentRows.length === 0) return null;

    // Verify child exists
    const childRows = this.db
      .select()
      .from(schema.items)
      .where(eq(schema.items.id, childId))
      .all();

    if (childRows.length === 0) return null;

    const now = new Date().toISOString();

    const rows = this.db
      .update(schema.items)
      .set({ parentId, updatedAt: now })
      .where(eq(schema.items.id, childId))
      .returning()
      .all();

    if (rows.length === 0) return null;

    // Log the hierarchy link
    this.db
      .insert(schema.activityLog)
      .values({
        itemId: parentId,
        eventType: "child:linked",
        payload: JSON.stringify({ childId }),
        createdAt: now,
      })
      .run();

    return rows[0];
  }

  /** List all direct children of an item (items whose parent_id matches). */
  async listChildren(parentId: number): Promise<Item[]> {
    return this.db
      .select()
      .from(schema.items)
      .where(eq(schema.items.parentId, parentId))
      .all();
  }

  /** Get the parent of an item. Returns null if item has no parent or doesn't exist. */
  async getParent(childId: number): Promise<Item | null> {
    const childRows = this.db
      .select()
      .from(schema.items)
      .where(eq(schema.items.id, childId))
      .all();

    if (childRows.length === 0 || childRows[0].parentId === null) return null;

    const parentRows = this.db
      .select()
      .from(schema.items)
      .where(eq(schema.items.id, childRows[0].parentId))
      .all();

    return parentRows.length > 0 ? parentRows[0] : null;
  }
}
