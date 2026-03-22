import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Hono } from "hono";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { createBoardRouter } from "../../src/api/board";
import { createItemsRouter } from "../../src/api/items";
import { ItemService } from "../../src/services/items";
import { BoardService } from "../../src/services/board";
import { LabelService } from "../../src/services/labels";
import { setupTestDb } from "../helpers/setup-db";
import type { Database } from "bun:sqlite";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

type AnyJson = Record<string, unknown>;
type Db = ReturnType<typeof drizzle>;

function buildApp(itemService: ItemService, boardService: BoardService, labelService: LabelService, db: Db): Hono {
  const app = new Hono();
  // Mount items router so we can create items in tests
  app.route("/api", createItemsRouter(itemService, labelService, db));
  // Mount board router under test
  app.route("/api", createBoardRouter(boardService));
  app.onError((err, c) => {
    console.error(err);
    return c.json({ error: "Internal server error" }, 500);
  });
  return app;
}

/** Create a test item and return its id. */
async function createItem(app: Hono, title = "Test Item", type = "story"): Promise<number> {
  const res = await app.fetch(
    new Request("http://localhost/api/items", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title, type }),
    })
  );
  const body = (await res.json()) as AnyJson;
  return body.id as number;
}

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

let sqlite: Database;
let db: Db;
let itemService: ItemService;
let boardService: BoardService;
let labelService: LabelService;
let app: Hono;

beforeEach(() => {
  const setup = setupTestDb();
  sqlite = setup.sqlite;
  db = setup.db;
  itemService = new ItemService(db);
  boardService = new BoardService(db);
  labelService = new LabelService(db);
  app = buildApp(itemService, boardService, labelService, db);
});

afterEach(() => {
  sqlite.close();
});

// ---------------------------------------------------------------------------
// POST /api/items/:id/status — Set board status
// ---------------------------------------------------------------------------

describe("POST /api/items/:id/status", () => {
  test("sets board status and returns 200 with updated item", async () => {
    const id = await createItem(app);

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id}/status`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ status: "in-progress" }),
      })
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as AnyJson;
    expect(body.status).toBe("in-progress");
    expect(body.id).toBe(id);
  });

  test("returns 404 for non-existent item", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/9999/status", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ status: "ready" }),
      })
    );
    expect(res.status).toBe(404);
    const body = (await res.json()) as AnyJson;
    expect(typeof body.error).toBe("string");
  });

  test("returns 400 for invalid status value", async () => {
    const id = await createItem(app);

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id}/status`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ status: "invalid-status" }),
      })
    );
    expect(res.status).toBe(400);
    const body = (await res.json()) as AnyJson;
    expect(typeof body.error).toBe("string");
  });

  test("returns 400 for missing status field", async () => {
    const id = await createItem(app);

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id}/status`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      })
    );
    expect(res.status).toBe(400);
  });

  test("accepts all valid status values", async () => {
    const statuses = ["backlog", "ready", "in-progress", "in-review", "done"] as const;
    for (const status of statuses) {
      const id = await createItem(app, `Item for ${status}`, "story");
      const res = await app.fetch(
        new Request(`http://localhost/api/items/${id}/status`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ status }),
        })
      );
      expect(res.status).toBe(200);
      const body = (await res.json()) as AnyJson;
      expect(body.status).toBe(status);
    }
  });

  test("returns 400 for invalid item id", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/not-a-number/status", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ status: "ready" }),
      })
    );
    expect(res.status).toBe(400);
  });

  test("returns 400 for invalid JSON body", async () => {
    const id = await createItem(app);
    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id}/status`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: "not-json",
      })
    );
    expect(res.status).toBe(400);
  });
});
