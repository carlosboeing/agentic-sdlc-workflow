import type { Hono } from "hono";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { ItemService } from "../services/items";
import { LabelService } from "../services/labels";
import { createItemsRouter } from "./items";

type Db = ReturnType<typeof drizzle>;

/**
 * Mount all API route groups onto the provided Hono app.
 *
 * This is the single registration point for all routes.
 * Future epics add their routers here (board, comments, telemetry, etc.).
 *
 * @param app - The Hono application instance
 * @param db  - Drizzle DB connection shared by all route groups
 */
export function registerRoutes(app: Hono, db: Db): void {
  const itemService = new ItemService(db);
  const labelService = new LabelService(db);

  // Item CRUD + label management (E02-S01)
  app.route("/api", createItemsRouter(itemService, labelService, db));

  // Future route groups will be registered here:
  // app.route("/api", createBoardRouter(boardService));          // E02-S02
  // app.route("/api", createLifecycleRouter(lifecycleService));  // E02-S02
  // app.route("/api", createCommentsRouter(commentService));     // E02-S02
}
