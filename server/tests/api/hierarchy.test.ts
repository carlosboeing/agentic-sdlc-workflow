import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Hono } from "hono";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { createHierarchyRouter } from "../../src/api/hierarchy";
import { createItemsRouter } from "../../src/api/items";
import { ItemService } from "../../src/services/items";
import { HierarchyService } from "../../src/services/hierarchy";
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
  hierarchyService: HierarchyService,
  labelService: LabelService,
  db: Db
): Hono {
  const app = new Hono();
  app.route("/api", createItemsRouter(itemService, labelService, db));
  app.route("/api", createHierarchyRouter(hierarchyService, itemService));
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
let hierarchyService: HierarchyService;
let labelService: LabelService;
let app: Hono;

beforeEach(() => {
  const setup = setupTestDb();
  sqlite = setup.sqlite;
  db = setup.db;
  itemService = new ItemService(db);
  hierarchyService = new HierarchyService(db);
  labelService = new LabelService(db);
  app = buildApp(itemService, hierarchyService, labelService, db);
});

afterEach(() => {
  sqlite.close();
});

// ---------------------------------------------------------------------------
// POST /api/items/:id/children — Link a child item
// ---------------------------------------------------------------------------

describe("POST /api/items/:id/children", () => {
  test("links a child item and returns 200 with updated child", async () => {
    const parentId = await createItem(app, "Parent Epic", "epic");
    const childId = await createItem(app, "Child Story", "story");

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${parentId}/children`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ childId }),
      })
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as AnyJson;
    expect(body.id).toBe(childId);
    expect(body.parentId).toBe(parentId);
  });

  test("returns 404 when parent does not exist", async () => {
    const childId = await createItem(app, "Orphan Story", "story");

    const res = await app.fetch(
      new Request("http://localhost/api/items/9999/children", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ childId }),
      })
    );
    expect(res.status).toBe(404);
  });

  test("returns 404 when child does not exist", async () => {
    const parentId = await createItem(app, "Parent Epic", "epic");

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${parentId}/children`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ childId: 9999 }),
      })
    );
    expect(res.status).toBe(404);
  });

  test("returns 400 for missing childId field", async () => {
    const parentId = await createItem(app, "Parent Epic", "epic");

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${parentId}/children`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      })
    );
    expect(res.status).toBe(400);
  });

  test("returns 400 for invalid parent item id", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/not-a-number/children", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ childId: 1 }),
      })
    );
    expect(res.status).toBe(400);
  });

  test("returns 400 for invalid JSON body", async () => {
    const parentId = await createItem(app, "Parent Epic", "epic");
    const res = await app.fetch(
      new Request(`http://localhost/api/items/${parentId}/children`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: "not-json",
      })
    );
    expect(res.status).toBe(400);
  });
});

// ---------------------------------------------------------------------------
// GET /api/items/:id/children — List children
// ---------------------------------------------------------------------------

describe("GET /api/items/:id/children", () => {
  test("returns empty array when item has no children", async () => {
    const parentId = await createItem(app, "Epic with no children", "epic");

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${parentId}/children`)
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as AnyJson[];
    expect(Array.isArray(body)).toBe(true);
    expect(body.length).toBe(0);
  });

  test("returns direct children only", async () => {
    const parentId = await createItem(app, "Parent Epic", "epic");
    const child1Id = await createItem(app, "Child Story 1", "story");
    const child2Id = await createItem(app, "Child Story 2", "story");

    // Link both children
    await app.fetch(
      new Request(`http://localhost/api/items/${parentId}/children`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ childId: child1Id }),
      })
    );
    await app.fetch(
      new Request(`http://localhost/api/items/${parentId}/children`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ childId: child2Id }),
      })
    );

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${parentId}/children`)
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as AnyJson[];
    expect(Array.isArray(body)).toBe(true);
    expect(body.length).toBe(2);
    const ids = body.map((item) => item.id);
    expect(ids).toContain(child1Id);
    expect(ids).toContain(child2Id);
  });

  test("does not return grandchildren", async () => {
    const grandparent = await createItem(app, "Backlog", "backlog");
    const parent = await createItem(app, "Epic", "epic");
    const child = await createItem(app, "Story", "story");

    // Link parent to grandparent, child to parent
    await app.fetch(
      new Request(`http://localhost/api/items/${grandparent}/children`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ childId: parent }),
      })
    );
    await app.fetch(
      new Request(`http://localhost/api/items/${parent}/children`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ childId: child }),
      })
    );

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${grandparent}/children`)
    );
    const body = (await res.json()) as AnyJson[];
    expect(body.length).toBe(1);
    expect(body[0].id).toBe(parent);
  });

  test("returns 404 for non-existent parent", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/9999/children")
    );
    expect(res.status).toBe(404);
  });

  test("returns 400 for invalid item id", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/not-a-number/children")
    );
    expect(res.status).toBe(400);
  });
});
