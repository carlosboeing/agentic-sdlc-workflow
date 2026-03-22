/**
 * MCP stdio transport setup and isolation.
 *
 * The stdio transport reads MCP JSON-RPC messages from stdin and writes
 * responses to stdout. This is the transport Claude Code uses to communicate
 * with MCP servers.
 *
 * CRITICAL: stdout is reserved exclusively for MCP protocol messages.
 * All application logging MUST go to stderr. The server MUST NOT use
 * console.log(), process.stdout.write(), or any other stdout output
 * except through the MCP transport.
 */

import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

/**
 * Connect an MCP server to the stdio transport.
 *
 * After calling this function:
 * - stdin is consumed by the MCP transport (JSON-RPC messages)
 * - stdout is used by the MCP transport (JSON-RPC responses)
 * - All logging goes to stderr
 *
 * @param mcpServer - Configured McpServer with tools registered
 * @returns The connected StdioServerTransport (for shutdown control)
 */
export async function connectStdioTransport(
  mcpServer: McpServer
): Promise<StdioServerTransport> {
  const transport = new StdioServerTransport();

  // Connect the MCP server to the stdio transport
  await mcpServer.connect(transport);

  process.stderr.write("MCP stdio transport connected\n");

  return transport;
}
