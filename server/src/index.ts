/**
 * Entry point for the Workflow Runtime Service.
 *
 * Usage:
 *   bun run src/index.ts start   — Start the daemon (returns immediately to caller)
 *   bun run src/index.ts stop    — Stop a running daemon
 *   bun run src/index.ts status  — Print running status
 *   bun run src/index.ts mcp     — Start as MCP server (stdio transport)
 *
 * All log output goes to stderr.  stdout is reserved for MCP JSON-RPC messages.
 *
 * Daemon model (start command):
 *   The `start` command daemonizes by spawning a child process that runs the
 *   HTTP server in the foreground.  The parent waits for the child to become
 *   healthy (via a health-check poll), then exits — giving the caller back
 *   control immediately.  This means `bun run server/src/index.ts start`
 *   returns immediately to the caller once the server is up.
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
 * The server lives at `server/src/index.ts`; the repo root is 3 levels up:
 *   server/src/index.ts -> server/src/ -> server/ -> <repo-root>
 */
const REPO_ROOT = resolve(new URL(import.meta.url).pathname, "../../..");
const WORK_DIR = join(REPO_ROOT, ".agentic-workflow");

// ---------------------------------------------------------------------------
// Command dispatch
// ---------------------------------------------------------------------------

const command = process.argv[2] ?? "start";
const isForegrounded = process.argv.includes("--foreground");

switch (command) {
  case "start":
    if (isForegrounded) {
      // Running as the daemonized child — serve in foreground
      await commandStartForeground();
    } else {
      // Running as the parent launcher — spawn child and return to caller
      await commandStart();
    }
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
// start command — daemonizes and returns to caller immediately
//
// `bun run server/src/index.ts start` returns immediately to the caller once
// the server child process is confirmed healthy via a health-check poll.
// ---------------------------------------------------------------------------

async function commandStart(): Promise<void> {
  ensureWorkDir();

  // Check if already running — idempotent no-op
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

  // Spawn the server child process in the background.
  // The child runs with --foreground so it does not re-daemonize.
  // stderr is inherited so log output is visible to the caller.
  // stdout is ignored per the MCP stdio rule (stdout reserved for JSON-RPC).
  const scriptPath = new URL(import.meta.url).pathname;
  const child = Bun.spawn(["bun", "run", scriptPath, "start", "--foreground"], {
    stdio: ["ignore", "ignore", "inherit"], // stdin: none, stdout: ignore, stderr: inherit
    env: process.env,
  });

  // Unref the child so the parent process can exit without waiting for it
  child.unref();

  process.stderr.write(
    `Spawned server daemon (PID ${child.pid}). Waiting for health check...\n`
  );

  // Poll for the server to become ready.
  // The child writes server.port after Bun.serve() succeeds (W1 fix).
  // We poll the port file, then confirm via health endpoint.
  const deadline = Date.now() + 15_000; // 15s timeout for startup
  let port: number | null = null;

  while (Date.now() < deadline) {
    await Bun.sleep(200);

    // Phase 1: wait for port file (child writes it after server starts)
    port = readPortFile(WORK_DIR);
    if (port === null) continue;

    // Phase 2: health check via HTTP
    try {
      const resp = await fetch(`http://127.0.0.1:${port}/api/health`, {
        signal: AbortSignal.timeout(1000),
      });
      if (resp.ok) {
        process.stderr.write(
          `Server is up on port ${port} (PID ${child.pid}).\n`
        );
        return; // Return control to caller — server is running
      }
    } catch {
      // Server not yet ready — keep polling
    }
  }

  process.stderr.write(
    `Server did not become healthy within 15 seconds. Check server logs.\n`
  );
  process.exit(1);
}

// ---------------------------------------------------------------------------
// start --foreground (internal) — runs the server in foreground
//
// Called by the child process spawned by commandStart(). Not intended for
// direct use by callers — use `start` (without --foreground) instead.
// ---------------------------------------------------------------------------

async function commandStartForeground(): Promise<void> {
  ensureWorkDir();

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

  // Write PID and port files AFTER the server starts successfully (W1 fix).
  // If Bun.serve() throws, these files are never written — no stale files left.
  writePidFile(WORK_DIR, process.pid);
  writePortFile(WORK_DIR, port);

  // Register graceful shutdown handlers
  async function handleShutdown(
    srv: ReturnType<typeof Bun.serve>
  ): Promise<void> {
    process.stderr.write("Shutting down server...\n");
    idleTracker?.stop();
    srv.stop(true); // Wait for in-flight requests
    // TODO(E02): wire checkpointFn when database is integrated with server startup
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

  const startTimeMs = Date.now();
  const idleTimeoutMs = config.idleTimeoutMinutes * 60 * 1000;
  const idleTracker =
    idleTimeoutMs > 0
      ? new IdleTimeoutTracker(idleTimeoutMs, async () => {
          process.stderr.write("Idle timeout in MCP mode. Shutting down.\n");
          idleTracker?.stop();
          server.stop(true);
          // TODO(E02): wire checkpointFn when database is integrated with server startup
          await gracefulShutdown(WORK_DIR);
          process.exit(0);
        })
      : undefined;

  const server = startServer({ port, startTimeMs, idleTracker });

  // Write PID and port files AFTER the server starts successfully (W1 fix).
  writePidFile(WORK_DIR, process.pid);
  writePortFile(WORK_DIR, port);

  // MCP stdio transport will be connected by E03 (MCP Server epic).
  // For now, keep the HTTP server alive until stdin closes.
  process.stdin.resume();
  process.stdin.on("end", async () => {
    process.stderr.write("MCP stdin closed. Shutting down.\n");
    idleTracker?.stop();
    server.stop(true);
    // TODO(E02): wire checkpointFn when database is integrated with server startup
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
