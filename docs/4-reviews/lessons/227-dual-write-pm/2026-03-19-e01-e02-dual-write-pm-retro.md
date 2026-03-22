---
date: 2026-03-19
author: carlosboeing
agent: retro
backlog-issue: 227
backlog-pr: 240
scope: Dual-Write PM Layer -- pm.sh refactored from single-adapter to always-local + optional-external with fire-and-forget sync
---

# Dual-Write PM Layer -- Agentic Workflow Retrospective

## Summary

Backlog item #227 refactored `pm.sh` from a single-adapter loader ("pick local or GitHub") to a dual-write architecture: the local adapter is always on as the foundation, and an external adapter (GitHub) optionally syncs state via fire-and-forget wrappers. The work spanned 2 epics and 6 stories, touching 22 files with +4,948/-546 lines. All 6 stories completed with ~293 new tests across 6 test files (3 new, 3 extended), 2 fix cycles across 2 stories, and 30 reviewer findings (2 critical, 12 warnings, 16 suggestions). This was the third PM infrastructure backlog item (after BL109's abstraction layer and BL111's local adapter) and the first to implement the dual-write pattern that was deferred in BL111's design.

## Timeline

| Phase | Time (UTC) | Wall Clock | Activity |
|-------|-----------|------------|----------|
| Design | 10:32 -- 10:41 | ~9 min | Designer creates design doc, PR #229 merged |
| Plan | 10:42 -- 10:52 | ~10 min | Planner creates 2 epics, 6 stories; plan PR #239 merged |
| Build W1 (E01-S01/S02/S03) | 10:54 -- 12:25 | ~91 min | 3-way parallel build; E01-S01 anomalously long (see analysis below) |
| Review W1 (E01-S01/S02/S03) | 12:26 -- 12:30 | ~4 min | 3-way parallel review; E01-S02 reviewer failed then issued REQUEST_CHANGES |
| Fix cycle E01-S02 | 21:35 -- 21:44 | ~9 min | Re-review, fix, re-review (session resumed after gap) |
| Merge E01 | ~21:45 | ~1 min | E01 merged into integration branch |
| Build E02-S01 | 21:46 -- 21:53 | ~7 min | Opus builder: pm.sh loader refactor |
| Review E02-S01 | 21:54 -- 22:00 | ~6 min | REQUEST_CHANGES: test regression + stale comments + guard gap |
| Fix cycle E02-S01 | 22:00 -- 22:07 | ~7 min | Fix build + re-review: APPROVE |
| Build E02-S02 | 22:08 -- 22:19 | ~11 min | Opus builder: dual-write wrapper generation |
| Review E02-S02 | 22:20 -- 22:24 | ~4 min | APPROVE on first pass |
| Build E02-S03 | 22:25 -- 22:30 | ~5 min | Sonnet builder: backward compat + integration tests |
| Review E02-S03 | 22:31 -- 22:35 | ~4 min | APPROVE on first pass |
| Merge E02 + changelog | 22:36 -- 22:38 | ~2 min | E02 merged into integration, changelog, PR #240 created |
| **Total** | 10:32 -- 22:38 | **~12h 6m wall clock** | Sequential agent time: 182m 43s; gap of ~9h between sessions |

*Source: git log and dispatch timestamps from `.agentic-workflow/runs/227/orchestrator.json`. The large gap between 12:30 and 21:35 was a session interruption (likely usage limit or manual pause).*

## Telemetry

### Per-Story Breakdown

| Story | Issue | Difficulty | Build Model | Review Model | Agent Time | Tokens | Est. Cost | Tool Uses | Fix Cycles | Verdict |
|-------|-------|-----------|------------|-------------|-----------|--------|-----------|-----------|------------|---------|
| E01-S01 | #233 | easy | sonnet | sonnet | 93m 8s | 135K | ~$0.81 | 80 | 0 | APPROVE |
| E01-S02 | #234 | medium | sonnet | opus | 21m 7s | 304K | ~$2.46 | 155 | 1 | FAILED, REQ, then APPROVE |
| E01-S03 | #235 | easy | sonnet | sonnet | 6m 56s | 142K | ~$0.86 | 59 | 0 | APPROVE |
| E02-S01 | #236 | hard | opus | opus | 19m 6s | 302K | ~$3.03 | 176 | 1 | REQ then APPROVE |
| E02-S02 | #237 | hard | opus | opus | 14m 24s | 228K | ~$2.29 | 100 | 0 | APPROVE |
| E02-S03 | #238 | medium | sonnet | opus | 9m 32s | 165K | ~$1.28 | 82 | 0 | APPROVE |
| **Story Total** | | | | | **164m 13s** | **1,276K** | **~$10.73** | **652** | **2** | |

*Note: E01-S01 has an anomalous 91m 2s build duration despite being an easy story. The builder was likely interrupted by a usage limit and the dispatch timer continued running. The actual work (2 commits, 10 new tests) suggests ~5-10 min of active build time. E01-S02 had a failed reviewer dispatch (opus, 0 tokens returned -- likely a transient error or usage limit) before a successful re-review that found a genuine issue.*

### Design and Plan

| Phase | Dispatches | Agent Time | Tokens | Est. Cost | Tool Uses |
|-------|-----------|-----------|--------|-----------|-----------|
| Design | 1 | 8m 21s | 127K | ~$1.27 | 56 |
| Plan | 1 | 9m 58s | 127K | ~$1.28 | 76 |
| **Total** | **2** | **18m 19s** | **254K** | **~$2.55** | **132** |

### Aggregate

| Metric | Value |
|--------|-------|
| Stories completed | 6/6 |
| Tests written | ~293 (across 6 test files, 3 entirely new) |
| Lines added (net) | +4,402 |
| Files changed | 22 |
| Critical issues caught by reviewer | 2 |
| Warnings caught by reviewer | 12 |
| Suggestions made by reviewer | 16 |
| Fix cycles | 2 across 2/6 stories (33%) |
| Parallel waves | 1 (Wave 1: 3-way parallel build + 3-way parallel review) |
| Total agent time (all phases) | 182m 32s |
| Total tokens (all phases) | 1,530K |
| Total estimated cost (all phases) | ~$13.28 |

*Cost breakdown: Design $1.27 (10%), Plan $1.28 (10%), Build $5.79 (44%), Review $4.93 (37%). Fix cycles added ~$0.94 and 4m 29s (7% of total cost). Note: the build cost share is inflated by E01-S01's anomalous duration (see below).*

## What Worked

### 1. Single-Dispatch Design and Plan Phases

Both design and plan completed in a single dispatch each (unlike BL109 which required 10 design dispatches). Combined design+plan cost was $2.55 (19% of total), continuing the pattern from BL111 ($2.26, 15%) where a prior design doc exists as a foundation.

**Evidence:** Dispatch 1 (designer, 8m 21s, 127K tokens, $1.27) and dispatch 2 (planner, 9m 58s, 127K tokens, $1.28) in the state file. Zero usage limit interruptions. The BL109 PM abstraction design and BL111 local adapter design docs provided the architectural context, enabling the designer to focus on the dual-write pattern rather than re-establishing the adapter interface.

### 2. Wave 1 Parallel Build Leveraged Independence

The planner correctly identified that all three E01 stories (config schema, GitHub prefix injection, local adapter helper) touch entirely separate files. This enabled a 3-way parallel build in Wave 1.

**Evidence:** Dispatches 3, 4, 5 all share `started_at: "2026-03-18T10:54:25Z"`. E01-S02 finished in 9m 3s and E01-S03 in 5m 32s. The parallel wave's wall clock was determined by E01-S01's anomalous 91m 2s (see "What Didn't Work"). Excluding E01-S01's anomaly, the parallel build would have completed in ~9 min vs ~14m 35s sequential -- a real savings.

### 3. Prefix Injection Pattern Was Clean and Mechanical

The `_PM_FN_PREFIX` pattern (E01-S02) proved to be a well-designed mechanism for namespace injection across 7 GitHub adapter modules. All 15 public functions were converted using a consistent `eval "${_PM_FN_PREFIX}pm_<name>() { ... }"` pattern. The reviewer found zero issues with the eval escaping -- a notable result given that eval-based function definition with GraphQL nested quotes, Python heredocs, and BASH_SOURCE resolution is inherently high-risk.

**Evidence:** E01-S02 review passed 108/108 new tests plus 177 existing adapter tests with no regressions. The reviewer's detailed eval escaping analysis (8 patterns verified) found all correct. The only critical issue was an existing test threshold that needed updating, not a prefix injection bug.

### 4. Composed Function Architecture Validated

The function classification (dual-write, local-only, composed) proved architecturally sound. The key insight -- that composed functions like `pm_start_work` should delegate to the *wrapper* versions of `pm_add_comment` and `pm_set_status` rather than calling `_external_pm_start_work` directly -- eliminates a class of double-write bugs. Tests explicitly verified this: `_external_pm_start_work` was NOT called while `_external_pm_add_comment` and `_external_pm_set_status` WERE called through the dual-write wrappers.

**Evidence:** E02-S02 Test Group 6 (pm_start_work composition) and E02-S03 Test Group 3 (integration composition verification). All 16 functions classified exactly as specified in the plan's Section 5 authoritative reference table -- zero deviations.

### 5. Reviewer-Opus Quality on Hard Stories Remains High

Both hard stories (E02-S01 and E02-S02) received thorough Opus reviews. E02-S01's review caught a genuine test regression (error message mismatch between local and GitHub adapter), a stale comment, and an incomplete idempotency guard -- all real issues. E02-S02's review verified all 16 function classifications against the plan and conducted a detailed eval escaping analysis.

**Evidence:** E02-S01 review found C1 (test-board-sh.sh regression), W1 (stale comment), W2 (idempotency guard gap). E02-S02 review verified function classification table with 16/16 matches and produced a comprehensive eval escaping correctness analysis.

## What Didn't Work

### 1. E01-S01 Anomalous 91-Minute Duration

The config schema story (E01-S01, difficulty/easy) consumed 91m 2s of dispatch time -- over 16x what would be expected for an easy config story. E01-S03 (also easy, same start time) completed in 5m 32s. The builder produced only 2 commits and 10 new test groups, suggesting ~5-10 min of active work.

**Root cause:** The dispatch timer in the state file recorded 5,462,935ms between `started_at` (10:54:25) and `finished_at` (12:25:27). This 91-minute span strongly suggests the builder agent was interrupted (usage limit or platform issue) and the dispatch timer continued counting during the inactive period. The orchestrator does not currently distinguish between active computation and idle waiting during a single dispatch. This inflated both the sequential sum and E01's apparent wall clock.

**Impact:** The E01 parallel wave's wall clock was dominated by this anomaly. Without it, Wave 1's critical path would have been ~9 min (E01-S02) instead of 91 min. The total agent time (182m 32s) and the E01 telemetry are both inflated.

### 2. Reviewer Dispatch Failure (Dispatch 7)

The first reviewer-opus dispatch for E01-S02 (dispatch 7) returned with 0 tokens and 0 tool uses but was recorded as "failed." The reviewer was successfully re-dispatched 9 hours later.

**Root cause:** The 0-token result suggests the reviewer agent failed to start or was immediately interrupted (usage limit, platform error). No review comment was posted on the issue. The orchestrator correctly identified the failure and re-dispatched, but the gap between the failure (12:30:17) and re-dispatch (21:35:39) indicates a session interruption.

**Impact:** The failed dispatch consumed 225,545ms (3m 45s) of wall clock with no useful output. The re-dispatch added $0.91 (5m 59s) for a successful review that found a genuine issue. Total cost: $0.91 for the useful review + $0.00 for the failed attempt.

### 3. Session Interruption Gap (~9 Hours)

A ~9-hour gap exists between E01 completion (12:30 UTC) and E02-S01 start (21:35 UTC). This gap is not captured in the state file beyond the timestamp discontinuity.

**Root cause:** Either a usage limit on the orchestrator's parent session, a manual pause, or a platform interruption. The orchestrator state file does not track interruption events (see existing recommendation W: "Add interruption tracking to orchestrator dispatch records").

**Impact:** The total wall clock of ~12 hours is misleading -- actual active time was approximately 3 hours. The session recovered correctly and continued from where it left off, validating the fault tolerance design.

### 4. pm.sh Exceeds 200-Line Convention

After E02-S02's wrapper generation additions, `pm.sh` reached 292 lines -- 46% over the 200-line convention limit. The reviewer flagged this as W1 on E02-S02 and suggested extracting wrapper logic into a separate `pm-wrappers.sh` module.

**Root cause:** The loader refactoring (E02-S01) expanded pm.sh to ~199 lines, and the wrapper generation (E02-S02) added 103 more. Both contributions are tightly coupled (the loader calls `_pm_generate_wrappers` inline), making extraction non-trivial without introducing sourcing order dependencies.

**Impact:** Convention violation. The file is readable and well-structured (clear sections for loader, classification, wrapper generation), but the 200-line convention exists for good reason. This should be addressed in a follow-up backlog item. See existing recommendation AB ("Amend the 200-line convention to exempt or raise the limit for test files") -- pm.sh is not a test file, so this is a separate concern.

## Workflow Evolution During Epic

No changes were made to CLAUDE.md or agent files during this backlog item.

| Commit | Change | Trigger |
|--------|--------|---------|
| (none) | No convention changes mid-epic | N/A |

## Key Learnings

### For Builders

1. **Easy stories can have anomalous durations.** E01-S01's 91m build on an easy config story demonstrates that dispatch duration is not a reliable proxy for story complexity when usage limits or platform interruptions occur. Builders should not be judged by dispatch duration alone -- commit count and diff size are better indicators of actual work performed.

2. **Eval escaping in bash requires systematic analysis.** E01-S02's prefix injection across 7 modules with GraphQL nested quotes, Python heredocs, and BASH_SOURCE resolution all worked correctly because the builder applied the same mechanical pattern consistently. The reviewer confirmed 8 distinct escaping patterns were correct. Consistency beats cleverness.

3. **Test regression from adapter abstraction is predictable.** E02-S01's critical issue (test-board-sh.sh expecting "Unknown status" instead of "invalid status") is a direct consequence of wrapping the GitHub adapter behind the local adapter. When the public API surface changes (local becomes primary), tests that hardcoded the old adapter's error messages break. Builders should grep for error message strings in test files when changing the adapter stack.

### For the Orchestrator

1. **Failed dispatches need immediate re-dispatch.** The 9-hour gap between dispatch 7 (failed reviewer) and dispatch 9 (successful re-review) was entirely due to a session interruption. If the orchestrator had been able to immediately re-dispatch, the fix cycle could have completed in ~10 min instead of spanning two sessions.

2. **Anomalous dispatch durations inflate all downstream metrics.** E01-S01's 91m duration inflated the E01 epic telemetry, the sequential sum, and any wall-clock calculations that use dispatch durations. The orchestrator should consider flagging dispatches where `duration_ms >> expected_for_difficulty` (e.g., easy stories over 30 min) for manual review.

### For the Workflow

1. **Three PM infrastructure backlogs (109, 111, 227) show a clear cost pattern.** Design+plan costs decrease as prior art increases: BL109 $8.08 (42%), BL111 $2.26 (15%), BL227 $2.55 (19%). Build costs are stable: BL109 $6.23, BL111 $6.29, BL227 $5.79. Review costs vary with fix cycle rate: BL111 $6.15 (42%, 4/9 fix cycles), BL227 $4.93 (37%, 2/6 fix cycles). The dual-write feature had the lowest fix cycle rate of the three PM infrastructure items.

2. **The dual-write pattern is now available for production use.** With `pm.adapter: "github"` in config, all `pm_*` calls write locally first and sync to GitHub asynchronously. The `pm_create_item` special wrapper returns the GitHub issue number as the canonical ID, enabling both systems to use the same numbering. This completes the vision from BL111's design doc.

## Recommendations

1. **Flag anomalous dispatch durations in the state file** -- When a dispatch's `duration_ms` exceeds a threshold relative to difficulty (e.g., easy > 30 min, medium > 60 min, hard > 120 min), the orchestrator should add a `"warning": "anomalous_duration"` field to the dispatch record. This would help the retro agent distinguish between genuine long builds and usage-limit-inflated timers. Evidence: E01-S01 dispatch 3 consumed 91m 2s on an easy config story.

2. **Consider extracting pm.sh wrapper logic into pm-wrappers.sh** -- pm.sh at 292 lines exceeds the 200-line convention. The wrapper generation logic (_pm_generate_wrapper, _pm_generate_create_item_wrapper, _pm_generate_wrappers, classification arrays, _pm_external_fire_and_forget, _pm_is_local_only) is a self-contained ~100-line module that could be sourced separately. This would keep pm.sh focused on the loader sequence (~190 lines). Evidence: Reviewer W1 on E02-S02 (#237).

3. **Add test file cleanup traps as a builder convention** -- Three separate reviewers flagged missing cleanup traps for temp files and mock symlinks in test files (W1 on #233, S3 on #236, W2/S1/S3 on #238). The pattern recurred across 4 of 6 stories. Add to builder.md: "Test files that create temp files or mock symlinks MUST use `trap cleanup EXIT` to ensure cleanup on early exit." Evidence: W1 on #233, S3 on #236, S1/S3 on #237, W2/S3 on #238.

4. **Grep test files for hardcoded error messages when changing adapter stack** -- When the public API surface shifts from one adapter to another (e.g., GitHub -> local as primary), tests that hardcode the old adapter's error strings will break. Builders should `grep -rn` for quoted error strings in test files when changing which adapter surfaces the public API. Evidence: E02-S01 critical issue C1 (test-board-sh.sh "Unknown status" vs "invalid status").

## Post-Retro Addendum (added by orchestrator)

### Telemetry fixes applied in post-build session

Three bugs were found and fixed in `compute-dispatches.py` during a post-build telemetry review:

1. **Reviewer variants missing from `AGENT_TO_PHASE`** — `reviewer-sonnet` and `reviewer-opus` fell through to "Other" instead of "Review" in the summary table.
2. **`is_reviewer` used exact match instead of `startswith`** — fix cycle detection in `compute_fix_cycles` didn't recognize reviewer variants, undercounting fix cycle cost by ~50%.
3. **Breakdown labels used simple `(issue, agent_prefix)` counting** — a retried review (after API 529 error) was mislabeled as "Re-review". Replaced with builder-centric logic matching `compute_fix_cycles` semantics.

All three fixes are on the `backlog/227-dual-write-pm` branch.

### Gantt timeline distortion (unresolved)

Gap compression was attempted (collapse idle gaps > 5 min to 30s spacers) but reverted — it interacted badly with E01-S01's anomalous 91m duration. The chart remains distorted by two compounding issues: (1) Agent tool `duration_ms` includes usage-limit wait time, not just compute time; (2) session gaps create dead space. See lesson file: `e00-setup/2026-03-19-s00-gantt-timeline-distortion.md`.

### pm.sh idempotency guard is broken and over-engineered (unresolved)

The guard (lines 29-41) tracks three variables to detect config changes between sourcing calls, but: (1) it never matches because `_PM_SH_COMPUTED_EXT` is captured before `config.sh` is sourced, (2) config never changes mid-session so the tracking is unnecessary — `[ -n "${_PM_SH_LOADED:-}" ]` would suffice, (3) `PM_ADAPTER`/`PM_ADAPTER_DIR`/`PM_EXTERNAL` are exported but no known subprocess reads them without sourcing pm.sh first. See lesson file: `e00-setup/2026-03-19-s00-gantt-timeline-distortion.md`.
