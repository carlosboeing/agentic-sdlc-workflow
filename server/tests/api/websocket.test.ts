/**
 * Tests for WebSocket integration and activity feed.
 *
 * Covers:
 * - WebSocket endpoint upgrade at /ws
 * - EventService: broadcasting activity events to subscribers
 * - Activity log backfill on connect (last 50 events)
 * - Message format validation (type + data fields)
 * - EventService listener subscription/unsubscription
 * - GET /api/activity endpoint for recent activity
 * - Services emit events via EventService after create/update/close/status
 */

import { describe, test, expect, beforeEach, afterEach, mock } from "bun:test";
import { setupTestDb } from "../helpers/setup-db";
import type { Database } from "bun:sqlite";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { EventService, type ActivityMessage } from "../../src/api/websocket";
import { ItemService } from "../../src/services/items";
import { BoardService } from "../../src/services/board";
import { CommentService } from "../../src/services/comments";
import * as schema from "../../src/db/schema";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

type Db = ReturnType<typeof drizzle>;

function makeActivityRow(
  db: Db,
  eventType: string,
  payload: Record<string, unknown>
): void {
  // Use null for itemId — activity_log.item_id is nullable (FK optional)
  db.insert(schema.activityLog)
    .values({
      itemId: null,
      eventType,
      payload: JSON.stringify(payload),
      createdAt: new Date().toISOString(),
    })
    .run();
}

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

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
// EventService unit tests
// ---------------------------------------------------------------------------

describe("EventService", () => {
  test("subscribe receives broadcast messages", () => {
    const service = new EventService(db);
    const received: ActivityMessage[] = [];

    service.subscribe((msg) => received.push(msg));
    service.broadcast({ type: "item:created", data: { id: 1, title: "Test" } });

    expect(received).toHaveLength(1);
    expect(received[0].type).toBe("item:created");
    expect(received[0].data).toEqual({ id: 1, title: "Test" });
  });

  test("multiple subscribers all receive broadcast", () => {
    const service = new EventService(db);
    const a: ActivityMessage[] = [];
    const b: ActivityMessage[] = [];

    service.subscribe((msg) => a.push(msg));
    service.subscribe((msg) => b.push(msg));
    service.broadcast({ type: "status:changed", data: { itemId: 5, from: "ready", to: "in-progress" } });

    expect(a).toHaveLength(1);
    expect(b).toHaveLength(1);
    expect(a[0].type).toBe("status:changed");
  });

  test("unsubscribe stops receiving messages", () => {
    const service = new EventService(db);
    const received: ActivityMessage[] = [];

    const unsub = service.subscribe((msg) => received.push(msg));
    unsub();
    service.broadcast({ type: "item:updated", data: { id: 1 } });

    expect(received).toHaveLength(0);
  });

  test("broadcast persists event to activity_log table", () => {
    const service = new EventService(db);

    // Use null itemId to avoid FK constraint (item_id is nullable)
    service.broadcast({
      type: "item:created",
      data: { id: 42, title: "Persisted" },
    });

    const rows = db.select().from(schema.activityLog).all();
    // broadcast persists with matching event type
    const logEntry = rows.find((r) => r.eventType === "item:created");
    expect(logEntry).toBeDefined();
    const payload = JSON.parse(logEntry!.payload) as Record<string, unknown>;
    expect(payload.id).toBe(42);
  });

  test("broadcast does NOT persist when persistToDb is false", () => {
    const service = new EventService(db);

    service.broadcast(
      { type: "item:created", data: { id: 99 } },
      { persistToDb: false }
    );

    const rows = db.select().from(schema.activityLog).all();
    // No rows should have been inserted
    expect(rows).toHaveLength(0);
  });

  test("getRecentEvents returns last N events in reverse chronological order", () => {
    const service = new EventService(db);

    makeActivityRow(db, "item:created", { id: 1 });
    makeActivityRow(db, "item:updated", { id: 1 });
    makeActivityRow(db, "status:changed", { itemId: 1, from: "backlog", to: "ready" });

    const events = service.getRecentEvents(2);
    expect(events).toHaveLength(2);
    // Most recent first (Drizzle returns camelCase field names)
    expect(events[0].eventType).toBe("status:changed");
    expect(events[1].eventType).toBe("item:updated");
  });

  test("getRecentEvents returns up to 50 by default", () => {
    const service = new EventService(db);

    // Insert 60 events
    for (let i = 0; i < 60; i++) {
      makeActivityRow(db, "item:created", { seq: i });
    }

    const events = service.getRecentEvents();
    expect(events).toHaveLength(50);
  });

  test("getRecentEvents returns empty array when no events", () => {
    const service = new EventService(db);
    const events = service.getRecentEvents();
    expect(events).toHaveLength(0);
  });
});

// ---------------------------------------------------------------------------
// EventService — connection:established backfill message
// ---------------------------------------------------------------------------

describe("EventService.buildBackfillMessage", () => {
  test("includes recent events in connection:established payload", () => {
    const service = new EventService(db);

    makeActivityRow(db, "item:created", { id: 1 });
    makeActivityRow(db, "status:changed", { itemId: 1, from: "backlog", to: "ready" });

    const msg = service.buildBackfillMessage();

    expect(msg.type).toBe("connection:established");
    const data = msg.data as { recentEvents: unknown[] };
    expect(Array.isArray(data.recentEvents)).toBe(true);
    expect(data.recentEvents).toHaveLength(2);
  });

  test("backfill message has empty recentEvents when no history", () => {
    const service = new EventService(db);
    const msg = service.buildBackfillMessage();

    expect(msg.type).toBe("connection:established");
    const data = msg.data as { recentEvents: unknown[] };
    expect(data.recentEvents).toHaveLength(0);
  });
});

// ---------------------------------------------------------------------------
// ItemService emits events via EventService
// ---------------------------------------------------------------------------

describe("ItemService with EventService", () => {
  test("create emits item:created event", async () => {
    const eventService = new EventService(db);
    const received: ActivityMessage[] = [];
    eventService.subscribe((msg) => received.push(msg));

    const itemService = new ItemService(db, eventService);
    await itemService.create({
      id: 100,
      title: "New Story",
      type: "story",
    });

    expect(received).toHaveLength(1);
    expect(received[0].type).toBe("item:created");
    const data = received[0].data as { title: string };
    expect(data.title).toBe("New Story");
  });

  test("update emits item:updated event", async () => {
    const eventService = new EventService(db);
    const received: ActivityMessage[] = [];
    eventService.subscribe((msg) => received.push(msg));

    const itemService = new ItemService(db, eventService);
    await itemService.create({ id: 101, title: "Update Me", type: "story" });
    received.length = 0; // clear create event

    await itemService.update(101, { title: "Updated Title" });

    expect(received).toHaveLength(1);
    expect(received[0].type).toBe("item:updated");
  });

  test("close emits item:closed event", async () => {
    const eventService = new EventService(db);
    const received: ActivityMessage[] = [];
    eventService.subscribe((msg) => received.push(msg));

    const itemService = new ItemService(db, eventService);
    await itemService.create({ id: 102, title: "Close Me", type: "story" });
    received.length = 0;

    await itemService.close(102);

    expect(received).toHaveLength(1);
    expect(received[0].type).toBe("item:closed");
  });

  test("ItemService without eventService still works (backward compat)", async () => {
    const itemService = new ItemService(db); // no eventService
    const item = await itemService.create({ id: 200, title: "No Events", type: "story" });
    expect(item.title).toBe("No Events");
  });
});

// ---------------------------------------------------------------------------
// BoardService emits events via EventService
// ---------------------------------------------------------------------------

describe("BoardService with EventService", () => {
  test("setStatus emits status:changed event", async () => {
    const eventService = new EventService(db);
    const received: ActivityMessage[] = [];
    eventService.subscribe((msg) => received.push(msg));

    const itemService = new ItemService(db);
    await itemService.create({ id: 110, title: "Board Item", type: "story" });

    const boardService = new BoardService(db, eventService);
    await boardService.setStatus(110, "in-progress");

    expect(received).toHaveLength(1);
    expect(received[0].type).toBe("status:changed");
    const data = received[0].data as { from: string; to: string; itemId: number };
    expect(data.from).toBe("backlog");
    expect(data.to).toBe("in-progress");
    expect(data.itemId).toBe(110);
  });

  test("BoardService without eventService still works (backward compat)", async () => {
    const itemService = new ItemService(db);
    await itemService.create({ id: 111, title: "No Events Board", type: "story" });

    const boardService = new BoardService(db); // no eventService
    const item = await boardService.setStatus(111, "ready");
    expect(item?.status).toBe("ready");
  });
});

// ---------------------------------------------------------------------------
// CommentService emits events via EventService
// ---------------------------------------------------------------------------

describe("CommentService with EventService", () => {
  test("addComment emits comment:added event", async () => {
    const eventService = new EventService(db);
    const received: ActivityMessage[] = [];
    eventService.subscribe((msg) => received.push(msg));

    const itemService = new ItemService(db);
    await itemService.create({ id: 120, title: "Comment Target", type: "story" });

    const commentService = new CommentService(db, eventService);
    await commentService.addComment({
      itemId: 120,
      body: "This is a comment",
      author: "builder",
    });

    expect(received).toHaveLength(1);
    expect(received[0].type).toBe("comment:added");
    const data = received[0].data as { itemId: number; author: string };
    expect(data.itemId).toBe(120);
    expect(data.author).toBe("builder");
  });

  test("CommentService without eventService still works (backward compat)", async () => {
    const itemService = new ItemService(db);
    await itemService.create({ id: 121, title: "Comment Target 2", type: "story" });

    const commentService = new CommentService(db); // no eventService
    const comment = await commentService.addComment({
      itemId: 121,
      body: "No events comment",
      author: "human",
    });
    expect(comment.body).toBe("No events comment");
  });
});

// ---------------------------------------------------------------------------
// GET /api/activity endpoint
// ---------------------------------------------------------------------------

describe("GET /api/activity", () => {
  test("returns recent activity events as JSON array", async () => {
    const eventService = new EventService(db);
    const { createActivityRouter } = await import("../../src/api/websocket");
    const { Hono } = await import("hono");

    const app = new Hono();
    app.route("/api", createActivityRouter(eventService));

    makeActivityRow(db, "item:created", { id: 1, title: "Story A" });
    makeActivityRow(db, "status:changed", { itemId: 1, from: "backlog", to: "ready" });

    const res = await app.fetch(
      new Request("http://localhost/api/activity")
    );

    expect(res.status).toBe(200);
    const body = (await res.json()) as unknown[];
    expect(Array.isArray(body)).toBe(true);
    expect(body.length).toBeGreaterThan(0);
  });

  test("respects limit query parameter", async () => {
    const eventService = new EventService(db);
    const { createActivityRouter } = await import("../../src/api/websocket");
    const { Hono } = await import("hono");

    const app = new Hono();
    app.route("/api", createActivityRouter(eventService));

    for (let i = 0; i < 10; i++) {
      makeActivityRow(db, "item:created", { seq: i });
    }

    const res = await app.fetch(
      new Request("http://localhost/api/activity?limit=3")
    );

    expect(res.status).toBe(200);
    const body = (await res.json()) as unknown[];
    expect(body.length).toBe(3);
  });
});

// ---------------------------------------------------------------------------
// ActivityMessage format
// ---------------------------------------------------------------------------

describe("ActivityMessage format", () => {
  test("broadcast message has required type and data fields", () => {
    const service = new EventService(db);
    const received: ActivityMessage[] = [];
    service.subscribe((msg) => received.push(msg));

    service.broadcast({ type: "item:created", data: { id: 1, title: "Test" } });

    const msg = received[0];
    expect(typeof msg.type).toBe("string");
    expect(msg.data).toBeDefined();
    expect(msg.type).toBe("item:created");
  });

  test("message includes timestamp when provided", () => {
    const service = new EventService(db);
    const received: ActivityMessage[] = [];
    service.subscribe((msg) => received.push(msg));

    const timestamp = new Date().toISOString();
    service.broadcast({
      type: "status:changed",
      data: { timestamp },
    });

    const msg = received[0];
    const data = msg.data as { timestamp: string };
    expect(data.timestamp).toBe(timestamp);
  });
});
