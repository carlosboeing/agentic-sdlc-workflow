import { Hono } from "hono";
import { sql } from "drizzle-orm";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { ItemService } from "../services/items";
import { LabelService } from "../services/labels";
import { HierarchyService } from "../services/hierarchy";
import * as schema from "../db/schema";
import {
  CreateItemBodySchema,
  UpdateItemBodySchema,
  ListItemsQuerySchema,
  CreateLabelBodySchema,
  formatZodError,
} from "./validation";

type Db = ReturnType<typeof drizzle>;

// ---------------------------------------------------------------------------
// ID generation
// ---------------------------------------------------------------------------

/**
 * Generate a new local item ID.
 *
 * Strategy: max(existing ids) + 1, with fallback to 1 when table is empty.
 * This matches the design doc's "GitHub-first ID with local fallback" approach
 * where local-only IDs are assigned sequentially from existing max.
 */
function generateLocalId(db: Db): number {
  const result = db
    .select({ maxId: sql<number>`coalesce(max(${schema.items.id}), 0)` })
    .from(schema.items)
    .all();
  const maxId = result[0]?.maxId ?? 0;
  return maxId + 1;
}

// ---------------------------------------------------------------------------
// Router factory
// ---------------------------------------------------------------------------

/**
 * Create the items and labels Hono router.
 *
 * All routes validate input with Zod and delegate to the service layer.
 * Error format is consistent: `{ error: string, details?: [...] }`.
 *
 * @param itemService - ItemService instance (constructed with a DB connection)
 * @param labelService - LabelService instance
 * @param db - Raw Drizzle DB connection (shared with services, used for ID generation and hierarchy queries)
 */
export function createItemsRouter(
  itemService: ItemService,
  labelService: LabelService,
  db: Db
): Hono {
  const hierarchyService = new HierarchyService(db);
  const router = new Hono();

  // ---------------------------------------------------------------------------
  // GET /api/items — List with filters
  // ---------------------------------------------------------------------------

  router.get("/items", async (c) => {
    const rawQuery = c.req.query();
    const parseResult = ListItemsQuerySchema.safeParse(rawQuery);

    if (!parseResult.success) {
      return c.json(formatZodError(parseResult.error), 400);
    }

    const items = await itemService.list(parseResult.data);
    return c.json(items);
  });

  // ---------------------------------------------------------------------------
  // POST /api/items — Create
  // ---------------------------------------------------------------------------

  router.post("/items", async (c) => {
    let raw: unknown;
    try {
      raw = await c.req.json();
    } catch {
      return c.json(
        { error: "Invalid JSON body", details: [] },
        400
      );
    }

    const parseResult = CreateItemBodySchema.safeParse(raw);
    if (!parseResult.success) {
      return c.json(formatZodError(parseResult.error), 400);
    }

    const data = parseResult.data;
    const id = generateLocalId(db);

    const item = await itemService.create({
      id,
      title: data.title,
      type: data.type,
      body: data.body,
      status: data.status,
      state: data.state,
      parentId: data.parentId,
      externalId: data.externalId,
      externalUrl: data.externalUrl,
      createdBy: data.createdBy,
    });

    // Attach labels if provided
    if (data.labels && data.labels.length > 0) {
      for (const labelName of data.labels) {
        await labelService.addLabelToItem(item.id, labelName);
      }
    }

    return c.json(item, 201);
  });

  // ---------------------------------------------------------------------------
  // GET /api/items/:id — Get single item with labels and children
  // ---------------------------------------------------------------------------

  router.get("/items/:id", async (c) => {
    const idStr = c.req.param("id");
    const id = Number(idStr);

    if (!Number.isInteger(id) || id <= 0 || isNaN(id)) {
      return c.json({ error: "Invalid item id — must be a positive integer", details: [] }, 400);
    }

    const item = await itemService.get(id);
    if (!item) {
      return c.json({ error: `Item ${id} not found`, details: [] }, 404);
    }

    // Fetch labels and children via their services
    const labels = await labelService.getLabelsForItem(id);
    const children = await hierarchyService.listChildren(id);

    return c.json({ ...item, labels, children });
  });

  // ---------------------------------------------------------------------------
  // PATCH /api/items/:id — Update allowed fields
  // ---------------------------------------------------------------------------

  router.patch("/items/:id", async (c) => {
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

    const parseResult = UpdateItemBodySchema.safeParse(raw);
    if (!parseResult.success) {
      return c.json(formatZodError(parseResult.error), 400);
    }

    const updated = await itemService.update(id, parseResult.data);
    if (!updated) {
      return c.json({ error: `Item ${id} not found`, details: [] }, 404);
    }

    return c.json(updated);
  });

  // ---------------------------------------------------------------------------
  // DELETE /api/items/:id — Soft-close item
  // ---------------------------------------------------------------------------

  router.delete("/items/:id", async (c) => {
    const idStr = c.req.param("id");
    const id = Number(idStr);

    if (!Number.isInteger(id) || id <= 0 || isNaN(id)) {
      return c.json({ error: "Invalid item id — must be a positive integer", details: [] }, 400);
    }

    const closed = await itemService.close(id);
    if (!closed) {
      return c.json({ error: `Item ${id} not found`, details: [] }, 404);
    }

    return c.json(closed);
  });

  // ---------------------------------------------------------------------------
  // GET /api/labels — List all labels
  // ---------------------------------------------------------------------------

  router.get("/labels", async (c) => {
    const labels = await labelService.listLabels();
    return c.json(labels);
  });

  // ---------------------------------------------------------------------------
  // POST /api/labels — Create label
  // ---------------------------------------------------------------------------

  router.post("/labels", async (c) => {
    let raw: unknown;
    try {
      raw = await c.req.json();
    } catch {
      return c.json({ error: "Invalid JSON body", details: [] }, 400);
    }

    const parseResult = CreateLabelBodySchema.safeParse(raw);
    if (!parseResult.success) {
      return c.json(formatZodError(parseResult.error), 400);
    }

    const label = await labelService.createLabel(parseResult.data);
    return c.json(label, 201);
  });

  return router;
}
