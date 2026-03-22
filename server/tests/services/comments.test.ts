import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Database } from "bun:sqlite";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { setupTestDb } from "../helpers/setup-db";
import { ItemService } from "../../src/services/items";
import { CommentService } from "../../src/services/comments";

describe("CommentService", () => {
  let sqlite: Database;
  let db: ReturnType<typeof drizzle>;
  let commentService: CommentService;
  let itemService: ItemService;

  beforeEach(async () => {
    const conn = setupTestDb();
    sqlite = conn.sqlite;
    db = conn.db;
    commentService = new CommentService(db);
    itemService = new ItemService(db);

    await itemService.create({ id: 1, title: "Test Story", type: "story" });
    await itemService.create({ id: 2, title: "Another Story", type: "story" });
  });

  afterEach(() => {
    sqlite.close();
  });

  describe("addComment", () => {
    test("creates comment and returns it with generated ID", async () => {
      const comment = await commentService.addComment({
        itemId: 1,
        body: "Work started on this story",
        author: "builder",
      });

      expect(comment.id).toBeGreaterThan(0);
      expect(comment.itemId).toBe(1);
      expect(comment.body).toBe("Work started on this story");
      expect(comment.author).toBe("builder");
      expect(comment.createdAt).toBeTruthy();
      expect(comment.updatedAt).toBeTruthy();
    });

    test("throws when referencing non-existent item", async () => {
      await expect(
        commentService.addComment({
          itemId: 999,
          body: "Orphan comment",
          author: "test",
        })
      ).rejects.toThrow();
    });

    test("creates document comment without itemId", async () => {
      const comment = await commentService.addComment({
        body: "Nice design doc section",
        author: "reviewer",
        documentPath: "docs/2-design/test.md",
        anchor: "overview",
      });

      expect(comment.id).toBeGreaterThan(0);
      expect(comment.itemId).toBeNull();
      expect(comment.documentPath).toBe("docs/2-design/test.md");
      expect(comment.anchor).toBe("overview");
    });

    test("creates threaded comment with threadId", async () => {
      const parent = await commentService.addComment({
        itemId: 1,
        body: "First comment",
        author: "reviewer",
      });

      const reply = await commentService.addComment({
        itemId: 1,
        body: "Reply to first",
        author: "builder",
        threadId: String(parent.id),
      });

      expect(reply.threadId).toBe(String(parent.id));
    });

    test("logs comment creation in activity_log", async () => {
      await commentService.addComment({
        itemId: 1,
        body: "Logged comment",
        author: "orchestrator",
      });

      const logs = sqlite
        .query(
          "SELECT * FROM activity_log WHERE item_id = 1 AND event_type = 'comment:added'"
        )
        .all() as { payload: string }[];

      expect(logs).toHaveLength(1);
    });
  });

  describe("listComments", () => {
    test("returns all comments for an item", async () => {
      await commentService.addComment({
        itemId: 1,
        body: "Comment 1",
        author: "builder",
      });
      await commentService.addComment({
        itemId: 1,
        body: "Comment 2",
        author: "reviewer",
      });
      await commentService.addComment({
        itemId: 2,
        body: "Other item comment",
        author: "builder",
      });

      const comments = await commentService.listComments(1);
      expect(comments).toHaveLength(2);
      expect(comments[0].body).toBe("Comment 1");
      expect(comments[1].body).toBe("Comment 2");
    });

    test("returns empty array for item with no comments", async () => {
      const comments = await commentService.listComments(1);
      expect(comments).toHaveLength(0);
    });

    test("returns empty array for non-existent item", async () => {
      const comments = await commentService.listComments(999);
      expect(comments).toHaveLength(0);
    });
  });
});
