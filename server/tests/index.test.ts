/**
 * Tests for the `sync` CLI command and startup seed replacement logic in
 * server/src/index.ts.
 *
 * Strategy: extract the testable logic into the functions under test via
 * module-level helpers, then exercise them with mocked dependencies.
 *
 * Note: `commandSync`, `runStartupSeed` are thin wrappers around the
 * PullSyncService, so tests mock PullSyncService.pullSync() directly.
 */

import { describe, test, expect, mock, spyOn, beforeEach } from "bun:test";
import * as fs from "node:fs";
import {
  runStartupSeed,
  commandSync,
  type StartupSeedDependencies,
  type SyncCommandDependencies,
} from "../src/index-internals";

// ---------------------------------------------------------------------------
// Mock helpers
// ---------------------------------------------------------------------------

function makeMockPullSyncResult() {
  return {
    totalIssues: 10,
    itemsCreated: 8,
    itemsUpdated: 2,
    labelsCreated: 5,
    commentsCreated: 3,
    commentsUpdated: 1,
    hierarchyLinked: 4,
    pointsConsumed: 42,
    durationMs: 1234,
    errors: [],
  };
}

/** Creates a mock PullSyncService. */
function makeMockPullSyncService(options: { shouldFail?: boolean; error?: Error } = {}) {
  return {
    pullSync: mock(async () => {
      if (options.shouldFail) {
        throw options.error ?? new Error("GitHub unavailable");
      }
      return makeMockPullSyncResult();
    }),
  };
}

// ---------------------------------------------------------------------------
// runStartupSeed
// ---------------------------------------------------------------------------

describe("runStartupSeed", () => {
  test("RunStartupSeed_EmptyDbGithubAvailable_RunsPullSync", async () => {
    const stderrMessages: string[] = [];
    const pullSyncService = makeMockPullSyncService();

    const deps: StartupSeedDependencies = {
      existingItemCount: 0,
      pullSyncService,
      itemsDir: "/nonexistent/items",
      migrateFromItems: mock(async () => ({
        itemsImported: 0,
        labelsCreated: 0,
        relationshipsLinked: 0,
        commentsImported: 0,
      })),
      itemsDirExists: false,
      stderrWrite: (msg: string) => {
        stderrMessages.push(msg);
      },
    };

    await runStartupSeed(deps);

    expect(pullSyncService.pullSync).toHaveBeenCalledTimes(1);
    expect(deps.migrateFromItems).not.toHaveBeenCalled();
    expect(stderrMessages.some((m) => m.includes("[seed] Pulled 10 issues from GitHub."))).toBe(
      true
    );
  });

  test("RunStartupSeed_EmptyDbGithubFails_FallsBackToFileSeed", async () => {
    const stderrMessages: string[] = [];
    const pullSyncService = makeMockPullSyncService({ shouldFail: true });
    const migrateFromItems = mock(async () => ({
      itemsImported: 5,
      labelsCreated: 2,
      relationshipsLinked: 1,
      commentsImported: 0,
    }));

    const deps: StartupSeedDependencies = {
      existingItemCount: 0,
      pullSyncService,
      itemsDir: "/some/items",
      migrateFromItems,
      itemsDirExists: true,
      stderrWrite: (msg: string) => {
        stderrMessages.push(msg);
      },
    };

    await runStartupSeed(deps);

    expect(pullSyncService.pullSync).toHaveBeenCalledTimes(1);
    expect(migrateFromItems).toHaveBeenCalledTimes(1);
    expect(
      stderrMessages.some((m) => m.includes("[seed] GitHub pull failed:") && m.includes("Falling back to .workflow/items/"))
    ).toBe(true);
  });

  test("RunStartupSeed_EmptyDbGithubFailsNoItemsDir_SkipsFileSeed", async () => {
    const stderrMessages: string[] = [];
    const pullSyncService = makeMockPullSyncService({ shouldFail: true });
    const migrateFromItems = mock(async () => ({
      itemsImported: 0,
      labelsCreated: 0,
      relationshipsLinked: 0,
      commentsImported: 0,
    }));

    const deps: StartupSeedDependencies = {
      existingItemCount: 0,
      pullSyncService,
      itemsDir: "/nonexistent/items",
      migrateFromItems,
      itemsDirExists: false,
      stderrWrite: (msg: string) => {
        stderrMessages.push(msg);
      },
    };

    await runStartupSeed(deps);

    expect(pullSyncService.pullSync).toHaveBeenCalledTimes(1);
    // migrateFromItems should NOT be called since itemsDirExists is false
    expect(migrateFromItems).not.toHaveBeenCalled();
  });

  test("RunStartupSeed_NonEmptyDb_SkipsBothSeeds", async () => {
    const stderrMessages: string[] = [];
    const pullSyncService = makeMockPullSyncService();
    const migrateFromItems = mock(async () => ({
      itemsImported: 0,
      labelsCreated: 0,
      relationshipsLinked: 0,
      commentsImported: 0,
    }));

    const deps: StartupSeedDependencies = {
      existingItemCount: 42, // non-empty DB
      pullSyncService,
      itemsDir: "/some/items",
      migrateFromItems,
      itemsDirExists: true,
      stderrWrite: (msg: string) => {
        stderrMessages.push(msg);
      },
    };

    await runStartupSeed(deps);

    expect(pullSyncService.pullSync).not.toHaveBeenCalled();
    expect(migrateFromItems).not.toHaveBeenCalled();
    // No seed messages emitted
    expect(stderrMessages.filter((m) => m.startsWith("[seed]")).length).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// commandSync
// ---------------------------------------------------------------------------

describe("commandSync", () => {
  test("CommandSync_Success_PrintsSummaryAndExitsZero", async () => {
    const stderrMessages: string[] = [];
    const pullSyncService = makeMockPullSyncService();
    let exitCode: number | undefined;

    const deps: SyncCommandDependencies = {
      pullSyncService,
      stderrWrite: (msg: string) => {
        stderrMessages.push(msg);
      },
      processExit: (code: number) => {
        exitCode = code;
      },
    };

    await commandSync(deps);

    expect(pullSyncService.pullSync).toHaveBeenCalledTimes(1);
    expect(exitCode).toBe(0);

    // Verify summary output contains key metrics
    const allOutput = stderrMessages.join("\n");
    expect(allOutput).toContain("10"); // totalIssues
    expect(allOutput).toContain("8"); // itemsCreated
    expect(allOutput).toContain("2"); // itemsUpdated
  });

  test("CommandSync_Failure_PrintsErrorAndExitsOne", async () => {
    const stderrMessages: string[] = [];
    const pullSyncService = makeMockPullSyncService({
      shouldFail: true,
      error: new Error("Rate limit exceeded"),
    });
    let exitCode: number | undefined;

    const deps: SyncCommandDependencies = {
      pullSyncService,
      stderrWrite: (msg: string) => {
        stderrMessages.push(msg);
      },
      processExit: (code: number) => {
        exitCode = code;
      },
    };

    await commandSync(deps);

    expect(exitCode).toBe(1);
    const allOutput = stderrMessages.join("\n");
    expect(allOutput).toContain("Rate limit exceeded");
  });

  test("CommandSync_Success_SummaryIncludesAllCounters", async () => {
    const stderrMessages: string[] = [];
    const pullSyncService = {
      pullSync: mock(async () => ({
        totalIssues: 50,
        itemsCreated: 40,
        itemsUpdated: 10,
        labelsCreated: 15,
        commentsCreated: 30,
        commentsUpdated: 5,
        hierarchyLinked: 20,
        pointsConsumed: 126,
        durationMs: 8500,
        errors: [],
      })),
    };
    let exitCode: number | undefined;

    const deps: SyncCommandDependencies = {
      pullSyncService,
      stderrWrite: (msg: string) => {
        stderrMessages.push(msg);
      },
      processExit: (code: number) => {
        exitCode = code;
      },
    };

    await commandSync(deps);

    expect(exitCode).toBe(0);
    const allOutput = stderrMessages.join("\n");

    // Check for all expected counters in output
    expect(allOutput).toContain("50"); // totalIssues
    expect(allOutput).toContain("40"); // itemsCreated
    expect(allOutput).toContain("10"); // itemsUpdated
    expect(allOutput).toContain("15"); // labelsCreated
    expect(allOutput).toContain("30"); // commentsCreated or commentsUpdated
    expect(allOutput).toContain("20"); // hierarchyLinked
    expect(allOutput).toContain("126"); // pointsConsumed
  });
});
