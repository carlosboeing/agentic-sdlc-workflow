import { Hono } from "hono";
import { HierarchyService } from "../services/hierarchy";
import { ItemService } from "../services/items";
import { LinkChildBodySchema, formatZodError } from "./validation";

// ---------------------------------------------------------------------------
// Router factory
// ---------------------------------------------------------------------------

/**
 * Create the hierarchy Hono router.
 *
 * Routes:
 *   POST /api/items/:id/children — Link a child item to a parent
 *   GET  /api/items/:id/children — List direct children of an item
 *
 * All routes validate input with Zod and delegate to the service layer.
 * Error format: `{ error: string, details?: [...] }`.
 *
 * @param hierarchyService - HierarchyService instance
 * @param itemService - ItemService instance (used to verify item existence)
 */
export function createHierarchyRouter(
  hierarchyService: HierarchyService,
  itemService?: ItemService
): Hono {
  const router = new Hono();

  // ---------------------------------------------------------------------------
  // POST /api/items/:id/children — Link a child item
  // ---------------------------------------------------------------------------

  router.post("/items/:id/children", async (c) => {
    const idStr = c.req.param("id");
    const parentId = Number(idStr);

    if (!Number.isInteger(parentId) || parentId <= 0 || isNaN(parentId)) {
      return c.json({ error: "Invalid item id — must be a positive integer", details: [] }, 400);
    }

    let raw: unknown;
    try {
      raw = await c.req.json();
    } catch {
      return c.json({ error: "Invalid JSON body", details: [] }, 400);
    }

    const parseResult = LinkChildBodySchema.safeParse(raw);
    if (!parseResult.success) {
      return c.json(formatZodError(parseResult.error), 400);
    }

    const { childId } = parseResult.data;

    // linkChild returns null when either parent or child does not exist
    const updated = await hierarchyService.linkChild(parentId, childId);
    if (!updated) {
      return c.json(
        { error: `Parent item ${parentId} or child item ${childId} not found`, details: [] },
        404
      );
    }

    return c.json(updated);
  });

  // ---------------------------------------------------------------------------
  // GET /api/items/:id/children — List direct children
  // ---------------------------------------------------------------------------

  router.get("/items/:id/children", async (c) => {
    const idStr = c.req.param("id");
    const parentId = Number(idStr);

    if (!Number.isInteger(parentId) || parentId <= 0 || isNaN(parentId)) {
      return c.json({ error: "Invalid item id — must be a positive integer", details: [] }, 400);
    }

    // Verify parent exists before listing children
    if (itemService) {
      const item = await itemService.get(parentId);
      if (!item) {
        return c.json({ error: `Item ${parentId} not found`, details: [] }, 404);
      }
    }

    const children = await hierarchyService.listChildren(parentId);
    return c.json(children);
  });

  return router;
}
