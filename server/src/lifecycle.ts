import { existsSync, writeFileSync, readFileSync, unlinkSync } from "node:fs";
import { join } from "node:path";
import { createServer } from "node:net";

/** Configuration for the server lifecycle manager. */
export interface LifecycleConfig {
  /** Default port to attempt first. */
  port: number;
  /** Inclusive [min, max] port range for fallback discovery. */
  portRange: [number, number];
  /** Minutes of inactivity before auto-shutdown. 0 disables idle timeout. */
  idleTimeoutMinutes: number;
}

const PID_FILE = "server.pid";
const PORT_FILE = "server.port";

// ---------------------------------------------------------------------------
// PID file helpers
// ---------------------------------------------------------------------------

/** Write the process PID to `<workDir>/server.pid`. */
export function writePidFile(workDir: string, pid: number): void {
  writeFileSync(join(workDir, PID_FILE), `${pid}\n`, { encoding: "utf8" });
}

/**
 * Read the PID from `<workDir>/server.pid`.
 * Returns `null` if the file does not exist or contains an invalid integer.
 */
export function readPidFile(workDir: string): number | null {
  const path = join(workDir, PID_FILE);
  if (!existsSync(path)) return null;
  const raw = readFileSync(path, "utf8").trim();
  const pid = parseInt(raw, 10);
  return Number.isFinite(pid) ? pid : null;
}

/** Remove `<workDir>/server.pid`.  No-op if the file does not exist. */
export function removePidFile(workDir: string): void {
  const path = join(workDir, PID_FILE);
  if (existsSync(path)) unlinkSync(path);
}

// ---------------------------------------------------------------------------
// Port file helpers
// ---------------------------------------------------------------------------

/** Write the port to `<workDir>/server.port`. */
export function writePortFile(workDir: string, port: number): void {
  writeFileSync(join(workDir, PORT_FILE), `${port}\n`, { encoding: "utf8" });
}

/**
 * Read the port from `<workDir>/server.port`.
 * Returns `null` if the file does not exist or contains an invalid integer.
 */
export function readPortFile(workDir: string): number | null {
  const path = join(workDir, PORT_FILE);
  if (!existsSync(path)) return null;
  const raw = readFileSync(path, "utf8").trim();
  const port = parseInt(raw, 10);
  return Number.isFinite(port) ? port : null;
}

/** Remove `<workDir>/server.port`.  No-op if the file does not exist. */
export function removePortFile(workDir: string): void {
  const path = join(workDir, PORT_FILE);
  if (existsSync(path)) unlinkSync(path);
}

// ---------------------------------------------------------------------------
// Process detection
// ---------------------------------------------------------------------------

/**
 * Returns `true` if a process with the given PID is alive.
 * Uses `kill(pid, 0)` — no signal is sent; only existence is tested.
 */
export function isProcessAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Port discovery
// ---------------------------------------------------------------------------

/**
 * Attempt to bind a TCP socket to `port` on localhost.
 * Returns `true` if the port is available (binding succeeds); `false` otherwise.
 */
function isPortAvailable(port: number): Promise<boolean> {
  return new Promise((resolve) => {
    const server = createServer();
    server.unref(); // Don't keep the process alive
    server.once("error", () => resolve(false));
    server.once("listening", () => {
      server.close(() => resolve(true));
    });
    server.listen(port, "127.0.0.1");
  });
}

/**
 * Find the first available port in the configured range, starting from the
 * default port.  Returns the available port number or `null` if the entire
 * range is exhausted.
 */
export async function findAvailablePort(
  config: LifecycleConfig
): Promise<number | null> {
  const [min, max] = config.portRange;
  // Start from config.port, but ensure it's within [min, max]
  const start = Math.max(min, Math.min(max, config.port));

  // Try start..max, then min..(start-1)
  const candidates: number[] = [];
  for (let p = start; p <= max; p++) candidates.push(p);
  for (let p = min; p < start; p++) candidates.push(p);

  for (const port of candidates) {
    if (await isPortAvailable(port)) return port;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Idle timeout tracker
// ---------------------------------------------------------------------------

/**
 * IdleTimeoutTracker records the timestamp of the last activity and fires a
 * callback after `idleTimeoutMs` milliseconds of inactivity.
 *
 * Call `touch()` on every HTTP request or MCP message to reset the timer.
 * Call `stop()` when the server is shutting down to cancel the timer.
 */
export class IdleTimeoutTracker {
  private timer: ReturnType<typeof setTimeout> | null = null;
  private lastActivity: number = Date.now();

  constructor(
    private readonly idleTimeoutMs: number,
    private readonly onTimeout: () => void
  ) {
    if (idleTimeoutMs > 0) {
      this.schedule();
    }
  }

  /** Record activity and reset the idle timer. */
  touch(): void {
    this.lastActivity = Date.now();
    if (this.idleTimeoutMs > 0) {
      this.cancel();
      this.schedule();
    }
  }

  /** Cancel the idle timer (call on graceful shutdown). */
  stop(): void {
    this.cancel();
  }

  /** Milliseconds since the last recorded activity. */
  get idleDurationMs(): number {
    return Date.now() - this.lastActivity;
  }

  private schedule(): void {
    this.timer = setTimeout(() => {
      this.onTimeout();
    }, this.idleTimeoutMs);
    // Allow the process to exit even if the timer is pending
    if (this.timer && typeof this.timer.unref === "function") {
      this.timer.unref();
    }
  }

  private cancel(): void {
    if (this.timer !== null) {
      clearTimeout(this.timer);
      this.timer = null;
    }
  }
}

// ---------------------------------------------------------------------------
// Graceful shutdown helpers
// ---------------------------------------------------------------------------

/**
 * Run a WAL checkpoint and close the database connection, then remove the
 * PID and port files.  This is the canonical shutdown sequence.
 *
 * @param workDir - Path to `.agentic-workflow/` (or equivalent) directory.
 * @param checkpointFn - Optional function to flush the database WAL.
 */
export async function gracefulShutdown(
  workDir: string,
  checkpointFn?: () => void
): Promise<void> {
  // 1. Flush WAL to main database file
  if (checkpointFn) {
    try {
      checkpointFn();
    } catch {
      // Non-fatal: checkpoint failure shouldn't block shutdown
    }
  }

  // 2. Remove PID and port files so the server is no longer discoverable
  removePidFile(workDir);
  removePortFile(workDir);
}

// ---------------------------------------------------------------------------
// Config reader
// ---------------------------------------------------------------------------

/** Default server configuration values. */
const DEFAULT_CONFIG: LifecycleConfig = {
  port: 3117,
  portRange: [3117, 3127],
  idleTimeoutMinutes: 240,
};

/**
 * Read the server lifecycle configuration from `.claude/agentic-sdlc-config.json`.
 * Falls back to defaults for any missing fields.
 */
export function readServerConfig(repoRoot: string): LifecycleConfig {
  const configPath = join(repoRoot, ".claude", "agentic-sdlc-config.json");
  if (!existsSync(configPath)) return { ...DEFAULT_CONFIG };

  try {
    const raw = readFileSync(configPath, "utf8");
    const parsed = JSON.parse(raw) as {
      server?: {
        port?: number;
        portRange?: [number, number];
        idleTimeoutMinutes?: number;
      };
    };
    const s = parsed.server ?? {};
    return {
      port: s.port ?? DEFAULT_CONFIG.port,
      portRange: s.portRange ?? DEFAULT_CONFIG.portRange,
      idleTimeoutMinutes: s.idleTimeoutMinutes ?? DEFAULT_CONFIG.idleTimeoutMinutes,
    };
  } catch {
    return { ...DEFAULT_CONFIG };
  }
}
