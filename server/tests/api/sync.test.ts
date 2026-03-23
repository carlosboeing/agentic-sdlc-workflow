/**
 * API integration tests for POST /api/sync/pull and GET /api/sync/status.
 *
 * Uses the createSyncRouter pattern (not createApp) to isolate the sync
 * route group, following the same pattern as items.test.ts and board.test.ts.
 *
 * PullSyncService is mocked to avoid touching the real GitHub GraphQL API.
 */

import { describe, test, expect, beforeEach, afterEach, mock } from "bun:test";
import { Hono } from "hono";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { createSyncRouter } from "../../src/api/sync";
import { setupTestDb } from "../helpers/setup-db";
import { EventService } from "../../src/api/websocket";
import type { Database } from "bun:sqlite";
import type { PullSyncResult, PullSyncOptions } from "../../src/services/pull-sync";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

type Db = ReturnType<typeof drizzle>;
type AnyJson = Record<string, unknown>;

function makeResult(overrides: Partial<PullSyncResult> = {}): PullSyncResult {
  return {
    totalIssues: 10,
    itemsCreated: 8,
    itemsUpdated: 2,
    labelsCreated: 3,
    commentsCreated: 5,
    commentsUpdated: 1,
    hierarchyLinked: 4,
    pointsConsumed: 50,
    durationMs: 1200,
    errors: [],
    ...overrides,
  };
}

/** Build a minimal test app with only the sync router mounted. */
function buildApp(syncRouter: Hono): Hono {
  const app = new Hono();
  app.route("/api", syncRouter);
  app.onError((err, c) => {
    return c.json({ error: err.message }, 500);
  });
  return app;
}

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

let sqlite: Database;
let db: Db;
let eventService: EventService;
let app: Hono;

/** Spy on pullSync — reassigned in each test via closures on the mock service. */
let pullSyncImpl: (opts?: PullSyncOptions) => Promise<PullSyncResult>;

beforeEach(() => {
  const setup = setupTestDb();
  sqlite = setup.sqlite;
  db = setup.db;
  eventService = new EventService(db);

  // Default: successful sync
  pullSyncImpl = async (_opts?: PullSyncOptions) => makeResult();

  const mockService = {
    pullSync: mock(async (opts?: PullSyncOptions) => pullSyncImpl(opts)),
  };

  const router = createSyncRouter(mockService);
  app = buildApp(router);
});

afterEach(() => {
  sqlite.close();
});

// ---------------------------------------------------------------------------
// POST /api/sync/pull — success
// ---------------------------------------------------------------------------

describe("POST /api/sync/pull — success", () => {
  test("returns 200 with PullSyncResult on valid body", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/sync/pull", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ filterLabels: ["backlog/364"], includeComments: true }),
      })
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as AnyJson;
    expect(body.totalIssues).toBe(10);
    expect(body.itemsCreated).toBe(8);
    expect(body.itemsUpdated).toBe(2);
    expect(body.errors).toEqual([]);
  });

  test("returns 200 with empty body (all options optional)", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/sync/pull", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      })
    );
    expect(res.status).toBe(200);
  });

  test("returns 200 with no Content-Type and no body", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/sync/pull", {
        method: "POST",
      })
    );
    // Missing body should be treated as empty options — not 400
    expect(res.status).toBe(200);
  });
});

// ---------------------------------------------------------------------------
// POST /api/sync/pull — validation errors (400)
// ---------------------------------------------------------------------------

describe("POST /api/sync/pull — validation errors", () => {
  test("returns 400 when filterLabels is not an array", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/sync/pull", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ filterLabels: "not-an-array" }),
      })
    );
    expect(res.status).toBe(400);
    const body = (await res.json()) as AnyJson;
    expect(body.error).toBe("Validation failed");
    expect(Array.isArray(body.details)).toBe(true);
  });

  test("returns 400 when filterLabels contains non-strings", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/sync/pull", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ filterLabels: [1, 2, 3] }),
      })
    );
    expect(res.status).toBe(400);
  });

  test("returns 400 when includeComments is not a boolean", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/sync/pull", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ includeComments: "yes" }),
      })
    );
    expect(res.status).toBe(400);
  });
});

// ---------------------------------------------------------------------------
// POST /api/sync/pull — concurrent request rejection (409)
// ---------------------------------------------------------------------------

describe("POST /api/sync/pull — concurrency", () => {
  test("returns 409 when sync is already running", async () => {
    // Make the first sync hang until we send the second request
    let resolveFirstSync!: (result: PullSyncResult) => void;
    const firstSyncPromise = new Promise<PullSyncResult>((resolve) => {
      resolveFirstSync = resolve;
    });
    pullSyncImpl = async (_opts?: PullSyncOptions) => firstSyncPromise;

    const mockService = {
      pullSync: mock(async (opts?: PullSyncOptions) => pullSyncImpl(opts)),
    };
    const router = createSyncRouter(mockService);
    const concurrentApp = buildApp(router);

    // Send first request (will hang in pullSyncImpl until resolved)
    const firstRes = concurrentApp.fetch(
      new Request("http://localhost/api/sync/pull", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      })
    );

    // Small delay to ensure first request acquires the mutex
    await Bun.sleep(10);

    // Send second request while first is still running
    const secondRes = await concurrentApp.fetch(
      new Request("http://localhost/api/sync/pull", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      })
    );
    expect(secondRes.status).toBe(409);
    const body = (await secondRes.json()) as AnyJson;
    expect(body.error).toContain("already in progress");

    // Clean up: resolve the first sync
    resolveFirstSync(makeResult());
    await firstRes;
  });
});

// ---------------------------------------------------------------------------
// POST /api/sync/pull — server error (500)
// ---------------------------------------------------------------------------

describe("POST /api/sync/pull — server error", () => {
  test("returns 500 when PullSyncService throws", async () => {
    pullSyncImpl = async (_opts?: PullSyncOptions) => {
      throw new Error("Rate limit: remaining points (300) below threshold (500)");
    };

    const mockService = {
      pullSync: mock(async (opts?: PullSyncOptions) => pullSyncImpl(opts)),
    };
    const router = createSyncRouter(mockService);
    const errorApp = buildApp(router);

    const res = await errorApp.fetch(
      new Request("http://localhost/api/sync/pull", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      })
    );
    expect(res.status).toBe(500);
    const body = (await res.json()) as AnyJson;
    expect(typeof body.error).toBe("string");
    expect(body.error).toContain("Rate limit");
  });
});

// ---------------------------------------------------------------------------
// GET /api/sync/status
// ---------------------------------------------------------------------------

describe("GET /api/sync/status", () => {
  test("returns idle state when no sync has run", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/sync/status")
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as AnyJson;
    expect(body.state).toBe("idle");
    expect(body.progress).toBeUndefined();
  });

  test("returns lastResult after a successful sync", async () => {
    // Run a sync first
    await app.fetch(
      new Request("http://localhost/api/sync/pull", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      })
    );

    const res = await app.fetch(
      new Request("http://localhost/api/sync/status")
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as AnyJson;
    expect(body.state).toBe("idle");
    expect(body.lastResult).toBeDefined();
    const lastResult = body.lastResult as AnyJson;
    expect(lastResult.totalIssues).toBe(10);
  });
});
