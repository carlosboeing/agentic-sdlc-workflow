import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Hono } from "hono";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { createCommentsRouter } from "../../src/api/comments";
import { createItemsRouter } from "../../src/api/items";
import { ItemService } from "../../src/services/items";
import { CommentService } from "../../src/services/comments";
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
  commentService: CommentService,
  labelService: LabelService,
  db: Db
): Hono {
  const app = new Hono();
  app.route("/api", createItemsRouter(itemService, labelService, db));
  app.route("/api", createCommentsRouter(commentService, itemService));
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
let commentService: CommentService;
let labelService: LabelService;
let app: Hono;

beforeEach(() => {
  const setup = setupTestDb();
  sqlite = setup.sqlite;
  db = setup.db;
  itemService = new ItemService(db);
  commentService = new CommentService(db);
  labelService = new LabelService(db);
  app = buildApp(itemService, commentService, labelService, db);
});

afterEach(() => {
  sqlite.close();
});

// ---------------------------------------------------------------------------
// POST /api/items/:id/comments — Add comment
// ---------------------------------------------------------------------------

describe("POST /api/items/:id/comments", () => {
  test("adds a comment and returns 201 with created comment", async () => {
    const id = await createItem(app);

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id}/comments`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ body: "This is a comment.", author: "builder" }),
      })
    );
    expect(res.status).toBe(201);
    const body = (await res.json()) as AnyJson;
    expect(body.body).toBe("This is a comment.");
    expect(body.author).toBe("builder");
    expect(body.itemId).toBe(id);
    expect(typeof body.id).toBe("number");
  });

  test("returns 400 for missing body field", async () => {
    const id = await createItem(app);

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id}/comments`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ author: "builder" }),
      })
    );
    expect(res.status).toBe(400);
  });

  test("returns 400 for missing author field", async () => {
    const id = await createItem(app);

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id}/comments`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ body: "Some comment" }),
      })
    );
    expect(res.status).toBe(400);
  });

  test("returns 404 for non-existent item", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/9999/comments", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ body: "Some comment", author: "builder" }),
      })
    );
    expect(res.status).toBe(404);
  });

  test("returns 400 for invalid item id", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/not-a-number/comments", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ body: "Some comment", author: "builder" }),
      })
    );
    expect(res.status).toBe(400);
  });

  test("returns 400 for invalid JSON body", async () => {
    const id = await createItem(app);
    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id}/comments`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: "not-json",
      })
    );
    expect(res.status).toBe(400);
  });
});

// ---------------------------------------------------------------------------
// GET /api/items/:id/comments — List comments
// ---------------------------------------------------------------------------

describe("GET /api/items/:id/comments", () => {
  test("returns empty array when no comments exist", async () => {
    const id = await createItem(app);

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id}/comments`)
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as AnyJson[];
    expect(Array.isArray(body)).toBe(true);
    expect(body.length).toBe(0);
  });

  test("returns paginated comments for an item", async () => {
    const id = await createItem(app);

    // Add two comments
    await app.fetch(
      new Request(`http://localhost/api/items/${id}/comments`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ body: "Comment 1", author: "builder" }),
      })
    );
    await app.fetch(
      new Request(`http://localhost/api/items/${id}/comments`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ body: "Comment 2", author: "reviewer" }),
      })
    );

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id}/comments`)
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as AnyJson[];
    expect(Array.isArray(body)).toBe(true);
    expect(body.length).toBe(2);
    expect(body[0].body).toBe("Comment 1");
    expect(body[1].body).toBe("Comment 2");
  });

  test("returns only comments for the requested item", async () => {
    const id1 = await createItem(app, "Item 1");
    const id2 = await createItem(app, "Item 2");

    await app.fetch(
      new Request(`http://localhost/api/items/${id1}/comments`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ body: "Comment for item 1", author: "builder" }),
      })
    );
    await app.fetch(
      new Request(`http://localhost/api/items/${id2}/comments`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ body: "Comment for item 2", author: "reviewer" }),
      })
    );

    const res = await app.fetch(
      new Request(`http://localhost/api/items/${id1}/comments`)
    );
    const body = (await res.json()) as AnyJson[];
    expect(body.length).toBe(1);
    expect(body[0].body).toBe("Comment for item 1");
  });

  test("returns 404 for non-existent item", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/9999/comments")
    );
    expect(res.status).toBe(404);
  });

  test("returns 400 for invalid item id", async () => {
    const res = await app.fetch(
      new Request("http://localhost/api/items/not-a-number/comments")
    );
    expect(res.status).toBe(400);
  });
});
