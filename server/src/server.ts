import { Hono } from "hono";
import { cors } from "hono/cors";
import { serveStatic } from "hono/bun";
import { existsSync } from "node:fs";
import { join } from "node:path";
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
// Static serving options
// ---------------------------------------------------------------------------

export interface StaticOptions {
  /**
   * Absolute path to the directory containing the built frontend assets.
   * Defaults to `<server-dir>/frontend/dist`.
   */
  distDir?: string;
  /** Millisecond timestamp of server start (forwarded to createApp). */
  startTimeMs?: number;
  /** Idle timeout tracker (forwarded to createApp). */
  idleTracker?: IdleTimeoutTracker;
  /** Drizzle DB connection (forwarded to createApp). */
  db?: ReturnType<typeof drizzle>;
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
// App factory with static SPA serving
// ---------------------------------------------------------------------------

/**
 * Build the Hono application with static file serving for the React SPA.
 *
 * Serving strategy:
 * 1. `/api/*` routes are handled by the API layer (no fallback).
 * 2. Requests for files with extensions (`.js`, `.css`, `.ico`, etc.) are
 *    served from `distDir/`. If the file does not exist, returns 404.
 * 3. All other paths fall back to `index.html` so client-side routing works.
 *
 * @param options.distDir - Absolute path to the built frontend dist directory.
 */
export function createAppWithStatic(options: StaticOptions = {}): Hono {
  const serverDir = new URL(import.meta.url).pathname.replace(/\/src\/server\.ts$/, "");
  const distDir = options.distDir ?? join(serverDir, "frontend", "dist");
  const app = createApp({
    startTimeMs: options.startTimeMs,
    idleTracker: options.idleTracker,
    db: options.db,
  });

  // Serve static files from distDir for requests with a file extension.
  // serveStatic resolves paths relative to the Bun process cwd, so we use
  // an explicit root that points to the dist directory.
  app.use(
    "/assets/*",
    serveStatic({ root: distDir })
  );

  // SPA fallback: any path without an extension (or unknown) returns index.html.
  // API paths are already matched above and never reach this handler.
  app.get("*", async (c) => {
    // Requests for files with extensions that weren't found → 404
    const path = c.req.path;
    const hasExtension = /\.[^./]+$/.test(path) && !path.endsWith("/");
    if (hasExtension) {
      return c.json({ error: "Not found" }, 404);
    }

    // Serve index.html for all other paths (client-side routes)
    const indexPath = join(distDir, "index.html");
    if (!existsSync(indexPath)) {
      return c.text(
        "Frontend not built. Run: bun run build:frontend",
        503
      );
    }
    const file = Bun.file(indexPath);
    return new Response(file, {
      headers: {
        "content-type": "text/html; charset=utf-8",
        // index.html must not be cached so deployments take effect immediately
        "cache-control": "no-cache, no-store, must-revalidate",
      },
    });
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
  /**
   * Absolute path to the built frontend dist directory.
   * When provided (or defaulted), the server serves the React SPA in addition
   * to the API routes.  Defaults to `<server-dir>/frontend/dist`.
   */
  distDir?: string;
  /** Drizzle DB connection — required for item CRUD routes. Omit for health-only mode. */
  db?: ReturnType<typeof drizzle>;
}

/**
 * Start a Bun HTTP server on `localhost:<port>`.
 *
 * The server always serves the React SPA via `createAppWithStatic()` so that
 * the production startup path serves both the API and the frontend.
 *
 * Returns the Bun server instance (has `.stop()` for graceful shutdown).
 * All logging goes to stderr.
 */
export function startServer(options: ServerOptions): ReturnType<typeof Bun.serve> {
  const startTimeMs = options.startTimeMs ?? Date.now();
  const app = createAppWithStatic({
    distDir: options.distDir,
    startTimeMs,
    idleTracker: options.idleTracker,
    db: options.db,
  });

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
