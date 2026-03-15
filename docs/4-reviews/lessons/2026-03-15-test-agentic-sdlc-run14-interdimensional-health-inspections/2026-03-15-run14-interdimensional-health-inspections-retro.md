---
date: 2026-03-15
author: retro
backlog-issue: 83
backlog-pr: null
scope: "Run 14 — Interdimensional Restaurant Health Inspections: fix cycle validation, 12 stories, 2 epics, 5 waves"
---

# Run 14 — Interdimensional Health Inspections: Agentic Workflow Retrospective

## Summary

Run 14 produced 12 markdown documents (7 inspection reports, 5 regulatory documents) across 2 epics and 5 dispatch waves, making it the largest SDLC v2 run to date (Run 13 had 6 stories). The primary test objective -- **validating the fix cycle path** -- was achieved: 4 bugs were deliberately planted, 2 triggered fix cycles that completed successfully (REQUEST_CHANGES, builder fix, re-review, APPROVE), and 2 were avoided because builders followed acceptance criteria over contradictory story descriptions. A secondary finding was worktree cross-contamination during fix cycle dispatches, where E02-S01's violation file leaked into E01-S04's branch. The run consumed 32 agent dispatches, ~1.3M tokens, and ~$11.34 in estimated API cost over approximately 77 minutes of wall clock time.

## Timeline

| Phase | Time (UTC) | Wall Clock | Activity |
|-------|-----------|------------|----------|
| Setup | 10:18:00 | ~0m | Session start, pricing fetch |
| Design | 10:18:30 -- 10:25:56 | ~7m 36s | Designer creates design doc with 4 planted bugs (PR #85) |
| Plan | 10:26:00 -- 10:37:56 | ~11m 56s | Planner decomposes into 2 epics, 12 stories, 5 waves (PR #101) |
| Wave 1 Build | 10:38:00 -- 10:40:50 | ~2m 50s | 3-way parallel sonnet: E01-S01, E01-S02, E01-S03 |
| Wave 1 Review | 10:42:00 -- 10:43:24 | ~1m 24s | 3-way parallel review: all APPROVE |
| Wave 2 Build | 10:45:00 -- 10:48:17 | ~3m 17s | 3-way parallel sonnet: E01-S04, E01-S05, E02-S01 |
| Wave 2 Review | 10:50:00 -- 10:51:36 | ~1m 48s | 3-way parallel review: E01-S04 REQUEST_CHANGES, E01-S05 APPROVE, E02-S01 REQUEST_CHANGES |
| Fix Cycle 1 | 10:55:00 -- 10:58:19 | ~3m 19s | 2-way parallel fix: E01-S04 (word count trim), E02-S01 (list-to-table) |
| Re-review 1 | 10:58:00 -- 10:59:45 | ~1m 45s | E01-S04 REQUEST_CHANGES again (header fields removed), E02-S01 APPROVE |
| Fix Cycle 2 | 11:00:00 -- 11:01:52 | ~1m 52s | E01-S04 fix: restore headers, trim prose |
| Re-review 2 | 11:02:00 -- 11:03:01 | ~1m 1s | E01-S04 REQUEST_CHANGES (cross-contaminated file). Orchestrator removes file manually |
| Wave 3 Build | 11:05:00 -- 11:08:14 | ~3m 14s | 3-way parallel sonnet: E02-S02, E02-S03, E02-S04 |
| Wave 3 Review | 11:12:00 -- 11:14:03 | ~2m 3s | 3-way parallel review: all APPROVE |
| Wave 4 Build | 11:15:00 -- 11:20:26 | ~5m 26s | 2-way parallel opus: E01-S06, E01-S07 |
| Wave 4 Review | 11:22:00 -- 11:23:36 | ~1m 36s | 2-way parallel review: all APPROVE |
| Wave 5 Build | 11:25:00 -- 11:31:41 | ~6m 41s | Sequential opus: E02-S05 |
| Wave 5 Review | 11:33:00 -- 11:34:42 | ~1m 42s | Review: APPROVE |
| Post-build | ~11:35:00 | ~1m | Merges, changelog, board cleanup |
| **Total** | 10:18:00 -- ~11:36:00 | **~1h 18m** | |

*Source: orchestrator state file `.agentic-workflow/runs/83/orchestrator.json` dispatch timestamps and `git log` commit timestamps.*

## Telemetry

### Per-Story Breakdown

| Story | Issue | Difficulty | Model | Agent Time | Tokens | Est. Cost | Tool Uses | Fix Cycles | Verdict |
|-------|-------|-----------|-------|-----------|--------|-----------|-----------|------------|---------|
| E01-S01 | #89 | easy | sonnet | 3m 40s | 68K | ~$0.52 | 50 | 0 | APPROVE |
| E01-S02 | #90 | easy | sonnet | 3m 32s | 63K | ~$0.50 | 41 | 0 | APPROVE |
| E01-S03 | #91 | medium | sonnet | 3m 11s | 63K | ~$0.49 | 36 | 0 | APPROVE |
| E01-S04 | #92 | medium | sonnet | 11m 11s | 183K | ~$1.60 | 136 | 2 | REQUEST_CHANGES x2 |
| E01-S05 | #93 | medium | sonnet | 3m 49s | 77K | ~$0.62 | 46 | 0 | APPROVE |
| E01-S06 | #94 | hard | opus | 4m 25s | 87K | ~$0.87 | 44 | 0 | APPROVE |
| E01-S07 | #95 | hard | opus | 6m 48s | 85K | ~$0.85 | 61 | 0 | APPROVE |
| E02-S01 | #96 | easy | sonnet | 8m 11s | 157K | ~$1.26 | 100 | 1 | REQUEST_CHANGES x1 |
| E02-S02 | #97 | easy | sonnet | 3m 45s | 65K | ~$0.50 | 49 | 0 | APPROVE |
| E02-S03 | #98 | medium | sonnet | 3m 50s | 82K | ~$0.68 | 42 | 0 | APPROVE |
| E02-S04 | #99 | medium | sonnet | 4m 49s | 79K | ~$0.59 | 50 | 0 | APPROVE |
| E02-S05 | #100 | hard | opus | 8m 23s | 99K | ~$0.99 | 88 | 0 | APPROVE |
| **Build Total** | | | | **65m 40s** | **1.1M** | **~$9.21** | **743** | **3** | |
| Design | #84 | -- | opus | 7m 36s | 88K | ~$0.88 | 30 | -- | -- |
| Plan | #86 | -- | opus | 11m 56s | 96K | ~$0.96 | 51 | -- | -- |
| **Grand Total** | | | | **86m 15s** | **1.3M** | **~$11.34** | **839** | **3** | |

*Note: "Agent Time" is sequential sum of all dispatches for that story (build + review + fix cycles). Wall clock is shorter due to parallel dispatch. Story costs include both builder and reviewer dispatches. E01-S04 review3 had 0 tokens/0 duration because the orchestrator resolved the cross-contamination issue manually.*

### Aggregate

| Metric | Value |
|--------|-------|
| Stories completed | 12/12 |
| Tests written | 0 (content-only run) |
| Critical bugs caught by reviewer | 2 (E01-S04 word count, E02-S01 format) |
| Warnings caught by reviewer | 1 (E01-S01 contradictory AC noted as plan-quality warning) |
| Bugs planted | 4 |
| Bugs that triggered fix cycles | 2 (E01-S04, E02-S01) |
| Bugs avoided by builder | 2 (E01-S01 builder followed AC, E02-S04 builder followed AC) |
| Fix cycles completed | 3 (E01-S04 x2, E02-S01 x1) |
| Total dispatches | 32 (2 design/plan + 15 build + 15 review) |
| Parallel waves | 5 (3+3+3+2+1 stories) |
| Cross-contamination incidents | 1 (E01-S04 fix cycle 2) |
| Sequential agent time | 86m 15s |
| Estimated wall clock | ~77m |
| Parallelism savings | ~9m (10.4%) |

### Cost by Role

| Role | Duration | Tokens | Est. Cost |
|------|----------|--------|-----------|
| Designer (opus) | 7m 36s | 88K | ~$0.88 |
| Planner (opus) | 11m 56s | 96K | ~$0.96 |
| Builders (sonnet) | 32m 33s | 469K | ~$2.80 |
| Builders (opus) | 14m 55s | 174K | ~$1.74 |
| Fix builders (sonnet) | 7m 29s | 117K | ~$0.70 |
| Reviewers (opus) | 21m 50s | 494K | ~$4.94 |
| **Total** | **86m 15s** | **1.3M** | **~$11.34** |

*Note: Reviewer cost ($4.94) exceeds builder cost ($5.24) as a proportion of total because all reviewers run on Opus regardless of story difficulty, while most builders run on Sonnet.*

### Fix Cycle Cost Analysis

| Story | Base Cost | Fix Cycle Cost | Total Cost | Fix Overhead |
|-------|-----------|---------------|------------|-------------|
| E01-S04 (#92) | $0.57 | $1.03 | $1.60 | +181% |
| E02-S01 (#96) | $0.76 | $0.50 | $1.26 | +66% |
| **Total fix overhead** | **$1.33** | **$1.53** | **$2.86** | **+115%** |

Fix cycles more than doubled the cost of affected stories. E01-S04's 2 fix cycles cost $1.03 in additional dispatches (2 builder fixes + 2 re-reviews), a 181% overhead. E02-S01's single fix cycle added $0.50 (66% overhead). Total fix cycle overhead across the run was $1.53 out of $11.34 total (13.5% of run cost).

## What Worked

### 1. Fix Cycle Machinery Validated End-to-End

The primary test objective was achieved. The orchestrator correctly handled the REQUEST_CHANGES, builder fix, re-review loop for both E01-S04 and E02-S01. The dispatch log shows clean state transitions: build (dispatches 9, 11) -> review (dispatches 12, 14) -> fix (dispatches 15, 16) -> re-review (dispatches 17, 18). For E02-S01, the cycle completed in one iteration. For E01-S04, the orchestrator correctly dispatched a second fix cycle when the first fix introduced a regression (header field removal). This is the first time fix cycles have been exercised in SDLC v2, ending a streak of 28 consecutive first-pass approvals (Runs 9-13).

### 2. Builders Consistently Prioritize Acceptance Criteria Over Story Descriptions

Two of four planted bugs (Bug 1: E01-S01 contradictory AC, Bug 4: E02-S04 wrong cross-reference) were neutralized because the builder followed the acceptance criteria rather than the story description when the two conflicted. For E01-S01, the description said "exactly 3 violations" but the AC said "at least 5" -- the builder wrote 6 violations, passing the AC. For E02-S04, the description said to cross-reference MFSA-INS-2026-003 but the AC said MFSA-INS-2026-004 -- the builder used the correct number from the AC. This is a robust behavioral pattern: builders treat acceptance criteria as the authoritative contract, which is the correct behavior for a well-designed workflow. The reviewer for E01-S01 correctly noted the contradiction as a warning (W1) but did not block merge since the AC was satisfied.

### 3. Cross-Epic Dependencies Worked Cleanly

E02 stories referenced E01 documents by MFSA document number (e.g., E02-S01 referenced MFSA-INS-2026-001 from E01-S01). The deterministic document numbering system in the design doc meant E02 builders could write accurate cross-references without needing to read actual E01 files (for easy/medium stories). Hard stories (E01-S06, E01-S07, E02-S05) successfully read prior files for content-specific cross-references. All cross-references were verified as correct by reviewers.

### 4. Parallel Review Dispatch

Reviewers were dispatched in parallel for independent stories within the same wave. Waves 1-3 each had 3-way parallel reviews. This pattern was first validated in Run 11 (Wave 3) and is now confirmed as stable across 5 waves in a single run.

### 5. Reviewer Caught Planted Bugs When They Survived to Review

For the 2 bugs that reached the reviewer (E01-S04 word count exceeded after builder included all required sections, E02-S01 numbered list instead of table), the reviewer correctly identified them and issued REQUEST_CHANGES with clear, actionable feedback. The reviewer for E01-S04 even noted in its "Strengths" section that the builder had correctly included the Contamination Timeline despite it not being mentioned in the story description -- showing the reviewer was aware of the AC-vs-description tension.

## What Didn't Work

### 1. Fix Cycle 1 for E01-S04 Introduced a Regression

When the reviewer flagged E01-S04's word count (444 words, 11% over the 400-word limit), the builder trimmed the count from 444 to 399 by **shortening header field labels and removing the Document Type line** rather than trimming body prose. Commit `5a97f20` removed `**Document Type:** Inspection Report`, shortened `**Inspector/Author:**` to `**Inspector:**`, and shortened `**Date of Inspection/Issue:**` to `**Date:**`. The re-reviewer (dispatch 17) correctly caught this regression, requiring a second fix cycle.

**Root cause:** The builder received a directive to "trim approximately 44-50 words" but was not instructed on *where* to trim. Header fields are short strings that are easy targets for a word-count-focused builder. The reviewer's feedback in the first REQUEST_CHANGES suggested "The 'Required Corrective Actions' section and parts of the Executive Summary are the most natural candidates for tightening" -- the builder ignored this guidance and took the path of least resistance.

**Impact:** Added one additional fix cycle (dispatch 19: 1m 52s, 37K tokens, ~$0.22) plus one additional re-review (dispatch 20: 1m 1s, 28K tokens, ~$0.28). Total overhead for the regression: ~$0.50.

### 2. Worktree Cross-Contamination in Fix Cycle 2

The third reviewer pass on E01-S04 (dispatch 20) found that commit `9aa16c7` on the `e01-s04/probability-cafe` branch included `violation-quantum-bistro.md` -- a file belonging to E02-S01's story. This file appeared because the fix cycle 2 builder was dispatched in a worktree that contained artifacts from the parallel Wave 2 dispatch (E02-S01 ran in the same wave as E01-S04).

**Root cause:** When the orchestrator dispatched the fix cycle builder for E01-S04, the worktree still contained E02-S01's output file from the earlier parallel wave. The builder's `git add` or commit operation picked up this stray file. The existing convention requires "Post-worktree cleanup" (`git clean -fd` after parallel dispatch), but this was not re-applied before fix cycle dispatches.

**Resolution:** The orchestrator manually removed the file with commit `d537441` (`fix(e01-s04): remove cross-contaminated file from worktree dispatch`). The review3 entry in the state file has 0 tokens/0 duration with a note: "Content approved in review 2. Cross-contamination fixed by orchestrator."

**Impact:** The cross-contamination did not affect the final content quality but added orchestrator overhead to detect and fix. More importantly, it reveals that the post-worktree cleanup convention does not cover fix cycle dispatches -- only the initial parallel wave.

### 3. Two Planted Bugs Were Not Testable

Bug 1 (contradictory AC in E01-S01) and Bug 4 (wrong cross-reference in E02-S04) did not trigger fix cycles because the builder followed the acceptance criteria rather than the story description. While this is *correct builder behavior*, it means the bug planting strategy failed to exercise the fix cycle for these stories. The design doc's assumption ("the builder will likely follow either the description or the acceptance criteria") underestimated how strongly builders prioritize the AC checklist.

**Root cause:** The bugs relied on a contradiction between the story description and acceptance criteria. Since builders treat the AC as authoritative (the AC is presented as a checklist they must satisfy), description-level contradictions are insufficient to trigger failures. To reliably trigger fix cycles, the *acceptance criteria themselves* must contain the defect (e.g., an impossible word count in the AC, or a structurally ambiguous AC that the builder misinterprets).

### 4. Reviewer Noted E01-S01 Contradiction as Warning, Not Critical

The reviewer for E01-S01 (dispatch 6) detected the contradiction between "exactly 3 violations" (description) and "at least 5 violations" (AC) but classified it as a warning (W1) rather than a critical issue, since the builder had already satisfied the AC. While the reviewer's reasoning was sound (the deliverable met the AC), this means the reviewer did not issue REQUEST_CHANGES even though a plan-level defect was present. The reviewer correctly identified it as a "plan-quality issue, not a builder issue."

**Impact:** None for the fix cycle test (the builder had already resolved the contradiction). But it shows that the reviewer agent distinguishes between builder-actionable issues and plan-level issues, issuing REQUEST_CHANGES only for the former.

## Workflow Evolution During Epic

No convention changes were made to CLAUDE.md or agent files during this run. The `git diff main..backlog/83-interdimensional-health-inspections -- CLAUDE.md .claude/agents/` is empty.

The backlog issue mentioned 8 "quick wins" (A-H) from the workflow analysis that the orchestrator should implement before dispatching builders. The orchestrator state and commit history do not show these quick wins being implemented during this run. They may have been deferred or implemented separately.

## Key Learnings

### For Builders

1. **Header fields are not a valid word-count trimming target.** When a reviewer flags word count overflow, trim body prose (paragraphs, table cell text, redundant sentences) rather than shortening or removing header template fields. The template fields are a structural contract across all documents in the epic. Evidence: E01-S04 fix cycle 1 (commit `5a97f20`) removed Document Type and shortened Inspector/Author and Date of Inspection/Issue labels, causing a second fix cycle.

2. **Acceptance criteria take precedence over story descriptions.** This is already the observed builder behavior (2/4 planted bugs avoided), but it should be explicitly documented as a convention. When the AC and description contradict, the builder should satisfy the AC and note the discrepancy in the commit message or issue comment.

### For the Orchestrator

1. **Post-worktree cleanup must also run before fix cycle dispatches, not only after the initial parallel wave.** The existing convention ("Post-worktree cleanup (REQUIRED)") specifies cleanup "after all worktree-dispatched builders complete" but does not mention fix cycles. Evidence: E01-S04 fix cycle 2 picked up E02-S01's file from a stale worktree (commit `9aa16c7`, fixed in `d537441`).

2. **Fix cycle dispatches in the same wave should be parallelized.** The orchestrator correctly dispatched E01-S04 and E02-S01 fix builders in parallel (dispatches 15-16 at 10:55:00), which is the right approach. This should be documented as the expected pattern.

3. **The orchestrator may need to manually resolve cross-contamination after fix cycles.** The reviewer found the stray file but the builder cannot be expected to clean up files from other stories. The orchestrator should check for unexpected files on the story branch before merging, especially after fix cycle dispatches.

### For the Workflow

1. **To reliably trigger fix cycles in test runs, plant bugs in the acceptance criteria themselves, not in description-vs-AC contradictions.** Builders consistently follow the AC, so bugs must survive into the AC checklist to reach the reviewer. Effective bug types for future testing: impossible word counts in the AC, structurally ambiguous AC items, or AC items that reference nonexistent content. Evidence: 2/4 bugs (50%) failed to trigger because they relied on description-AC contradictions.

2. **Fix cycles are expensive.** The 3 fix cycles in this run added $1.53 (13.5% of total run cost) and 11m 29s of additional agent time. Each fix cycle involves at minimum 2 additional dispatches (builder fix + re-review). E01-S04 required 4 additional dispatches due to the regression. For real-world usage, preventing fix cycles through clearer acceptance criteria is significantly cheaper than fixing defects iteratively.

3. **12 stories across 2 epics is a viable scale for the workflow.** The 5-wave dispatch plan respected `maxParallelBuilders: 3` and completed in approximately 57 minutes of build+review wall clock (excluding design and plan phases). Cross-epic dependencies were handled cleanly through deterministic document numbering. This confirms the workflow can handle larger backlog items without structural changes.

## Recommendations

1. **Add post-worktree cleanup before fix cycle dispatches** -- The existing convention covers initial parallel waves but not fix cycles. Add to CLAUDE.md: "Post-worktree cleanup is also required before dispatching fix cycle builders in worktree mode." Evidence: E01-S04 cross-contamination (commit `d537441`).

2. **Document the builder AC-priority behavior as a convention** -- Add to builder agent instructions: "When acceptance criteria and story descriptions contradict, satisfy the acceptance criteria and note the discrepancy." This is already the observed behavior but is not codified. Evidence: 2/4 planted bugs avoided by builders following AC (issues #89, #99).

3. **Update bug planting guidance for future test runs** -- For deliberately triggering fix cycles, bugs must be placed in the acceptance criteria themselves (e.g., an impossible word count as an AC item) rather than relying on description-vs-AC contradictions. Evidence: 50% bug trigger rate in Run 14.

4. **Update observation ii in retro-recommendations.md** -- The 28-consecutive-first-pass-approvals streak (Runs 9-13) is broken. Run 14 had 2 genuine fix cycles (E01-S04 word count, E02-S01 format) plus 1 regression-induced fix cycle. The observation should note that fix cycles are achievable when AC contains structural defects.

5. **Track fix cycle overhead as a metric** -- Fix cycles added 13.5% to Run 14's total cost. As the workflow matures toward real-world usage, tracking fix cycle rate and overhead per run would help identify whether builder or reviewer instructions need tuning.

## Lesson Retention

No individual lesson files were written during this run (no `e01-inspection-reports/` or `e02-regulatory-admin/` lesson files exist). All learnings are captured in this retro doc. The retro doc is the primary reference for Run 14's learnings going forward.

**Lessons absorbed into recommendations:**
- Worktree cross-contamination in fix cycles -> Recommendation 1 (proposed convention change)
- Builder AC-priority behavior -> Recommendation 2 (proposed convention change)
- Bug planting strategy effectiveness -> Recommendation 3 (guidance update)
- Fix cycle cost overhead -> Recommendation 5 (new tracking metric)
