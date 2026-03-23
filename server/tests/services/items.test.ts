import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Database } from "bun:sqlite";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { setupTestDb } from "../helpers/setup-db";
import { ItemService } from "../../src/services/items";
import { LabelService } from "../../src/services/labels";

describe("ItemService", () => {
  let sqlite: Database;
  let db: ReturnType<typeof drizzle>;
  let service: ItemService;

  beforeEach(() => {
    const conn = setupTestDb();
    sqlite = conn.sqlite;
    db = conn.db;
    service = new ItemService(db);
  });

  afterEach(() => {
    sqlite.close();
  });

  describe("create", () => {
    test("inserts a row and returns the item with assigned ID", async () => {
      const item = await service.create({
        id: 42,
        title: "Test Backlog Item",
        type: "backlog",
        body: "A test item body",
        createdBy: "planner",
      });

      expect(item.id).toBe(42);
      expect(item.title).toBe("Test Backlog Item");
      expect(item.type).toBe("backlog");
      expect(item.status).toBe("backlog");
      expect(item.state).toBe("open");
      expect(item.body).toBe("A test item body");
      expect(item.createdBy).toBe("planner");
      expect(item.createdAt).toBeTruthy();
      expect(item.updatedAt).toBeTruthy();
    });

    test("creates item with default status 'backlog' and state 'open'", async () => {
      const item = await service.create({
        id: 1,
        title: "Story Item",
        type: "story",
      });

      expect(item.status).toBe("backlog");
      expect(item.state).toBe("open");
    });

    test("creates item with explicit status override", async () => {
      const item = await service.create({
        id: 1,
        title: "Ready Story",
        type: "story",
        status: "ready",
      });

      expect(item.status).toBe("ready");
    });

    test("creates item with parentId linking to existing parent", async () => {
      await service.create({ id: 100, title: "Parent", type: "backlog" });
      const child = await service.create({
        id: 200,
        title: "Child Epic",
        type: "epic",
        parentId: 100,
      });

      expect(child.parentId).toBe(100);
    });

    test("throws when parentId references non-existent item", async () => {
      await expect(
        service.create({
          id: 1,
          title: "Orphan",
          type: "story",
          parentId: 999,
        })
      ).rejects.toThrow();
    });
  });

  describe("get", () => {
    test("returns item by ID", async () => {
      await service.create({ id: 1, title: "Test Item", type: "story" });
      const item = await service.get(1);

      expect(item).not.toBeNull();
      expect(item!.title).toBe("Test Item");
    });

    test("returns null for non-existent item", async () => {
      const item = await service.get(999);
      expect(item).toBeNull();
    });
  });

  describe("list", () => {
    beforeEach(async () => {
      await service.create({ id: 1, title: "Backlog 1", type: "backlog" });
      await service.create({ id: 2, title: "Epic 1", type: "epic", status: "ready" });
      await service.create({ id: 3, title: "Story 1", type: "story", status: "in-progress" });
      await service.create({ id: 4, title: "Story 2", type: "story", status: "done" });
    });

    test("returns all items when no filters", async () => {
      const items = await service.list({});
      expect(items).toHaveLength(4);
    });

    test("filters by type", async () => {
      const stories = await service.list({ type: "story" });
      expect(stories).toHaveLength(2);
      expect(stories.every((i) => i.type === "story")).toBe(true);
    });

    test("filters by status", async () => {
      const inProgress = await service.list({ status: "in-progress" });
      expect(inProgress).toHaveLength(1);
      expect(inProgress[0].title).toBe("Story 1");
    });

    test("filters by state", async () => {
      // Close one item first
      await service.close(4);
      const openItems = await service.list({ state: "open" });
      expect(openItems).toHaveLength(3);

      const closedItems = await service.list({ state: "closed" });
      expect(closedItems).toHaveLength(1);
      expect(closedItems[0].id).toBe(4);
    });

    test("applies limit", async () => {
      const items = await service.list({ limit: 2 });
      expect(items).toHaveLength(2);
    });

    test("combines multiple filters", async () => {
      const items = await service.list({ type: "story", status: "in-progress" });
      expect(items).toHaveLength(1);
      expect(items[0].title).toBe("Story 1");
    });

    test("filters by label", async () => {
      const labelService = new LabelService(db);
      await labelService.addLabelToItem(1, "hierarchy/backlog");
      await labelService.addLabelToItem(2, "hierarchy/epic");
      await labelService.addLabelToItem(3, "hierarchy/story");

      const backlogs = await service.list({ label: "hierarchy/backlog" });
      expect(backlogs).toHaveLength(1);
      expect(backlogs[0].id).toBe(1);
    });

    test("returns empty for non-existent label", async () => {
      const items = await service.list({ label: "nonexistent-label" });
      expect(items).toHaveLength(0);
    });
  });

  describe("update", () => {
    test("updates title and body", async () => {
      await service.create({ id: 1, title: "Original", type: "story" });
      const updated = await service.update(1, {
        title: "Updated Title",
        body: "New body content",
      });

      expect(updated).not.toBeNull();
      expect(updated!.title).toBe("Updated Title");
      expect(updated!.body).toBe("New body content");
    });

    test("returns null when updating non-existent item", async () => {
      const result = await service.update(999, { title: "Ghost" });
      expect(result).toBeNull();
    });

    test("updates updatedAt timestamp", async () => {
      await service.create({ id: 1, title: "Original", type: "story" });
      const original = await service.get(1);

      // Small delay to ensure different timestamp
      await new Promise((r) => setTimeout(r, 10));

      const updated = await service.update(1, { title: "Changed" });
      expect(updated!.updatedAt).not.toBe(original!.updatedAt);
    });
  });

  describe("close", () => {
    test("sets state to closed", async () => {
      await service.create({ id: 1, title: "Open Item", type: "story" });
      const closed = await service.close(1);

      expect(closed).not.toBeNull();
      expect(closed!.state).toBe("closed");
    });

    test("returns null for non-existent item", async () => {
      const result = await service.close(999);
      expect(result).toBeNull();
    });

    test("logs item:closed event in activity_log", async () => {
      await service.create({ id: 1, title: "Closeable Item", type: "story" });
      await service.close(1);

      const logs = sqlite
        .query(
          "SELECT * FROM activity_log WHERE item_id = 1 AND event_type = 'item:closed'"
        )
        .all() as { payload: string }[];

      expect(logs).toHaveLength(1);
      const payload = JSON.parse(logs[0].payload);
      expect(payload.previousState).toBe("open");
    });
  });

  describe("activity log", () => {
    test("create() logs item:created event", async () => {
      await service.create({
        id: 10,
        title: "Logged Item",
        type: "story",
        createdBy: "builder",
      });

      const logs = sqlite
        .query(
          "SELECT * FROM activity_log WHERE item_id = 10 AND event_type = 'item:created'"
        )
        .all() as { payload: string }[];

      expect(logs).toHaveLength(1);
      const payload = JSON.parse(logs[0].payload);
      expect(payload.title).toBe("Logged Item");
      expect(payload.type).toBe("story");
      expect(payload.createdBy).toBe("builder");
    });

    test("update() logs item:updated event", async () => {
      await service.create({ id: 20, title: "Original", type: "story" });
      await service.update(20, { title: "Updated", body: "New body" });

      const logs = sqlite
        .query(
          "SELECT * FROM activity_log WHERE item_id = 20 AND event_type = 'item:updated'"
        )
        .all() as { payload: string }[];

      expect(logs).toHaveLength(1);
      const payload = JSON.parse(logs[0].payload);
      expect(payload.changes).toBeDefined();
      expect(payload.changes.title).toBe("Updated");
      expect(payload.changes.body).toBe("New body");
    });

    test("update() does not log when item not found", async () => {
      await service.update(999, { title: "Ghost" });

      const logs = sqlite
        .query(
          "SELECT * FROM activity_log WHERE event_type = 'item:updated'"
        )
        .all();

      expect(logs).toHaveLength(0);
    });

    test("close() does not log when item not found", async () => {
      await service.close(999);

      const logs = sqlite
        .query(
          "SELECT * FROM activity_log WHERE event_type = 'item:closed'"
        )
        .all();

      expect(logs).toHaveLength(0);
    });
  });
});
