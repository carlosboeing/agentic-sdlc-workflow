import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { mkdirSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import type { Database } from "bun:sqlite";
import { setupTestDb } from "../helpers/setup-db";
import { migrateFromItems, type MigrationResult } from "../../src/db/seed";
import * as schema from "../../src/db/schema";
import { eq } from "drizzle-orm";

// ---------------------------------------------------------------------------
// Test fixtures — minimal .workflow/items/ content shapes
// ---------------------------------------------------------------------------

const BACKLOG_ITEM_MD = `---
id: 10
title: "[#10] Widget Platform"
type: backlog
status: in-progress
labels:
  - hierarchy/backlog
  - type/feature
  - size/L
  - backlog/10-widget-platform
parent: null
state: open
created: 2026-01-01T10:00:00Z
updated: 2026-01-02T11:00:00Z
created_by: planner
---

## Overview

**Blocked by:** none

Widget platform delivers core widget functionality.
`;

const EPIC_ITEM_MD = `---
id: 20
title: "[#10/E01] Core Widgets"
type: epic
status: ready
labels:
  - hierarchy/epic
  - backlog/10-widget-platform
  - type/feature
parent: 10
state: open
created: 2026-01-01T10:05:00Z
updated: 2026-01-01T10:05:00Z
---

## Summary

Core widget epic delivers the widget foundation.

**Blocked by:** none
`;

const STORY_ITEM_MD = `---
id: 21
title: "[#10/E01-S01] Widget Schema"
type: story
status: done
labels:
  - hierarchy/story
  - backlog/10-widget-platform
  - difficulty/easy
parent: 20
state: closed
created: 2026-01-01T10:10:00Z
updated: 2026-01-03T09:00:00Z
created_by: planner
---

## Summary

Set up the widget database schema.

**Blocked by:** none

─────────────────────────────────────────────────────────────────────────
## Activity Log

<!-- comment: 2026-01-02T08:00:00Z -->
### 🚀 Work Started

| Field | Value |
|-------|-------|
| **Agent** | builder |
| **Model** | sonnet |
| **Started** | 2026-01-02T08:00:00Z |

---

<!-- comment: 2026-01-02T09:30:00Z -->
### 👀 Ready for Review

| Field | Value |
|-------|-------|
| **Commit** | abc1234 |
| **Completed** | 2026-01-02T09:30:00Z |

---
`;

const STORY_NO_LABELS_MD = `---
id: 22
title: "[#10/E01-S02] Widget Tests"
type: story
status: backlog
state: open
created: 2026-01-01T10:15:00Z
updated: 2026-01-01T10:15:00Z
---

`;

const STORY_EMPTY_BODY_MD = `---
id: 23
title: "[#10/E01-S03] Widget Lint"
type: story
status: backlog
labels:
  - hierarchy/story
parent: 20
state: open
created: 2026-01-01T10:20:00Z
updated: 2026-01-01T10:20:00Z
---
`;

const STORY_NULL_PARENT_MD = `---
id: 24
title: "[#10/E01-S04] Widget Docs"
type: story
status: backlog
labels:
  - hierarchy/story
  - difficulty/medium
parent: null
state: open
created: 2026-01-01T10:25:00Z
updated: 2026-01-01T10:25:00Z
---

Body content here.
`;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createFixtureDir(files: Record<string, string>): string {
  const dir = join(tmpdir(), `seed-test-${Date.now()}-${Math.random().toString(36).slice(2)}`);
  mkdirSync(dir, { recursive: true });
  for (const [name, content] of Object.entries(files)) {
    writeFileSync(join(dir, name), content, "utf-8");
  }
  return dir;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("migrateFromItems", () => {
  let sqlite: Database;
  let db: ReturnType<typeof drizzle>;
  let fixtureDir: string;

  beforeEach(() => {
    const conn = setupTestDb();
    sqlite = conn.sqlite;
    db = conn.db;
    fixtureDir = "";
  });

  afterEach(() => {
    sqlite.close();
    if (fixtureDir) {
      try {
        rmSync(fixtureDir, { recursive: true, force: true });
      } catch {
        // best-effort cleanup
      }
    }
  });

  // -------------------------------------------------------------------------
  // Basic import
  // -------------------------------------------------------------------------

  describe("basic import", () => {
    test("imports a backlog item with correct column mapping", async () => {
      fixtureDir = createFixtureDir({ "10.md": BACKLOG_ITEM_MD });
      const result = await migrateFromItems(db, fixtureDir);

      expect(result.itemsImported).toBe(1);

      const rows = db.select().from(schema.items).all();
      expect(rows).toHaveLength(1);
      const item = rows[0];
      expect(item.id).toBe(10);
      expect(item.title).toBe("[#10] Widget Platform");
      expect(item.type).toBe("backlog");
      expect(item.status).toBe("in-progress");
      expect(item.state).toBe("open");
      expect(item.parentId).toBeNull();
      expect(item.createdAt).toBe("2026-01-01T10:00:00Z");
      expect(item.updatedAt).toBe("2026-01-02T11:00:00Z");
      expect(item.createdBy).toBe("planner");
    });

    test("maps body content (after second ---) to item body column", async () => {
      fixtureDir = createFixtureDir({ "10.md": BACKLOG_ITEM_MD });
      await migrateFromItems(db, fixtureDir);

      const rows = db.select().from(schema.items).all();
      expect(rows[0].body).toContain("Widget platform delivers core widget functionality.");
    });

    test("maps parent_id from frontmatter parent field", async () => {
      fixtureDir = createFixtureDir({
        "10.md": BACKLOG_ITEM_MD,
        "20.md": EPIC_ITEM_MD,
      });
      await migrateFromItems(db, fixtureDir);

      const rows = db.select().from(schema.items).where(eq(schema.items.id, 20)).all();
      expect(rows[0].parentId).toBe(10);
    });

    test("null parent in frontmatter yields null parent_id", async () => {
      fixtureDir = createFixtureDir({ "24.md": STORY_NULL_PARENT_MD });
      await migrateFromItems(db, fixtureDir);

      const rows = db.select().from(schema.items).where(eq(schema.items.id, 24)).all();
      expect(rows[0].parentId).toBeNull();
    });

    test("imports state field: closed item", async () => {
      fixtureDir = createFixtureDir({
        "10.md": BACKLOG_ITEM_MD,
        "20.md": EPIC_ITEM_MD,
        "21.md": STORY_ITEM_MD,
      });
      await migrateFromItems(db, fixtureDir);

      const rows = db.select().from(schema.items).where(eq(schema.items.id, 21)).all();
      expect(rows[0].state).toBe("closed");
    });
  });

  // -------------------------------------------------------------------------
  // Labels
  // -------------------------------------------------------------------------

  describe("labels", () => {
    test("creates labels from frontmatter labels array", async () => {
      fixtureDir = createFixtureDir({ "10.md": BACKLOG_ITEM_MD });
      const result = await migrateFromItems(db, fixtureDir);

      expect(result.labelsCreated).toBeGreaterThan(0);

      const labelRows = db.select().from(schema.labels).all();
      const names = labelRows.map((l) => l.name);
      expect(names).toContain("hierarchy/backlog");
      expect(names).toContain("type/feature");
      expect(names).toContain("size/L");
      expect(names).toContain("backlog/10-widget-platform");
    });

    test("associates labels with items via item_labels junction table", async () => {
      fixtureDir = createFixtureDir({ "10.md": BACKLOG_ITEM_MD });
      await migrateFromItems(db, fixtureDir);

      const assocs = db
        .select()
        .from(schema.itemLabels)
        .where(eq(schema.itemLabels.itemId, 10))
        .all();
      expect(assocs.length).toBe(4); // hierarchy/backlog, type/feature, size/L, backlog/10-widget-platform
    });

    test("deduplicates shared labels across items (same label name → one row)", async () => {
      fixtureDir = createFixtureDir({
        "10.md": BACKLOG_ITEM_MD,
        "20.md": EPIC_ITEM_MD, // also has backlog/10-widget-platform
      });
      await migrateFromItems(db, fixtureDir);

      // backlog/10-widget-platform appears in both files but should only be one label row
      const labelRows = db
        .select()
        .from(schema.labels)
        .all()
        .filter((l) => l.name === "backlog/10-widget-platform");
      expect(labelRows).toHaveLength(1);
    });

    test("handles missing labels field gracefully", async () => {
      fixtureDir = createFixtureDir({ "22.md": STORY_NO_LABELS_MD });
      const result = await migrateFromItems(db, fixtureDir);

      expect(result.itemsImported).toBe(1);
      expect(result.labelsCreated).toBe(0);

      const assocs = db
        .select()
        .from(schema.itemLabels)
        .where(eq(schema.itemLabels.itemId, 22))
        .all();
      expect(assocs).toHaveLength(0);
    });
  });

  // -------------------------------------------------------------------------
  // Parent-child relationships
  // -------------------------------------------------------------------------

  describe("parent-child relationships", () => {
    test("links child items to parents via parent_id", async () => {
      fixtureDir = createFixtureDir({
        "10.md": BACKLOG_ITEM_MD,
        "20.md": EPIC_ITEM_MD,
        "21.md": STORY_ITEM_MD,
      });
      await migrateFromItems(db, fixtureDir);

      const storyRows = db.select().from(schema.items).where(eq(schema.items.id, 21)).all();
      expect(storyRows[0].parentId).toBe(20);
    });

    test("reports relationships linked count in result", async () => {
      fixtureDir = createFixtureDir({
        "10.md": BACKLOG_ITEM_MD,
        "20.md": EPIC_ITEM_MD, // parent: 10
        "21.md": STORY_ITEM_MD, // parent: 20
      });
      const result = await migrateFromItems(db, fixtureDir);
      expect(result.relationshipsLinked).toBe(2);
    });
  });

  // -------------------------------------------------------------------------
  // Comments from Activity Log
  // -------------------------------------------------------------------------

  describe("comments from activity log", () => {
    test("imports comments from activity log sections", async () => {
      fixtureDir = createFixtureDir({
        "10.md": BACKLOG_ITEM_MD,
        "20.md": EPIC_ITEM_MD,
        "21.md": STORY_ITEM_MD,
      });
      const result = await migrateFromItems(db, fixtureDir);

      expect(result.commentsImported).toBe(2);

      const commentRows = db
        .select()
        .from(schema.comments)
        .where(eq(schema.comments.itemId, 21))
        .all();
      expect(commentRows).toHaveLength(2);
    });

    test("each comment has correct createdAt from <!-- comment: timestamp --> marker", async () => {
      fixtureDir = createFixtureDir({
        "10.md": BACKLOG_ITEM_MD,
        "20.md": EPIC_ITEM_MD,
        "21.md": STORY_ITEM_MD,
      });
      await migrateFromItems(db, fixtureDir);

      const commentRows = db
        .select()
        .from(schema.comments)
        .where(eq(schema.comments.itemId, 21))
        .all()
        .sort((a, b) => a.createdAt.localeCompare(b.createdAt));

      expect(commentRows[0].createdAt).toBe("2026-01-02T08:00:00Z");
      expect(commentRows[1].createdAt).toBe("2026-01-02T09:30:00Z");
    });

    test("comment body contains the markdown content after the timestamp marker", async () => {
      fixtureDir = createFixtureDir({
        "10.md": BACKLOG_ITEM_MD,
        "20.md": EPIC_ITEM_MD,
        "21.md": STORY_ITEM_MD,
      });
      await migrateFromItems(db, fixtureDir);

      const commentRows = db
        .select()
        .from(schema.comments)
        .where(eq(schema.comments.itemId, 21))
        .all()
        .sort((a, b) => a.createdAt.localeCompare(b.createdAt));

      expect(commentRows[0].body).toContain("Work Started");
      expect(commentRows[1].body).toContain("Ready for Review");
    });

    test("comment author is set to 'system' for activity log entries", async () => {
      fixtureDir = createFixtureDir({
        "10.md": BACKLOG_ITEM_MD,
        "20.md": EPIC_ITEM_MD,
        "21.md": STORY_ITEM_MD,
      });
      await migrateFromItems(db, fixtureDir);

      const commentRows = db
        .select()
        .from(schema.comments)
        .where(eq(schema.comments.itemId, 21))
        .all();

      for (const c of commentRows) {
        expect(c.author).toBe("system");
      }
    });

    test("items without activity log have no comments imported", async () => {
      fixtureDir = createFixtureDir({ "10.md": BACKLOG_ITEM_MD });
      const result = await migrateFromItems(db, fixtureDir);

      expect(result.commentsImported).toBe(0);
      const commentRows = db.select().from(schema.comments).all();
      expect(commentRows).toHaveLength(0);
    });
  });

  // -------------------------------------------------------------------------
  // Idempotency
  // -------------------------------------------------------------------------

  describe("idempotency", () => {
    test("running migration twice does not create duplicate items", async () => {
      fixtureDir = createFixtureDir({ "10.md": BACKLOG_ITEM_MD });
      await migrateFromItems(db, fixtureDir);
      const result2 = await migrateFromItems(db, fixtureDir);

      const rows = db.select().from(schema.items).all();
      expect(rows).toHaveLength(1);
      // Second run should report 0 items imported (all already existed)
      expect(result2.itemsImported).toBe(0);
    });

    test("running migration twice does not create duplicate labels", async () => {
      fixtureDir = createFixtureDir({ "10.md": BACKLOG_ITEM_MD });
      await migrateFromItems(db, fixtureDir);
      await migrateFromItems(db, fixtureDir);

      const labelRows = db.select().from(schema.labels).all();
      const names = labelRows.map((l) => l.name);
      const unique = new Set(names);
      expect(unique.size).toBe(names.length);
    });

    test("running migration twice does not create duplicate comments", async () => {
      fixtureDir = createFixtureDir({
        "10.md": BACKLOG_ITEM_MD,
        "20.md": EPIC_ITEM_MD,
        "21.md": STORY_ITEM_MD,
      });
      await migrateFromItems(db, fixtureDir);
      await migrateFromItems(db, fixtureDir);

      const commentRows = db.select().from(schema.comments).all();
      expect(commentRows).toHaveLength(2);
    });

    test("running migration twice does not create duplicate item_labels associations", async () => {
      fixtureDir = createFixtureDir({ "10.md": BACKLOG_ITEM_MD });
      await migrateFromItems(db, fixtureDir);
      await migrateFromItems(db, fixtureDir);

      const assocs = db
        .select()
        .from(schema.itemLabels)
        .where(eq(schema.itemLabels.itemId, 10))
        .all();
      expect(assocs).toHaveLength(4);
    });
  });

  // -------------------------------------------------------------------------
  // Edge cases
  // -------------------------------------------------------------------------

  describe("edge cases", () => {
    test("item with empty body after frontmatter", async () => {
      fixtureDir = createFixtureDir({ "23.md": STORY_EMPTY_BODY_MD });
      const result = await migrateFromItems(db, fixtureDir);

      expect(result.itemsImported).toBe(1);
      const rows = db.select().from(schema.items).where(eq(schema.items.id, 23)).all();
      // body is null or empty string — either is acceptable
      const body = rows[0].body;
      expect(body == null || body.trim() === "").toBe(true);
    });

    test("non-md files in directory are skipped", async () => {
      fixtureDir = createFixtureDir({
        "10.md": BACKLOG_ITEM_MD,
        "README.txt": "ignore me",
        ".gitkeep": "",
      });
      const result = await migrateFromItems(db, fixtureDir);
      expect(result.itemsImported).toBe(1);
    });

    test("empty directory returns zero counts", async () => {
      fixtureDir = createFixtureDir({});
      const result = await migrateFromItems(db, fixtureDir);

      expect(result.itemsImported).toBe(0);
      expect(result.labelsCreated).toBe(0);
      expect(result.relationshipsLinked).toBe(0);
      expect(result.commentsImported).toBe(0);
    });

    test("non-existent directory returns zero counts without throwing", async () => {
      const result = await migrateFromItems(db, "/nonexistent/path/xyz");
      expect(result.itemsImported).toBe(0);
    });

    test("migration summary includes all count fields", async () => {
      fixtureDir = createFixtureDir({
        "10.md": BACKLOG_ITEM_MD,
        "20.md": EPIC_ITEM_MD,
        "21.md": STORY_ITEM_MD,
      });
      const result = await migrateFromItems(db, fixtureDir);

      expect(typeof result.itemsImported).toBe("number");
      expect(typeof result.labelsCreated).toBe("number");
      expect(typeof result.relationshipsLinked).toBe("number");
      expect(typeof result.commentsImported).toBe("number");
      expect(typeof result.filesProcessed).toBe("number");
    });

    test("item file with missing optional fields (no created_by) imports successfully", async () => {
      fixtureDir = createFixtureDir({ "20.md": EPIC_ITEM_MD });
      const result = await migrateFromItems(db, fixtureDir);

      expect(result.itemsImported).toBe(1);
      const rows = db.select().from(schema.items).where(eq(schema.items.id, 20)).all();
      expect(rows[0].createdBy).toBeNull();
    });
  });

  // -------------------------------------------------------------------------
  // Multi-file import
  // -------------------------------------------------------------------------

  describe("multi-file import", () => {
    test("imports all items from a directory", async () => {
      fixtureDir = createFixtureDir({
        "10.md": BACKLOG_ITEM_MD,
        "20.md": EPIC_ITEM_MD,
        "21.md": STORY_ITEM_MD,
        "22.md": STORY_NO_LABELS_MD,
        "23.md": STORY_EMPTY_BODY_MD,
        "24.md": STORY_NULL_PARENT_MD,
      });
      const result = await migrateFromItems(db, fixtureDir);

      expect(result.itemsImported).toBe(6);
      expect(result.filesProcessed).toBe(6);
    });

    test("reports correct filesProcessed count", async () => {
      fixtureDir = createFixtureDir({
        "10.md": BACKLOG_ITEM_MD,
        "20.md": EPIC_ITEM_MD,
      });
      const result = await migrateFromItems(db, fixtureDir);
      expect(result.filesProcessed).toBe(2);
    });
  });
});
