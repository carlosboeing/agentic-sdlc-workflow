# Retro Recommendations Tracker

Consolidated tracker for all recommendations from workflow retrospectives. Updated manually after each retro — the retro agent should append new recommendations here, and the orchestrator should check this document before each run.

Last updated: 2026-03-17 (compiled from Runs 2-16 + backlogs 105, 106, 150)

---

## Outstanding (not yet implemented)

### M. Fix bash operator precedence bug in batch-set-status.sh verification

- **Source:** Backlog 105 (PR 143 review W3)
- **Recurrence:** 1 run (new script)
- **Priority:** Medium
- **Description:** In `scripts/batch-set-status.sh` line ~113-115, the verification phase's skip guard `[ -z "$item_id" ] || [ "$item_id" = "null" ] && continue` has incorrect operator precedence. The `&&` binds tighter than `||`, so empty item IDs are not skipped correctly. Fix: `{ [ -z "$item_id" ] || [ "$item_id" = "null" ]; } && continue`. The bug is non-critical (the script still exits 0 and the Phase 2 mutation handles the case), but it may produce spurious error messages during verification.
- **Effort:** Low (one-line fix)

### N. Validate Sonnet reviewer quality on easy stories

- **Source:** Backlog 105 retro (rec 3)
- **Recurrence:** 3 runs (BL150, Run 16) -- trending toward observation
- **Priority:** Low -- third positive data point, ready to move to observation
- **Description:** Backlog 105 implemented reviewer routing (Sonnet for easy, Opus for medium/hard) but could not use it in the same session (Claude Code loads agents at session start only). BL150 E01-S03 (difficulty/easy) was the first story reviewed by `reviewer-sonnet`. The review was thorough: verified all 7 acceptance criteria, confirmed 142 tests passed, provided 3 constructive suggestions, and the verdict (APPROVE) was correct. Run 16 added 5 sonnet reviews across 4 easy stories: E01-S01 (APPROVE with 1W/1S), E01-S04 (APPROVE with 2W), E02-S02 initial (REQUEST_CHANGES with 3W -- caught genuine format issues), E02-S02 re-review (APPROVE), E03-S01 (APPROVE). Notably, the E02-S02 REQUEST_CHANGES demonstrated that sonnet reviewers can catch real defects, not just approve everything. Three positive data points across 6 reviews -- ready to move to observation on next run.
- **Effort:** None (monitoring only)

### O. Add `Files to modify` boundary enforcement to builder instructions

- **Source:** Backlog 106 (rec 1)
- **Recurrence:** 1 run (E01-S03 scope creep into E01-S04's files)
- **Priority:** Medium
- **Description:** Builders should treat the story issue's `Files to modify` section as a hard constraint. When E01-S03 modified `issue-telemetry.sh` (which was E01-S04's scope), it pre-completed half of E01-S04's acceptance criteria and created downstream confusion. Builders should flag to the orchestrator if they need to modify files outside their listed scope, rather than silently doing so.
- **Effort:** Low (builder.md instruction update)

### P. Consider model routing for docs-only reviewers

- **Source:** Backlog 106 (rec 2)
- **Recurrence:** 1 run (observation)
- **Priority:** Low
- **Description:** E02's three docs-only stories consumed ~$1.00 in Opus reviewer cost for straightforward convention documentation changes. A `difficulty/easy` + `type/docs` combination could route to a Sonnet reviewer instead of inheriting the orchestrator's Opus model, saving ~40% on review cost for low-risk stories. Needs validation that Sonnet reviews catch convention violations as reliably as Opus.
- **Effort:** Medium (requires reviewer variant files + routing logic)

### Q. Split large test files across stories in plans

- **Source:** Backlog 106 (rec 3)
- **Recurrence:** 1 run (E01-S02 + E01-S03 merge conflict on test file)
- **Priority:** Low
- **Description:** When parallel stories add tests to the same file, merge conflicts are likely. Plans should specify separate test files per story (e.g., `test_gantt.py`, `test_fix_cycles.py`) or non-overlapping insertion points to avoid conflicts on test file boundaries.
- **Effort:** Low (planner guideline)

### R. Add post-merge `python3 <test_file>` check for Python test suites

- **Source:** Backlog 106 (rec 4)
- **Recurrence:** 1 run (premature `__name__` block in test file skipped 35 of 123 tests)
- **Priority:** Medium
- **Description:** A misplaced `if __name__ == "__main__"` block at line 1076 caused `unittest.main()` to exit before loading Gantt test classes defined after line 1078. All 123 tests passed with pytest but only 88 passed with `python3` direct execution. Add a convention that Python test files must pass both runners, ensuring the `__name__` guard is at the end of the file.
- **Effort:** Low (convention + optional CI check)

### S. Add "grep for pattern" convention to builder fix cycle instructions

- **Source:** Backlog 150 (rec 1)
- **Recurrence:** 1 run (E01-S01 required 2 fix cycle rounds because builder only fixed 3 of 5 vulnerable heredocs)
- **Priority:** Medium
- **Description:** When a reviewer flags a pattern-based bug (same vulnerability in multiple locations), the builder's fix cycle should include a file-wide grep for the pattern before committing. E01-S01's builder fixed the 3 explicitly cited heredocs (C1-C3) but missed 2 more with the identical unquoted `<< PYEOF` pattern. The reviewer's second review found C4-C5, adding ~6 minutes of wall clock. Add to builder.md: "When fixing a pattern-based bug, grep the entire file (and related files) for all instances of the pattern before committing."
- **Effort:** Low (builder.md instruction update)

### T. Add "always quote heredoc markers" convention

- **Source:** Backlog 150 (rec 2)
- **Recurrence:** 1 run (5 critical heredoc injection vulnerabilities in a single script)
- **Priority:** High
- **Description:** Unquoted bash heredoc markers (`python3 << PYEOF`) allow shell variable expansion into the heredoc body, enabling code injection. The fix pattern is: quote the marker (`<< 'PYEOF'`), pass data via environment variables, read with `os.environ[]` in Python. Add to builder.md: "Always quote heredoc delimiters when embedding another language in bash." Add to reviewer.md checklist: "Verify all heredoc markers in bash scripts are quoted when the body contains non-bash code." Evidence: 5 critical issues on issue 157, lesson file `150-split-orchestrator-md/e01-script-extraction/2026-03-17-s01-python-heredoc-injection.md`.
- **Effort:** Low (builder.md + reviewer.md instruction updates)

### U. Require reviewer agents to commit lesson files before completing

- **Source:** Backlog 150 (rec 3)
- **Recurrence:** 1 run (reviewer wrote lesson file in worktree, file lost on cleanup)
- **Priority:** Low
- **Description:** The E01-S01 reviewer stated it wrote a lesson file at a specific path, but the file was never committed to the branch. Worktree-isolated agents' file writes are lost when the worktree is cleaned up. Add to reviewer.md: "If you write a lesson file, commit and push it to the story branch before posting your verdict."
- **Effort:** Low (reviewer.md instruction update)

### V. Add per-story word count calibration to planner instructions

- **Source:** Run 16 (rec 1)
- **Recurrence:** 2 runs (Run 14 E01-S04 word count fix cycle, Run 16 all 3 fix cycles related to word count vs. format templates)
- **Priority:** Medium
- **Description:** When the planner assigns word count ranges in acceptance criteria, they should account for the format template's structural overhead. Stories with heavy repeated templates (7 character bios, 9 orchestra entries) have a structural floor that may exceed 60% of the word ceiling, making the standard 300-500 range infeasible without sacrificing content quality. The planner should compute per-story ranges based on template complexity. Evidence: Run 16 had 3/3 fix cycles caused by word count pressure (issues 177, 178, 183).
- **Effort:** Low (planner.md instruction update)

### W. Add interruption tracking to orchestrator dispatch records

- **Source:** Run 16 (rec 3)
- **Recurrence:** 1 run (first observed interruption -- E02-S01 CC mobile remote control issue)
- **Priority:** Low
- **Description:** When an agent is interrupted and re-dispatched, the orchestrator should record the interruption event in the state file. Currently, the only trace is a timestamp gap between dispatches. Adding an `interrupted` flag or a separate dispatch entry for the interrupted session would improve traceability and make it possible to compute accurate costs (interrupted sessions consume tokens that are not captured). Evidence: 22-minute gap between dispatch 4 completion (10:06:10) and dispatch 5 start (10:27:51) on issue 177.
- **Effort:** Low (state.sh schema update + orchestrator convention)

### X. Add epic-level telemetry posting to orchestrator checklist

- **Source:** Run 16 (rec 4)
- **Recurrence:** 1 run (convention exists in CLAUDE.md but was not followed)
- **Priority:** Medium
- **Description:** The orchestrator must post telemetry on each epic issue when all its stories complete (per CLAUDE.md "Per-epic telemetry" convention). Run 16 did not post epic telemetry on issues 172, 173, or 174. Add a checklist item to the orchestrator's post-wave merge step to ensure this is not skipped. This provides intermediate checkpoints during long runs and makes per-epic cost analysis available without recomputing from the state file.
- **Effort:** Low (orchestrator.md checklist addition)

---

## Implemented


| #   | Recommendation                                                       | Source        | Implemented In                                    |
| --- | -------------------------------------------------------------------- | ------------- | ------------------------------------------------- |
| 1   | Orchestrator owns all board transitions in autonomous mode           | Run 3         | CLAUDE.md, orchestrator.md                        |
| 2   | Add `Bash` to planner agent tool list                                | Run 3         | Commit `cfb2231`                                  |
| 3   | Add `Bash` to designer agent tool list                               | Run 4         | Subsequent agent update                           |
| 4   | Require `isolation: "worktree"` for parallel builder dispatch        | Runs 4, 7     | CLAUDE.md convention                              |
| 5   | Builder agents must not merge story branches into epic               | Run 4         | Builder agent instructions                        |
| 6   | Add `git add -f` guidance for gitignored `test-output/` paths        | Run 4         | Builder agent instructions                        |
| 7   | Add `backlog/<N>-<slug>` label to design/plan issues                 | Run 5         | Designer/planner instructions                     |
| 8   | Add `e00-setup/` lesson folder convention for pre-epic lessons       | Run 5         | CLAUDE.md lesson conventions                      |
| 9   | Builders must verify word counts before committing                   | Run 3         | Builder agent instructions                        |
| 10  | Cross-story consistency contracts in plans                           | Runs 3, 5     | Planner convention                                |
| 11  | `tr -d '\x00-\x1f'` pipe for `gh project item-list` output           | Run 7         | CLAUDE.md convention                              |
| 12  | Worktree cleanup step after parallel dispatch                        | Run 8         | CLAUDE.md convention                              |
| 13  | Builder must push to remote in worktree mode                         | Run 8         | CLAUDE.md convention                              |
| 14  | CLI dispatch scope clarified (standalone terminal only)              | Run 2         | CLAUDE.md convention                              |
| 15  | All story issues included in backlog PR `Closes` list                | Run 2         | CLAUDE.md convention                              |
| 16  | `--cost` flag on `issue-telemetry.sh` for mixed-model epics          | Run 2         | Script updated                                    |
| 17  | Reviewer dispatch is mandatory (no skip option)                      | Run 2         | CLAUDE.md + orchestrator.md                       |
| 18  | Single-PR workflow (`backlog/<N>-<slug>` to `main`)                  | Run 6         | CLAUDE.md convention                              |
| 19  | Fix artifact matching to use YAML frontmatter grep                   | Run 10        | orchestrator.md updated                           |
| 20  | Replace `item-list` with per-issue GraphQL in `issue-set-status.sh`  | Run 10        | Pre-Run 11 commit `487b382`                       |
| 21  | `issue-create-backlog.sh` for consolidated backlog item setup        | Run 10 lesson | Pre-Run 11 commit `0785196`                       |
| 22  | Story branches created from recorded epic base before parallel waves | Run 9         | CLAUDE.md convention                              |
| 23  | Audit agent tool lists when instructions reference CLI commands      | Run 3         | CLAUDE.md convention                              |
| 24  | Post-wave comment verification for parallel builders                 | Runs 4, 11    | CLAUDE.md convention (Run 11)                     |
| 25  | Document `gh project item-add` does not set default status           | Run 11        | CLAUDE.md convention (Run 11)                     |
| 26  | GraphQL rate limit awareness convention in CLAUDE.md                 | Runs 6-8, 10  | CLAUDE.md (pre-Run 11), `issue-set-status.sh` fix |
| 27  | Remove duplicated status option IDs from orchestrator.md             | Run 6         | orchestrator.md (Run 11 post-run cleanup)         |
| 28  | Parallel review dispatch for independent stories                     | Run 6         | Validated in Run 11 Wave 3 (3 parallel reviews)   |
| 29  | Inline Gantt color tagging rules in orchestrator.md                  | Run 11        | orchestrator.md + CLAUDE.md (Run 11 post-run fix) |
| 30  | Move backlog In Progress transition to Phase 1 (Design)              | Run 12        | orchestrator.md (Run 12 retro)                    |
| 31  | Extend post-worktree cleanup to fix cycle dispatches                 | Run 14        | CLAUDE.md + orchestrator.md (Run 14)              |
| E   | Format templates for cross-story parallel content                    | Runs 5, 12    | planner.md "Format Templates" section (backlog 105) |
| F   | Document orchestrator override pattern for pre-fixed reviewer findings | Runs 9, 14  | orchestrator.md "Orchestrator Override Pattern" section (backlog 105) |
| G   | Track autonomous lifecycle duration baseline                         | Run 9 (rec G) | Backlog 106 E02-S03: `lifecycle_duration_ms` in state schema + changelog duration convention |
| H   | Capture orchestrator overhead metrics (wall-clock heuristic)         | Run 10        | CLAUDE.md + orchestrator.md (backlog 105)         |
| I   | Extract dispatch computation from issue-telemetry.sh                 | Run 12 (rec I) | Backlog 106 E01-S01 through E01-S04: `compute-dispatches.py` (875 lines, 123 tests) |
| L   | Track fix cycle overhead as per-run metric                           | Run 14 (rec L) | Backlog 106 E01-S03: structured `fix_cycles` object in `compute-dispatches.py` output |


---

## Observations (no convention change warranted)


| #    | Observation                                                                        | Source                           | Notes                                                                                                                                                                                                                                                                                                |
| ---- | ---------------------------------------------------------------------------------- | -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| i    | Haiku uses 3-4x more tokens than Sonnet for comparable tasks                       | Runs 3, 6, 7, 8, 9, 10, 11       | Consistent across 7 runs. Cost is comparable due to 3x lower per-token rate. No model routing change warranted.                                                                                                                                                                                      |
| ii   | Stories with detailed acceptance criteria achieve low organic fix cycles           | Runs 5, 6, 9-14, BL105, BL106, Run 16 | 62+ stories tracked. BL150: 1 organic fix cycle (heredoc injection, security pattern invisible to tests). Run 16: 2 organic fix cycles (E02-S01 format contract, E02-S02 word count + missing sections) plus 1 planted bug cycle (E02-S03). Both organic cycles trace to word count ceiling vs. format template overhead, not builder error. Organic fix cycle rate: 3/62 stories (4.8%). All organic fix cycles are pattern-based (security or format), not logic errors. |
| iii  | CHANGELOG conflicts with per-epic PRs                                              | Run 5                            | Moot -- switched to single-PR model in Run 6.                                                                                                                                                                                                                                                         |
| iv   | Board status "drift" caused by GitHub default project automation                   | Runs 3-16                         | **Root cause found (Run 16):** GitHub's built-in "Pull request linked to issue" automation reverts Done→In Progress when the backlog PR references already-closed doc issues via `Closes` keywords. Not an API bug — an automation conflict. Fix: (1) don't use `Closes` on already-closed issues, (2) `reconcile-board.sh` for defense-in-depth. See CLAUDE.md "Link all issues to the PR" convention. |
| v    | `orchestrator.md` reduced from 1,323 to 503 lines (62%)                            | Runs 11, BL105, BL150            | Was ~1000 lines at Run 11, grew to 1,323 by BL105. BL150 extracted inline scripts to `state.sh`, deleted dead code (System Prompt Hardening), and condensed verbose sections. Now 503 lines. The monitoring threshold ("consider extraction at 1500 lines") is no longer relevant. |
| vi   | Reviewer doesn't reference the recommendations tracker for known patterns          | Run 11                           | Reviewer greps raw lesson files; the compiled tracker would be more efficient. Low priority -- current approach works.                                                                                                                                                                                |
| vii  | Average tokens per build story: convention work uses more tokens than content       | Runs 13, 14, BL105               | Content stories: Run 13 averaged 43K tokens/build, Run 14 averaged 43K (excl. fix cycles). Convention/docs stories (BL105): averaged 68K tokens/build. S02 (easy docs change) used 90K due to Edit tool worktree issues. Higher token usage likely reflects reading existing large files (orchestrator.md, CLAUDE.md) for context. |
| viii | Fix cycles add 70-100% overhead per affected story                                | Runs 14, 16                      | Run 14: E01-S04 +181% (2 rounds), E02-S01 +66% (1 round). Total: $1.53 / $11.34 = 13.5%. Run 16: E02-S01 +100%, E02-S02 +79%, E02-S03 +71% (all single-round). Total: $2.85 / $13.78 = 20.7%. Single-round fix cycles average ~80% overhead. Multi-round (Run 14 E01-S04) can exceed 180%. Run 16's higher percentage reflects 3/9 stories having fix cycles vs. Run 14's 2/12. |
| ix   | Builders prioritize acceptance criteria over story descriptions when they conflict | Run 14                           | 2/4 planted bugs neutralized because builders followed AC. Correct behavior -- AC is the binding contract. Rec K (document as convention) declined: this only surfaced during deliberate bug planting, not organic usage. Already captured in builder.md as existing behavior ("Acceptance criteria take precedence over story descriptions"). |
| x    | Self-referential convention changes succeed without fix cycles                      | BL105                            | First run where agents modified their own instructions (orchestrator.md, CLAUDE.md, planner.md, config). 6/6 stories passed review on first attempt. Separation of concerns (designer/planner/builder/reviewer) works even when the target is the pipeline's own conventions.                          |
| xi   | Reviewer variants created mid-session are unusable until next session               | BL105                            | S01 created reviewer-sonnet.md and reviewer-opus.md, but Claude Code only loads agent files at session start. All 7 reviews used the base reviewer agent with Opus. Feature takes effect on the next run. Known platform limitation (CLAUDE.md "Dynamic agent files at runtime").                      |
| xii  | Infrastructure refactoring stories take 3-4x longer than content-creation stories | BL106                            | Average build duration: 11m 6s (infrastructure) vs ~3m 40s (content, Run 14). Average tool uses: 134/story vs ~56/story. Infrastructure builders must read existing code, understand dependencies, and write tests. First infrastructure backlog item in the workflow. |
| xiii | Reviewer cost dominates total cost in infrastructure runs (47.8% of total)        | BL106                            | All reviewers inherit orchestrator's Opus model. Reviewers consumed $6.65 of $13.92 total (47.8%) despite only 28.7% of duration. For infrastructure where correctness is critical, Opus review is appropriate. For docs-only stories, may be overkill (see rec P). |
| xiv  | PR-level review catches structural bugs invisible to story-level reviews          | BL106                            | Premature `if __name__` block at line 1076 of test file caused 35/123 tests to be skipped. Each story reviewer only saw their own additions and missed the structural issue. The PR reviewer saw the full file and caught it. Validates two-tier review model. |
| xv   | Interactive design produces better architectural decisions than autonomous for refactoring | BL150                   | Design evolved from "split into reference docs" (original backlog proposal) to "extract inline scripts" through interactive Q&A. The designer's critical analysis revealed 61% of extractable content was "scripts written in markdown." Autonomous mode would have accepted the initial approach without this re-evaluation. For greenfield or content work, autonomous is efficient; for refactoring existing infrastructure, interactive design yields superior results. |
| xvi  | First organic fix cycle in the workflow was for a security pattern invisible to tests | BL150                        | E01-S01 had 2 fix cycle rounds for heredoc injection (5 critical issues). This is the first non-planted fix cycle in 53+ stories. The vulnerability (unquoted bash heredoc markers) is invisible to functional tests because bash variable expansion happens before Python execution. The reviewer demonstrated working exploits. This validates the review process: reviewers catch classes of bugs that tests cannot. |
| xvii | Incomplete fix cycle pattern: builders fix only cited locations, not file-wide pattern | BL150                       | E01-S01 fix cycle 1 addressed 3 of 5 vulnerable heredocs (the 3 explicitly cited by the reviewer). The builder did not grep for the pattern across the file. Fix cycle 2 was needed to catch the remaining 2. This "fix the cited lines, not the pattern" behavior cost ~6 minutes of additional wall clock. See rec S for proposed convention. |
