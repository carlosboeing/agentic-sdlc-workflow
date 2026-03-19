---
date: 2026-03-09
author: retro
backlog-issue: 57
epic-pr: 70
scope: End-to-end test of Agentic SDLC v2 — 9 stories, 2 epics, creative writing tasks
---

# Test SDLC v2 Pipeline — Agentic Workflow Retrospective

## Summary

The Test SDLC v2 Pipeline was the first end-to-end execution of the v2 agentic workflow (automated orchestrator dispatch, model routing, telemetry, board status management). Nine creative writing stories across two epics (Poetry Collection and Sci-Fi Story) were executed in three sequential waves. All 9 stories completed successfully with correct model routing (4 haiku, 4 sonnet, 1 opus), producing 9 markdown files in `test-output/`. The test revealed two critical CLI dispatch limitations — the unsupported `--max-turns` flag and the nested Claude Code session block — which forced a fallback from parallel CLI dispatch to sequential in-session execution. Total sequential time was approximately 13 minutes using 106K tokens at an estimated cost of $1.20.

## Timeline

| Phase | Time (UTC) | Wall Clock | Activity |
|-------|-----------|------------|----------|
| Setup | 10:32 – 10:33 | ~1 min | Backlog #57, epic issues #58/#59, story issues #60-#68 created |
| CLI dispatch attempt | 10:58 | ~0 min | 5 Wave 1 stories dispatched via `dispatch-story.sh`; all failed (`--max-turns` flag) |
| Script fix | 10:57 – 10:58 | ~1 min | Removed `--max-turns` from `dispatch-story.sh` (commit `d33c03d`) |
| CLI dispatch attempt 2 | 10:58 | ~0 min | Re-dispatch failed — nested Claude Code session block |
| Sequential fallback | 11:00 – 11:05 | ~5 min | Wave 1: E01-S01, E01-S02, E01-S03, E02-S01, E02-S02 executed sequentially |
| Wave 2 | 11:06 – 11:12 | ~6 min | E01-S04, E02-S03, E02-S04 executed sequentially |
| Wave 3 | 11:13 – 11:15 | ~2 min | E02-S05 executed |
| Wrap-up | 11:15 – 11:17 | ~2 min | CHANGELOG, lesson files, epic telemetry, PR #70 opened |
| **Total** | **10:32 – 11:17** | **~45 min** | Setup through PR (13 min agent time) |

*Source: git log timestamps (UTC+10 converted to UTC) and GitHub issue comment timestamps.*

## Telemetry

### Per-Story Breakdown

| Story | Issue | Difficulty | Model Used | Agent Time | Tokens | Cost | Tool Uses |
|-------|-------|-----------|------------|-----------|--------|------|-----------|
| E01-S01 | #60 | easy | haiku | 53s | 5K | ~$0.02 | 8 |
| E01-S02 | #61 | easy | haiku | 58s | 6K | ~$0.03 | 8 |
| E01-S03 | #62 | medium | sonnet | 1m 10s | 12K | ~$0.07 | 10 |
| E01-S04 | #63 | medium | sonnet | 59s | 15K | ~$0.09 | 10 |
| E02-S01 | #64 | easy | haiku | 1m 7s | 8K | ~$0.04 | 8 |
| E02-S02 | #65 | easy | haiku | 1m 8s | 8K | ~$0.04 | 8 |
| E02-S03 | #66 | medium | sonnet | 1m 50s | 15K | ~$0.09 | 10 |
| E02-S04 | #67 | hard | opus | 3m 9s | 25K | ~$0.75 | 12 |
| E02-S05 | #68 | medium | sonnet | 1m 52s | 12K | ~$0.07 | 10 |
| **Epic Total** | | | | **13m 6s** | **106K** | **~$1.20** | **84** |

*All 9 stories have complete telemetry: Work Started, Ready for Review, and Telemetry comments posted on every story issue. This is a significant improvement over the Calendar Tool build where E01/E02 telemetry was incomplete.*

### Aggregate

| Metric | Value |
|--------|-------|
| Stories completed | 9/9 |
| Tests written | 0 (creative writing, no code) |
| Critical bugs caught by reviewer | 0 (reviewer not dispatched) |
| Warnings caught by reviewer | 0 (reviewer not dispatched) |
| CLI dispatch failures | 2 (all Wave 1, both resolved) |
| Infrastructure fixes committed | 1 (`dispatch-story.sh` `--max-turns` removal) |
| Lesson files captured | 2 |

### Cost by Model Tier

| Model | Stories | Tokens | Cost | Avg Cost/Story |
|-------|---------|--------|------|----------------|
| haiku | 4 | 27K | ~$0.13 | ~$0.03 |
| sonnet | 4 | 54K | ~$0.32 | ~$0.08 |
| opus | 1 | 25K | ~$0.75 | ~$0.75 |
| **Total** | **9** | **106K** | **~$1.20** | **~$0.13** |

Model routing worked correctly: easy stories used haiku ($0.03 avg), medium used sonnet ($0.08 avg), hard used opus ($0.75). This validates the difficulty-to-model mapping and demonstrates the cost savings from proper routing — the opus story consumed 62.5% of total cost for just 11% of stories.

### Parallelism Analysis

| Metric | Value |
|--------|-------|
| Sequential agent time | 13m 6s |
| Wall-clock time | 13m 6s |
| Parallelism speedup | 1.0x (no parallelism achieved) |
| Theoretical wall-clock (with parallelism) | ~6m 10s |
| Theoretical speedup | ~2.1x |

*Wave 1 (5 stories) would have taken ~1m 10s wall-clock (longest story) instead of ~5m 16s sequential. Wave 2 (3 stories) would have taken ~3m 9s instead of ~5m 58s. Wave 3 is a single story. Theoretical minimum: ~1m 10s + ~3m 9s + ~1m 52s = ~6m 10s.*

## What Worked

### 1. Model Routing Applied Correctly from the Start

Unlike the Calendar Tool build where model routing was only applied from E03 onwards (all E01/E02 stories ran on opus), this test pipeline executed correct routing from the first story. Every `difficulty/easy` story used haiku, `difficulty/medium` used sonnet, and `difficulty/hard` used opus. This was a direct result of the Calendar retro recommendation (#6: "Ensure all future dispatches respect difficulty labels from the first story") being codified into the orchestrator agent conventions.

Evidence: All 9 telemetry comments show correct model assignments. The 4 haiku stories averaged $0.03 each vs $0.75 for the single opus story — a 25x cost differential that justifies model routing.

### 2. Complete Telemetry on Every Story

All 9 stories received the full triple-comment set: Work Started, Ready for Review, and Telemetry. This is a marked improvement over the Calendar build where E01/E02 stories had incomplete telemetry (missing tokens, cost, tool uses) and parallel dispatch telemetry showed 0s durations.

Evidence: Compare issues #60-#68 (all complete) to Calendar issues #26-#30 where 3 stories show "0m 0s (0 ms)" duration and zero token/cost data.

### 3. Immediate Lesson Capture

When the `--max-turns` flag failure and nested session block occurred, the orchestrator immediately created lesson files (`2026-03-09-s00-max-turns-flag-removed.md` and `2026-03-09-s00-nested-claude-sessions.md`) before continuing with the fallback approach. This demonstrates the lesson system working as designed — lessons are captured at the point of discovery, not deferred to the end.

Evidence: Commit `d33c03d` (fix) and `c25c50f` (lesson files) were committed during the epic, not after.

### 4. Consistent Issue Lifecycle

Every story progressed through the full lifecycle: Todo -> In Progress (via `item-start.sh`) -> In Review (via `item-review.sh`) with telemetry posted. The helper scripts (`item-start.sh`, `item-review.sh`, `item-telemetry.sh`) continue to be reliable workflow anchors.

### 5. Creative Writing as Workflow Test

Using creative writing tasks instead of code was an effective test design choice. It isolated the workflow mechanics (dispatch, telemetry, board management, branching) from code-specific concerns (compilation, testing, DI wiring). This made failures clearly attributable to the workflow infrastructure rather than implementation complexity.

## What Didn't Work

### 1. CLI Dispatch Is Not Viable from Within Claude Code Sessions

Both `dispatch-story.sh` failures stem from the same architectural constraint: `claude -p` cannot be invoked as a subprocess of a running Claude Code session.

**Failure 1 — `--max-turns` flag (commit `d33c03d`):** All 5 Wave 1 dispatches failed immediately because `dispatch-story.sh` included `--max-turns 100`, a flag that does not exist in the Claude Code CLI. The script's own preflight check caught this with a clear error message, which is good design — the fix was straightforward flag removal.

**Failure 2 — Nested session detection:** After the flag fix, all 5 re-dispatches failed because `claude -p` detects the `CLAUDECODE` environment variable and refuses to start inside another Claude Code session. This is a platform-level constraint, not a script bug.

**Root cause:** CLAUDE.md documents CLI dispatch as the "secondary" dispatch method and the Agent tool as "primary," but the orchestrator attempted CLI dispatch first. The CLAUDE.md convention is correct but the orchestrator's execution path did not follow it.

**Impact:** All 9 stories were executed sequentially instead of in the planned 3-wave parallel execution. Wall-clock time was 13m 6s instead of an estimated 6m 10s — a 2.1x penalty.

### 2. Reviewer Was Not Dispatched

The SDLC v2 dispatch protocol requires reviewer dispatch on each story branch (step 6) and on the epic PR (step 10). Neither was done in this test run. PR #70 notes describe this as intentional (creative writing, no code to review), but the protocol does not have a skip condition for non-code stories.

**Impact:** The test did not validate the reviewer dispatch step, the critical-findings re-dispatch loop, or the reviewer's integration with the board status workflow.

### 3. Epic Telemetry Shows Inflated Cost Estimate

The epic telemetry posted on issues #58 and #59 (and PR #70) shows `~$3.18` estimated cost, but the per-story breakdown in the same comment totals to `~$1.20`. The discrepancy appears to be caused by the `item-telemetry.sh` script computing cost from the `--model opus` flag (the highest-tier model in the epic) applied to all 106K tokens, rather than using the per-story model assignments.

**Evidence:** 106K tokens at opus rates (~$30/MTok) = ~$3.18. But actual cost was 27K haiku + 54K sonnet + 25K opus = ~$1.20. The breakdown table is correct; the summary cost is wrong.

**Root cause:** `item-telemetry.sh` takes a single `--model` flag for cost calculation. For epic-level telemetry with mixed models, this produces an incorrect total because it applies the single model's rate to all tokens.

### 4. Issues Not Closed After PR Opened

All 9 story issues, both epic issues (#58, #59), and the backlog issue (#57) remain open. PR #70 body includes `Closes #57, closes #58, closes #59` but: (a) the PR has not been merged yet, so auto-close has not fired; and (b) the story issues (#60-#68) are not listed in the PR `Closes` list and would need to be closed via `issue-merged.sh` or added to the PR body.

This is the same gap identified in the Calendar retro ("Issues Never Closed") — the v2 workflow added `auto-close-issues.yml` and enhanced `issue-merged.sh`, but neither fires until the PR is actually merged.

### 5. No Parallel Execution Achieved

The test was designed to validate parallel dispatch across 3 waves (5 + 3 + 1 stories). Due to the CLI dispatch failures and the Agent tool not being available in the session configuration, all stories ran sequentially. The planned parallelism test — measuring wall-clock speedup vs sequential time — could not be validated.

**Impact:** The `--wall-clock` vs `--duration` telemetry comparison is meaningless (both are 13m 6s). The theoretical 2.1x speedup remains unvalidated.

## Workflow Evolution During Epic

| Commit | Change | Trigger |
|--------|--------|---------|
| `d33c03d` | Removed `--max-turns` flag from `dispatch-story.sh` preflight check and invocation | CLI does not support `--max-turns`; all 5 Wave 1 dispatches failed |

This was the only convention/infrastructure change during the epic. No changes were made to CLAUDE.md or agent files.

## Key Learnings

### For Builders

1. Creative writing stories (no code, no tests) complete significantly faster than code stories. Average time was 1m 27s vs 4-6 minutes for Calendar code stories. The absence of test cycles and compilation is the primary factor.
2. Haiku-tier models are sufficient for simple structured content generation (haiku poems, limerick collections, character profiles, world-building docs). Quality was adequate for the acceptance criteria.

### For the Orchestrator

1. **CLI dispatch is out-of-session only.** The `dispatch-story.sh` script cannot be invoked from within a Claude Code session due to nested session detection. The orchestrator must use the Agent tool with `subagent_type` for in-session dispatch. This is already documented in CLAUDE.md but the test confirmed it empirically.
2. **Epic-level cost estimates with mixed models are inaccurate.** The `item-telemetry.sh` script applies a single model rate to all tokens. For mixed-model epics, the per-story breakdown is accurate but the summary cost is inflated (in this case, $3.18 reported vs $1.20 actual — a 2.65x overestimate).
3. **Story issues need explicit `Closes` references.** The PR body only references the epic and backlog issues. The 9 story issues will remain open unless manually closed or added to the PR body.

### For the Workflow

1. **The Agent tool is the correct primary dispatch path.** CLI dispatch is a useful fallback for out-of-session test scenarios (standalone terminal invocation) but cannot support in-session parallel dispatch. Future orchestrator tests should verify Agent tool dispatch.
2. **Reviewer dispatch should be explicitly required or explicitly skipped.** The protocol has no mechanism for the orchestrator to document why a step was skipped. A skip needs to be a deliberate, recorded decision — not a silent omission.
3. **Telemetry scripts need mixed-model cost support.** The `item-telemetry.sh` script should either accept per-story cost overrides or compute cost from the breakdown table rather than applying a single model rate.
4. **The test validated 6 of 8 checklist items.** Parallel dispatch and reviewer dispatch were not tested. A follow-up test with Agent tool dispatch is needed to validate those two items.

## Recommendations

1. **Add `--cost` override to `item-telemetry.sh`** — Allow manual cost override for mixed-model epics where the single-model calculation is inaccurate. Evidence: epic telemetry on #58/#59/#70 shows $3.18 vs actual $1.20. (proposed)
2. **Add "reviewer skip" convention** — When reviewer dispatch is intentionally skipped (e.g., non-code stories), the orchestrator must post a comment on the story issue explaining why. This prevents silent protocol violations. Evidence: all 9 stories in this epic have no reviewer dispatch and no explanation. (proposed)
3. **Clarify CLI dispatch scope in CLAUDE.md** — Add an explicit note under the CLI dispatch section: "CLI dispatch (`dispatch-story.sh`) cannot be invoked from within a Claude Code session due to nested session detection. Use this only from a standalone terminal." Evidence: lesson file `2026-03-09-s00-nested-claude-sessions.md`. (proposed)
4. **Add story issues to epic PR `Closes` list** — Convention should require that the epic PR body includes `Closes #NN` for all story issues, not just epic issues. Otherwise stories remain open after merge. Evidence: issues #60-#68 will not auto-close when PR #70 merges. (proposed)
5. **Run a follow-up test with Agent tool dispatch** — The two untested items (parallel dispatch speedup, reviewer integration) require the Agent tool to be available. A targeted test with 3-5 stories using in-session dispatch would complete the validation. (not proposed as convention change — needs orchestrator action)
6. **Add `test-output/` to `.gitignore`** — The 9 test files in `test-output/` are not production artifacts and should not persist in the repository after validation. (not proposed — one-time cleanup)

## Lesson Retention

| Lesson File | Status | Absorbed Into |
|-------------|--------|---------------|
| `2026-03-09-s00-max-turns-flag-removed.md` | Compiled | Fixed in commit `d33c03d`; no convention change needed (flag already removed) |
| `2026-03-09-s00-nested-claude-sessions.md` | Proposed | Recommendation #3 (clarify CLI dispatch scope) |

Both lesson files remain on disk in `docs/4-reviews/lessons/2026-03-09-test-agentic-sdlc-run01-sdlc-v2/e01-test-poetry/` for traceability. This retro doc is now the primary reference for this epic's learnings.
