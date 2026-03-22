/**
 * Entry point for the Workflow Runtime Service.
 *
 * Usage:
 *   bun run src/index.ts start   — Start the daemon (idempotent)
 *   bun run src/index.ts stop    — Stop a running daemon
 *   bun run src/index.ts status  — Print running status
 *   bun run src/index.ts mcp     — Start as MCP server (stdio transport)
 *
 * All log output goes to stderr.  stdout is reserved for MCP JSON-RPC messages.
 */

import { resolve, join } from "node:path";
import { existsSync, mkdirSync } from "node:fs";
import {
  readPidFile,
  readPortFile,
  writePidFile,
  writePortFile,
  removePidFile,
  removePortFile,
  isProcessAlive,
  findAvailablePort,
  gracefulShutdown,
  IdleTimeoutTracker,
  readServerConfig,
} from "./lifecycle";
import { startServer } from "./server";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/**
 * Resolve the repo root and work directory.
 * The server lives at `server/src/index.ts`; the repo root is two levels up.
 */
const REPO_ROOT = resolve(new URL(import.meta.url).pathname, "../../../..");
const WORK_DIR = join(REPO_ROOT, ".agentic-workflow");

// ---------------------------------------------------------------------------
// Command dispatch
// ---------------------------------------------------------------------------

const command = process.argv[2] ?? "start";

switch (command) {
  case "start":
    await commandStart();
    break;
  case "stop":
    await commandStop();
    break;
  case "status":
    await commandStatus();
    break;
  case "mcp":
    await commandMcp();
    break;
  default:
    process.stderr.write(`Unknown command: ${command}\n`);
    process.stderr.write(
      "Usage: bun run src/index.ts [start|stop|status|mcp]\n"
    );
    process.exit(1);
}

// ---------------------------------------------------------------------------
// start command
// ---------------------------------------------------------------------------

async function commandStart(): Promise<void> {
  ensureWorkDir();

  // Check if already running
  const existingPid = readPidFile(WORK_DIR);
  if (existingPid !== null && isProcessAlive(existingPid)) {
    const port = readPortFile(WORK_DIR);
    process.stderr.write(
      `Server already running (PID ${existingPid}, port ${port ?? "unknown"}). No-op.\n`
    );
    return;
  }

  // Clean up stale files from a dead process
  if (existingPid !== null) {
    process.stderr.write(
      `Found stale PID file (PID ${existingPid} is not running). Cleaning up.\n`
    );
    removePidFile(WORK_DIR);
    removePortFile(WORK_DIR);
  }

  // Read configuration
  const config = readServerConfig(REPO_ROOT);

  // Discover available port
  const port = await findAvailablePort(config);
  if (port === null) {
    process.stderr.write(
      `No available port in range [${config.portRange[0]}, ${config.portRange[1]}]. Exiting.\n`
    );
    process.exit(1);
  }

  // Write PID and port files before starting the server
  writePidFile(WORK_DIR, process.pid);
  writePortFile(WORK_DIR, port);

  const startTimeMs = Date.now();

  // Set up idle timeout
  const idleTimeoutMs = config.idleTimeoutMinutes * 60 * 1000;
  const idleTracker =
    idleTimeoutMs > 0
      ? new IdleTimeoutTracker(idleTimeoutMs, async () => {
          process.stderr.write(
            `Idle timeout reached (${config.idleTimeoutMinutes} minutes). Shutting down.\n`
          );
          await handleShutdown(server);
        })
      : undefined;

  // Start the HTTP server
  const server = startServer({ port, startTimeMs, idleTracker });

  // Register graceful shutdown handlers
  async function handleShutdown(
    srv: ReturnType<typeof Bun.serve>
  ): Promise<void> {
    process.stderr.write("Shutting down server...\n");
    idleTracker?.stop();
    srv.stop(true); // Wait for in-flight requests
    await gracefulShutdown(WORK_DIR);
    process.stderr.write("Server stopped.\n");
    process.exit(0);
  }

  process.on("SIGTERM", () => handleShutdown(server));
  process.on("SIGINT", () => handleShutdown(server));
}

// ---------------------------------------------------------------------------
// stop command
// ---------------------------------------------------------------------------

async function commandStop(): Promise<void> {
  const pid = readPidFile(WORK_DIR);

  if (pid === null) {
    process.stderr.write("No server PID file found. Server may not be running.\n");
    return;
  }

  if (!isProcessAlive(pid)) {
    process.stderr.write(
      `PID ${pid} is not running. Cleaning up stale files.\n`
    );
    removePidFile(WORK_DIR);
    removePortFile(WORK_DIR);
    return;
  }

  process.stderr.write(`Sending SIGTERM to PID ${pid}...\n`);
  process.kill(pid, "SIGTERM");

  // Wait for the process to exit (poll for up to 10 seconds)
  const deadline = Date.now() + 10_000;
  while (Date.now() < deadline) {
    await Bun.sleep(200);
    if (!isProcessAlive(pid)) {
      process.stderr.write("Server stopped.\n");
      return;
    }
  }

  process.stderr.write(
    `Server (PID ${pid}) did not stop within 10 seconds. Sending SIGKILL.\n`
  );
  try {
    process.kill(pid, "SIGKILL");
  } catch {
    // Process may have exited between the check and the kill
  }
  removePidFile(WORK_DIR);
  removePortFile(WORK_DIR);
}

// ---------------------------------------------------------------------------
// status command
// ---------------------------------------------------------------------------

async function commandStatus(): Promise<void> {
  const pid = readPidFile(WORK_DIR);
  const port = readPortFile(WORK_DIR);

  if (pid === null) {
    process.stdout.write("Server is not running (no PID file).\n");
    return;
  }

  if (!isProcessAlive(pid)) {
    process.stdout.write(
      `Server is not running (PID ${pid} is dead, stale files exist).\n`
    );
    return;
  }

  process.stdout.write(
    `Server is running: PID=${pid}, port=${port ?? "unknown"}\n`
  );
}

// ---------------------------------------------------------------------------
// mcp command (dual-mode: HTTP server + MCP stdio transport)
// ---------------------------------------------------------------------------

async function commandMcp(): Promise<void> {
  ensureWorkDir();

  const config = readServerConfig(REPO_ROOT);
  const port = await findAvailablePort(config);
  if (port === null) {
    process.stderr.write(
      `No available port in range [${config.portRange[0]}, ${config.portRange[1]}]. Exiting.\n`
    );
    process.exit(1);
  }

  writePidFile(WORK_DIR, process.pid);
  writePortFile(WORK_DIR, port);

  const startTimeMs = Date.now();
  const idleTimeoutMs = config.idleTimeoutMinutes * 60 * 1000;
  const idleTracker =
    idleTimeoutMs > 0
      ? new IdleTimeoutTracker(idleTimeoutMs, async () => {
          process.stderr.write("Idle timeout in MCP mode. Shutting down.\n");
          server.stop(true);
          await gracefulShutdown(WORK_DIR);
          process.exit(0);
        })
      : undefined;

  const server = startServer({ port, startTimeMs, idleTracker });

  // MCP stdio transport will be connected by E03 (MCP Server epic).
  // For now, keep the HTTP server alive until stdin closes.
  process.stdin.resume();
  process.stdin.on("end", async () => {
    process.stderr.write("MCP stdin closed. Shutting down.\n");
    idleTracker?.stop();
    server.stop(true);
    await gracefulShutdown(WORK_DIR);
    process.exit(0);
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function ensureWorkDir(): void {
  if (!existsSync(WORK_DIR)) {
    mkdirSync(WORK_DIR, { recursive: true });
  }
}
