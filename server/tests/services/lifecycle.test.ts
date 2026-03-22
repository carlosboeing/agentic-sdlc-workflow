import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Database } from "bun:sqlite";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { setupTestDb } from "../helpers/setup-db";
import { ItemService } from "../../src/services/items";
import { LifecycleService } from "../../src/services/lifecycle";

describe("LifecycleService", () => {
  let sqlite: Database;
  let db: ReturnType<typeof drizzle>;
  let lifecycleService: LifecycleService;
  let itemService: ItemService;

  beforeEach(async () => {
    const conn = setupTestDb();
    sqlite = conn.sqlite;
    db = conn.db;
    lifecycleService = new LifecycleService(db);
    itemService = new ItemService(db);

    await itemService.create({ id: 1, title: "Test Story", type: "story", status: "ready" });
    await itemService.create({ id: 2, title: "Another Story", type: "story", status: "in-progress" });
  });

  afterEach(() => {
    sqlite.close();
  });

  describe("startWork", () => {
    test("sets status to in-progress", async () => {
      const item = await lifecycleService.startWork(1, {
        agent: "builder",
        model: "sonnet",
      });

      expect(item).not.toBeNull();
      expect(item!.status).toBe("in-progress");
    });

    test("records start event in activity_log", async () => {
      await lifecycleService.startWork(1, {
        agent: "builder",
        model: "sonnet",
      });

      const logs = sqlite
        .query(
          "SELECT * FROM activity_log WHERE item_id = 1 AND event_type = 'status:changed'"
        )
        .all() as { payload: string }[];

      expect(logs.length).toBeGreaterThanOrEqual(1);
      const payload = JSON.parse(logs[0].payload);
      expect(payload.to).toBe("in-progress");
    });

    test("returns null for non-existent item", async () => {
      const result = await lifecycleService.startWork(999, {
        agent: "builder",
        model: "opus",
      });
      expect(result).toBeNull();
    });

    test("includes agent and model in activity log metadata", async () => {
      await lifecycleService.startWork(1, {
        agent: "builder",
        model: "opus",
      });

      const logs = sqlite
        .query(
          "SELECT * FROM activity_log WHERE item_id = 1 AND event_type = 'status:changed'"
        )
        .all() as { payload: string }[];

      const payload = JSON.parse(logs[0].payload);
      expect(payload.agent).toBe("builder");
      expect(payload.model).toBe("opus");
    });
  });

  describe("completeWork", () => {
    test("sets status to in-review", async () => {
      const item = await lifecycleService.completeWork(2, {
        commitHash: "abc123def",
      });

      expect(item).not.toBeNull();
      expect(item!.status).toBe("in-review");
    });

    test("records complete event in activity_log", async () => {
      await lifecycleService.completeWork(2, {
        commitHash: "abc123",
      });

      const logs = sqlite
        .query(
          "SELECT * FROM activity_log WHERE item_id = 2 AND event_type = 'status:changed'"
        )
        .all() as { payload: string }[];

      expect(logs.length).toBeGreaterThanOrEqual(1);
      const lastLog = logs[logs.length - 1];
      const payload = JSON.parse(lastLog.payload);
      expect(payload.to).toBe("in-review");
      expect(payload.commitHash).toBe("abc123");
    });

    test("returns null for non-existent item", async () => {
      const result = await lifecycleService.completeWork(999, {
        commitHash: "abc",
      });
      expect(result).toBeNull();
    });
  });

  describe("postTelemetry", () => {
    test("inserts telemetry row for item", async () => {
      const telemetryRow = await lifecycleService.postTelemetry(1, {
        model: "opus",
        durationMs: 120000,
        tokens: 50000,
        toolUses: 25,
        costEstimate: 1.5,
        commitHash: "abc123",
      });

      expect(telemetryRow.id).toBeGreaterThan(0);
      expect(telemetryRow.itemId).toBe(1);
      expect(telemetryRow.model).toBe("opus");
      expect(telemetryRow.durationMs).toBe(120000);
      expect(telemetryRow.tokens).toBe(50000);
      expect(telemetryRow.toolUses).toBe(25);
      expect(telemetryRow.costEstimate).toBe(1.5);
      expect(telemetryRow.commitHash).toBe("abc123");
    });

    test("broadcasts activity event", async () => {
      await lifecycleService.postTelemetry(1, {
        model: "sonnet",
        durationMs: 60000,
        tokens: 20000,
      });

      const logs = sqlite
        .query(
          "SELECT * FROM activity_log WHERE item_id = 1 AND event_type = 'telemetry:posted'"
        )
        .all() as { payload: string }[];

      expect(logs).toHaveLength(1);
      const payload = JSON.parse(logs[0].payload);
      expect(payload.model).toBe("sonnet");
      expect(payload.durationMs).toBe(60000);
    });

    test("inserts with optional fields as null", async () => {
      const telemetryRow = await lifecycleService.postTelemetry(1, {
        model: "haiku",
        durationMs: 30000,
        tokens: 10000,
      });

      expect(telemetryRow.toolUses).toBeNull();
      expect(telemetryRow.costEstimate).toBeNull();
      expect(telemetryRow.commitHash).toBeNull();
    });

    test("stores metadata as JSON string", async () => {
      const metadata = { breakdown: "test data", summary: "quick run" };
      const telemetryRow = await lifecycleService.postTelemetry(1, {
        model: "opus",
        durationMs: 90000,
        tokens: 40000,
        metadata,
      });

      expect(telemetryRow.metadata).toBe(JSON.stringify(metadata));
    });

    test("throws for non-existent item", async () => {
      await expect(
        lifecycleService.postTelemetry(999, {
          model: "opus",
          durationMs: 1000,
          tokens: 100,
        })
      ).rejects.toThrow();
    });
  });
});
