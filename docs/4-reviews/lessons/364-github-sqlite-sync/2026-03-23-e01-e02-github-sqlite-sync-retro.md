---
date: 2026-03-23
author: carlosboeing
agent: retro
backlog-issue: 364
backlog-pr: 376
scope: GitHub-to-SQLite pull sync engine for the Workflow Runtime Service
---

# GitHub-to-SQLite Sync -- Agentic Workflow Retrospective

## Summary

This backlog item added a pull sync engine to the Workflow Runtime Service that fetches all GitHub issues via GraphQL and upserts them into the SQLite database. The work spanned 2 epics and 5 stories (2 medium + 1 medium + 2 easy), producing 11 new TypeScript files (6 production, 5 test) totaling 5,360 lines of new code. One story (E01-S01) required a fix cycle after the reviewer identified a latent data corruption bug in the comment overflow handling. All 5 stories passed review and were merged.

## Timeline

| Phase | Time (UTC) | Wall Clock | Activity |
|-------|-----------|------------|----------|
| Design | 02:36 -- 02:43 | ~7m 34s | Designer: design doc for pull sync architecture |
| Plan | 03:11 -- 03:18 | ~7m 30s | Planner: 2 epics, 5 stories, dependency graph, dispatch plan |
| E01 Build (Wave 1) | 03:22 -- 03:33 | ~10m 23s | Parallel: E01-S01 GitHubPullFetcher + PullSyncService, E01-S02 IssueMapper + DatabaseUpserter |
| E01 Review (Wave 1) | 03:34 -- 03:38 | ~4m 38s | Parallel: E01-S01 REQUEST_CHANGES (C1 data corruption, C2 wrong error msg), E01-S02 APPROVE |
| E01 Fix Cycle | 03:39 -- 03:45 | ~5m 34s | E01-S01 fix build: added upsertComments interface, fixed rate limit error message, added pre-flight check |
| E01 Re-review | 03:45 -- 03:48 | ~3m 19s | E01-S01 re-review APPROVE |
| E01 Merge | ~03:48 -- 03:49 | ~1m | Merge E01 stories into epic, epic into integration branch |
| E02 Build (Wave 2) | 03:49 -- 04:08 | ~18m 46s | Parallel: E02-S01 API endpoint, E02-S02 CLI + startup seed, E02-S03 integration tests |
| E02 Review (Wave 2) | 04:09 -- 04:14 | ~5m 9s | Parallel: E02-S01 APPROVE, E02-S02 APPROVE, E02-S03 APPROVE |
| E02 Merge | ~04:14 -- 04:15 | ~1m | Merge E02 stories into epic, epic into integration branch |
| **Total** | 02:36 -- 04:15 | **~62m 57s** | 14 dispatches, 5 stories, 1 fix cycle |

*Source: `git log main..backlog/364-github-sqlite-sync --format="%h %ai %s"` and `.agentic-workflow/runs/364/orchestrator.json` dispatch timestamps.*

## Telemetry

### Per-Story Breakdown

| Story | Issue | Difficulty | Build | Review | Agent Time | Tokens | Est. Cost | Tool Uses |
|-------|-------|-----------|-------|--------|-----------|--------|-----------|-----------|
| E01-S01 | #369 | medium | 15m 58s (fix cycle) | 7m 58s (2 rounds) | 23m 56s | 495K | ~$5.05 | 201 |
| E01-S02 | #370 | medium | 6m 34s | 4m 8s | 10m 42s | 172K | ~$1.36 | 109 |
| E02-S01 | #371 | medium | 12m 32s | 3m 46s | 16m 18s | 175K | ~$1.33 | 142 |
| E02-S02 | #372 | easy | 9m 44s | 4m 37s | 14m 22s | 240K | ~$1.84 | 142 |
| E02-S03 | #373 | easy | 18m 46s | 5m 9s | 23m 56s | 253K | ~$1.87 | 172 |

### Phase Summary

| Phase | Model | Agent Time | Tokens | Est. Cost |
|-------|-------|-----------|--------|-----------|
| Design | opus | 7m 34s | 124K | ~$1.24 |
| Plan | opus | 7m 30s | 110K | ~$1.11 |
| Build (5 stories + 1 fix) | sonnet | 63m 36s | 732K | ~$4.40 |
| Review (7 dispatches) | opus | 25m 39s | 705K | ~$7.05 |
| **Total** | mixed | **104m 20s** | **1,473K** | **~$13.80** |

### Aggregate

| Metric | Value |
|--------|-------|
| Stories completed | 5/5 |
| Tests written | ~151 (across 8 test files, 3,688 test LOC) |
| Lines of code (production + test) | 5,360 new, 32 modified |
| Fix cycles | 1/5 stories (20% fix rate) |
| Critical issues found by reviewer | 2 (both on E01-S01) |
| Warnings found by reviewer | 14 across all stories |
| Suggestions | 15 across all stories |
| Wall clock (critical path) | 62m 57s |
| Parallelism savings | ~40% (104m sequential compressed to 62m wall clock) |
| Fix cycle overhead | ~$1.42 (10.3% of total cost) |

*Telemetry data from `.agentic-workflow/runs/364/orchestrator.json` dispatch records. Cost estimates use Anthropic published API pricing with a 75/25 input/output blended rate.*

## What Worked

### 1. Clean Two-Wave Dispatch Plan

The planner's dependency graph cleanly separated the two epics: E01 (core engine) had no external dependencies and its two stories could run in parallel; E02 (integration) depended on both E01 stories and its three stories could also run in parallel. This produced two well-defined waves, each with maximum internal parallelism. The critical path was 62m 57s versus 104m 20s sequential -- a 40% reduction. This is notably efficient for 5 stories.

### 2. Design Doc Feasibility Verification

The designer verified 10 assumptions via live GitHub GraphQL queries before the plan was written (design doc section 10.1). This included testing the `parent`/`subIssues` fields, board status extraction from `projectItems.fieldValues`, cursor pagination, and rate limit costs. The live verification eliminated several risks that would have surfaced during builds -- notably confirming that `subIssues` was not needed in the query (the `parent` field alone is sufficient for hierarchy reconstruction), saving ~15,000 estimated GraphQL nodes per sync.

### 3. Reviewer Caught a Latent Data Corruption Bug

The E01-S01 reviewer identified that the comment overflow handler constructed a synthetic `MappedIssue` with dummy data (`title: ""`, `type: "story"`, `status: "backlog"`) and passed it through `upsertPage()`. When the real `DatabaseUpserter` (E01-S02) performs `ON CONFLICT DO UPDATE`, this would silently overwrite correct item data with dummy values. The bug was latent -- unit tests passed because the upserter was mocked. The fix added a dedicated `upsertComments(itemId, comments)` method to the interface, cleanly separating the two operations. This validates the reviewer's role in catching cross-story interface mismatches that unit tests miss (see also the lesson file on async/sync mismatch).

### 4. Integration Tests Caught Cross-Story Interface Mismatch

E02-S03 explicitly tested the full pipeline with real implementations wired together. It discovered that E01-S01's `PullSyncService` defined a synchronous `DatabaseUpserter` interface while E01-S02's implementation was async (returning `Promise<T>`). The builder documented this in a lesson file (`2026-03-23-s03-async-interface-mismatch.md`) and fixed the interface to accept both sync and async return types. This confirms the plan's rationale for a dedicated integration test story (plan section 1.2).

### 5. Existing Infrastructure Reuse

The builder consistently reused patterns from the existing codebase: the `_runGh()` spy pattern from `GitHubAdapter` tests, the `setupTestDb()` helper, the `createApp()` factory for API tests, and the DI pattern for `PullSyncService`. This reduced implementation time and ensured stylistic consistency with the existing server code.

## What Didn't Work

### 1. Easy Stories Took Longer Than Medium Stories

E02-S02 (easy, CLI command) took 9m 44s build time and E02-S03 (easy, integration tests) took 18m 46s -- both longer than E01-S02 (medium, 6m 34s) and comparable to E02-S01 (medium, 12m 32s). E02-S03 was the longest build in the entire backlog despite being rated "easy." The root cause for E02-S03 is the integration test story required understanding all three components (fetcher, mapper, upserter) plus fixing the async interface mismatch, which is medium-level complexity masked by an easy label. E02-S02 required refactoring `index.ts` into a testable `index-internals.ts` pattern for DI, which is a structural change beyond what "easy" typically implies. This aligns with observation xii (infrastructure stories take 2-3x longer than content).

### 2. Async/Sync Interface Mismatch Not Caught Until Integration

E01-S01 defined synchronous interfaces for `IssueMapper` and `DatabaseUpserter`. E01-S02 implemented async versions. Neither story's unit tests caught the mismatch because mocks satisfied the interface contract at the type level. This was only caught by E02-S03's integration tests, which wired real implementations. The 18m 46s build time for E02-S03 includes the time spent diagnosing and fixing this mismatch. The lesson file correctly identifies that "interfaces should match implementation signatures" -- when a story defines an interface that another story implements, the plan should specify whether methods are sync or async.

### 3. Reviewer Warnings Carried Forward Without Resolution

The E01-S01 reviewer flagged 5 warnings, of which only W2 was addressed in the fix cycle (the critical issues took priority). The remaining 4 warnings (W1: unused `maxPoints`, W3: type cast, W4: unused options, W5: misleading test fixture) were carried forward as "low severity" on re-review. The E02 stories did not address them either. While individually minor, these accumulated warnings represent technical debt that will need cleanup.

### 4. PullSyncOptions Parameter Is Dead Code

The `PullSyncOptions` parameter in `pullSync()` was implemented as a typed interface with four fields (`filterLabels`, `updatedSince`, `maxPoints`, `includeComments`), none of which affect behavior. The parameter is underscore-prefixed to suppress lint warnings. This was flagged by the reviewer (W4 on E01-S01) but not fixed. The design doc describes these as useful features, but the plan did not assign them to any story. Future work should either implement the filtering or remove the interface to avoid misleading callers.

## Workflow Evolution During Epic

| Commit | Change | Trigger |
|--------|--------|---------|
| `05790ab` | Made primary PM adapter configurable (server + github dual-write) | Pre-build infrastructure setup |
| `5b08f76` | Simplified adapter config -- local is always the server | Clean up after PM adapter change |
| `15c4400` | Updated CLAUDE.md: local PM data lives in SQLite, not files | Documentation consistency with new adapter |
| `26aa47b` | Removed legacy `.workflow/items/` files (80 files, 5,445 lines deleted) | Server is now the primary PM; file-based state is no longer needed |

These changes were made by the orchestrator before builds started. They reflect the transition from file-based PM to server-based PM that was completed in BL116. The CLAUDE.md convention change (commit `15c4400`) updates the "Local PM items must be committed" instruction to reflect that PM data now lives in SQLite.

## Key Learnings

### For Builders

1. **When implementing an interface defined by a sibling story, verify async/sync alignment.** If the implementation uses `async/await`, the interface must declare `Promise<T>` return types. Unit tests with mocks will not catch this because mocks satisfy structural typing regardless of async behavior. (Evidence: E02-S03 lesson file, 18m 46s build time.)

2. **Integration test stories should be rated medium, not easy, when they wire together components from multiple stories.** E02-S03 required understanding all three pipeline components plus diagnosing and fixing a cross-story interface mismatch. The "easy" label set incorrect time expectations.

### For the Orchestrator

1. **PM infrastructure changes should be committed and pushed before design dispatch.** The orchestrator made 4 PM-related commits (`d194353`, `05790ab`, `5b08f76`, `15c4400`, `26aa47b`) between Phase 0 and Phase 1. These could have been batched into a single setup commit to reduce the commit noise on the integration branch.

2. **Difficulty labels should be reviewed against story dependencies.** E02-S03 was labeled "easy" but depended on E01-S01 and E01-S02 outputs, required understanding all three components, and ended up being the most time-consuming story. The planner should consider whether dependency complexity affects difficulty.

### For the Workflow

1. **The design-verified-assumptions table (section 10.1) should become a standard convention.** The designer's live GraphQL verification prevented several potential build-time failures. This structured verification approach is especially valuable for API-dependent features where assumptions about schema fields, pagination, and rate limits can be tested before any code is written.

2. **Dedicated integration test stories pay for themselves.** E02-S03 caught two interface mismatches (async/sync types and missing `upsertComments` method) that would have been production bugs. The 18m 46s investment prevented runtime failures that would be harder to diagnose post-merge.

## Recommendations

1. **Rate integration test stories at least "medium" when they wire multiple components** -- The planner should raise the difficulty of stories whose primary purpose is verifying cross-component integration. These stories require understanding all dependencies and frequently uncover interface mismatches. Evidence: E02-S03 (#373) was labeled "easy" but took 18m 46s (longest build) and required fixing async interface mismatch.

2. **Require async/sync declaration in interface-defining acceptance criteria** -- When a plan splits interface definition (story A) from implementation (story B), the acceptance criteria should specify whether methods return `T` or `Promise<T>`. This prevents the mismatch discovered in this backlog where E01-S01 assumed sync and E01-S02 implemented async. Evidence: lesson file `2026-03-23-s03-async-interface-mismatch.md`.

3. **Standardize the "verified assumptions" table in design docs** -- The designer's practice of listing assumptions, verification method, and status (VERIFIED/UNVERIFIED) with risk ratings proved valuable. Propose adding this as a recommended section in `designer.md` for features that depend on external APIs or undocumented behavior. Evidence: design doc section 10.1 verified 10 assumptions, 0 surfaced during builds.

## Lesson Retention

| Lesson File | Status | Disposition |
|-------------|--------|-------------|
| `e02-integration-triggers/2026-03-23-s03-async-interface-mismatch.md` | Compiled | Absorbed into recommendations 1 and 2 above |

This retro doc is now the primary reference for backlog 364 learnings. The lesson file remains on disk for traceability.
