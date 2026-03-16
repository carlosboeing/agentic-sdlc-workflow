# Retro Recommendations Tracker

Consolidated tracker for all recommendations from workflow retrospectives. Updated manually after each retro — the retro agent should append new recommendations here, and the orchestrator should check this document before each run.

Last updated: 2026-03-16 (compiled from Runs 2-14 + backlogs 105, 106)

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
- **Recurrence:** 1 run (first implementation)
- **Priority:** Medium
- **Description:** Backlog 105 implemented reviewer routing (Sonnet for easy, Opus for medium/hard) but could not use it in the same session (Claude Code loads agents at session start only). The next run will be the first to dispatch `reviewer-sonnet` for easy stories. Monitor for false negatives (issues Sonnet misses that Opus would catch). Design doc assumption: across Runs 8-14, zero easy-story reviews found critical issues that required Opus-level analysis.
- **Effort:** None (monitoring only in next run)

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
| ii   | Stories with detailed acceptance criteria achieve zero organic fix cycles          | Runs 5, 6, 9-14, BL105           | 46+ consecutive first-pass approvals across content-creation AND self-referential convention work. Run 14 had 2 fix cycles from deliberate bug planting. Backlog 105 added 6 more (self-modifying agent instructions) with 0 fix cycles. Organic fix cycle rate remains 0%.                           |
| iii  | CHANGELOG conflicts with per-epic PRs                                              | Run 5                            | Moot -- switched to single-PR model in Run 6.                                                                                                                                                                                                                                                         |
| iv   | Board status persistence bug (mutations succeed, statuses revert later)            | Runs 3, 10, 12, 14               | Run 11 created `check-board-drift.sh`; Run 12 confirmed drift (all stories + closed issues reverted to In Progress). Run 14: all 18 issues reverted to In Progress despite successful `issue-set-status.sh` calls. Orchestrator now has mandatory post-run verification step -- confirmed essential. |
| v    | `orchestrator.md` now at 1270 lines -- largest agent file by 6.4x                  | Runs 11, BL105                   | Was ~1000 lines at Run 11. Backlog 105 added +185 lines (Phase 4 branch creation, overhead computation, override pattern, state schema). State schema (~200 lines), board management examples, and code snippets could move to a reference doc. Monitor for readability; consider extraction at 1500 lines. |
| vi   | Reviewer doesn't reference the recommendations tracker for known patterns          | Run 11                           | Reviewer greps raw lesson files; the compiled tracker would be more efficient. Low priority -- current approach works.                                                                                                                                                                                |
| vii  | Average tokens per build story: convention work uses more tokens than content       | Runs 13, 14, BL105               | Content stories: Run 13 averaged 43K tokens/build, Run 14 averaged 43K (excl. fix cycles). Convention/docs stories (BL105): averaged 68K tokens/build. S02 (easy docs change) used 90K due to Edit tool worktree issues. Higher token usage likely reflects reading existing large files (orchestrator.md, CLAUDE.md) for context. |
| viii | Fix cycles more than double the cost of affected stories                           | Run 14                           | E01-S04: +181% overhead (2 fix cycles). E02-S01: +66% overhead (1 fix cycle). Total fix overhead: $1.53 / $11.34 = 13.5% of run cost. First data point -- track across future runs with organic (non-planted) fix cycles.                                                                            |
| ix   | Builders prioritize acceptance criteria over story descriptions when they conflict | Run 14                           | 2/4 planted bugs neutralized because builders followed AC. Correct behavior -- AC is the binding contract. Rec K (document as convention) declined: this only surfaced during deliberate bug planting, not organic usage. Already captured in builder.md as existing behavior ("Acceptance criteria take precedence over story descriptions"). |
| x    | Self-referential convention changes succeed without fix cycles                      | BL105                            | First run where agents modified their own instructions (orchestrator.md, CLAUDE.md, planner.md, config). 6/6 stories passed review on first attempt. Separation of concerns (designer/planner/builder/reviewer) works even when the target is the pipeline's own conventions.                          |
| xi   | Reviewer variants created mid-session are unusable until next session               | BL105                            | S01 created reviewer-sonnet.md and reviewer-opus.md, but Claude Code only loads agent files at session start. All 7 reviews used the base reviewer agent with Opus. Feature takes effect on the next run. Known platform limitation (CLAUDE.md "Dynamic agent files at runtime").                      |
| xii  | Infrastructure refactoring stories take 3-4x longer than content-creation stories | BL106                            | Average build duration: 11m 6s (infrastructure) vs ~3m 40s (content, Run 14). Average tool uses: 134/story vs ~56/story. Infrastructure builders must read existing code, understand dependencies, and write tests. First infrastructure backlog item in the workflow. |
| xiii | Reviewer cost dominates total cost in infrastructure runs (47.8% of total)        | BL106                            | All reviewers inherit orchestrator's Opus model. Reviewers consumed $6.65 of $13.92 total (47.8%) despite only 28.7% of duration. For infrastructure where correctness is critical, Opus review is appropriate. For docs-only stories, may be overkill (see rec P). |
| xiv  | PR-level review catches structural bugs invisible to story-level reviews          | BL106                            | Premature `if __name__` block at line 1076 of test file caused 35/123 tests to be skipped. Each story reviewer only saw their own additions and missed the structural issue. The PR reviewer saw the full file and caught it. Validates two-tier review model. |
