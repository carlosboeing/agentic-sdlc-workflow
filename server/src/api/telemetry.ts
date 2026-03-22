import { Hono } from "hono";
import { LifecycleService } from "../services/lifecycle";
import { ItemService } from "../services/items";
import {
  StartWorkBodySchema,
  CompleteWorkBodySchema,
  PostTelemetryBodySchema,
  formatZodError,
} from "./validation";

// ---------------------------------------------------------------------------
// Router factory
// ---------------------------------------------------------------------------

/**
 * Create the telemetry and lifecycle Hono router.
 *
 * Routes:
 *   POST /api/items/:id/start     — Start work (lifecycle transition → in-progress)
 *   POST /api/items/:id/complete  — Complete work (lifecycle transition → in-review)
 *   POST /api/items/:id/telemetry — Post telemetry data for an item
 *   GET  /api/items/:id/telemetry — Get all telemetry for an item
 *
 * All routes validate input with Zod and delegate to LifecycleService.
 * Error format: `{ error: string, details?: [...] }`.
 *
 * @param lifecycleService - LifecycleService instance
 * @param itemService - ItemService instance (used to verify item existence for GET telemetry)
 */
export function createTelemetryRouter(
  lifecycleService: LifecycleService,
  itemService?: ItemService
): Hono {
  const router = new Hono();

  // ---------------------------------------------------------------------------
  // POST /api/items/:id/start — Start work (lifecycle)
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
  // POST /api/items/:id/complete — Complete work (lifecycle)
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

  // ---------------------------------------------------------------------------
  // POST /api/items/:id/telemetry — Post telemetry data
  // ---------------------------------------------------------------------------

  router.post("/items/:id/telemetry", async (c) => {
    const idStr = c.req.param("id");
    const id = Number(idStr);

    if (!Number.isInteger(id) || id <= 0 || isNaN(id)) {
      return c.json({ error: "Invalid item id — must be a positive integer", details: [] }, 400);
    }

    // Verify item exists
    if (itemService) {
      const item = await itemService.get(id);
      if (!item) {
        return c.json({ error: `Item ${id} not found`, details: [] }, 404);
      }
    }

    let raw: unknown;
    try {
      raw = await c.req.json();
    } catch {
      return c.json({ error: "Invalid JSON body", details: [] }, 400);
    }

    const parseResult = PostTelemetryBodySchema.safeParse(raw);
    if (!parseResult.success) {
      return c.json(formatZodError(parseResult.error), 400);
    }

    const telemetry = await lifecycleService.postTelemetry(id, parseResult.data);
    return c.json(telemetry, 201);
  });

  // ---------------------------------------------------------------------------
  // GET /api/items/:id/telemetry — Get item telemetry
  // ---------------------------------------------------------------------------

  router.get("/items/:id/telemetry", async (c) => {
    const idStr = c.req.param("id");
    const id = Number(idStr);

    if (!Number.isInteger(id) || id <= 0 || isNaN(id)) {
      return c.json({ error: "Invalid item id — must be a positive integer", details: [] }, 400);
    }

    // Verify item exists
    if (itemService) {
      const item = await itemService.get(id);
      if (!item) {
        return c.json({ error: `Item ${id} not found`, details: [] }, 404);
      }
    }

    const rows = await lifecycleService.getTelemetry(id);
    return c.json(rows);
  });

  return router;
}
