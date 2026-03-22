import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Hono } from "hono";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { createTelemetryRouter } from "../../src/api/telemetry";
import { createItemsRouter } from "../../src/api/items";
import { ItemService } from "../../src/services/items";
import { LifecycleService } from "../../src/services/lifecycle";
import { LabelService } from "../../src/services/labels";
import { setupTestDb } from "../helpers/setup-db";
import type { Database } from "bun:sqlite";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

type AnyJson = Record<string, unknown>;
type Db = ReturnType<typeof drizzle>;

function buildApp(
  itemService: ItemService,
  lifecycleService: LifecycleService,
  labelService: LabelService,
  db: Db
): Hono {
  const app = new Hono();
  app.route("/api", createItemsRouter(itemService, labelService, db));
  app.route("/api", createTelemetryRouter(lifecycleService, itemService));
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
let lifecycleService: LifecycleService;
let labelService: LabelService;
let app: Hono;

beforeEach(() => {
  const setup = setupTestDb();
  sqlite = setup.sqlite;
  db = setup.db;
  itemService = new ItemService(db);
  lifecycleService = new LifecycleService(db);
  labelService = new LabelService(db);
  app = buildApp(itemService, lifecycleService, labelService, db);
});

afterEach(() => {
  sqlite.close();
});

// ---------------------------------------------------------------------------
// POST /api/items/:id/telemetry — Post telemetry data
// ---------------------------------------------------------------------------

describe("POST /api/items/:id/telemetry", () => {
  test("posts telemetry and returns 201 with created telemetry row", async () => {
    const id = await createItem(app);

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id}/telemetry`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          model: "sonnet",
          durationMs: 120000,
          tokens: 50000,
        }),
      })
    );
    expect(res.status).toBe(201);
    const body = (await res.json()) as AnyJson;
    expect(body.itemId).toBe(id);
    expect(body.model).toBe("sonnet");
    expect(body.durationMs).toBe(120000);
    expect(body.tokens).toBe(50000);
    expect(typeof body.id).toBe("number");
  });

  test("accepts optional fields: toolUses, costEstimate, commitHash", async () => {
    const id = await createItem(app);

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id}/telemetry`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          model: "opus",
          durationMs: 240000,
          tokens: 100000,
          toolUses: 42,
          costEstimate: 1.25,
          commitHash: "abc123def456",
        }),
      })
    );
    expect(res.status).toBe(201);
    const body = (await res.json()) as AnyJson;
    expect(body.toolUses).toBe(42);
    expect(body.costEstimate).toBe(1.25);
    expect(body.commitHash).toBe("abc123def456");
  });

  test("accepts all valid model values", async () => {
    const models = ["haiku", "sonnet", "opus", "mixed"] as const;
    for (const model of models) {
      const id = await createItem(app, `Item for ${model}`, "story");
      const res = await app.fetch(
        new Request(`http://localhost/api/items/${id}/telemetry`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ model, durationMs: 1000, tokens: 100 }),
        })
      );
      expect(res.status).toBe(201);
      const body = (await res.json()) as AnyJson;
      expect(body.model).toBe(model);
    }
  });

  test("returns 400 for missing required fields", async () => {
    const id = await createItem(app);

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id}/telemetry`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ model: "sonnet" }), // missing durationMs and tokens
      })
    );
    expect(res.status).toBe(400);
  });

  test("returns 400 for invalid model value", async () => {
    const id = await createItem(app);

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id}/telemetry`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ model: "gpt-4", durationMs: 1000, tokens: 100 }),
      })
    );
    expect(res.status).toBe(400);
  });

  test("returns 404 for non-existent item", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/9999/telemetry", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ model: "sonnet", durationMs: 1000, tokens: 100 }),
      })
    );
    expect(res.status).toBe(404);
  });

  test("returns 400 for invalid item id", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/not-a-number/telemetry", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ model: "sonnet", durationMs: 1000, tokens: 100 }),
      })
    );
    expect(res.status).toBe(400);
  });

  test("returns 400 for invalid JSON body", async () => {
    const id = await createItem(app);
    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id}/telemetry`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: "not-json",
      })
    );
    expect(res.status).toBe(400);
  });
});

// ---------------------------------------------------------------------------
// GET /api/items/:id/telemetry — Get item telemetry
// ---------------------------------------------------------------------------

describe("GET /api/items/:id/telemetry", () => {
  test("returns empty array when no telemetry exists", async () => {
    const id = await createItem(app);

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id}/telemetry`)
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as AnyJson[];
    expect(Array.isArray(body)).toBe(true);
    expect(body.length).toBe(0);
  });

  test("returns all telemetry rows for the item", async () => {
    const id = await createItem(app);

    // Post two telemetry entries
    await app.fetch(
      new Request(`http://localhost/api/items/${id}/telemetry`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ model: "sonnet", durationMs: 60000, tokens: 30000 }),
      })
    );
    await app.fetch(
      new Request(`http://localhost/api/items/${id}/telemetry`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ model: "opus", durationMs: 90000, tokens: 50000 }),
      })
    );

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id}/telemetry`)
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as AnyJson[];
    expect(Array.isArray(body)).toBe(true);
    expect(body.length).toBe(2);
  });

  test("returns only telemetry for the requested item", async () => {
    const id1 = await createItem(app, "Item 1");
    const id2 = await createItem(app, "Item 2");

    await app.fetch(
      new Request(`http://localhost/api/items/${id1}/telemetry`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ model: "sonnet", durationMs: 60000, tokens: 30000 }),
      })
    );
    await app.fetch(
      new Request(`http://localhost/api/items/${id2}/telemetry`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ model: "haiku", durationMs: 20000, tokens: 10000 }),
      })
    );

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id1}/telemetry`)
    );
    const body = (await res.json()) as AnyJson[];
    expect(body.length).toBe(1);
    expect(body[0].model).toBe("sonnet");
  });

  test("returns 404 for non-existent item", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/9999/telemetry")
    );
    expect(res.status).toBe(404);
  });

  test("returns 400 for invalid item id", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/not-a-number/telemetry")
    );
    expect(res.status).toBe(400);
  });
});

// ---------------------------------------------------------------------------
// POST /api/items/:id/start — Lifecycle: start work
// ---------------------------------------------------------------------------

describe("POST /api/items/:id/start", () => {
  test("starts work and returns 200 with updated item", async () => {
    const id = await createItem(app);

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id}/start`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ agent: "builder", model: "sonnet" }),
      })
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as AnyJson;
    expect(body.status).toBe("in-progress");
    expect(body.id).toBe(id);
  });

  test("returns 404 for non-existent item", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/9999/start", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ agent: "builder", model: "sonnet" }),
      })
    );
    expect(res.status).toBe(404);
  });

  test("returns 400 for missing agent field", async () => {
    const id = await createItem(app);
    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id}/start`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ model: "sonnet" }),
      })
    );
    expect(res.status).toBe(400);
  });

  test("returns 400 for missing model field", async () => {
    const id = await createItem(app);
    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id}/start`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ agent: "builder" }),
      })
    );
    expect(res.status).toBe(400);
  });

  test("returns 400 for invalid item id", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/not-a-number/start", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ agent: "builder", model: "sonnet" }),
      })
    );
    expect(res.status).toBe(400);
  });
});

// ---------------------------------------------------------------------------
// POST /api/items/:id/complete — Lifecycle: complete work
// ---------------------------------------------------------------------------

describe("POST /api/items/:id/complete", () => {
  test("completes work and returns 200 with updated item", async () => {
    const id = await createItem(app);

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id}/complete`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ commitHash: "abc123" }),
      })
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as AnyJson;
    expect(body.status).toBe("in-review");
    expect(body.id).toBe(id);
  });

  test("returns 404 for non-existent item", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/9999/complete", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ commitHash: "abc123" }),
      })
    );
    expect(res.status).toBe(404);
  });

  test("returns 400 for missing commitHash field", async () => {
    const id = await createItem(app);
    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id}/complete`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      })
    );
    expect(res.status).toBe(400);
  });

  test("returns 400 for invalid item id", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/not-a-number/complete", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ commitHash: "abc123" }),
      })
    );
    expect(res.status).toBe(400);
  });
});
