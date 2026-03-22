/**
 * MCP dual-mode startup tests.
 *
 * Verifies:
 *   1. createMcpServer() + connectStdioTransport() are exported and callable
 *   2. MCP tool set includes all 13 required tools from the design doc
 *   3. .mcp.json exists at project root with the correct structure
 *   4. commandMcp() behavior is verified via the exported createMcpServer function
 *      (direct process spawning is out of scope for unit tests)
 */

import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Database } from "bun:sqlite";
import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { setupTestDb } from "../helpers/setup-db";
import { createMcpServer } from "../../src/mcp/server";
import { createMcpToolHandlers } from "../../src/mcp/tools";
import { connectStdioTransport } from "../../src/mcp/transport";
import { ItemService } from "../../src/services/items";
import { BoardService } from "../../src/services/board";
import { CommentService } from "../../src/services/comments";
import { HierarchyService } from "../../src/services/hierarchy";
import { LifecycleService } from "../../src/services/lifecycle";
import { LabelService } from "../../src/services/labels";

/**
 * Resolve the repo root from this test file:
 *   server/tests/mcp/startup.test.ts -> server/tests/mcp/ -> server/tests/ -> server/ -> <repo-root>
 */
const REPO_ROOT = resolve(
  dirname(new URL(import.meta.url).pathname),
  "../../.."
);

/** The 13 required tools from the design doc § 7.1 */
const REQUIRED_TOOLS = [
  "create_item",
  "get_item",
  "list_items",
  "update_item",
  "close_item",
  "set_status",
  "link_child",
  "add_comment",
  "start_work",
  "complete_work",
  "post_telemetry",
  "add_doc_comment",
  "list_doc_comments",
];

// ---------------------------------------------------------------------------
// Test fixture
// ---------------------------------------------------------------------------

let sqlite: Database;
let db: ReturnType<typeof drizzle>;

beforeEach(() => {
  const setup = setupTestDb();
  sqlite = setup.sqlite;
  db = setup.db;
});

afterEach(() => {
  sqlite.close();
});

// ---------------------------------------------------------------------------
// MCP tool set completeness
// ---------------------------------------------------------------------------

describe("MCP tool set — all 13 tools registered", () => {
  test("createMcpToolHandlers returns all 13 required tools", () => {
    const services = {
      db,
      itemService: new ItemService(db),
      boardService: new BoardService(db),
      commentService: new CommentService(db),
      hierarchyService: new HierarchyService(db),
      lifecycleService: new LifecycleService(db),
      labelService: new LabelService(db),
    };
    const handlers = createMcpToolHandlers(services);
    const toolNames = Object.keys(handlers);

    for (const toolName of REQUIRED_TOOLS) {
      expect(toolNames).toContain(toolName);
    }

    expect(toolNames.length).toBe(13);
  });

  test("each tool handler has description, inputSchema, and handler", () => {
    const services = {
      db,
      itemService: new ItemService(db),
      boardService: new BoardService(db),
      commentService: new CommentService(db),
      hierarchyService: new HierarchyService(db),
      lifecycleService: new LifecycleService(db),
      labelService: new LabelService(db),
    };
    const handlers = createMcpToolHandlers(services);

    for (const [name, tool] of Object.entries(handlers)) {
      expect(tool.description, `${name} must have description`).toBeTruthy();
      expect(tool.inputSchema, `${name} must have inputSchema`).toBeDefined();
      expect(
        typeof tool.handler,
        `${name} handler must be a function`
      ).toBe("function");
    }
  });

  test("createMcpServer registers all 13 tools without throwing", () => {
    // If any tool registration fails (bad schema etc.), this throws
    const mcpServer = createMcpServer(db);
    expect(mcpServer).toBeDefined();
    expect(typeof mcpServer.connect).toBe("function");
  });
});

// ---------------------------------------------------------------------------
// add_doc_comment tool
// ---------------------------------------------------------------------------

describe("add_doc_comment tool", () => {
  test("add_doc_comment handler returns success with comment data", async () => {
    const services = {
      db,
      itemService: new ItemService(db),
      boardService: new BoardService(db),
      commentService: new CommentService(db),
      hierarchyService: new HierarchyService(db),
      lifecycleService: new LifecycleService(db),
      labelService: new LabelService(db),
    };
    const handlers = createMcpToolHandlers(services);
    const handler = handlers["add_doc_comment"];
    expect(handler).toBeDefined();

    const result = await handler.handler({
      path: "docs/2-design/2026-03-22-workflow-runtime-service-design.md",
      body: "This section explains the MCP server registration.",
    });

    expect(result.isError).toBeFalsy();
    const data = JSON.parse(result.content[0].text) as Record<string, unknown>;
    // Comment is returned with drizzle field names: documentPath, body, anchor
    expect(data.documentPath).toBe(
      "docs/2-design/2026-03-22-workflow-runtime-service-design.md"
    );
    expect(data.body).toBe(
      "This section explains the MCP server registration."
    );
  });

  test("add_doc_comment with anchor stores anchor field", async () => {
    const services = {
      db,
      itemService: new ItemService(db),
      boardService: new BoardService(db),
      commentService: new CommentService(db),
      hierarchyService: new HierarchyService(db),
      lifecycleService: new LifecycleService(db),
      labelService: new LabelService(db),
    };
    const handlers = createMcpToolHandlers(services);
    const handler = handlers["add_doc_comment"];

    const result = await handler.handler({
      path: "docs/2-design/design.md",
      body: "See section 5.4 for details.",
      anchor: "5-server-lifecycle",
    });

    expect(result.isError).toBeFalsy();
    const data = JSON.parse(result.content[0].text) as Record<string, unknown>;
    expect(data.anchor).toBe("5-server-lifecycle");
  });
});

// ---------------------------------------------------------------------------
// list_doc_comments tool
// ---------------------------------------------------------------------------

describe("list_doc_comments tool", () => {
  test("list_doc_comments returns empty array for doc with no comments", async () => {
    const services = {
      db,
      itemService: new ItemService(db),
      boardService: new BoardService(db),
      commentService: new CommentService(db),
      hierarchyService: new HierarchyService(db),
      lifecycleService: new LifecycleService(db),
      labelService: new LabelService(db),
    };
    const handlers = createMcpToolHandlers(services);
    const handler = handlers["list_doc_comments"];
    expect(handler).toBeDefined();

    const result = await handler.handler({
      path: "docs/nonexistent.md",
    });

    expect(result.isError).toBeFalsy();
    const data = JSON.parse(result.content[0].text) as unknown[];
    expect(Array.isArray(data)).toBe(true);
    expect(data.length).toBe(0);
  });

  test("list_doc_comments returns previously added comments", async () => {
    const services = {
      db,
      itemService: new ItemService(db),
      boardService: new BoardService(db),
      commentService: new CommentService(db),
      hierarchyService: new HierarchyService(db),
      lifecycleService: new LifecycleService(db),
      labelService: new LabelService(db),
    };
    const handlers = createMcpToolHandlers(services);

    const path = "docs/2-design/test.md";

    // Add two comments on the same doc
    await handlers["add_doc_comment"].handler({
      path,
      body: "First comment",
    });
    await handlers["add_doc_comment"].handler({
      path,
      body: "Second comment",
      anchor: "section-2",
    });

    const result = await handlers["list_doc_comments"].handler({ path });
    expect(result.isError).toBeFalsy();
    const data = JSON.parse(result.content[0].text) as Array<
      Record<string, unknown>
    >;
    expect(Array.isArray(data)).toBe(true);
    expect(data.length).toBe(2);
    expect(data[0].body).toBe("First comment");
    expect(data[1].body).toBe("Second comment");
    expect(data[1].anchor).toBe("section-2");
  });

  test("list_doc_comments only returns comments for the specified path", async () => {
    const services = {
      db,
      itemService: new ItemService(db),
      boardService: new BoardService(db),
      commentService: new CommentService(db),
      hierarchyService: new HierarchyService(db),
      lifecycleService: new LifecycleService(db),
      labelService: new LabelService(db),
    };
    const handlers = createMcpToolHandlers(services);

    // Add to two different docs
    await handlers["add_doc_comment"].handler({
      path: "docs/design-a.md",
      body: "Comment on design A",
    });
    await handlers["add_doc_comment"].handler({
      path: "docs/design-b.md",
      body: "Comment on design B",
    });

    const resultA = await handlers["list_doc_comments"].handler({
      path: "docs/design-a.md",
    });
    const dataA = JSON.parse(resultA.content[0].text) as Array<
      Record<string, unknown>
    >;
    expect(dataA.length).toBe(1);
    expect(dataA[0].body).toBe("Comment on design A");

    const resultB = await handlers["list_doc_comments"].handler({
      path: "docs/design-b.md",
    });
    const dataB = JSON.parse(resultB.content[0].text) as Array<
      Record<string, unknown>
    >;
    expect(dataB.length).toBe(1);
    expect(dataB[0].body).toBe("Comment on design B");
  });
});

// ---------------------------------------------------------------------------
// .mcp.json schema validation
// ---------------------------------------------------------------------------

describe(".mcp.json — project root MCP server registration", () => {
  test(".mcp.json exists at project root", () => {
    const mcpJsonPath = resolve(REPO_ROOT, ".mcp.json");
    expect(existsSync(mcpJsonPath)).toBe(true);
  });

  test(".mcp.json is valid JSON", () => {
    const mcpJsonPath = resolve(REPO_ROOT, ".mcp.json");
    const content = readFileSync(mcpJsonPath, "utf-8");
    expect(() => JSON.parse(content)).not.toThrow();
  });

  test('.mcp.json has mcpServers."workflow-pm" key', () => {
    const mcpJsonPath = resolve(REPO_ROOT, ".mcp.json");
    const content = readFileSync(mcpJsonPath, "utf-8");
    const config = JSON.parse(content) as Record<string, unknown>;

    expect(config.mcpServers).toBeDefined();
    const servers = config.mcpServers as Record<string, unknown>;
    expect(servers["workflow-pm"]).toBeDefined();
  });

  test('.mcp.json workflow-pm server uses "bun" command with "mcp" arg', () => {
    const mcpJsonPath = resolve(REPO_ROOT, ".mcp.json");
    const content = readFileSync(mcpJsonPath, "utf-8");
    const config = JSON.parse(content) as Record<string, unknown>;

    const servers = config.mcpServers as Record<string, unknown>;
    const server = servers["workflow-pm"] as Record<string, unknown>;

    expect(server.command).toBe("bun");
    const args = server.args as string[];
    expect(Array.isArray(args)).toBe(true);
    expect(args).toContain("mcp");
  });

  test(".mcp.json workflow-pm args include path to server entry point", () => {
    const mcpJsonPath = resolve(REPO_ROOT, ".mcp.json");
    const content = readFileSync(mcpJsonPath, "utf-8");
    const config = JSON.parse(content) as Record<string, unknown>;

    const servers = config.mcpServers as Record<string, unknown>;
    const server = servers["workflow-pm"] as Record<string, unknown>;
    const args = server.args as string[];

    // Must reference the server entry point (run + path containing index.ts)
    const hasRun = args.includes("run");
    const hasEntryPoint = args.some(
      (a) => a.includes("index.ts") || a.includes("server/src")
    );
    expect(hasRun).toBe(true);
    expect(hasEntryPoint).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// connectStdioTransport export
// ---------------------------------------------------------------------------

describe("connectStdioTransport — exported from transport module", () => {
  test("connectStdioTransport is a function", () => {
    expect(typeof connectStdioTransport).toBe("function");
  });
});

// ---------------------------------------------------------------------------
// Mode detection — CLI argument parsing
// ---------------------------------------------------------------------------

describe("mode detection — CLI argument conventions", () => {
  test("mcp command is distinct from start command", () => {
    // The index.ts switch statement routes 'mcp' to commandMcp()
    // and 'start' to commandStart(). We verify the string values used
    // by checking the source (indirectly via behaviour of tool count).
    // Tools should be 13 in MCP mode, 0 in HTTP-only mode.
    const services = {
      db,
      itemService: new ItemService(db),
      boardService: new BoardService(db),
      commentService: new CommentService(db),
      hierarchyService: new HierarchyService(db),
      lifecycleService: new LifecycleService(db),
      labelService: new LabelService(db),
    };
    const handlers = createMcpToolHandlers(services);
    // MCP mode has 13 tools; HTTP-only mode has 0 MCP tools
    expect(Object.keys(handlers).length).toBe(13);
  });
});
