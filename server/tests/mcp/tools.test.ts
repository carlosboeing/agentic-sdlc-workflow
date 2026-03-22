import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Database } from "bun:sqlite";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { setupTestDb } from "../helpers/setup-db";
import { ItemService } from "../../src/services/items";
import { BoardService } from "../../src/services/board";
import { CommentService } from "../../src/services/comments";
import { HierarchyService } from "../../src/services/hierarchy";
import { LifecycleService } from "../../src/services/lifecycle";
import { LabelService } from "../../src/services/labels";
import {
  createMcpToolHandlers,
  type McpToolHandler,
  type McpToolResult,
} from "../../src/mcp/tools";

describe("MCP Tool Handlers", () => {
  let sqlite: Database;
  let db: ReturnType<typeof drizzle>;
  let itemService: ItemService;
  let boardService: BoardService;
  let commentService: CommentService;
  let hierarchyService: HierarchyService;
  let lifecycleService: LifecycleService;
  let labelService: LabelService;
  let handlers: Record<string, McpToolHandler>;

  beforeEach(() => {
    const conn = setupTestDb();
    sqlite = conn.sqlite;
    db = conn.db;
    itemService = new ItemService(db);
    boardService = new BoardService(db);
    commentService = new CommentService(db);
    hierarchyService = new HierarchyService(db);
    lifecycleService = new LifecycleService(db);
    labelService = new LabelService(db);
    handlers = createMcpToolHandlers({
      db,
      itemService,
      boardService,
      commentService,
      hierarchyService,
      lifecycleService,
      labelService,
    });
  });

  afterEach(() => {
    sqlite.close();
  });

  // ---------------------------------------------------------------------------
  // Tool registration
  // ---------------------------------------------------------------------------

  describe("tool registration", () => {
    test("registers all 11 core PM tools", () => {
      const expectedTools = [
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
      ];

      for (const toolName of expectedTools) {
        expect(handlers[toolName]).toBeDefined();
        expect(handlers[toolName].description).toBeTruthy();
        expect(handlers[toolName].inputSchema).toBeDefined();
        expect(typeof handlers[toolName].handler).toBe("function");
      }
    });

    test("each tool has a non-empty description", () => {
      for (const [name, tool] of Object.entries(handlers)) {
        expect(tool.description.length).toBeGreaterThan(0);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // MCP content format
  // ---------------------------------------------------------------------------

  function assertMcpContentFormat(result: McpToolResult): void {
    expect(result.content).toBeDefined();
    expect(Array.isArray(result.content)).toBe(true);
    expect(result.content.length).toBeGreaterThan(0);
    expect(result.content[0].type).toBe("text");
    expect(typeof result.content[0].text).toBe("string");
  }

  function parseToolResult(result: McpToolResult): unknown {
    return JSON.parse(result.content[0].text);
  }

  // ---------------------------------------------------------------------------
  // create_item
  // ---------------------------------------------------------------------------

  describe("create_item", () => {
    test("creates item and returns MCP content format", async () => {
      const result = await handlers.create_item.handler({
        type: "story",
        title: "Test Story",
        body: "A test story body",
      });

      assertMcpContentFormat(result);
      const item = parseToolResult(result) as Record<string, unknown>;
      expect(item.title).toBe("Test Story");
      expect(item.type).toBe("story");
      expect(item.body).toBe("A test story body");
      expect(item.status).toBe("backlog");
      expect(item.state).toBe("open");
    });

    test("creates item with labels", async () => {
      const result = await handlers.create_item.handler({
        type: "backlog",
        title: "Backlog with Labels",
        labels: ["type/feature", "size/M"],
      });

      assertMcpContentFormat(result);
      const item = parseToolResult(result) as Record<string, unknown>;
      expect(item.title).toBe("Backlog with Labels");
    });

    test("creates item with parent_id", async () => {
      // Create parent first
      await handlers.create_item.handler({
        type: "backlog",
        title: "Parent Backlog",
      });

      const result = await handlers.create_item.handler({
        type: "epic",
        title: "Child Epic",
        parent_id: 1,
      });

      assertMcpContentFormat(result);
      const item = parseToolResult(result) as Record<string, unknown>;
      expect(item.title).toBe("Child Epic");
      expect(item.parentId).toBe(1);
    });
  });

  // ---------------------------------------------------------------------------
  // get_item
  // ---------------------------------------------------------------------------

  describe("get_item", () => {
    test("returns item by id in MCP content format", async () => {
      await itemService.create({ id: 10, title: "Item 10", type: "story" });

      const result = await handlers.get_item.handler({ id: 10 });

      assertMcpContentFormat(result);
      const item = parseToolResult(result) as Record<string, unknown>;
      expect(item.id).toBe(10);
      expect(item.title).toBe("Item 10");
    });

    test("returns error for non-existent item", async () => {
      const result = await handlers.get_item.handler({ id: 999 });

      assertMcpContentFormat(result);
      expect(result.isError).toBe(true);
      const data = parseToolResult(result) as Record<string, unknown>;
      expect(data.error).toBeTruthy();
    });
  });

  // ---------------------------------------------------------------------------
  // list_items
  // ---------------------------------------------------------------------------

  describe("list_items", () => {
    test("lists all items when no filter", async () => {
      await itemService.create({ id: 1, title: "Item A", type: "story" });
      await itemService.create({ id: 2, title: "Item B", type: "epic" });

      const result = await handlers.list_items.handler({});

      assertMcpContentFormat(result);
      const items = parseToolResult(result) as unknown[];
      expect(items.length).toBe(2);
    });

    test("filters by type", async () => {
      await itemService.create({ id: 1, title: "Story", type: "story" });
      await itemService.create({ id: 2, title: "Epic", type: "epic" });

      const result = await handlers.list_items.handler({ type: "story" });

      assertMcpContentFormat(result);
      const items = parseToolResult(result) as Array<Record<string, unknown>>;
      expect(items.length).toBe(1);
      expect(items[0].type).toBe("story");
    });

    test("filters by status", async () => {
      await itemService.create({
        id: 1,
        title: "Ready",
        type: "story",
        status: "ready",
      });
      await itemService.create({
        id: 2,
        title: "Backlog",
        type: "story",
      });

      const result = await handlers.list_items.handler({ status: "ready" });

      assertMcpContentFormat(result);
      const items = parseToolResult(result) as unknown[];
      expect(items.length).toBe(1);
    });

    test("respects limit parameter", async () => {
      for (let i = 1; i <= 5; i++) {
        await itemService.create({
          id: i,
          title: `Item ${i}`,
          type: "story",
        });
      }

      const result = await handlers.list_items.handler({ limit: 2 });

      assertMcpContentFormat(result);
      const items = parseToolResult(result) as unknown[];
      expect(items.length).toBe(2);
    });
  });

  // ---------------------------------------------------------------------------
  // update_item
  // ---------------------------------------------------------------------------

  describe("update_item", () => {
    test("updates item title and returns MCP content format", async () => {
      await itemService.create({ id: 5, title: "Old Title", type: "story" });

      const result = await handlers.update_item.handler({
        id: 5,
        title: "New Title",
      });

      assertMcpContentFormat(result);
      const item = parseToolResult(result) as Record<string, unknown>;
      expect(item.title).toBe("New Title");
    });

    test("updates item body", async () => {
      await itemService.create({ id: 5, title: "Item", type: "story" });

      const result = await handlers.update_item.handler({
        id: 5,
        body: "Updated body",
      });

      assertMcpContentFormat(result);
      const item = parseToolResult(result) as Record<string, unknown>;
      expect(item.body).toBe("Updated body");
    });

    test("returns error for non-existent item", async () => {
      const result = await handlers.update_item.handler({
        id: 999,
        title: "Nope",
      });

      assertMcpContentFormat(result);
      expect(result.isError).toBe(true);
    });
  });

  // ---------------------------------------------------------------------------
  // close_item
  // ---------------------------------------------------------------------------

  describe("close_item", () => {
    test("closes item and returns MCP content format", async () => {
      await itemService.create({ id: 7, title: "To Close", type: "story" });

      const result = await handlers.close_item.handler({ id: 7 });

      assertMcpContentFormat(result);
      const item = parseToolResult(result) as Record<string, unknown>;
      expect(item.state).toBe("closed");
    });

    test("returns error for non-existent item", async () => {
      const result = await handlers.close_item.handler({ id: 999 });

      assertMcpContentFormat(result);
      expect(result.isError).toBe(true);
    });
  });

  // ---------------------------------------------------------------------------
  // set_status
  // ---------------------------------------------------------------------------

  describe("set_status", () => {
    test("sets board status and returns MCP content format", async () => {
      await itemService.create({ id: 3, title: "In Progress", type: "story" });

      const result = await handlers.set_status.handler({
        id: 3,
        status: "in-progress",
      });

      assertMcpContentFormat(result);
      const item = parseToolResult(result) as Record<string, unknown>;
      expect(item.status).toBe("in-progress");
    });

    test("returns error for non-existent item", async () => {
      const result = await handlers.set_status.handler({
        id: 999,
        status: "ready",
      });

      assertMcpContentFormat(result);
      expect(result.isError).toBe(true);
    });
  });

  // ---------------------------------------------------------------------------
  // link_child
  // ---------------------------------------------------------------------------

  describe("link_child", () => {
    test("links child to parent and returns MCP content format", async () => {
      await itemService.create({ id: 1, title: "Parent", type: "backlog" });
      await itemService.create({ id: 2, title: "Child", type: "epic" });

      const result = await handlers.link_child.handler({
        parent_id: 1,
        child_id: 2,
      });

      assertMcpContentFormat(result);
      const item = parseToolResult(result) as Record<string, unknown>;
      expect(item.parentId).toBe(1);
    });

    test("returns error when parent does not exist", async () => {
      await itemService.create({ id: 2, title: "Child", type: "epic" });

      const result = await handlers.link_child.handler({
        parent_id: 999,
        child_id: 2,
      });

      assertMcpContentFormat(result);
      expect(result.isError).toBe(true);
    });
  });

  // ---------------------------------------------------------------------------
  // add_comment
  // ---------------------------------------------------------------------------

  describe("add_comment", () => {
    test("adds comment and returns MCP content format", async () => {
      await itemService.create({
        id: 4,
        title: "Commentable",
        type: "story",
      });

      const result = await handlers.add_comment.handler({
        item_id: 4,
        body: "This is a comment",
      });

      assertMcpContentFormat(result);
      const comment = parseToolResult(result) as Record<string, unknown>;
      expect(comment.body).toBe("This is a comment");
      expect(comment.itemId).toBe(4);
    });
  });

  // ---------------------------------------------------------------------------
  // start_work
  // ---------------------------------------------------------------------------

  describe("start_work", () => {
    test("starts work on item and returns MCP content format", async () => {
      await itemService.create({
        id: 8,
        title: "To Start",
        type: "story",
        status: "ready",
      });

      const result = await handlers.start_work.handler({
        id: 8,
        model: "sonnet",
        agent: "builder",
      });

      assertMcpContentFormat(result);
      const item = parseToolResult(result) as Record<string, unknown>;
      expect(item.status).toBe("in-progress");
    });

    test("returns error for non-existent item", async () => {
      const result = await handlers.start_work.handler({
        id: 999,
        model: "sonnet",
        agent: "builder",
      });

      assertMcpContentFormat(result);
      expect(result.isError).toBe(true);
    });
  });

  // ---------------------------------------------------------------------------
  // complete_work
  // ---------------------------------------------------------------------------

  describe("complete_work", () => {
    test("completes work on item and returns MCP content format", async () => {
      await itemService.create({
        id: 9,
        title: "To Complete",
        type: "story",
        status: "in-progress",
      });

      const result = await handlers.complete_work.handler({
        id: 9,
        commit: "abc123",
      });

      assertMcpContentFormat(result);
      const item = parseToolResult(result) as Record<string, unknown>;
      expect(item.status).toBe("in-review");
    });

    test("returns error for non-existent item", async () => {
      const result = await handlers.complete_work.handler({
        id: 999,
        commit: "abc123",
      });

      assertMcpContentFormat(result);
      expect(result.isError).toBe(true);
    });
  });

  // ---------------------------------------------------------------------------
  // post_telemetry
  // ---------------------------------------------------------------------------

  describe("post_telemetry", () => {
    test("posts telemetry and returns MCP content format", async () => {
      await itemService.create({
        id: 11,
        title: "Telemetry Target",
        type: "story",
      });

      const result = await handlers.post_telemetry.handler({
        id: 11,
        model: "sonnet",
        duration_ms: 120000,
        tokens: 50000,
        tool_uses: 25,
        commit: "def456",
      });

      assertMcpContentFormat(result);
      const telemetry = parseToolResult(result) as Record<string, unknown>;
      expect(telemetry.model).toBe("sonnet");
      expect(telemetry.durationMs).toBe(120000);
      expect(telemetry.tokens).toBe(50000);
    });

    test("posts telemetry with minimal fields", async () => {
      await itemService.create({
        id: 12,
        title: "Minimal Telemetry",
        type: "story",
      });

      const result = await handlers.post_telemetry.handler({
        id: 12,
        model: "haiku",
        duration_ms: 30000,
        tokens: 10000,
      });

      assertMcpContentFormat(result);
      const telemetry = parseToolResult(result) as Record<string, unknown>;
      expect(telemetry.model).toBe("haiku");
    });
  });

  // ---------------------------------------------------------------------------
  // Input validation error handling
  // ---------------------------------------------------------------------------

  describe("input validation", () => {
    test("each tool has a Zod input schema object", () => {
      for (const [name, tool] of Object.entries(handlers)) {
        expect(tool.inputSchema).toBeDefined();
        // inputSchema should be a record of Zod schemas (ZodRawShapeCompat)
        expect(typeof tool.inputSchema).toBe("object");
      }
    });
  });
});
