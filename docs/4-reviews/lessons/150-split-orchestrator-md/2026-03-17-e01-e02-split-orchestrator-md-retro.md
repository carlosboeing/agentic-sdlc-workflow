---
date: 2026-03-17
author: retro
backlog-issue: 150
backlog-pr: 163
scope: "Split orchestrator.md: extract inline scripts into state.sh, extend compute-dispatches.py with --overhead, rewrite orchestrator.md from 1323 to 503 lines, add Fault Tolerance principle"
---

# Split orchestrator.md into Core Instructions and Scripts -- Agentic Workflow Retrospective

## Summary

Backlog item 150 reduced `orchestrator.md` from 1,323 to 503 lines (62% reduction) across 2 epics and 5 stories. Epic E01 (Script Extraction) created `scripts/state.sh` with 6 subcommands for orchestrator state CRUD, extended `compute-dispatches.py` with an `--overhead` flag, and created a JSON Schema file for the state file format. Epic E02 (Documentation Rewrite) rewrote `orchestrator.md` to replace all inline Python/bash with script calls and delete dead/redundant content, then updated CLAUDE.md with a new "Fault Tolerance" design principle and `state.sh` references. The run's most significant finding was a heredoc injection vulnerability in E01-S01 where unquoted bash heredoc markers (`<< PYEOF`) allowed variable expansion into embedded Python code -- this required 2 fix cycle rounds to fully resolve because the first fix only addressed 3 of 5 affected heredocs.

## Timeline

| Phase | Time (UTC) | Wall Clock | Activity |
|-------|-----------|------------|----------|
| Design | 23:24 -- 23:55 | ~31m | Designer creates design doc, resolves open questions, adds Fault Tolerance principle (PR 153) |
| Plan | 00:01 -- 00:06 | ~5m | Planner decomposes into 2 epics, 5 stories, 4 waves (PR 162) |
| Wave 1 Build (parallel) | 00:09 -- 00:13 | ~4m | E01-S01 (state.sh core, 4m 29s) + E01-S03 (--overhead, 4m 4s) in parallel |
| Wave 1 Review (E01-S03) | ~00:13 -- ~00:20 | ~7m | E01-S03 review: APPROVE. E01-S01 review: REQUEST_CHANGES (C1-C3 heredoc injection) |
| Fix Cycle 1 (E01-S01) | ~00:20 -- 00:23 | ~3m | Builder fixes C1-C3 with quoted PYEOF and env vars (commit `230d841`) |
| Re-review 1 (E01-S01) | ~00:23 -- ~00:26 | ~3m | Reviewer finds C4-C5 (two more unquoted heredocs): REQUEST_CHANGES |
| Fix Cycle 2 (E01-S01) | ~00:26 -- 00:29 | ~3m | Builder fixes C4-C5, adds mode enum validation (commit `80b3c5a`) |
| Re-review 2 (E01-S01) | ~00:29 -- 00:31 | ~2m | APPROVE -- all 5 heredocs verified |
| Wave 2 Build | 00:31 -- 00:37 | ~6m | E01-S02 (state.sh computation + schema, 6m 5s) |
| Wave 2 Review | ~00:37 -- 00:40 | ~3m | E01-S02 review: APPROVE |
| E01 Merge | 00:40 -- 00:41 | ~1m | Merge E01-S02 into epic, epic into integration branch |
| Wave 3 Build | 00:44 -- 00:56 | ~12m | E02-S01 (orchestrator.md rewrite, 14m 39s, Opus) |
| Wave 3 Review | ~00:56 -- 01:02 | ~6m | E02-S01 review: APPROVE (W1: dropped `gh issue comment` line) |
| Wave 4 Build | 01:03 -- 01:06 | ~3m | E02-S02 (CLAUDE.md updates, 3m 41s) |
| Wave 4 Review | ~01:06 -- ~01:12 | ~6m | E02-S02 review: APPROVE (S1: missing --overhead in helper table) |
| E02 Merge + Changelog | 01:12 -- 01:13 | ~1m | Merge E02 into integration, write changelog |
| **Total** | 23:24 -- 01:13 | **~1h 49m** | |

*Source: `git log` commit timestamps (UTC+10 converted to UTC) and GitHub issue comment timestamps (UTC). Design phase timing is from commit timestamps as no Work Started / Ready for Review comments are posted for design/plan dispatches. The 77m wall-clock in the changelog entry was captured from the orchestrator state file's `lifecycle_duration_ms`.*

## Telemetry

### Per-Story Breakdown

| Story | Issue | Difficulty | Build Model | Build Time | Build Tokens | Build Cost | Review Model | Verdict | Fix Cycles |
|-------|-------|-----------|------------|-----------|-------------|-----------|-------------|---------|------------|
| E01-S01 | 157 | medium | sonnet | 4m 29s | 79K | ~$0.47 | opus | APPROVE (3rd round) | 2 |
| E01-S02 | 158 | medium | sonnet | 6m 5s | 78K | ~$0.47 | opus | APPROVE | 0 |
| E01-S03 | 159 | easy | sonnet | 4m 4s | 75K | ~$0.45 | sonnet | APPROVE | 0 |
| E02-S01 | 160 | hard | opus | 14m 39s | 143K | ~$1.44 | opus | APPROVE | 0 |
| E02-S02 | 161 | medium | sonnet | 3m 41s | 73K | ~$0.44 | opus | APPROVE | 0 |
| **Story Build Total** | | | | **32m 58s** | **448K** | **~$3.27** | | | **2** |

*Note: Build telemetry comes from `item-telemetry.sh` comments on each story issue. Fix cycle telemetry for E01-S01 (2 builder re-dispatches + 2 re-reviews) was not posted as separate telemetry comments -- the durations above reflect only the initial build dispatch. The reviewer posted review comments on the issue but no separate telemetry for fix cycle dispatches. The design phase telemetry was not posted to an issue (no design telemetry convention for interactive design). Plan telemetry was also not posted.*

### Aggregate

| Metric | Value |
|--------|-------|
| Stories completed | 5/5 |
| Python tests written (new) | 26 (compute-dispatches overhead tests) |
| Bash tests written (new) | 48 (state.sh: 20 core + 28 computation; orchestrator.md: 28 validation) |
| JSON Schema files created | 1 (orchestrator-state.v1.json, 236 lines) |
| Critical bugs caught by reviewer | 5 (C1-C5 heredoc injection on E01-S01, all same pattern) |
| Warnings caught by reviewer | 5 (W1-W4 on E01-S01 fix cycles, W1 on E01-S02, W1 on E02-S01, S1 on E02-S02) |
| Fix cycles (story-level) | 2 rounds on E01-S01 (heredoc injection) |
| Fix cycles (PR-level) | 0 (no backlog PR review dispatched before retro) |
| Lines removed from orchestrator.md | 1,023 |
| Lines added to orchestrator.md | 203 |
| Net orchestrator.md reduction | 820 lines (62%) |
| state.sh total lines | 836 |
| Wall clock (from changelog) | 77m |

### Cost by Role

| Role | Duration | Tokens | Est. Cost |
|------|----------|--------|-----------|
| Build (5 stories) | 32m 58s | 448K | ~$3.27 |
| Review (5 stories + fix cycles) | ~27m (est.) | ~350K (est.) | ~$3.30 (est.) |
| Design | ~31m (est.) | unknown | unknown |
| Plan | ~5m (est.) | unknown | unknown |
| **Estimated Total** | ~96m | ~800K+ | ~$6.50+ |

*Note: Reviewer, designer, and planner telemetry was not posted to issue comments for this run. The reviewer dispatches did not have telemetry captured by the orchestrator. Cost estimates for reviews are based on typical Opus review durations from prior runs (observation xiii: reviewer cost ~47.8% of total in infrastructure runs). The actual total is likely higher.*

## What Worked

### 1. Design evolution through interactive brainstorming produced the correct approach

The original backlog issue proposed a straightforward "split into reference docs" approach (Approach A in the design doc). Through interactive brainstorming, the designer identified that 61% of the extractable content was "scripts written in markdown" -- deterministic procedures that should be real scripts, not moved to different markdown files. This insight shifted the approach from reorganization (moving markdown between files) to extraction (turning inline code into real scripts). The Fault Tolerance principle also emerged naturally during the design phase rather than being imposed externally. Evidence: design doc section "Approaches Considered", commits `9f30b0f` and `b67ce7a`.

### 2. Reviewer caught a real security vulnerability through demonstrated exploits

The reviewer on E01-S01 did not just flag the unquoted heredoc markers as a style issue -- they demonstrated working code injection exploits for all three initially-flagged heredocs (C1: `pricing='"""+__import__("os").popen("echo INJECTED").read()+"""'`). This level of rigor is what the review process is designed for. The fix pattern (quoted `'PYEOF'` + env vars + `os.environ[]`) was applied consistently across all 5 heredocs. Evidence: issue 157 review comments.

### 3. E01-S03 first-pass approval validates Sonnet reviewer on easy stories

E01-S03 (compute-dispatches.py --overhead flag, difficulty/easy) was reviewed by `reviewer-sonnet` per the model routing convention. The review was thorough: it verified all 7 acceptance criteria, confirmed 142 tests passed with 0 regressions, noted the 26 new tests covered all three resolution paths, and provided 3 constructive suggestions. This is the first data point for observation N (validate Sonnet reviewer quality on easy stories). Verdict: Sonnet caught everything relevant and the review was indistinguishable in quality from Opus reviews on comparable stories. Evidence: issue 159 review comment.

### 4. Orchestrator.md rewrite achieved exact target with no behavioral changes

The rewrite hit 503 lines (target: ~530, range: 480-580). The 28-check validation test script (`test_orchestrator_md.sh`) confirmed all planned deletions were applied and all preserved sections remain intact. The reviewer verified "no behavioral changes to decision logic" and confirmed every `state.sh` call matches the implemented subcommand signatures. Evidence: commits `54004ed` (tests), `de59a0c` (rewrite), issue 160 review comment.

### 5. Second infrastructure backlog item completed with lower fix rate than first

Backlog 106 (first infrastructure backlog) had 1 story-level fix cycle + 1 PR-level fix cycle across 7 stories. Backlog 150 had 2 fix cycle rounds on 1 story across 5 stories. The E01-S01 fix cycles were for a genuine security issue (not a convention violation), and the organic pattern of "fix C1-C3, reviewer finds C4-C5 in the same pattern" is the correct escalation behavior -- the reviewer's second pass was more thorough precisely because the first fix was incomplete.

## What Didn't Work

### 1. Fix cycle did not address all instances of the vulnerable pattern

The builder's first fix (commit `230d841`) addressed only the 3 heredocs explicitly cited by the reviewer (C1-C3) without grepping the file for all instances of the same pattern. Two additional heredocs in `_cmd_update_story` and `_cmd_update_epic` used the identical unquoted `<< PYEOF` pattern but were not fixed. The reviewer's second review correctly caught C4-C5. This cost an additional fix cycle round (builder re-dispatch + re-review) and ~6 minutes of wall clock. Evidence: commits `230d841` (partial fix) and `80b3c5a` (complete fix), issue 157 review comments.

**Root cause:** The builder treated the reviewer's findings as a checklist of specific locations to fix, rather than recognizing them as symptoms of a file-wide pattern. No convention exists that tells builders to grep for the pattern across the entire file when fixing a pattern-based issue.

### 2. Telemetry data gaps for non-build dispatches

This run has no telemetry for the design, plan, review, or fix cycle dispatches. Only the 5 initial builder dispatches have telemetry posted on their issues. This makes it impossible to compute accurate aggregate cost for the run. Prior infrastructure runs (backlog 105, 106) had full dispatch telemetry because the orchestrator captured Agent tool results. The gap suggests this run's orchestrator did not post telemetry for all dispatch types, or the retro cannot access the state file to reconstruct it.

**Root cause:** The orchestrator state file (`.agentic-workflow/runs/150/orchestrator.json`) is gitignored and not available in this worktree. No telemetry comments were posted on epic issues (155, 156 have 0 comments). The reviewer, designer, and planner dispatches are invisible to the retro agent.

### 3. Reviewer lesson file referenced but not committed

The E01-S01 reviewer's verdict comment states: "A lesson file has been written at `docs/4-reviews/lessons/150-split-orchestrator-md/e01-script-extraction/2026-03-17-s01-python-heredoc-injection.md`." However, this file does not exist on the integration branch. The reviewer either wrote it to a worktree that was cleaned up, or the file was not committed/pushed. The retro agent created this lesson file as part of this retro. Evidence: `git ls-tree -r origin/backlog/150-split-orchestrator-md -- docs/4-reviews/lessons/150-split-orchestrator-md/` returns no results.

**Root cause:** Reviewer agents operate in worktree isolation. Files written to the worktree are lost when the worktree is cleaned up unless they are committed and pushed to the story/epic branch. The reviewer agent instructions do not include an explicit step to commit lesson files to the branch before completing.

## Workflow Evolution During Epic

| Commit | Change | Trigger |
|--------|--------|---------|
| `fec56dd` | Added "Fault Tolerance" design principle to CLAUDE.md | Design doc identified recovery from interruptions as a core principle missing from conventions |
| `fec56dd` | Added `state.sh` to CLAUDE.md helper scripts table | New script created in E01 |
| `fec56dd` | Replaced inline state code in CLAUDE.md with `state.sh` calls | E02-S02 convention propagation |
| `de59a0c` | Removed System Prompt Hardening from orchestrator.md | Dead code from NeuralNorris era (no `SdlcWorkflowTool` or `ClaudeDispatchTool` exist) |
| `de59a0c` | Removed legacy manual telemetry method from orchestrator.md | `--dispatches-from-state` is the only supported path; `state.sh reconstruct` replaces manual fallback |
| `de59a0c` | Removed Gantt color tagging table from orchestrator.md | `compute-dispatches.py` assigns colors automatically |

## Key Learnings

### For Builders

1. **When fixing a pattern-based bug, grep the entire file for all instances of the pattern before committing the fix.** The E01-S01 fix addressed only the 3 explicitly cited heredocs, missing 2 more with the same vulnerability. A simple `grep -n '<< [^'"'"']' scripts/state.sh` would have found all 5 in one pass.
2. **Always quote heredoc markers when embedding code in bash.** `python3 << 'PYEOF'` prevents shell expansion; `python3 << PYEOF` does not. Pass data via environment variables (`export _VAR; os.environ["_VAR"]`), not shell interpolation.

### For the Orchestrator

1. **Post telemetry for all dispatch types, not just builders.** This run's design, plan, review, and fix cycle dispatches have no telemetry on issue comments, making the retro's cost analysis incomplete. The convention in CLAUDE.md says "capture telemetry even from failed or usage-limited dispatches" but does not explicitly list design/plan/review.
2. **Reviewer lesson files need a commit step.** The reviewer's lesson file was written in the worktree but never committed. Consider adding a convention that reviewers commit lessons to the story branch before completing, or that the orchestrator checks for uncommitted lesson files post-review.

### For the Workflow

1. **Interactive design produces better architectural decisions than autonomous for refactoring work.** The design evolved from "split into reference docs" to "extract inline scripts" through Q&A that challenged the initial assumption. Autonomous mode would have accepted the backlog issue's proposed approach (Approach A) without this critical re-evaluation.
2. **Observation v (orchestrator.md size) is now resolved.** The file was tracked as an observation since Run 11 at ~1000 lines, growing to 1,323 by backlog 105. It is now 503 lines -- below the 200-line guideline per file still, but no longer the outlier it was. The observation can be moved to "implemented" in the recommendations tracker.

## Recommendations

1. **Add "grep for pattern" convention to builder fix cycle instructions** -- When a reviewer flags a pattern-based bug (same vulnerability in multiple locations), the builder's fix cycle should include `grep -rn '<pattern>' <file>` to find all instances before committing. This prevents the "fix 3 of 5, get re-reviewed, fix remaining 2" cycle observed in E01-S01. Evidence: 2 fix cycle rounds on issue 157 (C1-C3 fixed, C4-C5 missed, then C4-C5 fixed).

2. **Add "always quote heredoc markers" convention to builder/reviewer instructions** -- The `python3 << 'PYEOF'` pattern is a security-critical convention for any bash script that embeds Python, Ruby, or Perl. Add to builder.md: "When writing bash heredocs that embed another language, always quote the delimiter to prevent shell expansion." Add to reviewer.md checklist: "Verify all heredoc markers in bash scripts are quoted when the body contains non-bash code." Evidence: 5 critical issues (C1-C5) on issue 157.

3. **Require reviewer agents to commit lesson files before completing** -- The reviewer on E01-S01 wrote a lesson file but it was lost when the worktree was cleaned up. Add to reviewer.md: "If you write a lesson file, commit it to the story branch (`git add <lesson> && git commit -m 'docs(lesson): <summary>'`) before posting your review verdict." Evidence: lesson file referenced in issue 157 review comment but absent from integration branch.

4. **Update observation v (orchestrator.md size) to implemented** -- The observation tracked orchestrator.md growth from ~1000 lines (Run 11) to 1,323 (backlog 105). Backlog 150 reduced it to 503 lines. The monitoring threshold ("consider extraction at 1500 lines") is no longer relevant. Move to the Implemented table with reference to this backlog item.

## Lesson Retention

| Lesson | Status | Notes |
|--------|--------|-------|
| `e01-script-extraction/2026-03-17-s01-python-heredoc-injection.md` | Active -- proposed as convention change (rec 2) | Created by retro agent; the reviewer's original file was lost |

The heredoc injection lesson is the primary lesson from this backlog item. It represents a genuine security pattern that should be codified in builder and reviewer conventions. No other lesson files were written during the run.
