import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Database } from "bun:sqlite";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { setupTestDb } from "../helpers/setup-db";
import { ItemService } from "../../src/services/items";
import { BoardService } from "../../src/services/board";

describe("BoardService", () => {
  let sqlite: Database;
  let db: ReturnType<typeof drizzle>;
  let boardService: BoardService;
  let itemService: ItemService;

  beforeEach(async () => {
    const conn = setupTestDb();
    sqlite = conn.sqlite;
    db = conn.db;
    boardService = new BoardService(db);
    itemService = new ItemService(db);

    await itemService.create({ id: 1, title: "Test Story", type: "story" });
  });

  afterEach(() => {
    sqlite.close();
  });

  describe("setStatus", () => {
    test("updates status on existing item", async () => {
      const result = await boardService.setStatus(1, "in-progress");

      expect(result).not.toBeNull();
      expect(result!.status).toBe("in-progress");
    });

    test("validates status value against enum", async () => {
      await expect(
        boardService.setStatus(1, "invalid-status" as never)
      ).rejects.toThrow();
    });

    test("returns null for non-existent item", async () => {
      const result = await boardService.setStatus(999, "ready");
      expect(result).toBeNull();
    });

    test("accepts all valid status values", async () => {
      const statuses = [
        "backlog",
        "ready",
        "in-progress",
        "in-review",
        "done",
      ] as const;

      for (const status of statuses) {
        const result = await boardService.setStatus(1, status);
        expect(result!.status).toBe(status);
      }
    });

    test("logs status change in activity_log", async () => {
      await boardService.setStatus(1, "ready");

      const logs = sqlite
        .query(
          "SELECT * FROM activity_log WHERE item_id = 1 AND event_type = 'status:changed'"
        )
        .all() as { payload: string }[];

      expect(logs).toHaveLength(1);
      const payload = JSON.parse(logs[0].payload);
      expect(payload.from).toBe("backlog");
      expect(payload.to).toBe("ready");
    });
  });

  describe("getStatus", () => {
    test("returns current status of item", async () => {
      const status = await boardService.getStatus(1);
      expect(status).toBe("backlog");
    });

    test("returns null for non-existent item", async () => {
      const status = await boardService.getStatus(999);
      expect(status).toBeNull();
    });

    test("reflects latest status after setStatus", async () => {
      await boardService.setStatus(1, "in-review");
      const status = await boardService.getStatus(1);
      expect(status).toBe("in-review");
    });
  });
});
