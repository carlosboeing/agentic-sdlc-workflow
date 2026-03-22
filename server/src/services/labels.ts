import { eq, and, inArray } from "drizzle-orm";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import * as schema from "../db/schema";

type Db = ReturnType<typeof drizzle>;

/** Row type returned from labels table queries. */
export type Label = typeof schema.labels.$inferSelect;

/** Row type returned from item_labels junction table. */
export type ItemLabel = typeof schema.itemLabels.$inferSelect;

/** Input for creating a new label. */
export interface CreateLabelInput {
  name: string;
  color?: string;
  description?: string;
}

/**
 * Service for label management and item-label associations.
 * Supports upsert semantics when adding labels to items.
 */
export class LabelService {
  constructor(private readonly db: Db) {}

  /** Create a new label. Throws if a label with the same name already exists. */
  async createLabel(input: CreateLabelInput): Promise<Label> {
    const rows = this.db
      .insert(schema.labels)
      .values({
        name: input.name,
        color: input.color ?? null,
        description: input.description ?? null,
      })
      .returning()
      .all();

    return rows[0];
  }

  /** List all labels in the system. */
  async listLabels(): Promise<Label[]> {
    return this.db.select().from(schema.labels).all();
  }

  /**
   * Add a label to an item. Creates the label if it does not exist (upsert).
   * Idempotent: adding the same label to the same item twice is a no-op.
   */
  async addLabelToItem(itemId: number, labelName: string): Promise<ItemLabel> {
    // Find or create the label
    let labelRows = this.db
      .select()
      .from(schema.labels)
      .where(eq(schema.labels.name, labelName))
      .all();

    if (labelRows.length === 0) {
      labelRows = this.db
        .insert(schema.labels)
        .values({ name: labelName })
        .returning()
        .all();
    }

    const labelId = labelRows[0].id;

    // Check if association already exists
    const existingAssoc = this.db
      .select()
      .from(schema.itemLabels)
      .where(
        and(
          eq(schema.itemLabels.itemId, itemId),
          eq(schema.itemLabels.labelId, labelId)
        )
      )
      .all();

    if (existingAssoc.length > 0) {
      return existingAssoc[0];
    }

    // Create the association
    const rows = this.db
      .insert(schema.itemLabels)
      .values({ itemId, labelId })
      .returning()
      .all();

    // Log the label addition
    const now = new Date().toISOString();
    this.db
      .insert(schema.activityLog)
      .values({
        itemId,
        eventType: "label:added",
        payload: JSON.stringify({ label: labelName, labelId }),
        createdAt: now,
      })
      .run();

    return rows[0];
  }

  /** Get all labels associated with an item. Uses SQL-level filtering. */
  async getLabelsForItem(itemId: number): Promise<Label[]> {
    const associations = this.db
      .select()
      .from(schema.itemLabels)
      .where(eq(schema.itemLabels.itemId, itemId))
      .all();

    if (associations.length === 0) return [];

    const labelIds = associations.map((a) => a.labelId);
    return this.db
      .select()
      .from(schema.labels)
      .where(inArray(schema.labels.id, labelIds))
      .all();
  }
}
