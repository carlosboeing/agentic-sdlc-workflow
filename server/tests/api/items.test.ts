import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Hono } from "hono";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { createItemsRouter } from "../../src/api/items";
import { ItemService } from "../../src/services/items";
import { LabelService } from "../../src/services/labels";
import { setupTestDb } from "../helpers/setup-db";
import type { Database } from "bun:sqlite";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

type AnyJson = Record<string, unknown>;
type Db = ReturnType<typeof drizzle>;

/** Build a test Hono app with items router mounted at /api. */
function buildApp(
  itemService: ItemService,
  labelService: LabelService,
  db: Db
): Hono {
  const app = new Hono();
  app.route("/api", createItemsRouter(itemService, labelService, db));
  // Global error handler mirrors server.ts
  app.onError((err, c) => {
    return c.json({ error: "Internal server error" }, 500);
  });
  return app;
}

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

let sqlite: Database;
let db: Db;
let itemService: ItemService;
let labelService: LabelService;
let app: Hono;

beforeEach(() => {
  const setup = setupTestDb();
  sqlite = setup.sqlite;
  db = setup.db;
  itemService = new ItemService(db);
  labelService = new LabelService(db);
  app = buildApp(itemService, labelService, db);
});

afterEach(() => {
  sqlite.close();
});

// ---------------------------------------------------------------------------
// POST /api/items — Create
// ---------------------------------------------------------------------------

describe("POST /api/items", () => {
  test("creates an item and returns 201", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: "My Story", type: "story" }),
      })
    );
    expect(res.status).toBe(201);
    const body = (await res.json()) as AnyJson;
    expect(body.title).toBe("My Story");
    expect(body.type).toBe("story");
    expect(typeof body.id).toBe("number");
  });

  test("sets default status to backlog and state to open", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: "My Backlog Item", type: "backlog" }),
      })
    );
    const body = (await res.json()) as AnyJson;
    expect(body.status).toBe("backlog");
    expect(body.state).toBe("open");
  });

  test("accepts optional fields: body, status, parentId", async () => {
    // Create parent first
    const parentRes = await app.fetch(
      new Request("http://localhost/api/items", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: "Parent Epic", type: "epic" }),
      })
    );
    const parent = (await parentRes.json()) as AnyJson;

    const res = await app.fetch(
      new Request("http://localhost/api/items", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          title: "Child Story",
          type: "story",
          body: "Story description",
          status: "ready",
          parentId: parent.id,
        }),
      })
    );
    expect(res.status).toBe(201);
    const body = (await res.json()) as AnyJson;
    expect(body.body).toBe("Story description");
    expect(body.status).toBe("ready");
    expect(body.parentId).toBe(parent.id);
  });

  test("returns 400 with field-level errors when title is missing", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ type: "story" }),
      })
    );
    expect(res.status).toBe(400);
    const body = (await res.json()) as AnyJson;
    expect(body.error).toBeDefined();
    expect(Array.isArray(body.details)).toBe(true);
  });

  test("returns 400 with field-level errors when type is invalid", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: "My Item", type: "invalid-type" }),
      })
    );
    expect(res.status).toBe(400);
    const body = (await res.json()) as AnyJson;
    expect(body.error).toBeDefined();
    expect(Array.isArray(body.details)).toBe(true);
  });

  test("returns 400 when body is not valid JSON", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: "not-json",
      })
    );
    expect(res.status).toBe(400);
  });

  test("returns consistent error format: { error, details }", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ type: "story" }), // missing title
      })
    );
    const body = (await res.json()) as AnyJson;
    expect(typeof body.error).toBe("string");
    expect(Array.isArray(body.details)).toBe(true);
  });

  test("assigns an auto-generated numeric ID when none is provided", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: "Auto ID Item", type: "story" }),
      })
    );
    expect(res.status).toBe(201);
    const body = (await res.json()) as AnyJson;
    expect(typeof body.id).toBe("number");
    expect(body.id).toBeGreaterThan(0);
  });
});

// ---------------------------------------------------------------------------
// GET /api/items — List
// ---------------------------------------------------------------------------

describe("GET /api/items", () => {
  beforeEach(async () => {
    // Seed a few items
    await itemService.create({ id: 1, title: "Backlog Item 1", type: "backlog", status: "backlog" });
    await itemService.create({ id: 2, title: "Epic 1", type: "epic", status: "ready" });
    await itemService.create({ id: 3, title: "Story 1", type: "story", status: "in-progress" });
    await itemService.create({ id: 4, title: "Story 2", type: "story", status: "done", state: "closed" });
  });

  test("returns 200 with all items when no filters", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items")
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as AnyJson[];
    expect(Array.isArray(body)).toBe(true);
    expect(body.length).toBe(4);
  });

  test("filters by type=story", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items?type=story")
    );
    const body = (await res.json()) as AnyJson[];
    expect(body.length).toBe(2);
    for (const item of body) {
      expect(item.type).toBe("story");
    }
  });

  test("filters by status=ready", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items?status=ready")
    );
    const body = (await res.json()) as AnyJson[];
    expect(body.length).toBe(1);
    expect((body[0] as AnyJson).status).toBe("ready");
  });

  test("filters by state=closed", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items?state=closed")
    );
    const body = (await res.json()) as AnyJson[];
    expect(body.length).toBe(1);
    expect((body[0] as AnyJson).state).toBe("closed");
  });

  test("filters by label", async () => {
    await labelService.addLabelToItem(3, "difficulty/medium");
    const res = await app.fetch(
      new Request("http://localhost/api/items?label=difficulty%2Fmedium")
    );
    const body = (await res.json()) as AnyJson[];
    expect(body.length).toBe(1);
    expect((body[0] as AnyJson).id).toBe(3);
  });

  test("respects limit query parameter", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items?limit=2")
    );
    const body = (await res.json()) as AnyJson[];
    expect(body.length).toBe(2);
  });

  test("returns empty array when no items match filter", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items?status=in-review")
    );
    const body = (await res.json()) as AnyJson[];
    expect(Array.isArray(body)).toBe(true);
    expect(body.length).toBe(0);
  });

  test("returns 400 for invalid type filter", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items?type=invalid")
    );
    expect(res.status).toBe(400);
  });

  test("returns 400 for invalid status filter", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items?status=unknown")
    );
    expect(res.status).toBe(400);
  });
});

// ---------------------------------------------------------------------------
// GET /api/items/:id — Get single item
// ---------------------------------------------------------------------------

describe("GET /api/items/:id", () => {
  beforeEach(async () => {
    await itemService.create({ id: 10, title: "Test Item", type: "story", status: "ready" });
    await labelService.addLabelToItem(10, "difficulty/easy");
  });

  test("returns 200 with item detail when found", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/10")
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as AnyJson;
    expect(body.id).toBe(10);
    expect(body.title).toBe("Test Item");
  });

  test("includes labels in item response", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/10")
    );
    const body = (await res.json()) as AnyJson;
    expect(Array.isArray(body.labels)).toBe(true);
    const labels = body.labels as AnyJson[];
    expect(labels.length).toBe(1);
    expect(labels[0].name).toBe("difficulty/easy");
  });

  test("includes children in item response", async () => {
    // Create a child item linked to parent 10
    await itemService.create({ id: 11, title: "Child Story", type: "story", parentId: 10 });
    const res = await app.fetch(
      new Request("http://localhost/api/items/10")
    );
    const body = (await res.json()) as AnyJson;
    expect(Array.isArray(body.children)).toBe(true);
    const children = body.children as AnyJson[];
    expect(children.length).toBe(1);
    expect(children[0].id).toBe(11);
  });

  test("returns 404 when item not found", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/99999")
    );
    expect(res.status).toBe(404);
    const body = (await res.json()) as AnyJson;
    expect(body.error).toBeDefined();
  });

  test("returns 400 for non-numeric id", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/not-a-number")
    );
    expect(res.status).toBe(400);
  });
});

// ---------------------------------------------------------------------------
// PATCH /api/items/:id — Update
// ---------------------------------------------------------------------------

describe("PATCH /api/items/:id", () => {
  beforeEach(async () => {
    await itemService.create({ id: 20, title: "Original Title", type: "story", body: "Original body" });
  });

  test("updates title and returns 200 with updated item", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/20", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: "Updated Title" }),
      })
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as AnyJson;
    expect(body.title).toBe("Updated Title");
    expect(body.id).toBe(20);
  });

  test("updates body only, title unchanged", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/20", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ body: "New body content" }),
      })
    );
    const body = (await res.json()) as AnyJson;
    expect(body.body).toBe("New body content");
    expect(body.title).toBe("Original Title");
  });

  test("returns 404 when item not found", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/99999", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: "New title" }),
      })
    );
    expect(res.status).toBe(404);
  });

  test("returns 400 when no updatable fields provided", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/20", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      })
    );
    expect(res.status).toBe(400);
    const body = (await res.json()) as AnyJson;
    expect(body.error).toBeDefined();
  });

  test("returns 400 for non-numeric id", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/abc", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: "x" }),
      })
    );
    expect(res.status).toBe(400);
  });
});

// ---------------------------------------------------------------------------
// DELETE /api/items/:id — Close (soft delete)
// ---------------------------------------------------------------------------

describe("DELETE /api/items/:id", () => {
  beforeEach(async () => {
    await itemService.create({ id: 30, title: "To Be Closed", type: "story", state: "open" });
  });

  test("closes item and returns 200", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/30", { method: "DELETE" })
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as AnyJson;
    expect(body.state).toBe("closed");
    expect(body.id).toBe(30);
  });

  test("item state is closed after delete", async () => {
    await app.fetch(
      new Request("http://localhost/api/items/30", { method: "DELETE" })
    );
    const item = await itemService.get(30);
    expect(item?.state).toBe("closed");
  });

  test("returns 404 when item not found", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/99999", { method: "DELETE" })
    );
    expect(res.status).toBe(404);
  });

  test("returns 400 for non-numeric id", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/xyz", { method: "DELETE" })
    );
    expect(res.status).toBe(400);
  });
});

// ---------------------------------------------------------------------------
// GET /api/labels — List all labels
// ---------------------------------------------------------------------------

describe("GET /api/labels", () => {
  test("returns 200 with empty array when no labels", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/labels")
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as AnyJson[];
    expect(Array.isArray(body)).toBe(true);
    expect(body.length).toBe(0);
  });

  test("returns all labels", async () => {
    await labelService.createLabel({ name: "difficulty/easy", color: "#0075ca" });
    await labelService.createLabel({ name: "type/feature" });
    const res = await app.fetch(
      new Request("http://localhost/api/labels")
    );
    const body = (await res.json()) as AnyJson[];
    expect(body.length).toBe(2);
  });
});

// ---------------------------------------------------------------------------
// POST /api/labels — Create label
// ---------------------------------------------------------------------------

describe("POST /api/labels", () => {
  test("creates label and returns 201", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/labels", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: "difficulty/hard", color: "#e4e669" }),
      })
    );
    expect(res.status).toBe(201);
    const body = (await res.json()) as AnyJson;
    expect(body.name).toBe("difficulty/hard");
    expect(body.color).toBe("#e4e669");
    expect(typeof body.id).toBe("number");
  });

  test("returns 400 when name is missing", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/labels", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ color: "#fff" }),
      })
    );
    expect(res.status).toBe(400);
    const body = (await res.json()) as AnyJson;
    expect(body.error).toBeDefined();
  });
});

// ---------------------------------------------------------------------------
// CRUD round-trip integration
// ---------------------------------------------------------------------------

describe("CRUD round-trip", () => {
  test("create → get → update → delete cycle", async () => {
    // Create
    const createRes = await app.fetch(
      new Request("http://localhost/api/items", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: "Round Trip Item", type: "story" }),
      })
    );
    expect(createRes.status).toBe(201);
    const created = (await createRes.json()) as AnyJson;
    const id = created.id as number;

    // Get
    const getRes = await app.fetch(
      new Request(`http://localhost/api/items/${id}`)
    );
    expect(getRes.status).toBe(200);
    const got = (await getRes.json()) as AnyJson;
    expect(got.title).toBe("Round Trip Item");

    // Update
    const patchRes = await app.fetch(
      new Request(`http://localhost/api/items/${id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: "Updated Round Trip" }),
      })
    );
    expect(patchRes.status).toBe(200);
    const updated = (await patchRes.json()) as AnyJson;
    expect(updated.title).toBe("Updated Round Trip");

    // Delete (close)
    const deleteRes = await app.fetch(
      new Request(`http://localhost/api/items/${id}`, { method: "DELETE" })
    );
    expect(deleteRes.status).toBe(200);
    const closed = (await deleteRes.json()) as AnyJson;
    expect(closed.state).toBe("closed");
  });
});
