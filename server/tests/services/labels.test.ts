import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Database } from "bun:sqlite";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { setupTestDb } from "../helpers/setup-db";
import { ItemService } from "../../src/services/items";
import { LabelService } from "../../src/services/labels";

describe("LabelService", () => {
  let sqlite: Database;
  let db: ReturnType<typeof drizzle>;
  let labelService: LabelService;
  let itemService: ItemService;

  beforeEach(async () => {
    const conn = setupTestDb();
    sqlite = conn.sqlite;
    db = conn.db;
    labelService = new LabelService(db);
    itemService = new ItemService(db);

    await itemService.create({ id: 1, title: "Test Story", type: "story" });
    await itemService.create({ id: 2, title: "Another Story", type: "story" });
  });

  afterEach(() => {
    sqlite.close();
  });

  describe("createLabel", () => {
    test("creates a label and returns it with generated ID", async () => {
      const label = await labelService.createLabel({
        name: "difficulty/hard",
        color: "#ff0000",
        description: "Hard difficulty",
      });

      expect(label.id).toBeGreaterThan(0);
      expect(label.name).toBe("difficulty/hard");
      expect(label.color).toBe("#ff0000");
      expect(label.description).toBe("Hard difficulty");
    });

    test("creates label with name only", async () => {
      const label = await labelService.createLabel({
        name: "hierarchy/story",
      });

      expect(label.name).toBe("hierarchy/story");
      expect(label.color).toBeNull();
      expect(label.description).toBeNull();
    });

    test("throws on duplicate label name", async () => {
      await labelService.createLabel({ name: "unique-label" });

      await expect(
        labelService.createLabel({ name: "unique-label" })
      ).rejects.toThrow();
    });
  });

  describe("listLabels", () => {
    test("returns all labels", async () => {
      await labelService.createLabel({ name: "label-a" });
      await labelService.createLabel({ name: "label-b" });
      await labelService.createLabel({ name: "label-c" });

      const labels = await labelService.listLabels();
      expect(labels).toHaveLength(3);
    });

    test("returns empty array when no labels exist", async () => {
      const labels = await labelService.listLabels();
      expect(labels).toHaveLength(0);
    });
  });

  describe("addLabelToItem", () => {
    test("creates the label if it does not exist (upsert)", async () => {
      // Label does not exist yet
      await labelService.addLabelToItem(1, "new-label");

      const labels = await labelService.listLabels();
      expect(labels).toHaveLength(1);
      expect(labels[0].name).toBe("new-label");
    });

    test("uses existing label when it already exists", async () => {
      await labelService.createLabel({
        name: "existing-label",
        color: "#00ff00",
      });
      await labelService.addLabelToItem(1, "existing-label");

      const labels = await labelService.listLabels();
      expect(labels).toHaveLength(1);
      expect(labels[0].color).toBe("#00ff00");
    });

    test("returns the item-label association", async () => {
      const result = await labelService.addLabelToItem(1, "test-label");

      expect(result.itemId).toBe(1);
      expect(result.labelId).toBeGreaterThan(0);
    });

    test("is idempotent for same item-label pair", async () => {
      await labelService.addLabelToItem(1, "test-label");
      // Adding the same label again should not throw
      const result = await labelService.addLabelToItem(1, "test-label");
      expect(result.itemId).toBe(1);

      // Verify only one association exists
      const labelsOnItem = await labelService.getLabelsForItem(1);
      expect(labelsOnItem).toHaveLength(1);
    });

    test("adds multiple labels to same item", async () => {
      await labelService.addLabelToItem(1, "hierarchy/story");
      await labelService.addLabelToItem(1, "difficulty/hard");
      await labelService.addLabelToItem(1, "type/feature");

      const labelsOnItem = await labelService.getLabelsForItem(1);
      expect(labelsOnItem).toHaveLength(3);
    });

    test("logs label addition in activity_log", async () => {
      await labelService.addLabelToItem(1, "test-label");

      const logs = sqlite
        .query(
          "SELECT * FROM activity_log WHERE item_id = 1 AND event_type = 'label:added'"
        )
        .all() as { payload: string }[];

      expect(logs).toHaveLength(1);
      const payload = JSON.parse(logs[0].payload);
      expect(payload.label).toBe("test-label");
    });
  });

  describe("getLabelsForItem", () => {
    test("returns labels for a specific item", async () => {
      await labelService.addLabelToItem(1, "label-a");
      await labelService.addLabelToItem(1, "label-b");
      await labelService.addLabelToItem(2, "label-c");

      const labels = await labelService.getLabelsForItem(1);
      expect(labels).toHaveLength(2);
      expect(labels.map((l) => l.name).sort()).toEqual(["label-a", "label-b"]);
    });

    test("returns empty array for item with no labels", async () => {
      const labels = await labelService.getLabelsForItem(1);
      expect(labels).toHaveLength(0);
    });
  });
});
