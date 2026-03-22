import { Hono } from "hono";
import { LifecycleService } from "../services/lifecycle";
import { StartWorkBodySchema, CompleteWorkBodySchema, formatZodError } from "./validation";

// ---------------------------------------------------------------------------
// Router factory
// ---------------------------------------------------------------------------

/**
 * Create the lifecycle Hono router.
 *
 * Routes:
 *   POST /api/items/:id/start    — Start work on an item (transitions to in-progress)
 *   POST /api/items/:id/complete — Complete work on an item (transitions to in-review)
 *
 * All routes validate input with Zod and delegate to the service layer.
 * Error format: `{ error: string, details?: [...] }`.
 *
 * @param lifecycleService - LifecycleService instance
 */
export function createLifecycleRouter(lifecycleService: LifecycleService): Hono {
  const router = new Hono();

  // ---------------------------------------------------------------------------
  // POST /api/items/:id/start — Start work
  // ---------------------------------------------------------------------------

  router.post("/items/:id/start", async (c) => {
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

    const parseResult = StartWorkBodySchema.safeParse(raw);
    if (!parseResult.success) {
      return c.json(formatZodError(parseResult.error), 400);
    }

    const updated = await lifecycleService.startWork(id, parseResult.data);
    if (!updated) {
      return c.json({ error: `Item ${id} not found`, details: [] }, 404);
    }

    return c.json(updated);
  });

  // ---------------------------------------------------------------------------
  // POST /api/items/:id/complete — Complete work
  // ---------------------------------------------------------------------------

  router.post("/items/:id/complete", async (c) => {
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

    const parseResult = CompleteWorkBodySchema.safeParse(raw);
    if (!parseResult.success) {
      return c.json(formatZodError(parseResult.error), 400);
    }

    const updated = await lifecycleService.completeWork(id, parseResult.data);
    if (!updated) {
      return c.json({ error: `Item ${id} not found`, details: [] }, 404);
    }

    return c.json(updated);
  });

  return router;
}
