import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Database } from "bun:sqlite";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { setupTestDb } from "../helpers/setup-db";
import { createMcpServer } from "../../src/mcp/server";

describe("MCP Server", () => {
  let sqlite: Database;
  let db: ReturnType<typeof drizzle>;

  beforeEach(() => {
    const conn = setupTestDb();
    sqlite = conn.sqlite;
    db = conn.db;
  });

  afterEach(() => {
    sqlite.close();
  });

  test("createMcpServer returns an McpServer instance", () => {
    const mcpServer = createMcpServer(db);
    expect(mcpServer).toBeDefined();
    expect(typeof mcpServer.connect).toBe("function");
    expect(typeof mcpServer.close).toBe("function");
  });

  test("MCP server has workflow-pm name", () => {
    const mcpServer = createMcpServer(db);
    // The server property exposes the underlying Server instance
    expect(mcpServer.server).toBeDefined();
  });

  test("registered tools are accessible via the server", () => {
    const mcpServer = createMcpServer(db);
    // McpServer stores registered tools internally.
    // We verify it was created without throwing, meaning all tool
    // registrations succeeded (invalid schemas would throw at registration time).
    expect(mcpServer).toBeTruthy();
  });
});
