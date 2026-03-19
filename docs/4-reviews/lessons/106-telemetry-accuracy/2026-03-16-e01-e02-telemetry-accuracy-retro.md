---
date: 2026-03-16
author: retro
backlog-issue: 106
backlog-pr: 145
scope: "Telemetry Accuracy & Automation: extract Python module, Gantt from state data, fix cycle metrics, convention updates"
---

# Telemetry Accuracy & Automation -- Agentic Workflow Retrospective

## Summary

Backlog item 106 refactored the telemetry pipeline across 2 epics, 7 stories, and 4 dispatch waves. Epic E01 (Telemetry Pipeline Refactor) extracted ~230 lines of Python from bash heredocs into a standalone `compute-dispatches.py` module, added absolute-offset Gantt generation from state data, and implemented structured fix cycle metrics. Epic E02 (Conventions & Documentation) updated `orchestrator.md` and `CLAUDE.md` with precise timestamp conventions, the new `--gantt-from-state` flag, and a lifecycle duration baseline. The run produced 123 Python unit tests and 35 bash integration tests, reduced `item-telemetry.sh` from 662 to 469 lines, and introduced the first infrastructure-refactoring backlog item in the workflow's history (all prior runs were content-creation test workloads). The run completed 21 dispatches over ~2h 3m wall clock, consuming ~1.7M tokens at an estimated cost of ~$13.92. One story fix cycle occurred (E01-S02 section directives in Gantt output), and the PR review caught a premature `if __name__` block that silently skipped 35 of 123 tests.

## Timeline

| Phase | Time (UTC) | Wall Clock | Activity |
|-------|-----------|------------|----------|
| Design | 06:27:03 -- 06:31:57 | ~4m 54s | Designer creates design doc (PR 121, issue 120) |
| Plan | 06:32:45 -- 06:44:32 | ~11m 47s | Planner decomposes into 2 epics, 7 stories, 4 waves (PR 141) |
| Wave 1 Build | 06:46:09 -- 06:55:26 | ~9m 17s | Sequential sonnet: E01-S01 (extract Python module) |
| Wave 1 Review | 06:56:07 -- 07:01:37 | ~5m 30s | Sequential review: E01-S01 REQUEST_CHANGES (branch naming, C1) |
| Wave 2 Build | 07:03:16 -- 07:19:14 | ~15m 58s | 2-way parallel sonnet: E01-S02 (Gantt), E01-S03 (fix cycles) |
| Wave 2 Review | 07:21:01 -- 07:25:09 | ~4m 8s | 2-way parallel review: E01-S02 REQUEST_CHANGES (section directives), E01-S03 APPROVE |
| Fix Cycle 1 | 07:25:58 -- 07:29:40 | ~3m 42s | E01-S02 builder fix: remove `section Wave N` directives |
| Re-review 1 | 07:29:59 -- 07:31:14 | ~1m 15s | E01-S02 re-review: APPROVE |
| Wave 3 Build | 07:33:29 -- 07:48:17 | ~14m 48s | Sequential sonnet: E01-S04 (wire external module) |
| Wave 3 Review | 07:48:54 -- 07:54:24 | ~5m 30s | Sequential review: E01-S04 APPROVE |
| Wave 4 Build | 07:56:32 -- 08:09:05 | ~12m 33s | 3-way parallel sonnet: E02-S01, E02-S02, E02-S03 |
| Wave 4 Review | 08:10:12 -- 08:13:45 | ~3m 33s | 3-way parallel review: all APPROVE |
| Merges + Changelog | ~08:14 -- 08:16 | ~2m | Epic merges, changelog entry |
| PR Review | 08:16:58 -- 08:25:17 | ~8m 18s | Backlog PR review: REQUEST_CHANGES (C1: premature `__name__` block) |
| PR Fix | 08:25:39 -- 08:26:55 | ~1m 16s | Builder removes premature `if __name__` block (commit `f82ad14`) |
| PR Re-review | 08:27:11 -- 08:30:33 | ~3m 22s | Re-review: APPROVE |
| **Total** | 06:27:03 -- ~08:30:33 | **~2h 3m** | 21 dispatches across design, plan, build, review, retro |

*Source: orchestrator state file `.agentic-workflow/runs/106/orchestrator.json` dispatch timestamps and `git log` commit timestamps.*

## Telemetry

### Per-Story Breakdown

| Story | Issue | Difficulty | Model | Agent Time | Tokens | Est. Cost | Tool Uses | Fix Cycles | Verdict |
|-------|-------|-----------|-------|-----------|--------|-----------|-----------|------------|---------|
| E01-S01 | 127 | medium | sonnet+opus | 14m 48s | 163K | ~$1.29 | 118 | 0 | REQUEST_CHANGES (branch naming) |
| E01-S02 | 128 | medium | sonnet+opus | 17m 15s | 305K | ~$2.33 | 155 | 1 | REQUEST_CHANGES (section directives) |
| E01-S03 | 129 | medium | sonnet+opus | 20m 7s | 229K | ~$1.72 | 146 | 0 | APPROVE (W3: scope creep flagged) |
| E01-S04 | 130 | medium | sonnet+opus | 20m 19s | 200K | ~$1.47 | 169 | 0 | APPROVE |
| E02-S01 | 131 | easy | sonnet+opus | 7m 15s | 126K | ~$0.95 | 68 | 0 | APPROVE |
| E02-S02 | 133 | easy | sonnet+opus | 14m 43s | 154K | ~$1.07 | 126 | 0 | APPROVE |
| E02-S03 | 134 | easy | sonnet+opus | 14m 39s | 169K | ~$1.21 | 158 | 0 | APPROVE |
| **Story Total** | | | | **109m 8s** | **1,346K** | **~$10.05** | **940** | **1** | |
| Design | 120 | -- | opus | 4m 54s | 86K | ~$0.86 | 41 | -- | -- |
| Plan | -- | -- | opus | 11m 47s | 110K | ~$1.10 | 69 | -- | -- |
| PR Review | -- | -- | mixed | 12m 57s | 204K | ~$1.92 | 99 | -- | -- |
| **Grand Total** | | | | **138m 48s** | **1,747K** | **~$13.92** | **1,149** | **1** | |

*Note: "Agent Time" is sequential sum of all dispatches for that story (build + review + fix cycles). Wall clock is shorter due to parallel dispatch. "Model" shows sonnet+opus because builders used Sonnet while reviewers inherited the orchestrator's Opus model. PR Review includes the initial review (REQUEST_CHANGES), builder fix, and re-review.*

### Aggregate

| Metric | Value |
|--------|-------|
| Stories completed | 7/7 |
| Python unit tests written | 123 |
| Bash integration tests written | 35 |
| Critical bugs caught by story reviewer | 2 (E01-S01 C1 branch naming, E01-S02 C1 section directives) |
| Warnings caught by story reviewer | 14 across 7 stories |
| Critical bugs caught by PR reviewer | 1 (premature `__name__` block: 35 tests silently skipped) |
| Warnings caught by PR reviewer | 5 |
| Fix cycles (story-level) | 1 (E01-S02) |
| Fix cycles (PR-level) | 1 (C1: `__name__` block) |
| Total dispatches | 21 (design 1, plan 1, build 8, review 9, fix 2) |
| Sequential agent time | 138m 48s |
| Estimated wall clock | ~2h 3m |
| Estimated parallelism savings | ~30m (from 3 parallel waves) |

### Cost by Role

| Role | Duration | Tokens | Est. Cost |
|------|----------|--------|-----------|
| Designer (opus) | 4m 54s | 86K | ~$0.86 |
| Planner (opus) | 11m 47s | 110K | ~$1.10 |
| Builders (sonnet) | 82m 17s | 886K | ~$5.32 |
| Reviewers (opus) | 39m 49s | 665K | ~$6.65 |
| **Total** | **138m 48s** | **1,747K** | **~$13.92** |

*Note: Reviewer cost ($6.65) exceeds builder cost ($5.32) because all reviewers inherit the orchestrator's Opus model while all builders used Sonnet. Reviewers consumed 47.8% of total cost despite only 28.7% of total duration.*

### Fix Cycle Cost Analysis

| Cycle | Story | Duration | Tokens | Cost | Trigger |
|-------|-------|----------|--------|------|---------|
| E01-S02 fix + re-review | 128 | 4m 57s | 112K | ~$0.88 | `section Wave N` directives violated orchestrator.md convention |
| PR fix + re-review | PR 145 | 4m 38s | 72K | ~$0.73 | Premature `if __name__` block truncated test execution |
| **Total** | | **9m 36s** | **183K** | **~$1.61** | |

Fix cycle overhead: $1.61 / $13.92 = 11.6% of total cost. The E01-S02 fix was a convention violation caught by the reviewer; the PR-level fix was a structural bug caught by the PR reviewer. Both were one-iteration fixes.

## What Worked

### 1. Infrastructure refactoring with TDD produced high-quality code on first pass

6 of 7 stories received APPROVE on first review. The two REQUEST_CHANGES verdicts were for convention adherence (section directives in Gantt output) and branch naming (stale branch reference), not code correctness. The extracted `compute-dispatches.py` module faithfully reproduced the behavior of the original embedded Python -- the reviewer confirmed behavioral equivalence for all formatting functions, pricing resolution, wall-clock computation, and agent-to-phase mapping (review on issue 127).

### 2. Parallel waves delivered meaningful time savings

Three parallel waves (Wave 2: 2-way, Wave 4: 3-way, plus parallel reviews) reduced wall clock from ~138m sequential to ~123m effective. Wave 4 (E02-S01, E02-S02, E02-S03 in parallel) was the most effective -- all three stories were docs-only changes with no code dependencies, achieving a 2.3x speedup (36m 38s sequential compressed into ~16m 6s wall clock, per epic E02 telemetry on issue 126).

### 3. PR-level review caught a critical testing gap

The PR reviewer identified that a premature `if __name__ == "__main__"` block at line 1076 of `test_compute_dispatches.py` caused `unittest.main()` to exit before loading the Gantt test classes (defined after line 1078). This meant only 88 of 123 tests ran when executed directly with `python3`, though all 123 passed with pytest. This is precisely the kind of subtle bug that individual story reviews missed because each story only added tests within its own class boundaries (commit `f82ad14`).

### 4. Reviewer scope creep detection on E01-S03

The reviewer on issue 129 correctly flagged that E01-S03 (Fix Cycle Metrics) had replaced the `--dispatches-from-state` heredoc in `item-telemetry.sh` with a call to `compute-dispatches.py` -- work explicitly scoped to E01-S04 (issue 130). This was captured as W3 in the review, alerting the orchestrator that roughly half of E01-S04's acceptance criteria were pre-completed. The builder for E01-S04 was able to account for this and focus on the remaining work.

## What Didn't Work

### 1. Branch contamination on E01-S01 required a `-fresh` branch

The E01-S01 builder (issue 127) created its story branch `e01-s01/extract-python-module` from the wrong base -- it included commits from an unrelated backlog (`backlog/105-orchestrator-improvements`). The builder recovered by creating `e01-s01/extract-python-module-fresh` from the correct epic branch, but the reviewer flagged the stale original branch as C1 (critical). The orchestrator had to resolve this before merge by using the `-fresh` branch (review comment on issue 127).

This is a recurring pattern: when multiple backlog items are active concurrently, builders can start from the wrong branch if the working directory state is not clean. The lesson file (`2026-03-16-s04-stash-pop-branch-confusion.md`) documents a related git stash/pop failure on E01-S04.

### 2. E01-S03 scope creep partially completed E01-S04's work

The E01-S03 builder replaced the `--dispatches-from-state` Python heredoc in `item-telemetry.sh` with a call to `compute-dispatches.py` (reviewer W3 on issue 129). This was explicitly E01-S04's scope. The consequence was that E01-S04's acceptance criteria were partially pre-met, and the builder had to navigate existing changes rather than working from a clean baseline. While the final result was correct, this demonstrates that builders working on adjacent code paths may inadvertently absorb sibling story scope when not given explicit boundary guardrails.

### 3. Merge conflict when combining E01-S02 and E01-S03 test additions

Both E01-S02 (Gantt tests) and E01-S03 (fix cycle tests) added test classes to `test_compute_dispatches.py`. When merging these parallel branches into the epic branch, the test file had conflicts in the appended sections. The orchestrator resolved this manually. This is an inherent cost of parallel work on the same file, but the plan could have mitigated it by specifying non-overlapping insertion points or separate test files.

### 4. `compute-dispatches.py` reached 875 lines -- well above the 200-line guideline

The module that was extracted to reduce `item-telemetry.sh`'s line count itself grew to 875 lines, 4.4x the project's 200-line guideline. The PR reviewer noted this as W1. The Gantt generation functions alone account for ~250 lines. The original design accepted this trade-off (cohesion over file size), but the irony of a refactoring-for-readability story producing a file that violates the same guideline it was meant to address should inform future decomposition decisions.

## Workflow Evolution During Epic

| Commit | Change | Trigger |
|--------|--------|---------|
| `6767243` | `orchestrator.md`: `finished_at` field, precise timestamp instructions, `--gantt-from-state` preferred over manual `--gantt` | E02-S01 story scope |
| `64bd306` | `CLAUDE.md`: `--gantt-from-state` in helper table, `compute-dispatches.py` helper, fix cycle footer convention | E02-S02 story scope |
| `1fff6c7` | `orchestrator.md` + `CLAUDE.md`: `lifecycle_duration_ms` state field, changelog duration format | E02-S03 story scope |

These are planned convention changes (E02 was explicitly a documentation epic), not reactive mid-build adjustments. No emergency convention changes were needed during the build phase.

## Key Learnings

### For Builders

1. **Verify branch base before writing any code.** E01-S01's branch was created from the wrong base, requiring a `-fresh` branch recovery. Always run `git log --oneline -3` after `git checkout -b` to confirm the parent commits are from the expected epic branch.
2. **Do not modify files outside your story's `Files to modify` list.** E01-S03's scope creep into `item-telemetry.sh` (which was E01-S04's scope) created downstream confusion. The `Files to modify` section in the story issue is a hard boundary.
3. **Beware `git stash pop` after conflicts.** The lesson file (`2026-03-16-s04-stash-pop-branch-confusion.md`) documents how `git checkout --theirs` after a stash conflict resolves the index but does not switch HEAD. Always verify branch with `git branch --show-current` after any stash operation.
4. **Test file structure matters for runner compatibility.** A single misplaced `if __name__ == "__main__"` block at line 1076 (before later test classes) caused 35 tests to be silently skipped when running with `python3` directly. Keep the `if __name__` guard at the very end of the file, after all test classes.

### For the Orchestrator

1. **Detect and document scope creep between parallel stories.** When E01-S03 completed work that belonged to E01-S04, the orchestrator should have adjusted E01-S04's acceptance criteria or added a note to the story issue before dispatching the builder.
2. **Plan for merge conflicts on shared files in parallel waves.** Both E01-S02 and E01-S03 appended to the same test file. The plan could specify separate test files or ordered insertion points to avoid conflicts.
3. **Infrastructure stories take longer than content stories.** The 7 stories in this run averaged ~15m 35s agent time each (build + review), compared to ~5m 26s for content-creation stories in Run 14. The median build duration was 11m 6s vs ~3m 40s in content runs. Infrastructure refactoring involves more tool uses (average 134 per story vs ~56 in Run 14) because builders must read existing code, understand dependencies, and write tests.

### For the Workflow

1. **Reviewer cost dominates in infrastructure runs.** Reviewers consumed 47.8% of total cost despite 28.7% of duration. This is because all reviewers inherit the orchestrator's Opus model. For infrastructure refactoring (where review is high-value because correctness matters more than in content creation), this is the correct cost allocation. For docs-only stories (E02), Opus review is arguably overkill.
2. **The 200-line guideline needs nuance for module extraction.** Extracting Python from bash heredocs into a standalone module is net positive (testable, readable, maintainable), but applying the 200-line guideline to the extracted module would force premature decomposition. The guideline works well for scripts but may need a higher threshold for standalone Python modules with comprehensive test suites.
3. **PR-level review adds unique value beyond story reviews.** The premature `__name__` block was invisible to individual story reviewers because each saw only their own test class additions. The PR reviewer saw the full file and caught the structural issue. This validates the two-tier review model (story-level + PR-level).

## Recommendations

1. **Add a `Files to modify` boundary enforcement note to builder instructions** -- Builders should treat the story issue's `Files to modify` section as a hard constraint. Modifications to files not listed should be flagged to the orchestrator, not silently done. This would have prevented E01-S03's scope creep.

2. **Consider model routing for docs-only reviewers** -- E02's three docs-only stories consumed ~$1.00 in Opus reviewer cost for straightforward convention documentation. A `difficulty/easy` + `type/docs` combination could route to a Sonnet reviewer, saving ~40% on review cost for low-risk stories.

3. **Split large test files across stories in plans** -- When parallel stories add tests to the same file, specify separate test files per story (e.g., `test_gantt.py`, `test_fix_cycles.py`) or at minimum specify non-overlapping insertion points. This avoids merge conflicts on test file boundaries.

4. **Add a post-merge `python3 <test_file>` check for Python test suites** -- The premature `__name__` block bug would have been caught by running tests with the direct runner (not just pytest). Add a convention that Python test files must pass both `python3 -m pytest` and `python3 <file>` to verify the `__name__` guard is at the end.

5. **Track file size as a structured metric in review verdicts** -- The 200-line guideline was noted as a warning (W1/W2) in multiple reviews but never enforced. Consider adding file size to the reviewer's checklist with explicit thresholds: warning at 200 lines, critical at 500 lines (with documented exceptions for test files and extracted modules).

## Lesson Retention

### Compiled Lessons

| Lesson File | Status | Absorbed Into |
|-------------|--------|--------------|
| `e01-telemetry-pipeline/2026-03-16-s04-stash-pop-branch-confusion.md` | Compiled | Key Learnings for Builders (item 3) |

### Recommendations Status

| Recommendation | Status |
|----------------|--------|
| 1. `Files to modify` boundary enforcement | Proposed (new) |
| 2. Model routing for docs-only reviewers | Proposed (new) |
| 3. Split large test files in plans | Proposed (new) |
| 4. Post-merge `python3` direct runner check | Proposed (new) |
| 5. File size as structured review metric | Proposed (new) |

### Previously Outstanding Recommendations Addressed

| Recommendation | Source | Status in This Run |
|----------------|--------|--------------------|
| G. Track autonomous lifecycle duration baseline | Run 9 | Implemented: E02-S03 added `lifecycle_duration_ms` to state schema and changelog duration convention |
| I. Extract dispatch computation from item-telemetry.sh | Run 12 | Implemented: E01-S01 through E01-S04 extracted Python into `compute-dispatches.py` |
| L. Track fix cycle overhead as per-run metric | Run 14 | Implemented: E01-S03 added structured fix cycle metrics to `compute-dispatches.py` output |
