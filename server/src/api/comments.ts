import { Hono } from "hono";
import { CommentService } from "../services/comments";
import { ItemService } from "../services/items";
import { AddCommentBodySchema, formatZodError } from "./validation";

// ---------------------------------------------------------------------------
// Router factory
// ---------------------------------------------------------------------------

/**
 * Create the comments Hono router.
 *
 * Routes:
 *   GET  /api/items/:id/comments — List comments for an item
 *   POST /api/items/:id/comments — Add a comment to an item
 *
 * All routes validate input with Zod and delegate to the service layer.
 * Error format: `{ error: string, details?: [...] }`.
 *
 * @param commentService - CommentService instance
 * @param itemService - ItemService instance (used to verify item existence)
 */
export function createCommentsRouter(
  commentService: CommentService,
  itemService?: ItemService
): Hono {
  const router = new Hono();

  // ---------------------------------------------------------------------------
  // GET /api/items/:id/comments — List comments
  // ---------------------------------------------------------------------------

  router.get("/items/:id/comments", async (c) => {
    const idStr = c.req.param("id");
    const id = Number(idStr);

    if (!Number.isInteger(id) || id <= 0 || isNaN(id)) {
      return c.json({ error: "Invalid item id — must be a positive integer", details: [] }, 400);
    }

    // Verify item exists before listing comments
    if (itemService) {
      const item = await itemService.get(id);
      if (!item) {
        return c.json({ error: `Item ${id} not found`, details: [] }, 404);
      }
    }

    const comments = await commentService.listComments(id);
    return c.json(comments);
  });

  // ---------------------------------------------------------------------------
  // POST /api/items/:id/comments — Add comment
  // ---------------------------------------------------------------------------

  router.post("/items/:id/comments", async (c) => {
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

    const parseResult = AddCommentBodySchema.safeParse(raw);
    if (!parseResult.success) {
      return c.json(formatZodError(parseResult.error), 400);
    }

    const comment = await commentService.addComment({
      itemId: id,
      body: parseResult.data.body,
      author: parseResult.data.author,
    });

    return c.json(comment, 201);
  });

  return router;
}
