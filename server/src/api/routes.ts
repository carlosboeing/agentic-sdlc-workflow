import type { Hono } from "hono";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { ItemService } from "../services/items";
import { LabelService } from "../services/labels";
import { BoardService } from "../services/board";
import { CommentService } from "../services/comments";
import { HierarchyService } from "../services/hierarchy";
import { LifecycleService } from "../services/lifecycle";
import { EventService, createActivityRouter } from "./websocket";
import { createItemsRouter } from "./items";
import { createBoardRouter } from "./board";
import { createCommentsRouter } from "./comments";
import { createHierarchyRouter } from "./hierarchy";
import { createTelemetryRouter } from "./telemetry";

type Db = ReturnType<typeof drizzle>;

/**
 * Mount all API route groups onto the provided Hono app.
 *
 * This is the single registration point for all routes.
 * Each route group is created with the appropriate services.
 *
 * Route groups:
 *   items.ts     — /api/items CRUD (E02-S01)
 *   board.ts     — /api/items/:id/status (E02-S02)
 *   comments.ts  — /api/items/:id/comments (E02-S02)
 *   hierarchy.ts — /api/items/:id/children (E02-S02)
 *   telemetry.ts — /api/items/:id/telemetry + start + complete (E02-S02)
 *   websocket.ts — /api/activity feed endpoint (E05-S04)
 *
 * @param app          - The Hono application instance
 * @param db           - Drizzle DB connection shared by all route groups
 * @param eventService - Optional EventService for real-time broadcasts.
 *                       When omitted, services run without WebSocket events.
 */
export function registerRoutes(app: Hono, db: Db, eventService?: EventService): void {
  const effectiveEventService = eventService ?? new EventService(db);
  const itemService = new ItemService(db, effectiveEventService);
  const labelService = new LabelService(db);
  const boardService = new BoardService(db, effectiveEventService);
  const commentService = new CommentService(db, effectiveEventService);
  const hierarchyService = new HierarchyService(db);
  const lifecycleService = new LifecycleService(db, effectiveEventService);

  // Item CRUD + label management (E02-S01)
  app.route("/api", createItemsRouter(itemService, labelService, db));

  // Board status transitions (E02-S02)
  app.route("/api", createBoardRouter(boardService));

  // Item comments (E02-S02)
  app.route("/api", createCommentsRouter(commentService, itemService));

  // Parent-child hierarchy (E02-S02)
  app.route("/api", createHierarchyRouter(hierarchyService, itemService));

  // Lifecycle (start/complete) + telemetry (E02-S02)
  app.route("/api", createTelemetryRouter(lifecycleService, itemService));

  // Activity feed REST endpoint (E05-S04)
  app.route("/api", createActivityRouter(effectiveEventService));
}
