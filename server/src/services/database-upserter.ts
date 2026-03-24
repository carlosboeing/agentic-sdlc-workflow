/**
 * DatabaseUpserter: transactional upsert of mapped GitHub issues into SQLite.
 *
 * Each call to upsertPage() runs all SQL writes for the page in a single
 * SQLite transaction (all-or-nothing per page). linkHierarchy() runs in its
 * own separate transaction after all pages are inserted.
 *
 * GitHub is the source of truth:
 *   - Item fields are overwritten on conflict.
 *   - Exception: createdBy is preserved when the local value is non-null.
 *   - Labels are fully replaced (not merged) per item.
 *   - Comments are deduped by (itemId, createdAt, author).
 */

import { eq, and, sql } from "drizzle-orm";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import * as schema from "../db/schema";
import type { MappedIssue } from "../lib/issue-mapper";

export type { MappedIssue } from "../lib/issue-mapper";

type Db = ReturnType<typeof drizzle>;

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

/** Counters returned by a single upsertPage() call. */
export interface UpsertPageResult {
  itemsCreated: number;
  itemsUpdated: number;
  labelsCreated: number;
  commentsCreated: number;
  commentsUpdated: number;
}

// ---------------------------------------------------------------------------
// DatabaseUpserter
// ---------------------------------------------------------------------------

/**
 * Handles the transactional upsert of MappedIssue records into SQLite.
 * Accepts a Drizzle database connection via constructor for testability.
 */
export class DatabaseUpserter {
  constructor(private readonly db: Db) {}

  /**
   * Upsert a page of mapped issues into the database.
   *
   * All SQL writes for the page run in a single SQLite transaction.
   * Returns counters for created/updated items, labels, and comments.
   */
  async upsertPage(issues: MappedIssue[]): Promise<UpsertPageResult> {
    if (issues.length === 0) {
      return {
        itemsCreated: 0,
        itemsUpdated: 0,
        labelsCreated: 0,
        commentsCreated: 0,
        commentsUpdated: 0,
      };
    }

    return this.db.transaction((tx) => {
      let itemsCreated = 0;
      let itemsUpdated = 0;
      let labelsCreated = 0;
      let commentsCreated = 0;
      let commentsUpdated = 0;

      for (const issue of issues) {
        // ---------------------------------------------------------------
        // Item upsert: check if item exists to track created vs updated
        // ---------------------------------------------------------------
        const existing = tx
          .select({ id: schema.items.id, createdBy: schema.items.createdBy })
          .from(schema.items)
          .where(eq(schema.items.id, issue.item.id))
          .all();

        const existingCreatedBy = existing.length > 0 ? existing[0].createdBy : null;
        const isNew = existing.length === 0;

        // Preserve local createdBy when it is non-null (GitHub doesn't store agent role)
        const createdByValue = existingCreatedBy ?? null;

        tx
          .insert(schema.items)
          .values({
            id: issue.item.id,
            title: issue.item.title,
            body: issue.item.body ?? null,
            type: issue.item.type,
            status: issue.item.status,
            state: issue.item.state,
            externalId: issue.item.externalId,
            externalUrl: issue.item.externalUrl,
            createdBy: null,  // placeholder; overwritten in the ON CONFLICT branch
            createdAt: issue.item.createdAt,
            updatedAt: issue.item.updatedAt,
          })
          .onConflictDoUpdate({
            target: schema.items.id,
            set: {
              title: sql`excluded.title`,
              body: sql`excluded.body`,
              type: sql`excluded.type`,
              status: sql`excluded.status`,
              state: sql`excluded.state`,
              externalId: sql`excluded.external_id`,
              externalUrl: sql`excluded.external_url`,
              updatedAt: sql`excluded.updated_at`,
              // Preserve createdBy: keep local value when non-null
              createdBy: existingCreatedBy != null
                ? sql`${existingCreatedBy}`
                : sql`excluded.created_by`,
            },
          })
          .run();

        if (isNew) {
          // For new items, the insert above used createdBy: null.
          // We don't need to set it (it should remain null for pulled items).
          // createdByValue is null for new items anyway.
          itemsCreated++;
        } else {
          itemsUpdated++;
        }

        // Suppress createdByValue to avoid unused-variable lint in future
        void createdByValue;

        // ---------------------------------------------------------------
        // Label reconciliation: full replace
        // ---------------------------------------------------------------

        // Step 1: Delete existing item_labels for this item
        tx
          .delete(schema.itemLabels)
          .where(eq(schema.itemLabels.itemId, issue.item.id))
          .run();

        // Step 2: Ensure each label exists, then insert item_labels
        for (const labelName of issue.labels) {
          const existingLabel = tx
            .select({ id: schema.labels.id })
            .from(schema.labels)
            .where(eq(schema.labels.name, labelName))
            .all();

          let labelId: number;
          if (existingLabel.length === 0) {
            const inserted = tx
              .insert(schema.labels)
              .values({ name: labelName })
              .returning({ id: schema.labels.id })
              .all();
            labelId = inserted[0].id;
            labelsCreated++;
          } else {
            labelId = existingLabel[0].id;
          }

          tx
            .insert(schema.itemLabels)
            .values({ itemId: issue.item.id, labelId })
            .run();
        }

        // ---------------------------------------------------------------
        // Comment upsert: dedup by (itemId, createdAt, author)
        // ---------------------------------------------------------------

        for (const comment of issue.comments) {
          const existingComment = tx
            .select({ id: schema.comments.id })
            .from(schema.comments)
            .where(
              and(
                eq(schema.comments.itemId, issue.item.id),
                eq(schema.comments.createdAt, comment.createdAt),
                eq(schema.comments.author, comment.author)
              )
            )
            .all();

          if (existingComment.length === 0) {
            tx
              .insert(schema.comments)
              .values({
                itemId: issue.item.id,
                body: comment.body,
                author: comment.author,
                createdAt: comment.createdAt,
                updatedAt: comment.updatedAt,
              })
              .run();
            commentsCreated++;
          } else {
            tx
              .update(schema.comments)
              .set({
                body: comment.body,
                updatedAt: comment.updatedAt,
              })
              .where(eq(schema.comments.id, existingComment[0].id))
              .run();
            commentsUpdated++;
          }
        }
      }

      return {
        itemsCreated,
        itemsUpdated,
        labelsCreated,
        commentsCreated,
        commentsUpdated,
      };
    });
  }

  /**
   * Upsert additional comments for a specific item without touching item fields.
   *
   * Used for comment overflow pagination: when an issue has more than 50 comments,
   * the extra pages are fetched and inserted here rather than via `upsertPage`.
   * This avoids overwriting real item data with stale or synthetic values.
   *
   * @param itemId - The item ID (GitHub issue number) to attach comments to.
   * @param comments - Additional comment nodes to upsert.
   * @returns Counts of created and updated comments.
   */
  async upsertComments(
    itemId: number,
    comments: Array<{ body: string; author: string; createdAt: string; updatedAt: string }>
  ): Promise<{ commentsCreated: number; commentsUpdated: number }> {
    if (comments.length === 0) {
      return { commentsCreated: 0, commentsUpdated: 0 };
    }

    return this.db.transaction((tx) => {
      let commentsCreated = 0;
      let commentsUpdated = 0;

      for (const comment of comments) {
        const existingComment = tx
          .select({ id: schema.comments.id })
          .from(schema.comments)
          .where(
            and(
              eq(schema.comments.itemId, itemId),
              eq(schema.comments.createdAt, comment.createdAt),
              eq(schema.comments.author, comment.author)
            )
          )
          .all();

        if (existingComment.length === 0) {
          tx
            .insert(schema.comments)
            .values({
              itemId,
              body: comment.body,
              author: comment.author,
              createdAt: comment.createdAt,
              updatedAt: comment.updatedAt,
            })
            .run();
          commentsCreated++;
        } else {
          tx
            .update(schema.comments)
            .set({ body: comment.body, updatedAt: comment.updatedAt })
            .where(eq(schema.comments.id, existingComment[0].id))
            .run();
          commentsUpdated++;
        }
      }

      return { commentsCreated, commentsUpdated };
    });
  }

  /**
   * Set parentId for child items based on the accumulated parent map.
   * Runs in a single SQLite transaction.
   *
   * @param parentMap - Map from child issue number to parent issue number.
   * @returns The number of items whose parentId was updated.
   */
  async linkHierarchy(parentMap: Map<number, number>): Promise<number> {
    if (parentMap.size === 0) return 0;

    return this.db.transaction((tx) => {
      let linked = 0;

      for (const [childId, parentId] of parentMap.entries()) {
        tx
          .update(schema.items)
          .set({ parentId })
          .where(eq(schema.items.id, childId))
          .run();
        linked++;
      }

      return linked;
    });
  }
}
