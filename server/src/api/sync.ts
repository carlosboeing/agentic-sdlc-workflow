/**
 * Sync route group — POST /api/sync/pull and GET /api/sync/status.
 *
 * Responsibilities:
 *   - Validate request body (filterLabels, includeComments)
 *   - Guard against concurrent syncs via an in-memory mutex
 *   - Invoke PullSyncService.pullSync() and return PullSyncResult
 *   - Expose sync status (idle/running, lastResult)
 *
 * The PullSyncService is injected via the factory function so tests
 * can substitute a mock without touching the real GitHub GraphQL API.
 */

import { Hono } from "hono";
import { z } from "zod";
import type { PullSyncResult, PullSyncOptions } from "../services/pull-sync";
import { formatZodError } from "./validation";

// ---------------------------------------------------------------------------
// Request validation schemas
// ---------------------------------------------------------------------------

/** Body for POST /api/sync/pull */
const PullSyncBodySchema = z
  .object({
    filterLabels: z.array(z.string()).optional(),
    includeComments: z.boolean().optional(),
  })
  .optional()
  .default({});

// ---------------------------------------------------------------------------
// Minimal service interface (avoids tight coupling to PullSyncService impl)
// ---------------------------------------------------------------------------

export interface SyncService {
  pullSync(options?: PullSyncOptions): Promise<PullSyncResult>;
}

// ---------------------------------------------------------------------------
// Sync state (per-router instance, shared between handler invocations)
// ---------------------------------------------------------------------------

interface SyncState {
  running: boolean;
  lastResult: PullSyncResult | null;
}

// ---------------------------------------------------------------------------
// Router factory
// ---------------------------------------------------------------------------

/**
 * Create the sync Hono router.
 *
 * Each call returns a new router with its own independent mutex and state,
 * which is what tests need (one router per test case).  In production,
 * `registerRoutes` constructs exactly one instance.
 *
 * @param service - SyncService instance (PullSyncService in production, mock in tests)
 */
export function createSyncRouter(service: SyncService): Hono {
  const router = new Hono();

  /** Mutex: true when a pull sync is currently running. */
  const state: SyncState = {
    running: false,
    lastResult: null,
  };

  // -------------------------------------------------------------------------
  // POST /api/sync/pull
  // -------------------------------------------------------------------------

  router.post("/sync/pull", async (c) => {
    // Parse request body — treat missing/empty body as empty options
    let raw: unknown = {};
    const contentType = c.req.header("content-type") ?? "";
    if (contentType.includes("application/json")) {
      try {
        raw = await c.req.json();
      } catch {
        return c.json(
          { error: "Invalid JSON body", details: [] },
          400
        );
      }
    }

    const parseResult = PullSyncBodySchema.safeParse(raw);
    if (!parseResult.success) {
      return c.json(formatZodError(parseResult.error), 400);
    }

    // Concurrency guard — one pull sync at a time
    if (state.running) {
      return c.json(
        { error: "Sync already in progress" },
        409
      );
    }

    state.running = true;
    try {
      const opts: PullSyncOptions = {};
      if (parseResult.data.filterLabels !== undefined) {
        opts.filterLabels = parseResult.data.filterLabels;
      }
      if (parseResult.data.includeComments !== undefined) {
        opts.includeComments = parseResult.data.includeComments;
      }

      const result = await service.pullSync(opts);
      state.lastResult = result;
      return c.json(result, 200);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return c.json({ error: message }, 500);
    } finally {
      state.running = false;
    }
  });

  // -------------------------------------------------------------------------
  // GET /api/sync/status
  // -------------------------------------------------------------------------

  router.get("/sync/status", (c) => {
    const response: {
      state: "idle" | "running";
      lastResult?: PullSyncResult;
    } = {
      state: state.running ? "running" : "idle",
    };

    if (state.lastResult !== null) {
      response.lastResult = state.lastResult;
    }

    return c.json(response, 200);
  });

  return router;
}
