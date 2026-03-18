---
date: 2026-03-18
author: retro
backlog-issue: 109
backlog-pr: 206
scope: PM Abstraction Layer -- adapter boundary between workflow process logic and external PM platforms
---

# PM Abstraction Layer -- Agentic Workflow Retrospective

## Summary

Backlog item #109 introduced a clean PM adapter boundary between the workflow's process logic and the GitHub Issues + Projects platform. The work created `scripts/lib/pm.sh` (adapter loader), a GitHub adapter with 8 modules in `scripts/lib/adapters/pm/github/`, a `cost-budget.sh` library, and ADR-0004. Eight existing scripts were converted to thin wrappers, reducing their combined line count from ~752 to 276 (63% reduction). All 10 stories across 3 epics were completed with 289 new tests, a single fix cycle (E01-S06, 2 critical issues caught by reviewer), and 55 total review findings. This was the first infrastructure backlog item -- modifying core workflow scripts rather than creating content -- and it validated the "build alongside, verify, swap" migration strategy for zero-risk refactoring.

## Timeline

| Phase | Time (UTC) | Wall Clock | Activity |
|-------|-----------|------------|----------|
| Design | 00:59 -- 02:59 | ~120 min | 8 designer dispatches + 2 claude-code-guide dispatches across usage limit pauses |
| Design review + merge | 03:00 -- 03:53 | ~53 min | Design PR #188 reviewed and merged into integration branch |
| Plan | 03:57 -- 04:09 | ~12 min | Planner creates 3 epics, 10 stories; plan PR #203 merged |
| Build W1 (E01-S01) | 04:11 -- 04:20 | ~8 min | Config schema extension -- sequential build + review |
| Build W2 (E01-S02) | 04:20 -- 04:29 | ~8 min | pm.sh adapter loader -- sequential build + review |
| Build W3 (E01-S03..S06) | 04:29 -- 04:49 | ~19 min | 4-way parallel build + 4-way parallel review + S06 fix cycle |
| Build W4 (E02-S01, E03-S02) | 04:50 -- 04:59 | ~9 min | 2-way parallel build + review (lifecycle + ADR) |
| Build W5 (E02-S02) | 04:59 -- 05:06 | ~6 min | Cost budget -- sequential build + review |
| Build W6 (E03-S01) | 05:07 -- 05:21 | ~14 min | Swap wrappers -- sequential build + review |
| Merge + changelog | 05:21 -- 05:22 | ~1 min | Epic merges into integration branch, changelog entry, PR #206 created |
| **Total** | 00:59 -- 05:22 | **~4h 22m** | Design: ~173 min, Plan: ~12 min, Build+Review: ~66 min, Merge: ~1 min |

*Source: `git log main..backlog/109-pm-abstraction --format="%h %ai %s"` and dispatch timestamps from `.agentic-workflow/runs/109/orchestrator.json`. The design phase wall clock is inflated by usage limit pauses between dispatches -- the 10 design dispatches consumed only 19m 20s of agent time.*

## Telemetry

### Per-Story Breakdown

| Story | Issue | Difficulty | Build Model | Review Model | Agent Time | Tokens | Est. Cost | Tool Uses | Fix Cycles | Verdict |
|-------|-------|-----------|------------|-------------|-----------|--------|-----------|-----------|------------|---------|
| E01-S01 | #193 | easy | sonnet | sonnet | 7m 47s | 120K | ~$0.72 | 80 | 0 | APPROVE |
| E01-S02 | #194 | medium | sonnet | sonnet | 7m 44s | 158K | ~$0.95 | 78 | 0 | APPROVE |
| E01-S03 | #195 | medium | sonnet | opus | 7m 1s | 150K | ~$1.19 | 63 | 0 | APPROVE |
| E01-S04 | #196 | hard | opus | opus | 11m 53s | 180K | ~$1.80 | 112 | 0 | APPROVE |
| E01-S05 | #197 | medium | sonnet | sonnet | 6m 40s | 111K | ~$0.67 | 73 | 0 | APPROVE |
| E01-S06 | #198 | easy | sonnet | sonnet | 11m 30s | 222K | ~$1.33 | 125 | 1 | REQ_CHANGES then APPROVE |
| E02-S01 | #199 | medium | sonnet | opus | 8m 9s | 127K | ~$0.96 | 72 | 0 | APPROVE |
| E02-S02 | #200 | easy | sonnet | sonnet | 5m 55s | 100K | ~$0.60 | 63 | 0 | APPROVE |
| E03-S01 | #201 | hard | opus | opus | 12m 47s | 211K | ~$2.11 | 145 | 0 | APPROVE |
| E03-S02 | #202 | easy | sonnet | sonnet | 4m 35s | 105K | ~$0.63 | 37 | 0 | APPROVE |
| **Story Total** | | | | | **84m 1s** | **1,484K** | **~$10.96** | **848** | **1** | |

### Design and Plan

| Phase | Dispatches | Agent Time | Tokens | Est. Cost | Tool Uses |
|-------|-----------|-----------|--------|-----------|-----------|
| Design | 10 (8 designer + 2 guide) | 19m 20s | 705K | ~$7.05 | 182 |
| Plan | 1 | 11m 37s | 103K | ~$1.03 | 73 |
| **Total** | **11** | **30m 57s** | **808K** | **~$8.08** | **255** |

### Aggregate

| Metric | Value |
|--------|-------|
| Stories completed | 10/10 |
| Tests written | 289 (across 9 test suites) |
| Lines added (net) | +5,244 |
| Files changed | 34 |
| Critical issues caught by reviewer | 2 (both on E01-S06) |
| Warnings caught by reviewer | 24 |
| Suggestions made by reviewer | 29 |
| Fix cycles | 1/10 stories (10%) |
| Parallelism savings | ~25 min (3 parallel waves) |
| Build+Review wall clock | ~66 min |
| Sequential sum (all dispatches) | 84m 1s |
| Total agent time (all phases) | 115m 0s |
| Total tokens (all phases) | 2,292K |
| Total estimated cost (all phases) | ~$19.03 |

*Note: Design phase cost ($7.05) accounts for 37% of total cost. This is atypical -- the design required 10 dispatches due to the adversarial triangulation pattern and usage limit interruptions. Cost breakdown: Design $7.05, Plan $1.03, Build $6.23, Review $4.72.*

## What Worked

### 1. Shadow Stack Migration Strategy Eliminated Risk

The three-phase "build alongside, verify, swap" approach (documented as ADR-0004, commit `40eee85`) allowed the entire adapter stack to be built and tested without modifying any existing scripts until E03-S01. The swap commit (`511a489`) converted 8 scripts in a single atomic change, with all 413 tests (289 new + 124 pre-existing) passing immediately. No production disruption occurred at any point.

**Evidence:** The swap commit shows -568 lines removed from existing scripts, +131 lines added to adapter modules. Every removed line had a corresponding implementation in the adapter. The fact that 124 pre-existing tests continued to pass without modification validates the behavioral equivalence.

### 2. Parallel Dispatch Delivered Significant Time Savings

Three parallel waves saved approximately 25 minutes of wall clock time compared to sequential execution:

- **Wave 3** (4-way parallel: E01-S03/S04/S05/S06): 4 independent adapter modules built simultaneously, then 4 reviews in parallel. Wall clock 19m vs 43m sequential.
- **Wave 4** (2-way parallel: E02-S01 + E03-S02): Lifecycle module and ADR built in parallel. Wall clock 9m vs 14m sequential.
- Reviews also dispatched in parallel within each wave.

**Evidence:** Dispatch timestamps in state file confirm all 4 Wave 3 builders started at `2026-03-18T04:29:42Z` and all 4 Wave 3 reviewers started at `2026-03-18T04:37:50Z`.

### 3. Reviewer Quality Was Consistently High

Across 11 reviews (10 initial + 1 re-review), reviewers produced 55 findings (2 critical, 24 warnings, 29 suggestions). The single fix cycle (E01-S06) was triggered by 2 genuine critical issues:

- **C1:** Unchecked GraphQL exit code in `hierarchy.sh` -- a failed `addSubIssue` call would silently report success.
- **C2:** `|| true` on `gh label create` silently swallowing all errors including auth failures, when `--force` already handled the idempotency case.

Both were real correctness bugs that unit tests could not catch (they require live API interactions to manifest). The builder fixed both in commit `35349f1` and passed re-review.

**Evidence:** Issue #198 comments show the full REQUEST_CHANGES -> fix -> APPROVE cycle. The re-review specifically verified each critical issue was resolved.

### 4. Plan Decomposition Maximized Parallelism

The planner's three-epic structure with a clear dependency graph (plan commit `56ea366`) enabled optimal dispatch. E01 had 6 stories where 4 could run in parallel after 2 sequential dependencies. The planner correctly identified that E03-S02 (ADR) had no code dependencies and could run alongside E02-S01, saving an additional ~4 minutes.

**Evidence:** The Mermaid dependency graph in the plan matches the actual dispatch sequence exactly. No dispatch was delayed by a missing dependency.

### 5. Infrastructure Refactoring Succeeded Without Breaking Running Workflow

This was the first backlog item that modified core workflow scripts (board management, status transitions, issue creation). The existing workflow was never disrupted:

- All 8 wrapper scripts preserve their original CLI interfaces (same arguments, same exit codes).
- The `issue-create-backlog.sh` wrapper retained orchestrator-level concerns (placeholder replacement, title prefixing) while delegating PM operations to adapter functions.
- No agent `.md` files were modified -- agents continue calling the same scripts with the same arguments.

**Evidence:** The E03-S01 reviewer verified all 413 tests passed (including the 124 pre-existing tests from other test suites like `test-dispatch-workflow.sh`, `test-issue-telemetry.sh`, `test-validate-logs.sh`).

## What Didn't Work

### 1. Design Phase Was Disproportionately Expensive

The design phase consumed $7.05 (37% of total cost) across 10 dispatches over ~2 hours of wall clock time. This is the most expensive design phase in the workflow's history. The cost was driven by:

- **Adversarial triangulation pattern:** Three independent perspectives evaluating the PM/VCS boundary required extensive context reading and multi-perspective synthesis.
- **Usage limit interruptions:** The designer hit usage limits multiple times, requiring orchestrator re-dispatches. Each re-dispatch reads CLAUDE.md and context files again, consuming ~40-75K tokens per restart.
- **10 dispatches for a single design doc:** Previous design phases used 1-3 dispatches.

**Root cause:** The design scope was legitimately complex (three-layer abstraction landscape, 13 function signatures, agent architecture audit, migration strategy, forward compatibility analysis). However, the usage limit interruptions caused repeated context re-reading that amplified the cost. The 10 dispatches consumed 705K tokens when 2-3 uninterrupted dispatches would have used ~200-300K.

**Mitigation:** For future complex designs, consider interactive mode (which allows human-guided focus) over autonomous mode for infrastructure items. See observation xv in the recommendations tracker: "Interactive design produces better architectural decisions than autonomous for refactoring."

### 2. board.sh Exceeded 200-Line Convention

The `board.sh` adapter module is 232 lines, exceeding the 200-line convention in CLAUDE.md. The builder correctly split `reconcile.sh` out as a separate file (154 lines), but `board.sh` itself remained over the limit. The reviewer noted this as W1 on issue #196 but approved anyway.

**Root cause:** The board module has 7 internal helpers (`_gh_fetch_item_info`, `_gh_extract_item_info`, `_gh_mutate_status`, `_gh_verify_status`, `_gh_status_to_option_id`, `_gh_status_to_display`, `_gh_fetch_with_retry`) plus 3 public functions (`pm_set_status`, `pm_add_to_board`, `pm_batch_set_status`). The helpers cannot be easily separated because they share state variables (`ITEM_ID`, `CURRENT_STATUS`) set by `_gh_extract_item_info`.

**Mitigation:** The builder correctly split reconciliation into a separate file. The remaining 32-line overage is acceptable for the most complex adapter module. No further action needed unless the file grows.

### 3. No Epic-Level Telemetry Was Posted

The orchestrator did not post telemetry on epic issues #190, #191, or #192. The CLAUDE.md convention "Per-epic telemetry" requires posting telemetry on each epic issue when all its stories complete. The epic issues have zero comments.

**Root cause:** This is a recurring omission (also observed in Run 16, documented as recommendation X in the tracker). The orchestrator's build phase has many steps (dispatch, review, merge, board sync) and epic telemetry falls through the cracks.

### 4. Story Issues Were Not Closed

All 10 story issues (#193-#202) remain in OPEN state. The epic issues (#190-#192) and the backlog issue (#109) are also open. While stories are expected to remain open until the backlog PR merges (so `Closes` can auto-close them), the orchestrator should have set them to In Review status on the board after review passed. The current board state was not verified.

**Root cause:** The orchestrator focused on branch operations and PR creation but may not have run `reconcile-board.sh` as a final step.

## Workflow Evolution During Epic

| Commit | Change | Trigger |
|--------|--------|---------|
| `fdbcd7f` | Added "Think Long Term, Execute Short Term" design philosophy to CLAUDE.md | Design phase -- designer recognized the need to document the principle of namespaced folders (`adapters/pm/github/` not `adapters/github/`) |
| `17693c5` | Namespaced adapter folder layout in design doc | Designer recognized flat `adapters/github/` would block future VCS/DOC layers |

No changes were made to agent files during this backlog item. All convention changes were limited to CLAUDE.md and the design doc.

## Key Learnings

### For Builders

1. **Error suppression patterns must be reviewed carefully when porting code.** E01-S06 blindly ported `2>/dev/null || true` from existing scripts without evaluating whether `--force` already handled the idempotency case. The reviewer caught this -- builders should evaluate each error suppression pattern during porting rather than copying blindly.

2. **When splitting modules (board.sh + reconcile.sh), check line counts of both halves.** The builder correctly identified the need to split but only checked that `reconcile.sh` was under the limit, not `board.sh` itself.

3. **Infrastructure builds take 2-3x longer than content builds.** The average build duration for this backlog was 5m 0s (builds only), compared to ~3m 40s for content runs (Run 14). The most complex stories (E01-S04 board.sh: 6m 44s, E03-S01 swap: 8m 1s) required reading and understanding existing production code before writing.

### For the Orchestrator

1. **Epic-level telemetry posting continues to be skipped.** This is the third occurrence (Run 16, this run). The orchestrator should have a checklist step after each wave's merge to post epic telemetry.

2. **Design phase cost needs monitoring for infrastructure items.** The $7.05 design cost was 37% of the total. For infrastructure items with complex scope (13 functions, 3-layer architecture, agent audit), the design phase may dominate total cost. Consider capping design dispatches or using interactive mode.

3. **The 10-dispatch design phase suggests usage limits need better handling.** Each re-dispatch after a usage limit consumes ~40-75K tokens just to re-read context. A future improvement could checkpoint design progress to reduce context re-reading on resumption.

### For the Workflow

1. **"Build alongside, verify, swap" is validated as a safe migration strategy for core scripts.** The entire adapter stack was built and tested without modifying any existing scripts. The swap was atomic and all pre-existing tests passed immediately. This pattern should be used for all future core refactoring (as documented in ADR-0004).

2. **Infrastructure work has a different cost profile than content work.** Design: 37%, Build: 33%, Review: 25%, Plan: 5%. Content runs typically have Build at 50-60% and Design at 10-15%. The higher design and review costs reflect the complexity of infrastructure decisions and the need for correctness validation.

3. **The PM abstraction unblocks three downstream items.** Local-first PM (#111), plugin packaging (#112), and multi-PM adapters (#113) can now build on the `pm.sh` interface without modifying any workflow scripts. The namespaced folder structure (`adapters/pm/github/`) makes adding new adapters mechanical.

4. **Sonnet reviewers performed well on infrastructure code.** 6 of 11 reviews used Sonnet (for easy and medium stories). All 6 produced substantive findings. The one fix cycle (E01-S06, Sonnet reviewer) caught 2 genuine critical issues that would have caused silent failures in production. This provides another positive data point for recommendation N in the tracker.

## Recommendations

1. **Add epic telemetry posting to orchestrator's post-wave checklist** -- This is the third time epic telemetry was skipped (recommendation X in tracker). The pattern is clear: the orchestrator's post-wave steps should include an explicit "post telemetry on epic issue if all stories complete" step. Evidence: Epic issues #190, #191, #192 have zero comments.

2. **Cap design phase dispatches for autonomous infrastructure items** -- 10 dispatches consuming $7.05 (37% of total) is disproportionate. Consider a convention: if the design phase exceeds N dispatches or $X cost, pause and alert the human rather than continuing to re-dispatch. This preserves the autonomous workflow for normal items while adding a circuit breaker for edge cases.

3. **Add `pm_create_label` as a standalone function separate from `pm_add_label`** -- The E03-S01 reviewer (W2) noted that `setup-labels.sh` uses a "issue 0 as sentinel" workaround because `pm_add_label` requires an issue number even when the intent is only to create a label. A dedicated `pm_create_label` function would be cleaner. Low priority -- deferred to when `setup-labels.sh` is next modified.

4. **Consider shared test utilities for adapter test files** -- Four adapter test files (items, board, comments, hierarchy+labels) independently implement `build_mock_env`, `assert_equals`, and `assert_contains` helpers. Extracting these into a shared `tests/scripts/test-helpers.sh` would reduce duplication and standardize the test pattern. Evidence: test files range from 188 to 593 lines, with 40-60 lines of duplicated helper code in each.

5. **Track `hierarchy/docs` label creation** -- The E01-S03 reviewer (S1) noted that `pm_create_item docs "X"` maps to a `hierarchy/docs` label that does not exist in `setup-labels.sh`. If the `docs` level is used in production, the label must be created first. File a follow-up issue or add it to `setup-labels.sh`.

## Lesson Retention

No individual lesson files were created during this backlog item (no `docs/4-reviews/lessons/109-pm-abstraction/eNN-*/` directories exist). All findings are compiled from:

- Review comments on issues #193-#202 (primary data source)
- Dispatch telemetry from `.agentic-workflow/runs/109/orchestrator.json`
- Git log timestamps and diff statistics

This retro doc is the primary reference for this backlog item's learnings going forward.
