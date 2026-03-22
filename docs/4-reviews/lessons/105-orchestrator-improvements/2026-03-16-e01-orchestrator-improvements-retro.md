---
date: 2026-03-16
author: carlosboeing
agent: retro
backlog-issue: 105
backlog-pr: 143
scope: 6 orchestrator improvements — reviewer routing, early branch creation, batched board updates, format templates, override pattern, overhead metrics
---

# Orchestrator Improvements (E01) — Agentic Workflow Retrospective

## Summary

Backlog #105 implemented 6 orchestrator enhancements across a single epic (E01) with 6 stories dispatched in 4 waves (2 parallel, 2 sequential). All 6 stories passed review on first attempt (0 fix cycles), continuing the organic zero-fix-cycle streak through 40+ stories. This was the first "workflow-on-workflow" run where agents modified their own orchestrator and agent instruction files, proving that the pipeline can safely evolve its own conventions without human intervention during the build phase.

## Timeline

| Phase | Time (UTC) | Wall Clock | Activity |
|-------|-----------|------------|----------|
| Session start | 06:26 | — | Orchestrator initializes, fetches pricing |
| Design | 06:26 – 06:35 | ~9m 11s | Designer writes design doc for 8 improvements, recommends 6 include / 2 defer |
| Design PR merge | 06:35 – 06:36 | ~1m | Orchestrator merges design PR #122 |
| Plan | 06:36 – 06:45 | ~9m 13s | Planner decomposes into 1 epic, 6 stories, creates issues #132–#140 |
| Plan PR merge | 06:45 – 06:46 | ~1m | Orchestrator merges plan PR #142 |
| Orchestrator setup | 06:46 – 06:55 | ~9m | Phase 4 reads plan, creates branches, prepares dispatch |
| Wave 1 build (parallel) | 06:55 – 07:04 | ~9m 40s | S01 Sonnet Reviews (9m 40s) + S04 Format Templates (1m 37s) |
| Wave 1 review (parallel) | 07:05 – 07:08 | ~3m 5s | S01 review APPROVE (3m 5s) + S04 review APPROVE (1m 20s) |
| Orchestrator W1 merge | 07:08 – 07:15 | ~7m | Merge S01 + S04 into epic, board updates, comment verification |
| Wave 2 build | 07:15 – 07:18 | ~3m 39s | S03 Batched Board Updates |
| Wave 2 review | 07:19 – 07:23 | ~4m 45s | S03 review APPROVE |
| Orchestrator W2 merge | 07:23 – 07:30 | ~7m | Merge S03 into epic, board updates |
| Wave 3 build (parallel) | 07:30 – 07:43 | ~13m 58s | S02 Early Branches (13m 58s) + S05 Override Pattern (2m 43s) |
| Wave 3 review (parallel) | 07:45 – 07:46 | ~1m 57s | S02 review APPROVE (1m 57s) + S05 review APPROVE (1m 36s) |
| Orchestrator W3 merge | 07:46 – 07:55 | ~9m | Merge S02 + S05 into epic, board updates |
| Wave 4 build | 07:55 – 08:01 | ~6m 23s | S06 Overhead Metrics |
| Wave 4 review | 08:02 – 08:04 | ~2m 45s | S06 review COMMENT (non-blocking) |
| Orchestrator final merge | 08:04 – 08:15 | ~11m | Merge S06 into epic, epic into integration, changelog, PR creation |
| Backlog PR review | 08:15 – 08:20 | ~5m 21s | Cross-epic integration review APPROVE |
| **Total** | 06:26 – 08:20 | **~1h 54m** | |

*Source: orchestrator state file `.agentic-workflow/runs/105/orchestrator.json` dispatch timestamps, `git log` commit timestamps.*

## Telemetry

### Per-Story Breakdown

| Story | Issue | Difficulty | Build Model | Build Time | Build Tokens | Build Cost | Review Model | Review Time | Review Tokens | Review Cost | Total Cost | Verdict |
|-------|-------|-----------|------------|-----------|-------------|-----------|-------------|------------|--------------|------------|-----------|---------|
| E01-S01 Sonnet Reviews | #135 | medium | sonnet | 9m 40s | 91K | ~$0.55 | opus | 3m 5s | 53K | ~$0.54 | ~$1.09 | APPROVE |
| E01-S02 Early Branches | #136 | easy | sonnet | 13m 58s | 90K | ~$0.54 | opus | 1m 57s | 40K | ~$0.41 | ~$0.95 | APPROVE |
| E01-S03 Batched Board | #137 | medium | sonnet | 3m 39s | 55K | ~$0.33 | opus | 4m 45s | 43K | ~$0.44 | ~$0.77 | APPROVE |
| E01-S04 Format Templates | #138 | easy | sonnet | 1m 37s | 40K | ~$0.24 | opus | 1m 20s | 35K | ~$0.35 | ~$0.59 | APPROVE |
| E01-S05 Override Pattern | #139 | easy | sonnet | 2m 43s | 48K | ~$0.29 | opus | 1m 36s | 34K | ~$0.34 | ~$0.64 | APPROVE |
| E01-S06 Overhead Metrics | #140 | medium | sonnet | 6m 23s | 83K | ~$0.50 | opus | 2m 45s | 49K | ~$0.50 | ~$0.99 | COMMENT |
| **Epic Total** | | | | **38m 2s** | **409K** | **~$2.46** | | **15m 31s** | **257K** | **~$2.57** | **~$5.03** | |

*Note: All reviews used Opus because this run implemented the Sonnet reviewer routing feature itself -- the `reviewer-sonnet.md` variant was created during the run but could not be used due to Claude Code's "agents loaded at session start only" limitation. The backlog PR review (dispatch 15, Opus, 5m 21s, 76K tokens, ~$0.77) is not included in the per-story table above.*

### Full Lifecycle Breakdown

| Phase | Model | Duration | Tokens | Est. Cost | % of Cost |
|-------|-------|----------|--------|-----------|-----------|
| Design | opus | 9m 11s | 114K | ~$1.14 | 14.3% |
| Plan | opus | 9m 13s | 108K | ~$1.08 | 13.5% |
| Build (6 stories) | sonnet | 38m 2s | 409K | ~$2.46 | 30.6% |
| Review (6 stories + PR) | opus | 20m 53s | 333K | ~$3.34 | 41.6% |
| **Total** | | **77m 20s** | **965K** | **~$8.02** | |

### Aggregate

| Metric | Value |
|--------|-------|
| Stories completed | 6/6 |
| Fix cycles | 0 |
| First-pass approval rate | 100% (6/6 APPROVE, 0 REQUEST_CHANGES) |
| Tests written | 0 (convention/docs-only changes -- no production code) |
| Critical issues found by reviewer | 0 |
| Warnings found by reviewer (per-story) | 7 (W1-W2 on S01, W1-W2 on S02, W1 on S03, W1 on S04, W1-W2 on S06) |
| Warnings found by reviewer (backlog PR) | 3 (W1 GraphQL injection, W2 orchestrator.md size, W3 bash precedence bug) |
| Suggestions (per-story + PR) | 10 |
| Wall clock (session start to PR review end) | ~1h 54m |
| Critical path (subagent time) | 70m 2s |
| Orchestrator overhead | ~44m 19s (38.8% of wall clock) |
| Parallelism savings | 7m 18s (9.4% of sequential duration) |

### Cost Context

Review cost was 41.6% of total, consistent with the 35-41% range observed in Runs 8-14 (observation in the design doc). All reviews used Opus; the Sonnet reviewer routing implemented by this run will reduce this fraction in future runs. Estimated savings if S04, S05, and S02 reviews had used Sonnet (easy stories): ~$0.66 saved (easy story reviews cost ~$0.35-0.41 each with Opus; Sonnet equivalent ~$0.07-0.08 each). This would have reduced review cost share to ~33%.

## What Worked

### 1. Zero Fix Cycles on Self-Referential Convention Changes

All 6 stories modified the workflow's own conventions (orchestrator.md, CLAUDE.md, planner.md, config files) and all 6 passed review on first attempt. This is notable because the builders were editing the very instructions they were following -- a potential source of confusion or circular errors. The acceptance criteria in the plan were precise enough that builders could modify their own agent files correctly without getting confused by self-reference. Evidence: 6/6 APPROVE verdicts, 0 REQUEST_CHANGES, 0 critical issues across all 6 story reviews.

### 2. Well-Scoped Plan with Accurate File Overlap Analysis

The plan's file overlap analysis table (showing which stories share `orchestrator.md`, `CLAUDE.md`, etc.) correctly predicted where merge conflicts would occur and informed the wave sequencing. The 4-wave dispatch plan avoided all merge conflicts despite 5 of 6 stories modifying `orchestrator.md`. Evidence: 0 merge conflicts during any of the 6 story merges or the epic-to-integration merge (commits `d913c2f`, `3c2aa03`, `e6f79d6`, `0c5bd8e`, `5a370fe`, `41958ff`, `6f67856`).

### 3. Design-Phase Decision to Defer 2 Improvements

The designer evaluated 8 candidate improvements and deferred 2 (Streaming Reviews and Batch Issue Creation) based on complexity-vs-benefit analysis. This kept the backlog item manageable (6 stories in 1 epic) while still delivering meaningful value. Both deferrals had strong rationale: Streaming Reviews adds 3-4 new state transitions for ~1-2 min savings; Batch Issue Creation is obsoleted by the PM Abstraction Layer (backlog #109). Evidence: design doc "Summary: Inclusion Decisions" table.

### 4. Fastest Story Completed in 1m 37s

E01-S04 (Format Templates) completed its build phase in 1m 37s with only 18 tool uses and 40K tokens -- the most efficient builder dispatch in the run. The story was a single-file documentation addition to `planner.md` plus a `retro-recommendations.md` update. This demonstrates that easy documentation stories can be extremely efficient when properly scoped. Evidence: dispatch 4 in the state file.

## What Didn't Work

### 1. Easy Story S02 Took 14 Minutes (4.3x Expected)

E01-S02 (Early Story Branch Creation) was labeled `difficulty/easy` and was a documentation-only change (moving branch creation instructions from Phase 5 to Phase 4 in orchestrator.md). Despite this, the build took 13m 58s with 110 tool uses -- comparable to the medium-difficulty S01 (9m 40s, 108 tool uses). Root cause: the builder encountered repeated Edit tool failures due to worktree CWD confusion, as documented in the lesson file (`2026-03-16-s02-edit-tool-worktree-cwd-confusion.md`). The Edit tool's internal cache became stale when the file was modified by git operations in the worktree, causing the builder to retry multiple times before switching to a Python `str.replace()` workaround. Evidence: dispatch 9 in state file, lesson file on integration branch.

### 2. Reviewer Variant Files Created But Unusable in Same Session

S01 created `reviewer-sonnet.md` and `reviewer-opus.md` during the run, but the orchestrator could not use them for subsequent reviews because Claude Code only loads agent files at session start. All 6 story reviews and the backlog PR review used the base `reviewer` agent with Opus, which is the current default. This means the cost savings from reviewer routing (the primary goal of S01) will only be realized in the next run. Evidence: all review dispatches in the state file show `"model": "opus"` regardless of story difficulty. This is a known platform limitation documented in CLAUDE.md ("Dynamic agent files at runtime: Agent `.md` files created mid-session are NOT discovered").

### 3. Orchestrator Overhead Was 38.8% of Wall Clock

The orchestrator spent ~44 minutes on non-subagent work (branch creation, merging, board updates, comment verification, PR creation) out of ~114 minutes total wall clock. While this is lower than Run 10's 51%, it remains substantial. The largest overhead gaps were: planner-to-Wave-1 (~9m 47s, likely Phase 4 branch setup), Wave-3-to-Wave-4 (~8m 3s, merges and board updates), and Wave-4-review-to-PR-review (~10m 15s, epic merge, integration merge, changelog, PR creation). Evidence: dispatch `started_at` timestamps show inter-dispatch gaps totaling ~44 minutes.

### 4. Recommendation H Renumbered Inconsistently

The S06 builder moved recommendation H from Outstanding to Implemented but renumbered it to "32" instead of keeping the letter designation. The S04 and S05 builders correctly preserved their letters (E and F). The S06 reviewer caught this as W1. Evidence: `retro-recommendations.md` Implemented table shows "32" where "H" is expected. The backlog PR reviewer also flagged this as S3.

## Workflow Evolution During Epic

| Commit | Change | Trigger |
|--------|--------|---------|
| `7f5ff09` | Created `reviewer-sonnet.md` and `reviewer-opus.md` agent variants | S01: Enable difficulty-based reviewer routing |
| `1b36e69` | Added `reviewerRouting` to `agentic-sdlc-config.json` and `CFG_REVIEW_*` to `config.sh` | S01: Config-driven reviewer model selection |
| `233cbf0` | Updated `orchestrator.md` Phase 6 and `dispatch-workflow.sh` for reviewer variant dispatch | S01: Orchestrator uses variants instead of bare `reviewer` |
| `e91917a` | Updated `CLAUDE.md` dispatch protocol, variant sync convention | S01: Project-wide documentation of reviewer routing |
| `5558999` | Added "Format Templates for Parallel Content" section to `planner.md` | S04: Prevent cosmetic divergence in parallel builders |
| `a167292` | Created `scripts/batch-set-status.sh` (158 lines) | S03: Batch board status updates at wave boundaries |
| `ab67f13` | Updated `orchestrator.md` Phase 5 to use `batch-set-status.sh` | S03: Replace per-issue loops with batch invocation |
| `1ce4aae` | Added "Orchestrator Override Pattern" section to `orchestrator.md` | S05: Formalize pre-fix override convention |
| `21f6b76` | Moved branch creation from Phase 5 to Phase 4 in `orchestrator.md` | S02: Cleaner phase separation, eliminates wave transition overhead |
| `e34dad4` | Added overhead metrics capture (wall-clock heuristic) to `orchestrator.md` and `CLAUDE.md` | S06: Surface orchestrator's hidden time cost |

## Key Learnings

### For Builders

1. **Edit tool CWD resets between Bash calls in worktree mode.** When a builder's session starts in a worktree, `git checkout` in one Bash call does not persist to the next. Chain all git state changes in a single `&&` call. If the Edit tool reports stale-cache errors repeatedly, fall back to Python `str.replace()` or `sed`. Evidence: lesson file `2026-03-16-s02-edit-tool-worktree-cwd-confusion.md`, S02 taking 14 minutes for an easy story.
2. **Self-referential convention changes work when acceptance criteria are precise.** Builders modifying their own agent instructions (orchestrator.md, CLAUDE.md) did not get confused or introduce circular errors. The plan's per-story AC was specific enough to guide the edits. Evidence: 6/6 first-pass approvals on self-modifying stories.
3. **Preserve letter-based recommendation IDs when moving items to Implemented.** The Implemented table mixes numbered (1-31) and lettered (E, F) entries. When moving a lettered recommendation (G, H, etc.), keep the letter to maintain traceability from retro documents that reference it by letter. Evidence: S06 reviewer W1 (H renumbered to 32).

### For the Orchestrator

1. **Agent files created during a session are not available until the next session.** Plan runs that create agent variants (like reviewer-sonnet.md) knowing the variants will not be usable in the same run. The feature takes effect on the next run. This is a Claude Code platform constraint, not a workflow bug.
2. **Orchestrator overhead is measurable via dispatch timestamp gaps.** The 38.8% overhead observed in this run is directly computable from the `started_at` and `duration_ms` fields in the state file dispatch log. Future runs should use the S06-implemented heuristic to include an "Orchestrator" row in telemetry.
3. **The largest overhead gaps occur during merge phases.** Inter-wave merge and board update overhead (~7-10 min per gap) dominates orchestrator time. The `batch-set-status.sh` script implemented in S03 should reduce the board update portion of this overhead in future runs.

### For the Workflow

1. **The pipeline can safely evolve its own conventions.** This was the first run where the work product was changes to the workflow itself (agent files, scripts, config, CLAUDE.md). The zero-fix-cycle result demonstrates that the separation of concerns (designer recommends, planner decomposes, builder implements, reviewer verifies) works even when the target is the pipeline's own instructions.
2. **Review cost fraction remains the dominant cost center at 41.6%.** The Sonnet reviewer routing implemented here is projected to reduce this by ~$0.66/run for easy stories. Future runs with the routing active will validate this projection.
3. **Documentation-only stories benefit from the same TDD-like workflow.** Even though no tests were written (no production code), the review step caught 10 warnings and 10 suggestions across the 7 reviews, including a genuine bash operator precedence bug in `batch-set-status.sh` (W3 on PR review). The reviewer adds value even on purely documentation changes.

## Compiled Lessons

| Lesson File | Status | Absorbed Into |
|-------------|--------|---------------|
| `e01-orchestrator-improvements/2026-03-16-s02-edit-tool-worktree-cwd-confusion.md` | compiled | Key Learnings, Builder point 1 |

No additional lessons were written during the retro phase. The single lesson file from the build phase (Edit tool worktree confusion) is the only lesson for this backlog item.

## Recommendations

### New

1. **Fix the bash operator precedence bug in `batch-set-status.sh` line ~113-115 before the next run.** The verification phase's skip guard `[ -z "$item_id" ] || [ "$item_id" = "null" ] && continue` has incorrect precedence -- the `&&` binds tighter than `||`, so empty item IDs are not skipped. Fix: `{ [ -z "$item_id" ] || [ "$item_id" = "null" ]; } && continue`. Source: backlog PR review W3.
2. **Fix recommendation H renumbering (32 -> H) in `retro-recommendations.md`.** Source: S06 review W1, PR review S3.
3. **Validate Sonnet reviewer quality on easy stories in the next run.** This run implemented reviewer routing but could not use it (agents loaded at session start). The next run will be the first to dispatch `reviewer-sonnet` for easy stories. Monitor for false negatives (issues Sonnet misses that Opus would catch). Source: design doc assumption 2.
4. **Monitor orchestrator.md size.** Now at 1270 lines (6.4x the 200-line guideline) after this run added +185 lines. The state schema (~200 lines), board management examples, and code snippets are the primary contributors. Consider extracting to a reference doc if it grows past 1500 lines. Source: observation v, PR review W2.

### Existing (updated with new data)

- **Rec G (Track autonomous lifecycle duration baseline):** This run data: ~1h 54m wall clock, 6 stories, 1 epic. Updated baseline: Run 5 ~30m (5 stories), Run 12 ~23m (5 stories), Run 13 ~25m (6 stories), Run 14 ~77m (12 stories), Run 15 (backlog 105) ~114m (6 stories but includes design+plan+PR review, self-referential convention work). Not directly comparable to content-creation runs due to different workload type.
- **Observation ii (Zero organic fix cycles):** Extended to 46+ consecutive first-pass approvals (6 more from this run). This run is the first to include self-referential convention changes (not just content creation), broadening the evidence base.
- **Observation v (orchestrator.md size):** Updated from ~1000 lines to 1270 lines after this run.
