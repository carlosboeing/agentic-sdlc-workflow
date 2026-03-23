/**
 * Extracted testable logic from index.ts.
 *
 * The `sync` command and startup seed logic are extracted here so they can
 * be unit-tested without spawning a real process or touching the filesystem.
 *
 * Dependencies are injected via plain interfaces rather than imported directly,
 * following the project convention established for PullSyncService.
 */

import type { PullSyncResult } from "./services/pull-sync";

// ---------------------------------------------------------------------------
// Dependency interfaces
// ---------------------------------------------------------------------------

/** Minimal PullSyncService surface needed by this module. */
export interface PullSyncServiceLike {
  pullSync(): Promise<PullSyncResult>;
}

/** Result type from migrateFromItems (matches server/src/db/seed.ts). */
export interface MigrateFromItemsResult {
  itemsImported: number;
  labelsCreated: number;
  relationshipsLinked: number;
  commentsImported: number;
}

/**
 * Dependencies injected into `runStartupSeed`.
 * Extracted for testability — production callers pass real values;
 * tests pass mocks without touching the filesystem.
 */
export interface StartupSeedDependencies {
  /** Number of items already in the database (0 triggers seed logic). */
  existingItemCount: number;
  /** PullSyncService instance for pull sync on empty DB. */
  pullSyncService: PullSyncServiceLike;
  /** Path to the .workflow/items/ directory (informational — used by migrateFromItems). */
  itemsDir: string;
  /** Whether itemsDir exists on disk (avoids fs check in tests). */
  itemsDirExists: boolean;
  /** File-based seed function — called as fallback when GitHub is unreachable. */
  migrateFromItems: (db: unknown, itemsDir: string) => Promise<MigrateFromItemsResult>;
  /** Stderr writer — process.stderr.write in production, captured array in tests. */
  stderrWrite: (msg: string) => void;
}

/**
 * Dependencies injected into `commandSync`.
 * Production callers construct real dependencies; tests inject mocks.
 */
export interface SyncCommandDependencies {
  /** PullSyncService instance to run the pull sync. */
  pullSyncService: PullSyncServiceLike;
  /** Stderr writer — process.stderr.write in production, captured array in tests. */
  stderrWrite: (msg: string) => void;
  /** Process exit function — process.exit in production, no-op/mock in tests. */
  processExit: (code: number) => void;
}

// ---------------------------------------------------------------------------
// runStartupSeed
// ---------------------------------------------------------------------------

/**
 * Startup seed logic: when the database is empty, attempt pull sync first.
 * Falls back to the file-based seed if GitHub is unreachable.
 * Does nothing when the database already has items.
 *
 * This function never throws — errors from pull sync are caught and logged.
 * Errors from migrateFromItems propagate to the caller (startup is fatal).
 */
export async function runStartupSeed(deps: StartupSeedDependencies): Promise<void> {
  if (deps.existingItemCount > 0) {
    // DB already has data — skip seeding entirely
    return;
  }

  // Empty DB: attempt pull sync first
  try {
    const result = await deps.pullSyncService.pullSync();
    deps.stderrWrite(`[seed] Pulled ${result.totalIssues} issues from GitHub.\n`);
    return;
  } catch (err) {
    deps.stderrWrite(
      `[seed] GitHub pull failed: ${err}. Falling back to .workflow/items/\n`
    );
  }

  // Fallback: file-based seed
  if (deps.itemsDirExists) {
    deps.stderrWrite("[seed] Database is empty — importing .workflow/items/\n");
    const seedResult = await deps.migrateFromItems(null, deps.itemsDir);
    deps.stderrWrite(
      `[seed] Imported ${seedResult.itemsImported} items, ` +
        `${seedResult.labelsCreated} labels, ` +
        `${seedResult.relationshipsLinked} relationships, ` +
        `${seedResult.commentsImported} comments.\n`
    );
  }
}

// ---------------------------------------------------------------------------
// commandSync
// ---------------------------------------------------------------------------

/**
 * One-shot pull sync command: runs pull sync and exits.
 * Prints a summary to stderr on success, an error message on failure.
 * Exits with code 0 on success, 1 on failure.
 *
 * Does NOT start the HTTP server — it is a pure data operation.
 */
export async function commandSync(deps: SyncCommandDependencies): Promise<void> {
  try {
    const result = await deps.pullSyncService.pullSync();

    deps.stderrWrite(
      `[sync] Pull sync complete:\n` +
        `  Total issues:     ${result.totalIssues}\n` +
        `  Items created:    ${result.itemsCreated}\n` +
        `  Items updated:    ${result.itemsUpdated}\n` +
        `  Labels created:   ${result.labelsCreated}\n` +
        `  Comments created: ${result.commentsCreated}\n` +
        `  Comments updated: ${result.commentsUpdated}\n` +
        `  Hierarchy links:  ${result.hierarchyLinked}\n` +
        `  Points consumed:  ${result.pointsConsumed}\n` +
        `  Duration:         ${result.durationMs}ms\n`
    );

    deps.processExit(0);
  } catch (err) {
    deps.stderrWrite(`[sync] Pull sync failed: ${err}\n`);
    deps.processExit(1);
  }
}
