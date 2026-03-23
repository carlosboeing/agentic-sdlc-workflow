/**
 * Sync route group — POST /api/sync/pull and GET /api/sync/status.
 *
 * Responsibilities:
 *   - Guard against concurrent syncs via an in-memory mutex
 *   - Invoke PullSyncService.pullSync() and return PullSyncResult
 *   - Expose sync status (idle/running, lastResult)
 *
 * The PullSyncService is injected via the factory function so tests
 * can substitute a mock without touching the real GitHub GraphQL API.
 */

import { Hono } from "hono";
import type { PullSyncResult } from "../services/pull-sync";

// ---------------------------------------------------------------------------
// Minimal service interface (avoids tight coupling to PullSyncService impl)
// ---------------------------------------------------------------------------

export interface SyncService {
  pullSync(): Promise<PullSyncResult>;
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
    // Concurrency guard — one pull sync at a time
    if (state.running) {
      return c.json(
        { error: "Sync already in progress" },
        409
      );
    }

    state.running = true;
    try {
      const result = await service.pullSync();
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
