import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Database } from "bun:sqlite";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { eq } from "drizzle-orm";
import { setupTestDb } from "../helpers/setup-db";
import { DatabaseUpserter, type MappedIssue } from "../../src/services/database-upserter";
import * as schema from "../../src/db/schema";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeMappedIssue(overrides: Partial<MappedIssue> = {}): MappedIssue {
  return {
    item: {
      id: 1,
      title: "Test Story",
      body: "Story body",
      type: "story",
      status: "backlog",
      state: "open",
      externalId: "1",
      externalUrl: "https://github.com/owner/repo/issues/1",
      createdAt: "2026-03-01T00:00:00Z",
      updatedAt: "2026-03-01T00:00:00Z",
    },
    labels: [],
    parentNumber: null,
    comments: [],
    ...overrides,
  };
}

describe("DatabaseUpserter", () => {
  let sqlite: Database;
  let db: ReturnType<typeof drizzle>;
  let upserter: DatabaseUpserter;

  beforeEach(() => {
    const conn = setupTestDb();
    sqlite = conn.sqlite;
    db = conn.db;
    upserter = new DatabaseUpserter(db);
  });

  afterEach(() => {
    sqlite.close();
  });

  // -------------------------------------------------------------------------
  // Item insert
  // -------------------------------------------------------------------------

  describe("upsertPage - item insert", () => {
    test("inserts a new item with all columns", async () => {
      const issue = makeMappedIssue({
        item: {
          id: 42,
          title: "My Story",
          body: "Story description",
          type: "story",
          status: "ready",
          state: "open",
          externalId: "42",
          externalUrl: "https://github.com/owner/repo/issues/42",
          createdAt: "2026-03-01T10:00:00Z",
          updatedAt: "2026-03-02T10:00:00Z",
        },
        labels: [],
        parentNumber: null,
        comments: [],
      });

      const result = await upserter.upsertPage([issue]);

      expect(result.itemsCreated).toBe(1);
      expect(result.itemsUpdated).toBe(0);

      const rows = db.select().from(schema.items).all();
      expect(rows).toHaveLength(1);
      expect(rows[0].id).toBe(42);
      expect(rows[0].title).toBe("My Story");
      expect(rows[0].body).toBe("Story description");
      expect(rows[0].type).toBe("story");
      expect(rows[0].status).toBe("ready");
      expect(rows[0].state).toBe("open");
      expect(rows[0].externalId).toBe("42");
      expect(rows[0].externalUrl).toBe("https://github.com/owner/repo/issues/42");
      expect(rows[0].createdAt).toBe("2026-03-01T10:00:00Z");
      expect(rows[0].updatedAt).toBe("2026-03-02T10:00:00Z");
    });

    test("inserts multiple items in a single call", async () => {
      const issues = [
        makeMappedIssue({ item: { ...makeMappedIssue().item, id: 1, title: "Item 1" } }),
        makeMappedIssue({ item: { ...makeMappedIssue().item, id: 2, title: "Item 2" } }),
        makeMappedIssue({ item: { ...makeMappedIssue().item, id: 3, title: "Item 3" } }),
      ];

      const result = await upserter.upsertPage(issues);

      expect(result.itemsCreated).toBe(3);
      expect(result.itemsUpdated).toBe(0);
      const rows = db.select().from(schema.items).all();
      expect(rows).toHaveLength(3);
    });
  });

  // -------------------------------------------------------------------------
  // Item update (upsert on conflict)
  // -------------------------------------------------------------------------

  describe("upsertPage - item update", () => {
    test("updates existing item on conflict", async () => {
      // Insert initial item
      const initial = makeMappedIssue({
        item: {
          id: 10,
          title: "Original Title",
          body: "Original body",
          type: "story",
          status: "backlog",
          state: "open",
          externalId: "10",
          externalUrl: "https://github.com/owner/repo/issues/10",
          createdAt: "2026-03-01T00:00:00Z",
          updatedAt: "2026-03-01T00:00:00Z",
        },
        labels: [],
        parentNumber: null,
        comments: [],
      });
      await upserter.upsertPage([initial]);

      // Upsert with updated fields
      const updated = makeMappedIssue({
        item: {
          id: 10,
          title: "Updated Title",
          body: "Updated body",
          type: "story",
          status: "in-progress",
          state: "open",
          externalId: "10",
          externalUrl: "https://github.com/owner/repo/issues/10",
          createdAt: "2026-03-01T00:00:00Z",
          updatedAt: "2026-03-02T00:00:00Z",
        },
        labels: [],
        parentNumber: null,
        comments: [],
      });
      const result = await upserter.upsertPage([updated]);

      expect(result.itemsCreated).toBe(0);
      expect(result.itemsUpdated).toBe(1);

      const rows = db.select().from(schema.items).where(eq(schema.items.id, 10)).all();
      expect(rows[0].title).toBe("Updated Title");
      expect(rows[0].body).toBe("Updated body");
      expect(rows[0].status).toBe("in-progress");
      expect(rows[0].updatedAt).toBe("2026-03-02T00:00:00Z");
    });

    test("createdBy is preserved when local value is non-null and GitHub value is null", async () => {
      // Insert item with createdBy set locally
      db.insert(schema.items).values({
        id: 20,
        title: "Existing Item",
        body: null,
        type: "story",
        status: "backlog",
        state: "open",
        externalId: "20",
        externalUrl: "https://github.com/owner/repo/issues/20",
        createdBy: "planner",
        createdAt: "2026-03-01T00:00:00Z",
        updatedAt: "2026-03-01T00:00:00Z",
      }).run();

      // Upsert with GitHub data (no createdBy available from GitHub)
      const githubIssue = makeMappedIssue({
        item: {
          id: 20,
          title: "Updated Title from GitHub",
          body: "Updated body",
          type: "story",
          status: "in-progress",
          state: "open",
          externalId: "20",
          externalUrl: "https://github.com/owner/repo/issues/20",
          createdAt: "2026-03-01T00:00:00Z",
          updatedAt: "2026-03-02T00:00:00Z",
        },
        labels: [],
        parentNumber: null,
        comments: [],
      });

      await upserter.upsertPage([githubIssue]);

      const rows = db.select().from(schema.items).where(eq(schema.items.id, 20)).all();
      expect(rows[0].title).toBe("Updated Title from GitHub");
      expect(rows[0].status).toBe("in-progress");
      // createdBy is preserved from local
      expect(rows[0].createdBy).toBe("planner");
    });

    test("createdBy is null for new item (GitHub does not provide it)", async () => {
      const issue = makeMappedIssue({ item: { ...makeMappedIssue().item, id: 30 } });
      await upserter.upsertPage([issue]);

      const rows = db.select().from(schema.items).where(eq(schema.items.id, 30)).all();
      expect(rows[0].createdBy).toBeNull();
    });
  });

  // -------------------------------------------------------------------------
  // Label reconciliation
  // -------------------------------------------------------------------------

  describe("upsertPage - label reconciliation", () => {
    test("creates labels in labels table if they do not exist", async () => {
      const issue = makeMappedIssue({
        item: { ...makeMappedIssue().item, id: 1 },
        labels: ["hierarchy/story", "difficulty/easy"],
      });

      await upserter.upsertPage([issue]);

      const labelRows = db.select().from(schema.labels).all();
      const labelNames = labelRows.map((l) => l.name);
      expect(labelNames).toContain("hierarchy/story");
      expect(labelNames).toContain("difficulty/easy");
    });

    test("creates item_labels associations for new labels", async () => {
      const issue = makeMappedIssue({
        item: { ...makeMappedIssue().item, id: 1 },
        labels: ["hierarchy/story", "difficulty/easy"],
      });
      await upserter.upsertPage([issue]);
      const result2 = await upserter.upsertPage([issue]);

      // Labels already exist — no new labels created
      expect(result2.labelsCreated).toBe(0);

      const assocs = db.select().from(schema.itemLabels)
        .where(eq(schema.itemLabels.itemId, 1))
        .all();
      expect(assocs).toHaveLength(2);
    });

    test("full replace: removes old labels and adds new ones", async () => {
      // First sync: item has labels A and B
      const first = makeMappedIssue({
        item: { ...makeMappedIssue().item, id: 1 },
        labels: ["label-a", "label-b"],
      });
      await upserter.upsertPage([first]);

      // Second sync: item now has labels B and C (A was removed, C was added)
      const second = makeMappedIssue({
        item: { ...makeMappedIssue().item, id: 1 },
        labels: ["label-b", "label-c"],
      });
      await upserter.upsertPage([second]);

      // item_labels should only contain B and C
      const labelRows = db.select().from(schema.labels).all();
      const labelIds = Object.fromEntries(labelRows.map((l) => [l.name, l.id]));

      const assocs = db.select().from(schema.itemLabels)
        .where(eq(schema.itemLabels.itemId, 1))
        .all();

      const assocLabelIds = assocs.map((a) => a.labelId);
      expect(assocLabelIds).toContain(labelIds["label-b"]);
      expect(assocLabelIds).toContain(labelIds["label-c"]);
      expect(assocLabelIds).not.toContain(labelIds["label-a"]);
      expect(assocs).toHaveLength(2);
    });

    test("reports labelsCreated count for new labels only", async () => {
      // Create label-a beforehand
      db.insert(schema.labels).values({ name: "label-a" }).run();

      const issue = makeMappedIssue({
        item: { ...makeMappedIssue().item, id: 1 },
        labels: ["label-a", "label-b"],
      });
      const result = await upserter.upsertPage([issue]);

      // Only label-b is new
      expect(result.labelsCreated).toBe(1);
    });
  });

  // -------------------------------------------------------------------------
  // Comment dedup
  // -------------------------------------------------------------------------

  describe("upsertPage - comment dedup", () => {
    test("inserts new comments", async () => {
      const issue = makeMappedIssue({
        item: { ...makeMappedIssue().item, id: 1 },
        comments: [
          {
            body: "First comment",
            author: "alice",
            createdAt: "2026-03-01T10:00:00Z",
            updatedAt: "2026-03-01T10:00:00Z",
          },
          {
            body: "Second comment",
            author: "bob",
            createdAt: "2026-03-02T10:00:00Z",
            updatedAt: "2026-03-02T10:00:00Z",
          },
        ],
      });

      const result = await upserter.upsertPage([issue]);

      expect(result.commentsCreated).toBe(2);
      expect(result.commentsUpdated).toBe(0);

      const commentRows = db.select().from(schema.comments)
        .where(eq(schema.comments.itemId, 1))
        .all();
      expect(commentRows).toHaveLength(2);
    });

    test("dedup by (itemId, createdAt, author): same key -> update body and updatedAt", async () => {
      // First sync: comment with body "version 1"
      const first = makeMappedIssue({
        item: { ...makeMappedIssue().item, id: 1 },
        comments: [
          {
            body: "version 1",
            author: "alice",
            createdAt: "2026-03-01T10:00:00Z",
            updatedAt: "2026-03-01T10:00:00Z",
          },
        ],
      });
      await upserter.upsertPage([first]);

      // Second sync: same comment (same author + createdAt) with updated body
      const second = makeMappedIssue({
        item: { ...makeMappedIssue().item, id: 1 },
        comments: [
          {
            body: "version 2",
            author: "alice",
            createdAt: "2026-03-01T10:00:00Z",
            updatedAt: "2026-03-01T11:00:00Z",
          },
        ],
      });
      const result = await upserter.upsertPage([second]);

      expect(result.commentsCreated).toBe(0);
      expect(result.commentsUpdated).toBe(1);

      // Only one comment row should exist
      const commentRows = db.select().from(schema.comments)
        .where(eq(schema.comments.itemId, 1))
        .all();
      expect(commentRows).toHaveLength(1);
      expect(commentRows[0].body).toBe("version 2");
      expect(commentRows[0].updatedAt).toBe("2026-03-01T11:00:00Z");
    });

    test("different (itemId, createdAt, author) -> inserts as new comment", async () => {
      const first = makeMappedIssue({
        item: { ...makeMappedIssue().item, id: 1 },
        comments: [
          {
            body: "First comment",
            author: "alice",
            createdAt: "2026-03-01T10:00:00Z",
            updatedAt: "2026-03-01T10:00:00Z",
          },
        ],
      });
      await upserter.upsertPage([first]);

      const second = makeMappedIssue({
        item: { ...makeMappedIssue().item, id: 1 },
        comments: [
          {
            body: "First comment",
            author: "alice",
            createdAt: "2026-03-01T10:00:00Z",
            updatedAt: "2026-03-01T10:00:00Z",
          },
          {
            body: "Second comment by alice",
            author: "alice",
            createdAt: "2026-03-02T10:00:00Z",  // different createdAt
            updatedAt: "2026-03-02T10:00:00Z",
          },
        ],
      });
      const result = await upserter.upsertPage([second]);

      // One comment was updated (same key), one was new
      expect(result.commentsCreated).toBe(1);
      expect(result.commentsUpdated).toBe(1);

      const commentRows = db.select().from(schema.comments)
        .where(eq(schema.comments.itemId, 1))
        .all();
      expect(commentRows).toHaveLength(2);
    });
  });

  // -------------------------------------------------------------------------
  // Hierarchy linking
  // -------------------------------------------------------------------------

  describe("linkHierarchy", () => {
    test("sets parentId from parent map", async () => {
      // Insert parent and child items
      await upserter.upsertPage([
        makeMappedIssue({
          item: { ...makeMappedIssue().item, id: 100, title: "Parent Backlog", type: "backlog" },
        }),
        makeMappedIssue({
          item: { ...makeMappedIssue().item, id: 200, title: "Child Epic", type: "epic" },
        }),
        makeMappedIssue({
          item: { ...makeMappedIssue().item, id: 300, title: "Child Story", type: "story" },
        }),
      ]);

      // Link hierarchy: child 200 -> parent 100, child 300 -> parent 100
      const parentMap = new Map<number, number>([
        [200, 100],
        [300, 100],
      ]);
      const linkedCount = await upserter.linkHierarchy(parentMap);

      expect(linkedCount).toBe(2);

      const rows = db.select().from(schema.items).all();
      const itemMap = Object.fromEntries(rows.map((r) => [r.id, r]));

      expect(itemMap[200].parentId).toBe(100);
      expect(itemMap[300].parentId).toBe(100);
      expect(itemMap[100].parentId).toBeNull();
    });

    test("linkHierarchy with empty map -> no updates, returns 0", async () => {
      await upserter.upsertPage([makeMappedIssue({ item: { ...makeMappedIssue().item, id: 1 } })]);
      const count = await upserter.linkHierarchy(new Map());
      expect(count).toBe(0);
    });

    test("linkHierarchy runs in single transaction (all-or-nothing)", async () => {
      // Insert only the child, not the parent
      // With FK constraints on, this should fail when trying to set parentId to non-existent 999
      await upserter.upsertPage([
        makeMappedIssue({ item: { ...makeMappedIssue().item, id: 50, title: "Child" } }),
      ]);

      const parentMap = new Map<number, number>([[50, 999]]); // 999 does not exist
      await expect(upserter.linkHierarchy(parentMap)).rejects.toThrow();

      // Verify the child still has no parentId (transaction rolled back)
      const rows = db.select().from(schema.items).where(eq(schema.items.id, 50)).all();
      expect(rows[0].parentId).toBeNull();
    });
  });

  // -------------------------------------------------------------------------
  // Transaction atomicity
  // -------------------------------------------------------------------------

  describe("upsertPage - transaction atomicity", () => {
    test("all items in page are inserted in single transaction", async () => {
      // If any single item fails, all should be rolled back
      // We test the happy path here: all items present after successful call
      const issues = Array.from({ length: 5 }, (_, i) =>
        makeMappedIssue({
          item: { ...makeMappedIssue().item, id: i + 1, title: `Item ${i + 1}` },
        })
      );

      await upserter.upsertPage(issues);

      const rows = db.select().from(schema.items).all();
      expect(rows).toHaveLength(5);
    });

    test("empty page -> returns zero counts", async () => {
      const result = await upserter.upsertPage([]);

      expect(result.itemsCreated).toBe(0);
      expect(result.itemsUpdated).toBe(0);
      expect(result.labelsCreated).toBe(0);
      expect(result.commentsCreated).toBe(0);
      expect(result.commentsUpdated).toBe(0);
    });
  });
});
