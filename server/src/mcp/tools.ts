/**
 * MCP tool handler implementations for PM operations.
 *
 * Each tool is a thin wrapper that delegates to the PM service layer.
 * Tool handlers are exported as a record for two purposes:
 *   1. Registration with the McpServer instance (in server.ts)
 *   2. Direct testing without the MCP transport (in tests/mcp/tools.test.ts)
 *
 * All results use the MCP content format:
 *   { content: [{ type: "text", text: JSON.stringify(result) }] }
 */

import { sql } from "drizzle-orm";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { z } from "zod";
import * as schema from "../db/schema";
import type { ItemService } from "../services/items";
import type { BoardService } from "../services/board";
import type { CommentService } from "../services/comments";
import type { HierarchyService } from "../services/hierarchy";
import type { LifecycleService } from "../services/lifecycle";
import type { LabelService } from "../services/labels";

type Db = ReturnType<typeof drizzle>;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** MCP-formatted tool result. */
export interface McpToolResult {
  content: Array<{ type: "text"; text: string }>;
  isError?: boolean;
}

/** A single MCP tool definition: schema + handler + description. */
export interface McpToolHandler {
  description: string;
  inputSchema: Record<string, z.ZodTypeAny>;
  handler: (args: Record<string, unknown>) => Promise<McpToolResult>;
}

/** Service dependencies for MCP tool handlers. */
export interface McpToolServices {
  db: Db;
  itemService: ItemService;
  boardService: BoardService;
  commentService: CommentService;
  hierarchyService: HierarchyService;
  lifecycleService: LifecycleService;
  labelService: LabelService;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function success(data: unknown): McpToolResult {
  return {
    content: [{ type: "text", text: JSON.stringify(data) }],
  };
}

function error(message: string): McpToolResult {
  return {
    content: [{ type: "text", text: JSON.stringify({ error: message }) }],
    isError: true,
  };
}

// ---------------------------------------------------------------------------
// Input schemas (Zod raw shapes for MCP SDK compatibility)
// ---------------------------------------------------------------------------

export const createItemSchema = {
  type: z.enum(["backlog", "epic", "story", "docs"]),
  title: z.string(),
  body: z.string().optional(),
  labels: z.array(z.string()).optional(),
  parent_id: z.number().int().positive().optional(),
};

export const getItemSchema = {
  id: z.number().int().positive(),
};

export const listItemsSchema = {
  type: z.enum(["backlog", "epic", "story", "docs"]).optional(),
  status: z
    .enum(["backlog", "ready", "in-progress", "in-review", "done"])
    .optional(),
  state: z.enum(["open", "closed"]).optional(),
  label: z.string().optional(),
  limit: z.number().int().positive().optional(),
};

export const updateItemSchema = {
  id: z.number().int().positive(),
  title: z.string().optional(),
  body: z.string().optional(),
};

export const closeItemSchema = {
  id: z.number().int().positive(),
};

export const setStatusSchema = {
  id: z.number().int().positive(),
  status: z.enum(["backlog", "ready", "in-progress", "in-review", "done"]),
};

export const linkChildSchema = {
  parent_id: z.number().int().positive(),
  child_id: z.number().int().positive(),
};

export const addCommentSchema = {
  item_id: z.number().int().positive(),
  body: z.string(),
};

export const startWorkSchema = {
  id: z.number().int().positive(),
  model: z.string(),
  agent: z.string(),
};

export const completeWorkSchema = {
  id: z.number().int().positive(),
  commit: z.string(),
};

export const postTelemetrySchema = {
  id: z.number().int().positive(),
  model: z.enum(["haiku", "sonnet", "opus", "mixed"]),
  duration_ms: z.number().int().nonnegative(),
  tokens: z.number().int().nonnegative().optional(),
  tool_uses: z.number().int().nonnegative().optional(),
  cost_estimate: z.number().nonnegative().optional(),
  commit: z.string().optional(),
};

export const addDocCommentSchema = {
  path: z.string(),
  body: z.string(),
  anchor: z.string().optional(),
};

export const listDocCommentsSchema = {
  path: z.string(),
};

// ---------------------------------------------------------------------------
// ID generation (mirrors server/src/api/items.ts generateLocalId)
// ---------------------------------------------------------------------------

function generateLocalId(db: Db): number {
  const result = db
    .select({ maxId: sql<number>`coalesce(max(${schema.items.id}), 0)` })
    .from(schema.items)
    .all();
  const maxId = result[0]?.maxId ?? 0;
  return maxId + 1;
}

// ---------------------------------------------------------------------------
// Tool handler factory
// ---------------------------------------------------------------------------

/**
 * Create all MCP tool handler definitions.
 *
 * Returns a record keyed by tool name, each containing:
 *   - description: Human-readable tool description
 *   - inputSchema: Zod raw shape for MCP SDK input validation
 *   - handler: Async function that delegates to the service layer
 */
export function createMcpToolHandlers(
  services: McpToolServices
): Record<string, McpToolHandler> {
  const {
    db,
    itemService,
    boardService,
    commentService,
    hierarchyService,
    lifecycleService,
    labelService,
  } = services;

  return {
    // ----- Item CRUD -----

    create_item: {
      description:
        "Create a work item (backlog, epic, story, or docs) in the PM system",
      inputSchema: createItemSchema,
      handler: async (args) => {
        const id = generateLocalId(db);
        const item = await itemService.create({
          id,
          title: args.title as string,
          type: args.type as "backlog" | "epic" | "story" | "docs",
          body: args.body as string | undefined,
          parentId: args.parent_id as number | undefined,
        });

        // Handle labels if provided (addLabelToItem has upsert semantics)
        const labels = args.labels as string[] | undefined;
        if (labels && labels.length > 0) {
          for (const labelName of labels) {
            await labelService.addLabelToItem(item.id, labelName);
          }
        }

        return success(item);
      },
    },

    get_item: {
      description: "Get details of a work item by its ID",
      inputSchema: getItemSchema,
      handler: async (args) => {
        const item = await itemService.get(args.id as number);
        if (!item) {
          return error(`Item ${args.id} not found`);
        }
        return success(item);
      },
    },

    list_items: {
      description:
        "List work items with optional filtering by type, status, state, label, and limit",
      inputSchema: listItemsSchema,
      handler: async (args) => {
        const items = await itemService.list({
          type: args.type as
            | "backlog"
            | "epic"
            | "story"
            | "docs"
            | undefined,
          status: args.status as
            | "backlog"
            | "ready"
            | "in-progress"
            | "in-review"
            | "done"
            | undefined,
          state: args.state as "open" | "closed" | undefined,
          label: args.label as string | undefined,
          limit: args.limit as number | undefined,
        });
        return success(items);
      },
    },

    update_item: {
      description: "Update a work item's title and/or body",
      inputSchema: updateItemSchema,
      handler: async (args) => {
        const item = await itemService.update(args.id as number, {
          title: args.title as string | undefined,
          body: args.body as string | undefined,
        });
        if (!item) {
          return error(`Item ${args.id} not found`);
        }
        return success(item);
      },
    },

    close_item: {
      description: "Close a work item (set state to closed)",
      inputSchema: closeItemSchema,
      handler: async (args) => {
        const item = await itemService.close(args.id as number);
        if (!item) {
          return error(`Item ${args.id} not found`);
        }
        return success(item);
      },
    },

    // ----- Board -----

    set_status: {
      description:
        "Set the board status of a work item (backlog, ready, in-progress, in-review, done)",
      inputSchema: setStatusSchema,
      handler: async (args) => {
        const item = await boardService.setStatus(
          args.id as number,
          args.status as
            | "backlog"
            | "ready"
            | "in-progress"
            | "in-review"
            | "done"
        );
        if (!item) {
          return error(`Item ${args.id} not found`);
        }
        return success(item);
      },
    },

    // ----- Hierarchy -----

    link_child: {
      description: "Link a child work item to a parent item",
      inputSchema: linkChildSchema,
      handler: async (args) => {
        const child = await hierarchyService.linkChild(
          args.parent_id as number,
          args.child_id as number
        );
        if (!child) {
          return error(
            `Parent ${args.parent_id} or child ${args.child_id} not found`
          );
        }
        return success(child);
      },
    },

    // ----- Comments -----

    add_comment: {
      description: "Add a comment to a work item",
      inputSchema: addCommentSchema,
      handler: async (args) => {
        const comment = await commentService.addComment({
          itemId: args.item_id as number,
          body: args.body as string,
          author: "mcp",
        });
        return success(comment);
      },
    },

    // ----- Lifecycle -----

    start_work: {
      description:
        "Start work on a work item (sets status to in-progress, logs agent and model)",
      inputSchema: startWorkSchema,
      handler: async (args) => {
        const item = await lifecycleService.startWork(args.id as number, {
          agent: args.agent as string,
          model: args.model as string,
        });
        if (!item) {
          return error(`Item ${args.id} not found`);
        }
        return success(item);
      },
    },

    complete_work: {
      description:
        "Mark work complete on a work item (sets status to in-review, records commit hash)",
      inputSchema: completeWorkSchema,
      handler: async (args) => {
        const item = await lifecycleService.completeWork(args.id as number, {
          commitHash: args.commit as string,
        });
        if (!item) {
          return error(`Item ${args.id} not found`);
        }
        return success(item);
      },
    },

    post_telemetry: {
      description:
        "Post telemetry data for a work item (model, duration, tokens, cost)",
      inputSchema: postTelemetrySchema,
      handler: async (args) => {
        const telemetry = await lifecycleService.postTelemetry(
          args.id as number,
          {
            model: args.model as "haiku" | "sonnet" | "opus" | "mixed",
            durationMs: args.duration_ms as number,
            tokens: (args.tokens as number) ?? 0,
            toolUses: args.tool_uses as number | undefined,
            costEstimate: args.cost_estimate as number | undefined,
            commitHash: args.commit as string | undefined,
          }
        );
        return success(telemetry);
      },
    },

    // ----- Document Comments -----

    add_doc_comment: {
      description:
        "Add a comment to a design document, optionally anchored to a specific section",
      inputSchema: addDocCommentSchema,
      handler: async (args) => {
        const comment = await commentService.addComment({
          documentPath: args.path as string,
          body: args.body as string,
          anchor: args.anchor as string | undefined,
          author: "mcp",
        });
        return success(comment);
      },
    },

    list_doc_comments: {
      description: "List all comments on a design document by its path",
      inputSchema: listDocCommentsSchema,
      handler: async (args) => {
        const comments = await commentService.listDocumentComments(
          args.path as string
        );
        return success(comments);
      },
    },
  };
}
