import { describe, test, expect, beforeEach, afterEach, mock } from "bun:test";
import { Database } from "bun:sqlite";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { setupTestDb } from "../helpers/setup-db";
import { SyncService } from "../../src/services/sync";
import { SyncWorker } from "../../src/services/sync-worker";
import type {
  ExternalPmAdapter,
  SyncCreatePayload,
  SyncCommentPayload,
  SyncSetStatusPayload,
} from "../../src/types/sync";
import type { SyncOperation } from "../../src/types";

// ---------------------------------------------------------------------------
// Mock external adapter factory
// ---------------------------------------------------------------------------

function createMockAdapter(overrides: Partial<ExternalPmAdapter> = {}): ExternalPmAdapter {
  return {
    createItem: mock(() => Promise.resolve({ externalId: "ext-1", url: "https://example.com/1" })),
    updateItem: mock(() => Promise.resolve()),
    closeItem: mock(() => Promise.resolve()),
    setStatus: mock(() => Promise.resolve()),
    addComment: mock(() => Promise.resolve()),
    linkChild: mock(() => Promise.resolve()),
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// SyncService tests
// ---------------------------------------------------------------------------

describe("SyncService", () => {
  let sqlite: Database;
  let db: ReturnType<typeof drizzle>;
  let service: SyncService;
  let adapter: ExternalPmAdapter;

  beforeEach(() => {
    const conn = setupTestDb();
    sqlite = conn.sqlite;
    db = conn.db;
    adapter = createMockAdapter();
    service = new SyncService(db, adapter);
  });

  afterEach(() => {
    sqlite.close();
  });

  describe("enqueue", () => {
    test("inserts a pending operation into sync_queue", async () => {
      const payload: SyncCreatePayload = {
        itemId: 42,
        title: "Test Item",
        type: "story",
      };

      const entry = await service.enqueue("create", payload, { itemId: 42 });

      expect(entry.id).toBeGreaterThan(0);
      expect(entry.operation).toBe("create");
      expect(entry.status).toBe("pending");
      expect(entry.retryCount).toBe(0);
      expect(entry.lastError).toBeNull();
      expect(entry.createdAt).toBeTruthy();
      expect(entry.processedAt).toBeNull();
    });

    test("stores the payload as JSON string", async () => {
      const payload: SyncCreatePayload = {
        itemId: 42,
        title: "Test Item",
        type: "story",
        body: "Some body",
      };

      const entry = await service.enqueue("create", payload, { itemId: 42 });
      const parsed = JSON.parse(entry.payload);

      expect(parsed.itemId).toBe(42);
      expect(parsed.title).toBe("Test Item");
      expect(parsed.body).toBe("Some body");
    });

    test("generates an idempotency key", async () => {
      const payload: SyncCreatePayload = {
        itemId: 42,
        title: "Test Item",
        type: "story",
      };

      const entry = await service.enqueue("create", payload, { itemId: 42 });

      expect(entry.idempotencyKey).toBeTruthy();
      expect(typeof entry.idempotencyKey).toBe("string");
    });

    test("rejects duplicate idempotency keys", async () => {
      const payload: SyncCreatePayload = {
        itemId: 42,
        title: "Test Item",
        type: "story",
      };

      const first = await service.enqueue("create", payload, {
        itemId: 42,
        idempotencyKey: "unique-key-1",
      });

      const duplicate = await service.enqueue("create", payload, {
        itemId: 42,
        idempotencyKey: "unique-key-1",
      });

      // Duplicate returns the existing entry without creating a new one
      expect(duplicate.id).toBe(first.id);
    });

    test("stores item_id for per-item ordering", async () => {
      const payload: SyncCommentPayload = {
        itemId: 42,
        externalId: "ext-42",
        body: "A comment",
        author: "builder",
      };

      const entry = await service.enqueue("comment", payload, { itemId: 42 });

      expect(entry.itemId).toBe(42);
    });

    test("enqueues multiple operations for the same item", async () => {
      await service.enqueue(
        "comment",
        { itemId: 10, externalId: "ext-10", body: "First", author: "builder" } as SyncCommentPayload,
        { itemId: 10 }
      );
      await service.enqueue(
        "comment",
        { itemId: 10, externalId: "ext-10", body: "Second", author: "builder" } as SyncCommentPayload,
        { itemId: 10 }
      );

      const pending = await service.getPendingOperations();
      expect(pending).toHaveLength(2);
    });
  });

  describe("processQueue", () => {
    test("processes a pending operation and marks it success", async () => {
      const payload: SyncCreatePayload = {
        itemId: 42,
        title: "Test Item",
        type: "story",
      };

      await service.enqueue("create", payload, { itemId: 42 });
      const processed = await service.processQueue();

      expect(processed).toBe(1);

      const all = await service.getAllOperations();
      expect(all[0].status).toBe("success");
      expect(all[0].processedAt).toBeTruthy();
    });

    test("calls the correct adapter method for each operation type", async () => {
      await service.enqueue(
        "create",
        { itemId: 1, title: "Item", type: "story" } as SyncCreatePayload,
        { itemId: 1 }
      );
      await service.enqueue(
        "set_status",
        { itemId: 2, externalId: "ext-2", status: "in-progress" } as SyncSetStatusPayload,
        { itemId: 2 }
      );

      await service.processQueue();

      expect(adapter.createItem).toHaveBeenCalledTimes(1);
      expect(adapter.setStatus).toHaveBeenCalledTimes(1);
    });

    test("marks failed operations with error and increments retry count", async () => {
      const failAdapter = createMockAdapter({
        createItem: mock(() => Promise.reject(new Error("Network error"))),
      });
      const failService = new SyncService(db, failAdapter);

      await failService.enqueue(
        "create",
        { itemId: 42, title: "Fail Item", type: "story" } as SyncCreatePayload,
        { itemId: 42 }
      );

      await failService.processQueue();

      const all = await failService.getAllOperations();
      expect(all[0].status).toBe("pending");
      expect(all[0].retryCount).toBe(1);
      expect(all[0].lastError).toBe("Network error");
    });

    test("processes operations in insertion order per item_id", async () => {
      const callOrder: string[] = [];
      const orderAdapter = createMockAdapter({
        addComment: mock(async (payload: SyncCommentPayload) => {
          callOrder.push(payload.body);
        }),
      });
      const orderService = new SyncService(db, orderAdapter);

      await orderService.enqueue(
        "comment",
        { itemId: 10, externalId: "ext-10", body: "First", author: "builder" } as SyncCommentPayload,
        { itemId: 10 }
      );
      await orderService.enqueue(
        "comment",
        { itemId: 10, externalId: "ext-10", body: "Second", author: "builder" } as SyncCommentPayload,
        { itemId: 10 }
      );
      await orderService.enqueue(
        "comment",
        { itemId: 10, externalId: "ext-10", body: "Third", author: "builder" } as SyncCommentPayload,
        { itemId: 10 }
      );

      await orderService.processQueue();

      expect(callOrder).toEqual(["First", "Second", "Third"]);
    });

    test("does not skip ahead on per-item queue when earlier op is pending", async () => {
      let callCount = 0;
      const halfFailAdapter = createMockAdapter({
        addComment: mock(async () => {
          callCount++;
          if (callCount === 1) {
            throw new Error("Temporary failure");
          }
        }),
      });
      const halfFailService = new SyncService(db, halfFailAdapter);

      // Enqueue two comments for same item
      await halfFailService.enqueue(
        "comment",
        { itemId: 10, externalId: "ext-10", body: "First", author: "builder" } as SyncCommentPayload,
        { itemId: 10 }
      );
      await halfFailService.enqueue(
        "comment",
        { itemId: 10, externalId: "ext-10", body: "Second", author: "builder" } as SyncCommentPayload,
        { itemId: 10 }
      );

      // First processQueue: first op fails, second should NOT be processed
      await halfFailService.processQueue();

      const ops = await halfFailService.getAllOperations();
      const first = ops.find((o) => JSON.parse(o.payload).body === "First");
      const second = ops.find((o) => JSON.parse(o.payload).body === "Second");

      expect(first!.retryCount).toBe(1);
      expect(second!.status).toBe("pending");
      expect(second!.retryCount).toBe(0);
    });
  });

  describe("retry and backoff", () => {
    test("uses exponential backoff: 1s, 2s, 4s, 8s, max 60s", () => {
      expect(SyncService.computeBackoff(0)).toBe(1000);
      expect(SyncService.computeBackoff(1)).toBe(2000);
      expect(SyncService.computeBackoff(2)).toBe(4000);
      expect(SyncService.computeBackoff(3)).toBe(8000);
      expect(SyncService.computeBackoff(4)).toBe(16000);
      // After 5 retries it caps at 60s
      expect(SyncService.computeBackoff(10)).toBe(60000);
    });

    test("dead-letters after 5 retries", async () => {
      const alwaysFailAdapter = createMockAdapter({
        createItem: mock(() => Promise.reject(new Error("Persistent failure"))),
      });
      const failService = new SyncService(db, alwaysFailAdapter, { maxRetries: 5 });

      await failService.enqueue(
        "create",
        { itemId: 42, title: "Doomed Item", type: "story" } as SyncCreatePayload,
        { itemId: 42 }
      );

      // Process 5 times to exhaust retries
      for (let i = 0; i < 5; i++) {
        await failService.processQueue();
      }

      const all = await failService.getAllOperations();
      expect(all[0].status).toBe("dead_letter");
      expect(all[0].retryCount).toBe(5);
    });

    test("does not process dead-lettered operations", async () => {
      const alwaysFailAdapter = createMockAdapter({
        createItem: mock(() => Promise.reject(new Error("Persistent failure"))),
      });
      const failService = new SyncService(db, alwaysFailAdapter, { maxRetries: 5 });

      await failService.enqueue(
        "create",
        { itemId: 42, title: "Doomed Item", type: "story" } as SyncCreatePayload,
        { itemId: 42 }
      );

      // Exhaust retries
      for (let i = 0; i < 5; i++) {
        await failService.processQueue();
      }

      // One more process should not touch it
      const processed = await failService.processQueue();
      expect(processed).toBe(0);
      expect(alwaysFailAdapter.createItem).toHaveBeenCalledTimes(5);
    });

    test("skips operations still in backoff period", async () => {
      const failOnceAdapter = createMockAdapter({
        createItem: mock(() => Promise.reject(new Error("Temporary"))),
      });
      const backoffService = new SyncService(db, failOnceAdapter);

      await backoffService.enqueue(
        "create",
        { itemId: 42, title: "Backoff Item", type: "story" } as SyncCreatePayload,
        { itemId: 42 }
      );

      // First attempt fails and sets retry_count to 1
      await backoffService.processQueue();

      // Immediately try again - should skip due to backoff
      const processed = await backoffService.processQueue();
      expect(processed).toBe(0);
    });
  });

  describe("idempotency", () => {
    test("custom idempotency key prevents duplicate enqueue", async () => {
      const payload: SyncCreatePayload = {
        itemId: 42,
        title: "Test Item",
        type: "story",
      };

      const first = await service.enqueue("create", payload, {
        itemId: 42,
        idempotencyKey: "create-42",
      });
      const second = await service.enqueue("create", payload, {
        itemId: 42,
        idempotencyKey: "create-42",
      });

      expect(second.id).toBe(first.id);

      const all = await service.getAllOperations();
      expect(all).toHaveLength(1);
    });

    test("different idempotency keys create separate entries", async () => {
      const payload: SyncCreatePayload = {
        itemId: 42,
        title: "Test Item",
        type: "story",
      };

      await service.enqueue("create", payload, {
        itemId: 42,
        idempotencyKey: "key-a",
      });
      await service.enqueue("create", payload, {
        itemId: 42,
        idempotencyKey: "key-b",
      });

      const all = await service.getAllOperations();
      expect(all).toHaveLength(2);
    });
  });

  describe("getPendingOperations", () => {
    test("returns only pending operations", async () => {
      await service.enqueue(
        "create",
        { itemId: 1, title: "Item 1", type: "story" } as SyncCreatePayload,
        { itemId: 1 }
      );
      await service.enqueue(
        "create",
        { itemId: 2, title: "Item 2", type: "story" } as SyncCreatePayload,
        { itemId: 2 }
      );

      // Process first one (marks it success)
      await service.processQueue();

      const pending = await service.getPendingOperations();
      // After processing, one should still be pending (we process both in one pass)
      // Actually both get processed in one pass since they have different item_ids
      expect(pending).toHaveLength(0);
    });
  });

  describe("getQueueStatus", () => {
    test("returns counts by status", async () => {
      await service.enqueue(
        "create",
        { itemId: 1, title: "Item 1", type: "story" } as SyncCreatePayload,
        { itemId: 1 }
      );
      await service.enqueue(
        "create",
        { itemId: 2, title: "Item 2", type: "story" } as SyncCreatePayload,
        { itemId: 2 }
      );

      const status = await service.getQueueStatus();
      expect(status.pending).toBe(2);
      expect(status.success).toBe(0);
      expect(status.failed).toBe(0);
      expect(status.dead_letter).toBe(0);
    });
  });
});

// ---------------------------------------------------------------------------
// SyncWorker tests
// ---------------------------------------------------------------------------

describe("SyncWorker", () => {
  let sqlite: Database;
  let db: ReturnType<typeof drizzle>;
  let adapter: ExternalPmAdapter;

  beforeEach(() => {
    const conn = setupTestDb();
    sqlite = conn.sqlite;
    db = conn.db;
    adapter = createMockAdapter();
  });

  afterEach(() => {
    sqlite.close();
  });

  test("can be started and stopped cleanly", async () => {
    const worker = new SyncWorker(db, adapter, { pollIntervalMs: 50 });

    worker.start();
    expect(worker.isRunning()).toBe(true);

    await worker.stop();
    expect(worker.isRunning()).toBe(false);
  });

  test("processes enqueued operations on poll", async () => {
    const syncService = new SyncService(db, adapter);
    await syncService.enqueue(
      "create",
      { itemId: 42, title: "Worker Test", type: "story" } as SyncCreatePayload,
      { itemId: 42 }
    );

    const worker = new SyncWorker(db, adapter, { pollIntervalMs: 50 });
    worker.start();

    // Wait for at least one poll cycle
    await new Promise((r) => setTimeout(r, 150));

    await worker.stop();

    const all = await syncService.getAllOperations();
    expect(all[0].status).toBe("success");
  });

  test("stop() waits for in-flight processing to complete", async () => {
    let resolveProcessing: () => void;
    const processingPromise = new Promise<void>((r) => {
      resolveProcessing = r;
    });

    const slowAdapter = createMockAdapter({
      createItem: mock(async () => {
        await processingPromise;
        return { externalId: "ext-1", url: "https://example.com/1" };
      }),
    });

    const syncService = new SyncService(db, slowAdapter);
    await syncService.enqueue(
      "create",
      { itemId: 42, title: "Slow Item", type: "story" } as SyncCreatePayload,
      { itemId: 42 }
    );

    const worker = new SyncWorker(db, slowAdapter, { pollIntervalMs: 50 });
    worker.start();

    // Wait for poll to start processing
    await new Promise((r) => setTimeout(r, 100));

    // Start stop (should wait for in-flight work)
    const stopPromise = worker.stop();

    // Release the slow adapter
    resolveProcessing!();

    await stopPromise;

    expect(worker.isRunning()).toBe(false);
  });

  test("does not start multiple polling loops", () => {
    const worker = new SyncWorker(db, adapter, { pollIntervalMs: 50 });

    worker.start();
    worker.start(); // second call should be no-op

    expect(worker.isRunning()).toBe(true);

    // Cleanup
    worker.stop();
  });
});
