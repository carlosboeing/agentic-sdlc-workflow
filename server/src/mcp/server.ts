/**
 * MCP server instance creation and tool registration.
 *
 * Creates an McpServer from @modelcontextprotocol/sdk, registers all PM tools
 * from tools.ts, and returns the configured server ready for transport connection.
 *
 * Stdout is reserved exclusively for MCP JSON-RPC messages.
 * All logging MUST go to stderr.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { ItemService } from "../services/items";
import { BoardService } from "../services/board";
import { CommentService } from "../services/comments";
import { HierarchyService } from "../services/hierarchy";
import { LifecycleService } from "../services/lifecycle";
import { LabelService } from "../services/labels";
import { createMcpToolHandlers } from "./tools";

type Db = ReturnType<typeof drizzle>;

/**
 * Create and configure an MCP server with all PM tools registered.
 *
 * The returned McpServer is not yet connected to a transport.
 * Call `mcpServer.connect(transport)` to start handling messages.
 *
 * @param db - Drizzle database connection (shared with HTTP API routes)
 */
export function createMcpServer(db: Db): McpServer {
  const mcpServer = new McpServer({
    name: "workflow-pm",
    version: "1.0.0",
  });

  // Instantiate services (same instances the HTTP routes would use)
  const itemService = new ItemService(db);
  const boardService = new BoardService(db);
  const commentService = new CommentService(db);
  const hierarchyService = new HierarchyService(db);
  const lifecycleService = new LifecycleService(db);
  const labelService = new LabelService(db);

  // Create tool handler definitions
  const toolHandlers = createMcpToolHandlers({
    db,
    itemService,
    boardService,
    commentService,
    hierarchyService,
    lifecycleService,
    labelService,
  });

  // Register each tool with the MCP server
  for (const [name, tool] of Object.entries(toolHandlers)) {
    mcpServer.registerTool(
      name,
      {
        description: tool.description,
        inputSchema: tool.inputSchema,
      },
      async (args) => {
        try {
          return await tool.handler(args as Record<string, unknown>);
        } catch (err) {
          const message =
            err instanceof Error ? err.message : "Unknown error";
          process.stderr.write(
            `MCP tool "${name}" error: ${message}\n`
          );
          return {
            content: [
              {
                type: "text" as const,
                text: JSON.stringify({ error: message }),
              },
            ],
            isError: true,
          };
        }
      }
    );
  }

  process.stderr.write(
    `MCP server registered ${Object.keys(toolHandlers).length} tools\n`
  );

  return mcpServer;
}
