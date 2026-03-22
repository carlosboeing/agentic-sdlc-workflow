---
date: 2026-03-19
author: carlosboeing
agent: retro
backlog-issue: 242
backlog-pr: 255
scope: Fix Gantt chart story code regression and add work timeline mode with gap annotations and stalled dispatch detection
---

# Gantt Chart Readability -- Agentic Workflow Retrospective

## Summary

This backlog item fixed two compounding Gantt chart readability problems in `scripts/lib/compute-dispatches.py`: (1) a story code regression where Gantt labels and breakdown table rows lost their `ENN-SNN` prefixes, and (2) a timeline distortion problem where session interruptions (API errors, usage limits) compressed real work into unreadable chart slivers. The solution added a Story column to the breakdown table, implemented a cumulative-active-time "Work Timeline" Gantt mode as the new default (retaining wall-clock as `--gantt-mode wall-clock`), added gap annotation generation, and added stalled dispatch detection. Across 2 epics and 5 stories, 18 dispatches produced 110+ new Python tests (252 total) and 31 commits. Two fix cycles occurred: E01-S01 (template scope creep) and E02-S03 (stalled note inside Mermaid fence + None guards).

## Timeline

| Phase | Time (UTC) | Wall Clock | Activity |
|-------|-----------|------------|----------|
| Setup | 02:17:12 -- 02:17:34 | ~0m 22s | Session init, state file, pricing fetch |
| Design | 02:17:34 -- 02:23:51 | ~6m 17s | Designer dispatch (opus, 102K tokens) |
| Plan | 02:25:27 -- 02:35:26 | ~9m 59s | Planner dispatch (opus, 116K tokens, 5 stories + 2 epics) |
| Branch setup | 02:35:26 -- 02:38:32 | ~3m 6s | Epic/story branches, board transitions |
| Wave 1 build | 02:38:32 -- 02:42:48 | ~4m 16s | E01-S01 build (sonnet) |
| Wave 1 review + fix | 02:43:37 -- 02:52:23 | ~8m 46s | Review (REQUEST_CHANGES) -> fix -> re-review (APPROVE) |
| Merge E01-S01 + Wave 2 setup | 02:52:23 -- 02:53:32 | ~1m 9s | Merge into epic, branch prep |
| Wave 2 build | 02:53:32 -- 03:06:42 | ~13m 10s | E01-S02 + E02-S01 parallel (critical path: E01-S02 at 13m 10s) |
| Wave 2 review | 03:07:46 -- 03:12:02 | ~4m 16s | E01-S02 + E02-S01 parallel reviews (both APPROVE) |
| Merge Wave 2 + Wave 3 setup | 03:12:02 -- 03:14:01 | ~1m 59s | Merge stories, prep Wave 3 branches |
| Wave 3 build | 03:14:01 -- 03:29:16 | ~15m 15s | E02-S02 + E02-S03 parallel (critical path: E02-S02 at 15m 15s) |
| Wave 3 review + fix cycles | 03:30:19 -- 03:50:50 | ~20m 31s | E02-S02 APPROVE, E02-S03 REQUEST_CHANGES -> fix -> APPROVE -> fix2 |
| Merge conflicts + changelog | 03:50:50 -- 03:58:05 | ~7m 15s | E02-S03/E02-S02 merge, E02 into integration, changelog |
| **Total** | 02:17:12 -- 03:58:05 | **~1h 41m** | 18 dispatches, 31 commits |

*Source: `git log main..backlog/242-gantt-readability --format="%h %ai %s"` and orchestrator state file `.agentic-workflow/runs/242/orchestrator.json`.*

## Telemetry

### Per-Story Breakdown

| Story | Issue | Difficulty | Model Used | Agent Time | Tokens | Est. Cost | Tool Uses | Fix Cycles |
|-------|-------|-----------|------------|-----------|--------|-----------|-----------|------------|
| E01-S01 | #249 | medium | sonnet (build) / opus (review) | 12m 19s | 297K | ~$2.43 | 119 | 1 (template scope creep) |
| E01-S02 | #250 | easy | sonnet (build) / opus (review) | 17m 27s | 210K | ~$1.56 | 139 | 0 |
| E02-S01 | #251 | medium | sonnet (build) / opus (review) | 11m 2s | 184K | ~$1.40 | 89 | 0 |
| E02-S02 | #252 | easy | sonnet (build) / opus (review) | 19m 39s | 140K | ~$1.13 | 156 | 0 |
| E02-S03 | #253 | easy | sonnet (build) / opus (review) | 24m 19s | 392K | ~$2.94 | 212 | 1 (stalled note placement + None guards) |
| **Story Total** | | | | **84m 46s** | **1,223K** | **~$9.46** | **715** | **2** |

### Non-Story Dispatches

| Dispatch | Issue | Agent | Duration | Tokens | Est. Cost | Tool Uses |
|----------|-------|-------|----------|--------|-----------|-----------|
| Design | #244 | opus | 6m 17s | 102K | ~$1.03 | 41 |
| Plan | #246 | opus | 9m 59s | 116K | ~$1.16 | 64 |
| Merge conflicts | #248 | sonnet | 4m 18s | 53K | ~$0.32 | 51 |
| **Non-Story Total** | | | **20m 34s** | **271K** | **~$2.51** | **156** |

### Aggregate

| Metric | Value |
|--------|-------|
| Stories completed | 5/5 |
| Tests written | 110+ new (252 total Python, 44 shell) |
| Fix cycles triggered | 2 (E01-S01, E02-S03) |
| Fix cycle rate | 2/5 stories (40%) |
| Fix cycle cost | ~$2.57 (22% of total) |
| Critical issues caught by reviewer | 3 (C1 on E01-S01, C1 on E02-S03 initial, W1 on E02-S03) |
| Warnings caught by reviewer | 6 across all stories |
| Total dispatches | 18 |
| Sequential agent time | 105m 23s |
| Critical path (with parallelism) | 83m 41s |
| Parallel speedup | 1.3x (21m 41s saved) |
| Total tokens | 1.49M |
| Total estimated cost | ~$11.95 |

## What Worked

### 1. Cross-Epic Dependency Management Was Clean

The dependency graph had a cross-epic dependency (E02-S01 depends on E01-S01's `story_code` field). The planner correctly identified this and structured waves so E01-S01 completed before E02-S01 dispatched. Wave 2 dispatched E01-S02 and E02-S01 in parallel -- both depended only on E01-S01, not on each other. This maximized parallelism while respecting the cross-epic data dependency.

### 2. Reviewer Scope Enforcement Prevented Downstream Damage

The E01-S01 reviewer (dispatch 4) caught that the builder had modified `scripts/templates/telemetry.md` -- a file explicitly scoped to E01-S02's acceptance criteria. The reviewer correctly identified this as scope creep (C1), noted the 3 broken shell integration tests it caused (C2), and requested the change be reverted. The fix was a single-commit revert (`8039f37`). Without this catch, E01-S02 would have encountered a confusing "already done" situation for its template update task, potentially causing the builder to skip critical work or create merge conflicts.

### 3. Design Doc Root Cause Analysis Was Accurate

The design doc analyzed the story code regression as "not a regression but a gap that was never filled" for the breakdown table, and identified the Gantt label failure path as incomplete `state.epics` data. Both diagnoses proved correct: the builder implemented the `_build_story_labels()` integration into `state_to_dispatches()` and the fallback extraction mechanism exactly as designed. No mid-build design changes were needed.

### 4. Test-First Approach Produced High Test Coverage

All 5 stories followed TDD: tests committed before implementation (visible in commit pairs like `725b10a` / `4508e7f`, `6ddac37` / `680555c`, `ca3d993` / `c3091fc`). The 252 total Python tests provided regression coverage that made the merge conflict resolution safe -- after resolving conflicts, all tests passed, confirming the combined behavior was correct.

### 5. Work Timeline Algorithm Design Was Sound

The cumulative-active-time approach (Approach B from the design doc) worked as intended. The algorithm uses `max(duration_ms)` per wave as the offset increment, preserving parallel dispatch stacking while collapsing inter-wave gaps. The reverted commit's lesson (gap compression alone is insufficient; must also handle stalled dispatches) was directly addressed by making stalled detection a separate but coordinated feature.

## What Didn't Work

### 1. E02-S03 Required Two Fix Cycle Rounds (3 Dispatches)

E02-S03 (Stalled Dispatch Detection) consumed 5 dispatches total -- the most of any story. The initial review (dispatch 14) found C1 (stalled note appended inside Mermaid code fence, breaking chart rendering) and W1 (None values crash `_is_stalled()`). The builder fixed both and the re-review (dispatch 16) approved, but dispatch 17 was a second builder dispatch. The state file shows dispatches 15, 16, and 17 all on issue 253, suggesting the orchestrator dispatched an additional fix pass.

Root cause: The first fix (dispatch 15, commit `ba75e99`) resolved the review findings but the merged E02-S02 gap annotation code (commit `6555114`) required integration. The second builder pass (dispatch 17, 2m 31s) handled the post-merge integration -- a necessary step that should not count as a "fix cycle" in the quality sense.

### 2. Parallel Stories Both Modified `compute-dispatches.py`, Causing Merge Conflicts

E02-S02 (Gap Annotations) and E02-S03 (Stalled Detection) both modified `scripts/lib/compute-dispatches.py` -- the same module-level constants section, the same `generate_gantt()` function, and the same test file. When merging E02-S03 after E02-S02 was already in the epic branch (commit `6555114`), manual conflict resolution was needed for:

- Module-level constants (`_STALLED_THRESHOLD_TOKS` and `_GAP_THRESHOLD_S` coexisting)
- `gantt_note` generation (combining gap annotations from `generate_gantt_note()` and stalled annotations from `_build_stalled_note()` via a `gantt_note_parts` list)
- Test classes from both stories

This is a known anti-pattern (rec Q in the recommendations tracker: "Split large test files across stories in plans") but was unavoidable here because both features target the same function. The orchestrator handled it by dispatching a builder (dispatch 18 on issue 248) to resolve the merge conflicts, consuming 4m 18s and 53K tokens.

### 3. E01-S02 Took 13m for an "Easy" Story

E01-S02 (Fallback Story Code Extraction) was labeled `difficulty/easy` but consumed 13m 10s -- longer than E02-S01 (labeled `difficulty/medium` at 7m 16s). The throughput was low: 174 tok/s vs the typical 200-400 tok/s range for Sonnet. The high tool use count (91) suggests the builder spent significant time reading existing code to understand the `_build_story_labels()` function before implementing the fallback path. This aligns with observation xii (infrastructure refactoring takes 2-3x longer than greenfield).

### 4. Telemetry Breakdown Shows Empty Story Column

The backlog-level telemetry posted on issue 248 shows `--` in the Story column for all dispatches, despite the story code feature being the primary deliverable of E01. This is because the telemetry was posted by the orchestrator using `--dispatches-from-state`, and the state file's `epics.*.stories` section was empty (no story metadata was recorded by the orchestrator during dispatch). The `_build_story_labels()` function relies on this data, so the fallback extraction from issue 248's comment produced empty results. Ironic: the very feature built in this backlog item (story code fallback) was needed for its own telemetry but could not work because the state file lacked the required data.

## Workflow Evolution During Epic

| Commit | Change | Trigger |
|--------|--------|---------|
| `680555c` | CLAUDE.md helper scripts table updated with `--gantt-mode` flag | E02-S01 added `--gantt-mode` to `compute-dispatches.py` and `item-telemetry.sh` |

No other convention changes were made during this backlog item. The CLAUDE.md change was a propagation update (adding the new flag to the helper scripts table), not a convention change.

## Key Learnings

### For Builders

1. **Scope creep into sibling stories is caught by reviewers.** E01-S01's builder modified `telemetry.md` (E01-S02's scope), breaking 3 integration tests. The reviewer correctly flagged it as scope creep, and the fix was a clean revert. Builders should cross-check the "Files to modify" section in the story issue before committing template or infrastructure changes.

2. **Merge conflict resolution is a distinct skill from feature building.** Dispatch 18 (merge conflict resolution on issue 248) required understanding both E02-S02's gap annotation design and E02-S03's stalled detection design to correctly combine `gantt_note_parts`. The orchestrator handled this by dispatching a builder, which is the correct approach -- merge conflicts require human-like judgment about which code to keep.

3. **None guards on dict `.get()` need `or 0` pattern.** `d.get("key", 0)` returns `None` (not `0`) when the key exists but is explicitly `null` in JSON. The `or 0` pattern (`d.get("key") or 0`) handles both missing keys and null values. This was flagged as W1 on E02-S03.

### For the Orchestrator

1. **State file `epics.*.stories` must be populated for story code extraction to work.** The empty `stories` dict in the state file caused the breakdown table to show `--` instead of story codes in the backlog-level telemetry. The orchestrator should record story metadata (issue number, branch name, epic assignment) in the state file during Phase 4 (branch setup) so that `_build_story_labels()` and the fallback extraction can map dispatches to story codes.

2. **Merge conflict resolution dispatches should be tracked separately from story dispatches.** Dispatch 18 was recorded as `issue: 248` (the epic issue) because it was resolving E02 merge conflicts, not implementing a story. This is correct but makes the dispatch count (18) appear inflated compared to the actual story work (16 dispatches for 5 stories + design + plan).

### For the Workflow

1. **Parallel stories that modify the same file will always produce merge conflicts.** This backlog item confirmed rec Q: E02-S02 and E02-S03 both modified `compute-dispatches.py` and its test file. The conflict resolution was handled (dispatch 18, 4m 18s), but the planner could have avoided it by specifying non-overlapping insertion points or by making one story depend on the other. However, the dependency-free parallel dispatch saved ~6m 50s (E02-S03's build time), so the net effect was still positive: 4m 18s conflict resolution cost vs 6m 50s parallelism savings.

2. **The `generate_gantt()` return type constraint (always `str`) was a correct design decision.** The reverted commit from BL227 changed the return type to a tuple, requiring all callers to update. This backlog item kept the `str` return and used a separate `generate_gantt_note()` function for gap annotations. This preserved backward compatibility and made the stalled detection addition (E02-S03) clean -- it only needed to add to the `gantt_note` output channel, not modify the Gantt body.

3. **Fix cycle rate of 40% (2/5 stories) is above the baseline.** The organic fix cycle rate across tracked runs is ~9.2% (observation ii). Both fix cycles in this run were triggered by genuine code quality issues: scope creep (E01-S01) and incorrect output placement (E02-S03). Neither was a false positive. The elevated rate is likely due to the tight coupling between stories modifying the same file -- changes in one story's scope boundary are visible to the reviewer because the scope boundaries are well-defined in the plan.

## Recommendations

1. **Populate `epics.*.stories` in the orchestrator state file during branch setup** -- The empty `stories` dict caused the breakdown telemetry to show `--` for all story codes. The orchestrator should call `state.sh update --story <N> --branch <branch> --epic <slug>` when creating story branches in Phase 4. This would enable `_build_story_labels()` to work for the run's own telemetry, not just for future runs analyzing the state file.

2. **When parallel stories modify the same file, the planner should document the expected merge strategy** -- E02-S02 and E02-S03 both added to `compute-dispatches.py`. The conflict resolution required understanding both features. If the plan documented "E02-S03 should merge E02-S02 first and combine `gantt_note` via a parts list," the merge builder would have had clearer instructions. This is a refinement of existing rec Q.

3. **Track merge conflict resolution dispatches as a distinct dispatch type in the state file** -- Dispatch 18 was categorized as `builder-sonnet` on issue 248, but its purpose was merge conflict resolution, not story implementation. Adding an `agent: "merge-resolver"` or `purpose: "merge-conflict"` field would enable the retro and telemetry scripts to separate infrastructure overhead from story work.
