/**
 * WebSocket upgrade handler and EventService pub/sub hub.
 *
 * Architecture:
 * - EventService: in-process pub/sub for real-time activity events.
 *   Services (ItemService, BoardService, CommentService) call
 *   eventService.broadcast() after each mutation.
 * - The server's WebSocket handler subscribes to EventService and
 *   pushes messages to all connected WS clients via Bun native pub/sub.
 * - On client connect, the server sends a connection:established message
 *   with a backfill of the last 50 activity_log entries.
 *
 * WebSocket endpoint: ws://localhost:<port>/ws
 *
 * Message format (server → client):
 *   { type: ActivityEventType, data: unknown }
 */

import { desc } from "drizzle-orm";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import type { Hono } from "hono";
import * as schema from "../db/schema";
import type { ActivityEventType } from "../types";

type Db = ReturnType<typeof drizzle>;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ActivityMessage {
  /** Event type matching ActivityEventType. */
  type: ActivityEventType | "connection:established";
  /** Event payload — shape depends on type. */
  data: unknown;
  /**
   * Optional item ID for scoped events.
   * Used to set itemId when persisting to activity_log.
   */
  itemId?: number;
}

export type BroadcastOptions = {
  /** When false, the event is not written to activity_log. Default: true. */
  persistToDb?: boolean;
};

type Listener = (msg: ActivityMessage) => void;

// ---------------------------------------------------------------------------
// EventService
// ---------------------------------------------------------------------------

/**
 * In-process pub/sub hub for activity events.
 *
 * Services call broadcast() after mutations. The WebSocket upgrade handler
 * subscribes to push messages to connected clients.
 */
export class EventService {
  private readonly listeners = new Set<Listener>();

  constructor(private readonly db: Db) {}

  /**
   * Subscribe to broadcast events. Returns an unsubscribe function.
   */
  subscribe(listener: Listener): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /**
   * Broadcast an activity message to all subscribers.
   *
   * By default also persists the event to the activity_log table so
   * new clients can receive a backfill on connect.
   */
  broadcast(msg: ActivityMessage, options: BroadcastOptions = {}): void {
    const { persistToDb = true } = options;

    if (persistToDb && msg.type !== "connection:established") {
      const now = new Date().toISOString();
      try {
        this.db
          .insert(schema.activityLog)
          .values({
            itemId: msg.itemId ?? null,
            eventType: msg.type,
            payload: JSON.stringify(msg.data),
            createdAt: now,
          })
          .run();
      } catch {
        // Non-fatal: if DB write fails, still dispatch to listeners
        process.stderr.write(`EventService: failed to persist event ${msg.type}\n`);
      }
    }

    for (const listener of this.listeners) {
      try {
        listener(msg);
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        process.stderr.write(`EventService: listener error: ${message}\n`);
      }
    }
  }

  /**
   * Retrieve the most recent activity log entries, newest first.
   * Defaults to 50 entries (matching the design doc).
   */
  getRecentEvents(limit = 50): typeof schema.activityLog.$inferSelect[] {
    return this.db
      .select()
      .from(schema.activityLog)
      .orderBy(desc(schema.activityLog.id))
      .limit(limit)
      .all();
  }

  /**
   * Build the connection:established backfill message sent to new clients.
   */
  buildBackfillMessage(): ActivityMessage {
    const recentEvents = this.getRecentEvents(50);
    return {
      type: "connection:established",
      data: {
        recentEvents,
      },
    };
  }
}

// ---------------------------------------------------------------------------
// Activity REST router
// ---------------------------------------------------------------------------

/**
 * Create a Hono router for the activity feed REST endpoint.
 *
 * GET /api/activity?limit=<n>  — returns recent activity log entries.
 */
export function createActivityRouter(eventService: EventService): Hono {
  // Lazy import to avoid circular issues and keep the module importable in tests
  const { Hono } = require("hono") as typeof import("hono");
  const router = new Hono();

  router.get("/activity", (c) => {
    const limitParam = c.req.query("limit");
    const limit = limitParam ? Math.min(parseInt(limitParam, 10) || 50, 200) : 50;
    const events = eventService.getRecentEvents(limit);
    return c.json(events);
  });

  return router;
}

// ---------------------------------------------------------------------------
// Bun WebSocket upgrade handler
// ---------------------------------------------------------------------------

/**
 * Bun-native WebSocket upgrade handler options.
 *
 * The Bun.serve() websocket property is set with these handlers.
 * Each client is subscribed to the "activity" topic.
 */
export type BunWsData = {
  /** Client connection identifier (for logging). */
  clientId: string;
};

/**
 * Build the Bun WebSocket handler object for use in Bun.serve().
 *
 * @param eventService - The EventService instance to subscribe to.
 * @param serverRef    - Mutable reference to the Bun server (set after Bun.serve()
 *                       returns). Used to publish messages.
 */
export function createWsHandler(
  eventService: EventService,
  serverRef: { current: ReturnType<typeof Bun.serve> | null }
): {
  open: (ws: { subscribe: (topic: string) => void; send: (msg: string) => void; data: BunWsData }) => void;
  message: (ws: { data: BunWsData }, message: string | Buffer) => void;
  close: (ws: { data: BunWsData }, code: number, reason: string) => void;
} {
  // Subscribe to EventService and publish to Bun's "activity" topic
  eventService.subscribe((msg) => {
    if (serverRef.current) {
      try {
        serverRef.current.publish("activity", JSON.stringify(msg));
      } catch {
        // Server may have stopped
      }
    }
  });

  return {
    open(ws) {
      ws.subscribe("activity");
      // Send backfill
      const backfill = eventService.buildBackfillMessage();
      ws.send(JSON.stringify(backfill));
      process.stderr.write(`WS: client ${ws.data.clientId} connected\n`);
    },
    message(ws, message) {
      // Clients do not send messages in this protocol; log and ignore
      process.stderr.write(
        `WS: client ${ws.data.clientId} sent message (ignored): ${String(message).slice(0, 100)}\n`
      );
    },
    close(ws, code, reason) {
      process.stderr.write(
        `WS: client ${ws.data.clientId} disconnected (${code} ${reason})\n`
      );
    },
  };
}

/**
 * Add a /ws WebSocket upgrade endpoint to the provided Bun server fetch handler.
 *
 * This function wraps a Hono app's fetch so that requests to /ws are
 * upgraded to WebSocket connections before Hono sees them.
 *
 * Usage:
 *   const app = createApp(options);
 *   const serverRef = { current: null };
 *   const fetch = withWebSocketUpgrade(app.fetch, serverRef);
 *   const server = Bun.serve({ port, fetch, websocket: createWsHandler(eventService, serverRef) });
 *   serverRef.current = server;
 */
export function withWebSocketUpgrade(
  baseFetch: (req: Request, server: ReturnType<typeof Bun.serve>) => Response | Promise<Response>,
  serverRef: { current: ReturnType<typeof Bun.serve> | null }
): (req: Request, server: ReturnType<typeof Bun.serve>) => Response | Promise<Response> {
  return (req: Request, server: ReturnType<typeof Bun.serve>) => {
    const url = new URL(req.url);
    if (url.pathname === "/ws") {
      const clientId = crypto.randomUUID();
      const upgraded = server.upgrade(req, { data: { clientId } satisfies BunWsData });
      if (upgraded) {
        return new Response(null, { status: 101 });
      }
      return new Response("WebSocket upgrade failed", { status: 426 });
    }
    return baseFetch(req, server);
  };
}
