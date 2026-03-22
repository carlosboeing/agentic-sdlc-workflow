import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Database } from "bun:sqlite";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { setupTestDb } from "../helpers/setup-db";
import { ItemService } from "../../src/services/items";
import { HierarchyService } from "../../src/services/hierarchy";

describe("HierarchyService", () => {
  let sqlite: Database;
  let db: ReturnType<typeof drizzle>;
  let hierarchyService: HierarchyService;
  let itemService: ItemService;

  beforeEach(async () => {
    const conn = setupTestDb();
    sqlite = conn.sqlite;
    db = conn.db;
    hierarchyService = new HierarchyService(db);
    itemService = new ItemService(db);

    // Create a backlog -> epic -> story hierarchy
    await itemService.create({ id: 100, title: "Backlog Item", type: "backlog" });
    await itemService.create({ id: 200, title: "Epic 1", type: "epic" });
    await itemService.create({ id: 201, title: "Epic 2", type: "epic" });
    await itemService.create({ id: 300, title: "Story 1", type: "story" });
    await itemService.create({ id: 301, title: "Story 2", type: "story" });
    await itemService.create({ id: 302, title: "Story 3", type: "story" });
  });

  afterEach(() => {
    sqlite.close();
  });

  describe("linkChild", () => {
    test("sets parent_id on the child item", async () => {
      const result = await hierarchyService.linkChild(100, 200);

      expect(result).not.toBeNull();
      expect(result!.parentId).toBe(100);
    });

    test("returns null when parent does not exist", async () => {
      const result = await hierarchyService.linkChild(999, 200);
      expect(result).toBeNull();
    });

    test("returns null when child does not exist", async () => {
      const result = await hierarchyService.linkChild(100, 999);
      expect(result).toBeNull();
    });

    test("logs child link in activity_log", async () => {
      await hierarchyService.linkChild(100, 200);

      const logs = sqlite
        .query(
          "SELECT * FROM activity_log WHERE item_id = 100 AND event_type = 'child:linked'"
        )
        .all() as { payload: string }[];

      expect(logs).toHaveLength(1);
      const payload = JSON.parse(logs[0].payload);
      expect(payload.childId).toBe(200);
    });

    test("overwrites previous parent when re-linking", async () => {
      await hierarchyService.linkChild(200, 300);
      const afterFirst = await itemService.get(300);
      expect(afterFirst!.parentId).toBe(200);

      await hierarchyService.linkChild(201, 300);
      const afterSecond = await itemService.get(300);
      expect(afterSecond!.parentId).toBe(201);
    });
  });

  describe("listChildren", () => {
    test("returns only direct children", async () => {
      await hierarchyService.linkChild(100, 200);
      await hierarchyService.linkChild(100, 201);
      await hierarchyService.linkChild(200, 300);
      await hierarchyService.linkChild(200, 301);

      const children = await hierarchyService.listChildren(100);
      expect(children).toHaveLength(2);
      expect(children.map((c) => c.id).sort()).toEqual([200, 201]);
    });

    test("returns empty array for item with no children", async () => {
      const children = await hierarchyService.listChildren(300);
      expect(children).toHaveLength(0);
    });

    test("returns empty array for non-existent parent", async () => {
      const children = await hierarchyService.listChildren(999);
      expect(children).toHaveLength(0);
    });
  });

  describe("getParent", () => {
    test("returns parent item", async () => {
      await hierarchyService.linkChild(100, 200);
      const parent = await hierarchyService.getParent(200);

      expect(parent).not.toBeNull();
      expect(parent!.id).toBe(100);
      expect(parent!.title).toBe("Backlog Item");
    });

    test("returns null when item has no parent", async () => {
      const parent = await hierarchyService.getParent(100);
      expect(parent).toBeNull();
    });

    test("returns null for non-existent item", async () => {
      const parent = await hierarchyService.getParent(999);
      expect(parent).toBeNull();
    });
  });
});
