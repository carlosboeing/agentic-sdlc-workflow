import { Hono } from "hono";
import { BoardService } from "../services/board";
import { SetStatusBodySchema, formatZodError } from "./validation";

// ---------------------------------------------------------------------------
// Router factory
// ---------------------------------------------------------------------------

/**
 * Create the board status Hono router.
 *
 * Routes:
 *   POST /api/items/:id/status — Set board status for an item
 *
 * All routes validate input with Zod and delegate to the service layer.
 * Error format: `{ error: string, details?: [...] }`.
 *
 * @param boardService - BoardService instance (constructed with a DB connection)
 */
export function createBoardRouter(boardService: BoardService): Hono {
  const router = new Hono();

  // ---------------------------------------------------------------------------
  // POST /api/items/:id/status — Set board status
  // ---------------------------------------------------------------------------

  router.post("/items/:id/status", async (c) => {
    const idStr = c.req.param("id");
    const id = Number(idStr);

    if (!Number.isInteger(id) || id <= 0 || isNaN(id)) {
      return c.json({ error: "Invalid item id — must be a positive integer", details: [] }, 400);
    }

    let raw: unknown;
    try {
      raw = await c.req.json();
    } catch {
      return c.json({ error: "Invalid JSON body", details: [] }, 400);
    }

    const parseResult = SetStatusBodySchema.safeParse(raw);
    if (!parseResult.success) {
      return c.json(formatZodError(parseResult.error), 400);
    }

    const updated = await boardService.setStatus(id, parseResult.data.status);
    if (!updated) {
      return c.json({ error: `Item ${id} not found`, details: [] }, 404);
    }

    return c.json(updated);
  });

  return router;
}
