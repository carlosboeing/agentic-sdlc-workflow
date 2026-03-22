import { Hono } from "hono";
import { cors } from "hono/cors";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { IdleTimeoutTracker } from "./lifecycle";
import { registerRoutes } from "./api/routes";

// ---------------------------------------------------------------------------
// Health router (exported for testing without a running server)
// ---------------------------------------------------------------------------

/**
 * Create a Hono router with the `/health` endpoint.
 *
 * @param startTimeMs - `Date.now()` timestamp from when the server started.
 *   Used to compute uptime in the health response.
 */
export function createHealthRouter(startTimeMs: number): Hono {
  const router = new Hono();

  router.get("/health", (c) => {
    const uptimeSeconds = Math.floor((Date.now() - startTimeMs) / 1000);
    return c.json({ status: "ok", uptime: uptimeSeconds });
  });

  return router;
}

// ---------------------------------------------------------------------------
// Application factory
// ---------------------------------------------------------------------------

export interface AppOptions {
  /** Millisecond timestamp of server start (defaults to Date.now()). */
  startTimeMs?: number;
  /** Idle timeout tracker — its touch() method is called on every request. */
  idleTracker?: IdleTimeoutTracker;
  /** Drizzle DB connection — required for item CRUD routes. Omit in health-only tests. */
  db?: ReturnType<typeof drizzle>;
}

/**
 * Build the Hono application with CORS middleware, error handling, and the
 * health route.  Routes from other epics will be mounted here.
 *
 * All logging goes to stderr so stdout remains available for MCP protocol.
 */
export function createApp(options: AppOptions = {}): Hono {
  const startTimeMs = options.startTimeMs ?? Date.now();
  const app = new Hono();

  // --- Middleware: CORS (localhost only) ---
  app.use(
    "*",
    cors({
      origin: (origin) => {
        if (!origin) return origin; // same-origin requests
        try {
          const url = new URL(origin);
          if (url.hostname === "localhost" || url.hostname === "127.0.0.1") {
            return origin;
          }
        } catch {
          // malformed origin
        }
        return null; // Block non-localhost origins
      },
      allowMethods: ["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
      allowHeaders: ["Content-Type", "Authorization"],
    })
  );

  // --- Middleware: request logging (stderr) and idle tracking ---
  app.use("*", async (c, next) => {
    const start = Date.now();
    await next();
    const duration = Date.now() - start;
    process.stderr.write(
      `${c.req.method} ${c.req.path} → ${c.res.status} (${duration}ms)\n`
    );
    // Touch the idle timer on every request
    options.idleTracker?.touch();
  });

  // --- API routes ---
  app.route("/api", createHealthRouter(startTimeMs));

  if (options.db) {
    registerRoutes(app, options.db);
  }

  // --- Global error handler ---
  app.onError((err, c) => {
    process.stderr.write(`Unhandled error: ${err.message}\n`);
    return c.json({ error: "Internal server error" }, 500);
  });

  // --- 404 handler ---
  app.notFound((c) => {
    return c.json({ error: "Not found" }, 404);
  });

  return app;
}

// ---------------------------------------------------------------------------
// Server startup (returns the Bun server handle)
// ---------------------------------------------------------------------------

export interface ServerOptions {
  port: number;
  startTimeMs?: number;
  idleTracker?: IdleTimeoutTracker;
}

/**
 * Start a Bun HTTP server on `localhost:<port>`.
 *
 * Returns the Bun server instance (has `.stop()` for graceful shutdown).
 * All logging goes to stderr.
 */
export function startServer(options: ServerOptions): ReturnType<typeof Bun.serve> {
  const startTimeMs = options.startTimeMs ?? Date.now();
  const app = createApp({ startTimeMs, idleTracker: options.idleTracker });

  const server = Bun.serve({
    port: options.port,
    hostname: "127.0.0.1", // localhost only — never 0.0.0.0
    fetch: app.fetch,
    error(error) {
      process.stderr.write(`Server error: ${error.message}\n`);
    },
  });

  process.stderr.write(`Server running on http://127.0.0.1:${server.port}\n`);
  return server;
}
