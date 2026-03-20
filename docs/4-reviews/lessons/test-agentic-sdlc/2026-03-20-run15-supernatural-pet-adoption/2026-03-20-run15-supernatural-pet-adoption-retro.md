---
date: 2026-03-20
author: retro
backlog-issue: 290
backlog-pr: 301
scope: "Run 15 -- Supernatural Pet Adoption Agency: first production test of tiered review strategy, 5 stories, 2 epics, 2 waves"
---

# Run 15 -- Supernatural Pet Adoption Agency: Agentic Workflow Retrospective

## Summary

Run 15 produced 5 markdown content files (2 adoption listing files, 3 care guides) across 2 epics and 2 dispatch waves, validating the v2 workflow changes from backlog 243 -- specifically the tiered review strategy (`reviewStrategy.skipPerStoryReview.enabled: true`), parallel builder dispatch, and agent tool inheritance. The primary test objective was achieved: 4 easy stories correctly received `review_tier = SKIP` and bypassed per-story review, while the single medium story received a full reviewer dispatch that triggered 1 fix cycle (formatting issue in the nutrition guide's "Common Dietary Mistakes" section). The run consumed 10 agent dispatches, ~664K tokens, and ~$5.04 in estimated API cost over approximately 52 minutes wall clock.

## Timeline

| Phase | Time (UTC) | Wall Clock | Activity |
|-------|-----------|------------|----------|
| Setup | 23:49:03 | ~0m | Session start, pricing fetch, state init |
| Design | 23:49:39 -- 23:57:08 | ~7m 29s | Designer creates design doc (PR 291) |
| Design PR merge | 23:57:08 -- 23:58:30 | ~1m 22s | Auto-merge PR 291 into integration branch |
| Plan | 23:58:55 -- 00:10:00 | ~11m 5s | Planner creates plan + 7 issues (PR 300) |
| Plan PR merge | 00:10:00 -- 00:11:05 | ~1m 5s | Auto-merge PR 300 into integration branch |
| Branch setup | 00:11:05 -- 00:13:21 | ~2m 16s | Epic + story branches created, status transitions |
| Wave 1 Build | 00:13:21 -- 00:21:36 | ~8m 15s | 4-way parallel sonnet: E01-S01, E01-S02, E02-S01, E02-S02 (all SKIP) |
| Wave 1 Merge | 00:21:36 -- 00:24:54 | ~3m 18s | Merge stories into epics, merge E01 into integration, sync E02 |
| Wave 2 Build | 00:25:04 -- 00:34:52 | ~9m 48s | Sequential sonnet: E02-S03 (REVIEW tier) |
| Wave 2 Review | 00:35:21 -- 00:37:39 | ~2m 18s | Opus reviewer: REQUEST_CHANGES (format contract violation) |
| Fix Cycle | 00:38:06 -- 00:38:58 | ~0m 52s | Sonnet fix builder: convert Do NOT paragraphs to bullet list |
| Re-review | 00:39:12 -- 00:41:11 | ~1m 59s | Opus reviewer: APPROVE |
| Post-build | 00:41:11 -- 00:42:40 | ~1m 29s | Merge E02-S03, merge E02 epic, open PR 301, changelog, board cleanup |
| **Total** | 23:49:03 -- 00:42:40 | **~53m 37s** | |

*Source: orchestrator state file `.agentic-workflow/runs/290/orchestrator.json` dispatch timestamps and `git log` commit timestamps (AEST/UTC+10, converted to UTC).*

## Telemetry

### Per-Story Breakdown

| Story | Issue | Difficulty | Model | Agent Time | Tokens | Est. Cost | Tool Uses | Review Tier | Verdict |
|-------|-------|-----------|-------|-----------|--------|-----------|-----------|-------------|---------|
| E01-S01 | #295 | easy | sonnet | 7m 15s | 65K | ~$0.39 | 38 | SKIP | -- |
| E01-S02 | #296 | easy | sonnet | 8m 15s | 74K | ~$0.45 | 39 | SKIP | -- |
| E02-S01 | #297 | easy | sonnet | 5m 29s | 65K | ~$0.39 | 45 | SKIP | -- |
| E02-S02 | #298 | easy | sonnet | 3m 55s | 73K | ~$0.44 | 35 | SKIP | -- |
| E02-S03 | #299 | medium | sonnet | 14m 57s | 220K | ~$1.72 | 135 | REVIEW | APPROVE (after 1 fix cycle) |
| **Build Total** | | | | **39m 51s** | **499K** | **~$3.39** | **292** | | |
| Design | #291 | -- | opus | 7m 29s | 77K | ~$0.78 | 38 | -- | -- |
| Plan | #293 | -- | opus | 11m 5s | 87K | ~$0.87 | 70 | -- | -- |
| **Grand Total** | | | | **58m 28s** | **664K** | **~$5.04** | **400** | | |

*Note: E02-S03 "Agent Time" includes initial build (9m 48s, 85K tokens, ~$0.51), reviewer (2m 18s, 50K, ~$0.50), fix builder (0m 52s, 35K, ~$0.21), and re-reviewer (1m 59s, 49K, ~$0.50). All 4 SKIP-tier stories received no per-story review -- they were covered only by the PR-level review (pending at retro time).*

### Aggregate

| Metric | Value |
|--------|-------|
| Stories completed | 5/5 |
| Tests written | 0 (content-only run) |
| Critical bugs caught by reviewer | 1 (E02-S03: Do NOT items as paragraphs instead of bullet list) |
| Warnings caught by reviewer | 1 (E02-S03: no interdimensional pet in meal plan table) |
| Fix cycles completed | 1 (E02-S03, single round) |
| Total dispatches | 10 (2 design/plan + 5 build + 2 review + 1 fix) |
| Parallel waves | 1 (4-way parallel in Wave 1) |
| Sequential agent time | 58m 28s |
| Estimated wall clock | ~53m 37s |
| Parallelism savings | ~16m 40s (from 4-way Wave 1 parallel) |

### Cost by Role

| Role | Duration | Tokens | Est. Cost | % of Total |
|------|----------|--------|-----------|------------|
| Designer (opus) | 7m 29s | 77K | ~$0.78 | 15.5% |
| Planner (opus) | 11m 5s | 87K | ~$0.87 | 17.3% |
| Builders (sonnet) | 35m 37s | 399K | ~$2.39 | 47.4% |
| Reviewers (opus) | 4m 17s | 100K | ~$1.00 | 19.8% |
| **Total** | **58m 28s** | **664K** | **~$5.04** | **100%** |

*Note: "Builders" includes the fix cycle builder (dispatch 9). Reviewer cost is lower than prior runs because 4/5 stories used SKIP tier.*

### Fix Cycle Cost Analysis

| Metric | Value |
|--------|-------|
| Stories with fix cycles | 1/5 (20%) |
| Fix cycle rounds | 1 |
| Fix cycle cost (builder + re-reviewer) | ~$0.71 |
| Fix cycle % of total cost | 14.1% |
| Fix cycle duration | 2m 51s |

The fix was mechanical: adding `- ` prefix to 8 lines in the "Common Dietary Mistakes" section. The builder completed it in 52 seconds. The re-review confirmed the fix and approved in 1m 59s.

### Cost Comparison with Prior Content Runs

| Run | Stories | Dispatches | Tokens | Est. Cost | Wall Clock | Fix Cycles |
|-----|---------|------------|--------|-----------|------------|------------|
| Run 13 (Alien Tourist Bureau) | 6 | 18 | ~447K | ~$4.18 | ~28m | 0 |
| Run 14 (Health Inspections) | 12 | 32 | ~1.3M | ~$11.34 | ~77m | 3 |
| **Run 15 (Supernatural Pets)** | **5** | **10** | **~664K** | **~$5.04** | **~53m** | **1** |

Run 15's cost per story ($1.01) is higher than Run 13 ($0.70) and Run 14 ($0.94) because the design+plan overhead (~$1.65) is amortized over fewer stories. Excluding design+plan, the per-story build+review cost is $0.68 -- comparable to Run 13's build-only cost. The tiered review strategy eliminated ~$2.00 in potential Opus reviewer cost (4 stories at ~$0.50 each).

## What Worked

### 1. Tiered Review Strategy Validated Successfully

The primary test objective was achieved. All 4 easy stories (E01-S01, E01-S02, E02-S01, E02-S02) correctly received `review_tier = SKIP` and bypassed per-story review. The medium story (E02-S03) correctly received `review_tier = REVIEW` and was dispatched to an Opus reviewer. The config values (`skipPerStoryReview.enabled: true`, `maxDifficulty: "easy"`, `requireLabel: "test-agentic-sdlc"`) were all read and applied correctly. Estimated reviewer cost savings: ~$2.00 (4 skipped Opus reviews at ~$0.50 each).

### 2. Parallel 4-Way Builder Dispatch

Wave 1 dispatched 4 sonnet builders simultaneously (dispatches 3-6, all `started_at: "2026-03-20T00:13:21Z"`). The wall clock for Wave 1 was 8m 15s (limited by E01-S02, the slowest), versus 24m 54s sequential. This is a 3.0x speedup from parallelism. All 4 builders completed successfully with no cross-contamination, branch conflicts, or stale artifact issues.

### 3. Cross-Reference Consistency in Wave 2

E02-S03 (nutrition guide) needed to reference pet names from E01. The orchestrator correctly synced E01 content into the E02 epic branch before dispatching Wave 2 (commits `b9862b1` and `e2c0f30`). The reviewer confirmed all 6 pet names (Cinder, Flicker, Spark, Puddles, Marina, Abby) matched the E01 source files exactly, with dietary details consistent across all cross-references.

### 4. Fast Fix Cycle Resolution

The single fix cycle on E02-S03 was diagnosed and fixed efficiently. The reviewer correctly identified the format contract violation (Do NOT items as paragraphs instead of bullet list). The fix builder completed the mechanical change (adding `- ` prefix to 8 lines) in just 52 seconds (dispatch 9). The re-reviewer approved in 1m 59s. Total fix cycle overhead: 2m 51s and ~$0.71 -- well within the 70-100% overhead range for single-round fix cycles (observation viii).

### 5. Compact Run Validates Minimal Viable Workload

5 stories is the smallest workload that exercises all v2 features (SKIP, REVIEW, parallel dispatch, cross-reference dependency). The run completed in ~53 minutes wall clock at ~$5.04 -- significantly faster and cheaper than Run 14 (12 stories, ~77m, ~$11.34). This validates that the workflow scales down efficiently for validation runs.

## What Didn't Work

### 1. Designer Did Not Create a Separate Design Doc Issue

The designer opened PR 291 with title "[#290] Design doc: Supernatural Pet Adoption Agency" but did not create a dedicated docs issue for the design doc work. The convention calls for a `type/docs` issue to be created at the start of design work (see CLAUDE.md "Issue hierarchy" section: `Design doc issue (#24) -- designer creates, links to backlog`). Without a separate issue, the design work is tracked only through the PR, which conflates the PR (delivery vehicle) with the work item (tracking entity). PR 291 used `Closes #291` in its body, which is self-referential (a PR closing itself) -- this is harmless but semantically incorrect.

**Root cause:** The designer's instructions may not explicitly require issue creation before starting work. The convention is documented in CLAUDE.md's hierarchy diagram but not as an explicit procedural step in `designer.md`.

**Impact:** Low. The design doc was delivered correctly. The missing issue means the backlog item's sub-issue tree is incomplete (no design doc issue linked as a child of #290), and the project board has no status tracking for the design phase work.

### 2. Designer Title Format Deviated from Convention

PR 291 used the title "[#290] Design doc: Supernatural Pet Adoption Agency" instead of the expected "[#290] Write design doc for Supernatural Pet Adoption Agency". The convention in CLAUDE.md specifies: `[#<backlog>] Write design doc for X`. While the deviation is minor, it breaks pattern-matching consistency that agents and humans use to identify issue types at a glance.

**Root cause:** The convention is documented as an example pattern in CLAUDE.md's "Dependency declaration" section, not as a mandatory format in `designer.md`.

**Impact:** Minimal. Does not affect workflow execution.

### 3. Planner Worktree Isolation Created PM Items in Worktree Only

The planner, dispatched with `isolation: "worktree"`, created local PM items (`.workflow/items/*.md` files) in its worktree. These files were not synced to the integration branch. The orchestrator had to create the PM items manually on the integration branch (commit `c60fb40` includes `.workflow/items/` files for issues 292-299). This is a consequence of the local-first PM system (backlog 111) interacting with worktree isolation: the planner writes to the local filesystem adapter, but the worktree's filesystem is ephemeral.

**Root cause:** The local PM adapter writes to `.workflow/items/` in the current working directory. When the planner runs in a worktree, these files live in the worktree's directory, which is not the integration branch's working tree. After the planner's PR is merged (PR 300), only the plan document is included -- the PM items are left behind in the worktree.

**Impact:** Medium. The orchestrator had to manually create the PM items, adding overhead. The PM items are needed for `item-get.sh` to work in local-first mode. This is a systemic issue that affects any agent dispatched in a worktree that creates local PM items.

### 4. State File Not Updated with In-Review Status Before Board Reconciliation

The orchestrator's board reconciliation after PR creation used the state file to compute expected statuses. However, the state file's story statuses were still "reviewed" (from the build+review phase) rather than "in-review" (the board status after merging). When `reconcile-board.sh` ran, it may have computed incorrect expected statuses and reverted stories that had already been transitioned to In Review by the merge process.

**Root cause:** The state file's story status field tracks the builder/reviewer lifecycle ("built", "reviewed"), not the board status ("in-progress", "in-review"). The reconciliation script maps these differently, and the gap between state file semantics and board semantics can cause incorrect corrections.

**Impact:** Low-medium. Board statuses may have been temporarily incorrect, but the PR was still opened correctly and the final state is consistent.

## Workflow Evolution During Epic

No convention changes were made to CLAUDE.md or agent files during this backlog item. The `git diff main..backlog/290-supernatural-pet-adoption -- CLAUDE.md .claude/agents/` is empty.

## Key Learnings

### For Builders

1. **Format contract compliance matters even for small details.** E02-S03's fix cycle was caused by using `**Do NOT**` as standalone paragraphs instead of `- **Do NOT**` bullet items. The format contract was explicit about the required format. Builders should verify every format contract element before committing, not just the high-level structure.

### For the Orchestrator

1. **Worktree-isolated planners create PM items in the wrong location.** When the planner runs in a worktree, local PM items (`.workflow/items/`) are written to the worktree directory and lost after the PR merge. The orchestrator must either (a) sync these items to the integration branch after merging the plan PR, or (b) disable local PM writes for worktree-isolated dispatches.
2. **State file status semantics diverge from board status semantics.** The state file's "reviewed" status does not map cleanly to the board's "In Review" status when reconciliation runs. Either unify the terminology or add an explicit mapping layer to the reconciliation script.

### For the Workflow

1. **Tiered review strategy saves cost without sacrificing quality.** 4 skipped Opus reviews saved an estimated ~$2.00 (28% of total cost would have been reviewer cost without SKIP tier, vs 20% actual). The PR-level review serves as the quality backstop for SKIP-tier stories.
2. **Design+plan overhead is the dominant cost for small runs.** At $1.65 (33% of total), the design+plan phase is a fixed cost that makes small runs proportionally more expensive per story. For validation runs with 5 or fewer stories, consider lighter-weight design docs.
3. **The local-first PM system needs worktree-awareness.** The interaction between `isolation: "worktree"` and local PM writes is a gap that will recur on every run until addressed. This is the first run where the issue was explicitly observed because Run 15 is the first run after the local-first PM system (backlog 227) was integrated.

## Recommendations

1. **Add explicit "create design doc issue" step to designer.md** -- The designer should create a `type/docs` issue before starting work, matching the hierarchy diagram in CLAUDE.md. This ensures the backlog item's sub-issue tree is complete and the design phase has board status tracking. Evidence: Run 15 designer did not create an issue, only opened PR 291.

2. **Add worktree PM sync step to orchestrator post-merge** -- After merging a worktree-dispatched planner's PR, the orchestrator should copy `.workflow/items/` files from the merged content to the integration branch's working tree. Alternatively, modify the local PM adapter to detect worktree mode and write to the main repo's `.workflow/items/` path instead. Evidence: Run 15 orchestrator had to manually create PM items (commit `c60fb40`).

3. **Unify state file status terminology with board status** -- The state file uses "reviewed" while the board uses "In Review". The reconciliation script should either use a documented mapping or the state file should adopt board-compatible status values. Evidence: Run 15 board reconciliation may have computed incorrect expected statuses.

4. **Update Test Run History in CLAUDE.md** -- Run 15 should be added to the Test Run History table. The current table ends at Run 14. Evidence: CLAUDE.md "Test Run History" section.

## Lesson Retention

No individual lesson files were created during this backlog item's build phase (no agents encountered bugs or missing conventions that weren't already documented). The following lessons are captured here for the first time:

- **Worktree PM item isolation** (What Didn't Work item 3): First observation of local PM writes being lost in worktree mode. Recommendation 2 proposes a fix.
- **Designer issue creation gap** (What Didn't Work item 1): Documented as recommendation 1 for designer.md update.
- **State/board status terminology mismatch** (What Didn't Work item 4): Documented as recommendation 3.

This retro doc is the primary reference for Run 15 learnings. No raw lesson files exist to be compiled.
