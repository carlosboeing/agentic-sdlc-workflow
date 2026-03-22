/**
 * Data Migration Script — import .workflow/items/ markdown files into SQLite.
 *
 * Usage:
 *   import { migrateFromItems } from "./seed";
 *   const result = await migrateFromItems(db, "/path/to/.workflow/items");
 *
 * The function is idempotent: running it twice on the same database produces
 * the same result as running it once (items checked by ID, labels by name,
 * comments by itemId + createdAt).
 *
 * Each .md file in the items directory has the structure:
 *
 *   ---
 *   id: 42
 *   title: "[#42] My Item"
 *   type: story
 *   status: in-progress
 *   labels:
 *     - hierarchy/story
 *     - backlog/10-widget
 *   parent: 10
 *   state: open
 *   created: 2026-01-01T10:00:00Z
 *   updated: 2026-01-02T11:00:00Z
 *   created_by: planner
 *   ---
 *
 *   Body content here...
 *
 *   ─────────
 *   ## Activity Log
 *
 *   <!-- comment: 2026-01-02T08:00:00Z -->
 *   ### Comment heading
 *   ...body...
 *
 *   ---
 */

import { readdirSync, readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { eq, and } from "drizzle-orm";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import * as schema from "./schema";
import type { ItemType, BoardStatus, ItemState } from "../types";

type Db = ReturnType<typeof drizzle>;

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/** Summary returned after a migration run. */
export interface MigrationResult {
  /** Number of .md files scanned. */
  filesProcessed: number;
  /** Number of items inserted (skips items whose ID already exists). */
  itemsImported: number;
  /** Number of new label rows created (not counting pre-existing labels). */
  labelsCreated: number;
  /** Number of items with a non-null parent that was successfully linked. */
  relationshipsLinked: number;
  /** Number of activity log comments inserted. */
  commentsImported: number;
}

// ---------------------------------------------------------------------------
// YAML frontmatter parser (minimal — handles the specific shapes we produce)
// ---------------------------------------------------------------------------

interface ItemFrontmatter {
  id: number;
  title: string;
  type: ItemType;
  status: BoardStatus;
  state: ItemState;
  labels: string[];
  parent: number | null;
  created: string;
  updated: string;
  created_by?: string;
}

/**
 * Parse a minimal subset of YAML frontmatter.
 * Handles the specific field shapes produced by the workflow scripts.
 * Does NOT use a full YAML library to avoid adding a dependency.
 *
 * Returns null if the file does not start with `---` or is missing required fields.
 */
function parseFrontmatter(
  content: string
): { frontmatter: ItemFrontmatter; body: string } | null {
  // Must start with ---
  if (!content.startsWith("---")) return null;

  // Find the closing ---
  const afterFirst = content.slice(3);
  const closeIdx = afterFirst.indexOf("\n---");
  if (closeIdx === -1) return null;

  const yamlText = afterFirst.slice(0, closeIdx);
  // Body is everything after the closing ---\n
  const body = afterFirst.slice(closeIdx + 4).trim();

  const fm: Record<string, unknown> = {};
  const lines = yamlText.split("\n");

  let inLabelsList = false;
  const labelsList: string[] = [];

  for (const rawLine of lines) {
    const line = rawLine.trimEnd();
    if (!line) {
      inLabelsList = false;
      continue;
    }

    // List item under labels:
    if (inLabelsList) {
      const listMatch = line.match(/^[ \t]+-\s+(.+)$/);
      if (listMatch) {
        labelsList.push(listMatch[1].trim());
        continue;
      } else {
        // No longer a list item — fall through to re-parse as a key
        inLabelsList = false;
      }
    }

    const colonIdx = line.indexOf(":");
    if (colonIdx === -1) continue;

    const key = line.slice(0, colonIdx).trim();
    const rawValue = line.slice(colonIdx + 1).trim();

    if (key === "labels") {
      inLabelsList = true;
      // Inline labels: labels: [a, b] — not used by workflow scripts but handle defensively
      if (rawValue.startsWith("[")) {
        const inner = rawValue.slice(1, rawValue.lastIndexOf("]"));
        if (inner.trim()) {
          for (const v of inner.split(",")) {
            labelsList.push(v.trim());
          }
        }
        inLabelsList = false;
      }
      continue;
    }

    fm[key] = parseYamlValue(rawValue);
  }

  fm.labels = labelsList;

  // Validate required fields
  if (
    typeof fm.id !== "number" ||
    typeof fm.title !== "string" ||
    typeof fm.type !== "string" ||
    typeof fm.state !== "string" ||
    typeof fm.created !== "string" ||
    typeof fm.updated !== "string"
  ) {
    return null;
  }

  // Status defaults to "backlog" when missing
  const status = typeof fm.status === "string" ? fm.status : "backlog";

  // Coerce parent: numeric string or null
  let parent: number | null = null;
  if (typeof fm.parent === "number") {
    parent = fm.parent;
  } else if (
    typeof fm.parent === "string" &&
    fm.parent !== "null" &&
    fm.parent !== ""
  ) {
    const parsed = parseInt(fm.parent, 10);
    if (!isNaN(parsed)) parent = parsed;
  }

  return {
    frontmatter: {
      id: fm.id as number,
      title: fm.title as string,
      type: fm.type as ItemType,
      status: status as BoardStatus,
      state: fm.state as ItemState,
      labels: fm.labels as string[],
      parent,
      created: fm.created as string,
      updated: fm.updated as string,
      created_by:
        typeof fm.created_by === "string" ? fm.created_by : undefined,
    },
    body,
  };
}

/** Coerce a raw YAML scalar value string to a JS primitive. */
function parseYamlValue(raw: string): unknown {
  if (raw === "null" || raw === "~" || raw === "") return null;
  if (raw === "true") return true;
  if (raw === "false") return false;
  const n = Number(raw);
  if (!isNaN(n) && raw !== "") return n;
  // Strip optional surrounding quotes
  if (
    (raw.startsWith('"') && raw.endsWith('"')) ||
    (raw.startsWith("'") && raw.endsWith("'"))
  ) {
    return raw.slice(1, -1);
  }
  return raw;
}

// ---------------------------------------------------------------------------
// Activity Log comment parser
// ---------------------------------------------------------------------------

interface ParsedComment {
  createdAt: string;
  body: string;
}

/**
 * Extract comments from the Activity Log section of an item body.
 *
 * Comments are demarcated by:
 *   <!-- comment: 2026-01-02T08:00:00Z -->
 *   ...body content until next comment marker or end...
 *   ---
 *
 * The activity log section starts at the Activity Log separator line.
 */
function parseActivityLogComments(body: string): ParsedComment[] {
  if (!body) return [];

  // Find the Activity Log separator
  const activityLogMarker = /^─+\s*\n## Activity Log/m;
  const match = activityLogMarker.exec(body);
  if (!match) return [];

  const activitySection = body.slice(match.index + match[0].length);

  // Split on <!-- comment: <timestamp> --> markers
  const commentMarkerRe = /<!--\s*comment:\s*([^\s>]+)\s*-->/g;
  const segments: ParsedComment[] = [];

  let lastTimestamp: string | null = null;
  let lastMatchEnd = 0;

  let m: RegExpExecArray | null;
  while ((m = commentMarkerRe.exec(activitySection)) !== null) {
    if (lastTimestamp !== null) {
      const segmentText = activitySection
        .slice(lastMatchEnd, m.index)
        .trim()
        .replace(/\n---\s*$/, "")
        .trim();
      if (segmentText) {
        segments.push({ createdAt: lastTimestamp, body: segmentText });
      }
    }
    lastTimestamp = m[1];
    lastMatchEnd = m.index + m[0].length;
  }

  // Capture text after the last marker
  if (lastTimestamp !== null) {
    const segmentText = activitySection
      .slice(lastMatchEnd)
      .trim()
      .replace(/\n---\s*$/, "")
      .trim();
    if (segmentText) {
      segments.push({ createdAt: lastTimestamp, body: segmentText });
    }
  }

  return segments;
}

// ---------------------------------------------------------------------------
// Main migration function
// ---------------------------------------------------------------------------

/**
 * Import all .workflow/items/*.md files into the SQLite database.
 *
 * @param db       Drizzle database connection (must have migrations applied).
 * @param itemsDir Absolute path to the .workflow/items/ directory.
 * @returns A summary of what was imported.
 */
export async function migrateFromItems(
  db: Db,
  itemsDir: string
): Promise<MigrationResult> {
  const result: MigrationResult = {
    filesProcessed: 0,
    itemsImported: 0,
    labelsCreated: 0,
    relationshipsLinked: 0,
    commentsImported: 0,
  };

  // Return early if the directory doesn't exist
  if (!existsSync(itemsDir)) {
    return result;
  }

  // Read only .md files
  let files: string[];
  try {
    files = readdirSync(itemsDir).filter((f) => f.endsWith(".md"));
  } catch {
    return result;
  }

  // Sort numerically so parent items are inserted before children
  files.sort((a, b) => {
    const numA = parseInt(a, 10);
    const numB = parseInt(b, 10);
    if (!isNaN(numA) && !isNaN(numB)) return numA - numB;
    return a.localeCompare(b);
  });

  result.filesProcessed = files.length;

  // ---------------------------------------------------------------------------
  // Phase 1: Insert items (without parent_id — linked in phase 2)
  // ---------------------------------------------------------------------------
  for (const file of files) {
    const filePath = join(itemsDir, file);
    let content: string;
    try {
      content = readFileSync(filePath, "utf-8");
    } catch {
      continue;
    }

    const parsed = parseFrontmatter(content);
    if (!parsed) continue;

    const { frontmatter, body } = parsed;

    // Check if item already exists (idempotency check by ID)
    const existing = db
      .select({ id: schema.items.id })
      .from(schema.items)
      .where(eq(schema.items.id, frontmatter.id))
      .all();

    if (existing.length > 0) {
      // Item already imported — still ensure labels and comments are present
      await _ensureLabels(db, frontmatter.id, frontmatter.labels, result);
      await _ensureComments(db, frontmatter.id, body, result);
      continue;
    }

    // Insert item (parentId set to null — linked in phase 2)
    const now = new Date().toISOString();
    db.insert(schema.items)
      .values({
        id: frontmatter.id,
        title: frontmatter.title,
        type: frontmatter.type,
        status: frontmatter.status,
        state: frontmatter.state,
        body: body || null,
        parentId: null,
        createdBy: frontmatter.created_by ?? null,
        createdAt: frontmatter.created || now,
        updatedAt: frontmatter.updated || now,
      })
      .run();

    result.itemsImported++;

    // Process labels for this item
    await _ensureLabels(db, frontmatter.id, frontmatter.labels, result);

    // Process activity log comments
    await _ensureComments(db, frontmatter.id, body, result);
  }

  // ---------------------------------------------------------------------------
  // Phase 2: Link parent-child relationships
  // ---------------------------------------------------------------------------
  for (const file of files) {
    const filePath = join(itemsDir, file);
    let content: string;
    try {
      content = readFileSync(filePath, "utf-8");
    } catch {
      continue;
    }

    const parsed = parseFrontmatter(content);
    if (!parsed) continue;

    const { frontmatter } = parsed;
    if (frontmatter.parent === null) continue;

    // Verify parent exists before linking
    const parentExists = db
      .select({ id: schema.items.id })
      .from(schema.items)
      .where(eq(schema.items.id, frontmatter.parent))
      .all();

    if (parentExists.length === 0) continue;

    // Check current state of this item's parent_id
    const current = db
      .select({ parentId: schema.items.parentId })
      .from(schema.items)
      .where(eq(schema.items.id, frontmatter.id))
      .all();

    if (current.length === 0) continue;

    if (current[0].parentId === frontmatter.parent) {
      // Already correctly linked — count as linked (idempotent)
      result.relationshipsLinked++;
      continue;
    }

    // Set the parent_id
    db.update(schema.items)
      .set({ parentId: frontmatter.parent })
      .where(eq(schema.items.id, frontmatter.id))
      .run();
    result.relationshipsLinked++;
  }

  return result;
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/**
 * Ensure all labels exist and are associated with the item.
 * Idempotent: no duplicate label rows or associations created.
 */
async function _ensureLabels(
  db: Db,
  itemId: number,
  labelNames: string[],
  result: MigrationResult
): Promise<void> {
  for (const name of labelNames) {
    if (!name) continue;

    // Find or create the label
    let labelRow = db
      .select()
      .from(schema.labels)
      .where(eq(schema.labels.name, name))
      .all();

    if (labelRow.length === 0) {
      const rows = db
        .insert(schema.labels)
        .values({ name })
        .returning()
        .all();
      labelRow = rows;
      result.labelsCreated++;
    }

    const labelId = labelRow[0].id;

    // Check if association already exists
    const assocExists = db
      .select()
      .from(schema.itemLabels)
      .where(
        and(
          eq(schema.itemLabels.itemId, itemId),
          eq(schema.itemLabels.labelId, labelId)
        )
      )
      .all();

    if (assocExists.length === 0) {
      db.insert(schema.itemLabels).values({ itemId, labelId }).run();
    }
  }
}

/**
 * Ensure activity log comments are imported for an item.
 * Idempotent: deduplicates by (itemId, createdAt).
 */
async function _ensureComments(
  db: Db,
  itemId: number,
  body: string,
  result: MigrationResult
): Promise<void> {
  const comments = parseActivityLogComments(body);

  for (const comment of comments) {
    // Dedup by (itemId, createdAt)
    const existing = db
      .select({ id: schema.comments.id })
      .from(schema.comments)
      .where(
        and(
          eq(schema.comments.itemId, itemId),
          eq(schema.comments.createdAt, comment.createdAt)
        )
      )
      .all();

    if (existing.length > 0) continue;

    db.insert(schema.comments)
      .values({
        itemId,
        body: comment.body,
        author: "system",
        createdAt: comment.createdAt,
        updatedAt: comment.createdAt,
      })
      .run();

    result.commentsImported++;
  }
}
