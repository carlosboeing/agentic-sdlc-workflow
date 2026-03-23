/**
 * Startup wiring integration tests.
 *
 * Verifies that the full startup path — `startServer({ db })` — correctly
 * threads the database connection through to item CRUD routes. Tests use the
 * Hono `app.fetch()` pattern where possible; the `startServer` function path
 * is verified by confirming `ServerOptions.db` exists and is accepted at the
 * TypeScript level.
 *
 * These tests guard against the classic DI blind-spot: tests inject db
 * directly into `createApp`, but the production daemon startup calls
 * `startServer()` which must also accept and forward `db` to `createApp`.
 * Without this wiring, routes are silently absent at runtime even though all
 * unit tests pass.
 */

import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { createApp, startServer } from "../../src/server";
import type { ServerOptions } from "../../src/server";
import { setupTestDb } from "../helpers/setup-db";
import type { Database } from "bun:sqlite";
import type { drizzle } from "drizzle-orm/bun-sqlite";

type Db = ReturnType<typeof drizzle>;

let sqlite: Database;
let db: Db;

beforeEach(() => {
  const setup = setupTestDb();
  sqlite = setup.sqlite;
  db = setup.db;
});

afterEach(() => {
  sqlite.close();
});

// ---------------------------------------------------------------------------
// createApp — with DB (full wiring via app factory)
// ---------------------------------------------------------------------------

describe("createApp with db — item routes are active", () => {
  test("GET /api/items returns 200 when db is passed", async () => {
    const app = createApp({ db });
    const req = new Request("http://localhost/api/items");
    const res = await app.fetch(req);
    expect(res.status).toBe(200);
  });

  test("POST /api/items creates an item when db is passed", async () => {
    const app = createApp({ db });
    const req = new Request("http://localhost/api/items", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        title: "Wiring test item",
        type: "story",
        status: "backlog",
      }),
    });
    const res = await app.fetch(req);
    expect(res.status).toBe(201);
    const body = (await res.json()) as Record<string, unknown>;
    expect(body.title).toBe("Wiring test item");
  });

  test("GET /api/health still works when db is passed", async () => {
    const app = createApp({ db });
    const req = new Request("http://localhost/api/health");
    const res = await app.fetch(req);
    expect(res.status).toBe(200);
    const body = (await res.json()) as Record<string, unknown>;
    expect(body.status).toBe("ok");
  });

  test("GET /api/labels returns 200 when db is passed", async () => {
    const app = createApp({ db });
    const req = new Request("http://localhost/api/labels");
    const res = await app.fetch(req);
    expect(res.status).toBe(200);
  });
});

// ---------------------------------------------------------------------------
// createApp — without DB (health-only mode, regression guard)
// ---------------------------------------------------------------------------

describe("createApp without db — item routes are absent (health-only mode)", () => {
  test("GET /api/health returns 200 without db", async () => {
    const app = createApp({}); // no db
    const req = new Request("http://localhost/api/health");
    const res = await app.fetch(req);
    expect(res.status).toBe(200);
  });

  test("GET /api/items returns 404 without db (routes not registered)", async () => {
    const app = createApp({}); // no db — routes should NOT be registered
    const req = new Request("http://localhost/api/items");
    const res = await app.fetch(req);
    // Without a db, registerRoutes() is never called so the route doesn't exist
    expect(res.status).toBe(404);
  });
});

// ---------------------------------------------------------------------------
// Sync route wiring — createApp includes /api/sync/* when db is provided
// ---------------------------------------------------------------------------

describe("createApp with db — sync routes are active", () => {
  test("GET /api/sync/status returns 200 when db is passed", async () => {
    const app = createApp({ db });
    const req = new Request("http://localhost/api/sync/status");
    const res = await app.fetch(req);
    // Route is registered — should respond (not 404)
    expect(res.status).toBe(200);
    const body = (await res.json()) as Record<string, unknown>;
    expect(body.state).toBe("idle");
  });

  test("GET /api/sync/status returns 404 without db (sync routes not registered)", async () => {
    const app = createApp({}); // no db — sync routes should not be registered
    const req = new Request("http://localhost/api/sync/status");
    const res = await app.fetch(req);
    expect(res.status).toBe(404);
  });
});

// ---------------------------------------------------------------------------
// ServerOptions.db threading — verifies startServer() accepts and uses db
// ---------------------------------------------------------------------------

describe("ServerOptions includes db field (startup path wiring)", () => {
  test("ServerOptions type accepts a db parameter", () => {
    // Compile-time guard: if ServerOptions.db is missing from the interface,
    // this file won't compile and the test suite fails.
    const opts: ServerOptions = { port: 0, db };
    expect(opts.db).toBeDefined();
  });

  test("startServer with db produces an app that serves item routes", async () => {
    // Start a real Bun server on an ephemeral port to exercise the full wiring
    // path: startServer({ db }) -> createApp({ db }) -> registerRoutes(app, db)
    const server = startServer({ port: 0, db });
    const port = server.port;

    try {
      const res = await fetch(`http://127.0.0.1:${port}/api/items`);
      expect(res.status).toBe(200);
    } finally {
      server.stop(true);
    }
  });

  test("startServer without db only serves health endpoint", async () => {
    // Without db the server starts in health-only mode — item routes absent
    const server = startServer({ port: 0 });
    const port = server.port;

    try {
      const healthRes = await fetch(`http://127.0.0.1:${port}/api/health`);
      expect(healthRes.status).toBe(200);

      const itemsRes = await fetch(`http://127.0.0.1:${port}/api/items`);
      expect(itemsRes.status).toBe(404);
    } finally {
      server.stop(true);
    }
  });
});
