# Retro Recommendations Tracker

Consolidated tracker for all recommendations from workflow retrospectives. Updated manually after each retro — the retro agent should append new recommendations here, and the orchestrator should check this document before each run.

Last updated: 2026-03-19 (compiled from Runs 2-16 + backlogs 105, 106, 109, 111, 150, 227)

---

## Outstanding (not yet implemented)

### M. Fix bash operator precedence bug in batch-set-status.sh verification

- **Source:** Backlog 105 (PR 143 review W3)
- **Recurrence:** 1 run (new script)
- **Priority:** Low -- partially resolved by BL109 rewrite
- **Description:** In `scripts/batch-set-status.sh` line ~113-115, the verification phase's skip guard `[ -z "$item_id" ] || [ "$item_id" = "null" ] && continue` has incorrect operator precedence. The `&&` binds tighter than `||`, so empty item IDs are not skipped correctly. Fix: `{ [ -z "$item_id" ] || [ "$item_id" = "null" ]; } && continue`. The bug is non-critical (the script still exits 0 and the Phase 2 mutation handles the case), but it may produce spurious error messages during verification.
- **Update (BL109):** `batch-set-status.sh` was rewritten as a thin wrapper delegating to `pm_batch_set_status` in `board.sh` (commit `511a489`). The original buggy code is no longer in the wrapper. The operator precedence pattern should be verified in the adapter's `pm_batch_set_status` implementation to ensure the bug was not ported.
- **Effort:** Low (verification only)

### N. Validate Sonnet reviewer quality on easy stories

- **Source:** Backlog 105 retro (rec 3)
- **Recurrence:** 4 runs (BL150, Run 16, BL109) -- moved to observation
- **Priority:** Low -- fourth positive data point, promoted to observation xviii
- **Description:** Backlog 105 implemented reviewer routing (Sonnet for easy, Opus for medium/hard) but could not use it in the same session (Claude Code loads agents at session start only). BL150 E01-S03 (difficulty/easy) was the first story reviewed by `reviewer-sonnet`. The review was thorough: verified all 7 acceptance criteria, confirmed 142 tests passed, provided 3 constructive suggestions, and the verdict (APPROVE) was correct. Run 16 added 5 sonnet reviews across 4 easy stories. BL109 added 6 Sonnet reviews on infrastructure code (not just content). E01-S06 Sonnet reviewer issued REQUEST_CHANGES with 2 critical issues (unchecked GraphQL exit code, silenced label creation errors) -- both genuine correctness bugs in production adapter code. This demonstrates Sonnet reviewers can catch real infrastructure defects. Four positive data points across 12+ reviews -- promoted to observation.
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
- **Recurrence:** 2 runs (BL150 E01-S01: 2 fix cycle rounds for heredocs; BL111 E01-S01: 2 fix cycle rounds for awk -v)
- **Priority:** Medium -- elevated due to second occurrence
- **Description:** When a reviewer flags a pattern-based bug (same vulnerability in multiple locations), the builder's fix cycle should include a file-wide grep for the pattern before committing. BL150 E01-S01's builder fixed the 3 explicitly cited heredocs (C1-C3) but missed 2 more with the identical pattern. BL111 E01-S01's builder fixed `_local_fm_write` with ENVIRON but left `_local_fm_append_label` using `-v` in the same file. Both required a second fix cycle round (~6 min BL150, ~8 min BL111). Add to builder.md: "When fixing a pattern-based bug, grep the entire file (and related files) for all instances of the pattern before committing."
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
- **Recurrence:** 2 runs (Run 16, BL109 -- pattern confirmed)
- **Priority:** Medium -- elevated due to second occurrence
- **Description:** The orchestrator must post telemetry on each epic issue when all its stories complete (per CLAUDE.md "Per-epic telemetry" convention). Run 16 did not post epic telemetry on issues 172, 173, or 174. BL109 did not post epic telemetry on issues 190, 191, or 192. Add a checklist item to the orchestrator's post-wave merge step to ensure this is not skipped. This provides intermediate checkpoints during long runs and makes per-epic cost analysis available without recomputing from the state file.
- **Effort:** Low (orchestrator.md checklist addition)

### Y. Cap design phase dispatches for autonomous infrastructure items

- **Source:** Backlog 109 retro (rec 2)
- **Recurrence:** 1 run (first infrastructure design in autonomous mode)
- **Priority:** Low
- **Description:** BL109's design phase consumed 10 dispatches and $7.05 (37% of total cost). Most of the cost was driven by usage limit interruptions forcing context re-reading (~40-75K tokens per restart). For infrastructure items with complex scope, consider a convention: if the design phase exceeds N dispatches or $X cost, pause and alert the human. This preserves autonomous workflow for normal items while adding a circuit breaker for edge cases. See also observation xv (interactive design may be superior for infrastructure refactoring).
- **Effort:** Low (orchestrator convention)

### Z. Add shared test helpers for adapter test files

- **Source:** Backlog 109 retro (rec 4)
- **Recurrence:** 1 run (4+ adapter test files with duplicated helpers)
- **Priority:** Low
- **Description:** Four adapter test files independently implement `build_mock_env`, `assert_equals`, and `assert_contains` helpers (40-60 lines each). Extracting these into a shared `tests/scripts/test-helpers.sh` would reduce duplication (~200 lines) and standardize the test pattern. Test files range from 188 to 593 lines. Low priority -- the duplication is not causing bugs, just maintenance burden.
- **Effort:** Low (extract shared helpers)

### AA. Track `hierarchy/docs` label in setup-labels.sh

- **Source:** Backlog 109 E01-S03 review (S1)
- **Recurrence:** 1 run (design gap, not builder error)
- **Priority:** Low
- **Description:** `pm_create_item docs "X"` maps to a `hierarchy/docs` label that does not exist in `setup-labels.sh`. If the `docs` level is used in production, the label must be created first. Currently the designer and planner create doc issues with `type/docs` label, not `hierarchy/docs`, so this is not a live issue. Track for when the `docs` level is first used via `pm_create_item`.
- **Effort:** Low (add label to setup-labels.sh)

### AB. Amend the 200-line convention to exempt or raise the limit for test files

- **Source:** Backlog 111 retro (rec 1)
- **Recurrence:** 2 runs (BL111: 3 of 5 fix cycles triggered by test file size; BL109 E01-S01 review also flagged test file at 485 lines)
- **Priority:** Medium -- caused 3 fix cycle rounds at ~$1.50 and ~10 min wall clock in BL111 alone
- **Description:** The 200-line convention was designed for implementation files. Test files routinely exceed it (BL111: items 690, reconcile 601, lifecycle 475, board 419). Splitting test files adds overhead (duplicated helpers) without the modularity benefit. Proposed: "Implementation files under 200 lines. Test files under 700 lines." Or: clarify the convention applies to implementation files only and update AC templates accordingly. Evidence: BL111 fix cycles on issues 215, 219; reviewer on issue 218 noted "precedent: all other test files exceed 200 lines."
- **Effort:** Low (CLAUDE.md convention update + planner AC template guidance)

### AC. Add "cross-reference live implementation" convention for byte-identical contracts

- **Source:** Backlog 111 retro (rec 2)
- **Recurrence:** 1 run (E03-S01 fix cycle from stale design doc)
- **Priority:** Low
- **Description:** When acceptance criteria require byte-identical output matching another adapter, the builder should read the target adapter's source code, not the design doc. The BL111 design doc omitted emoji from lifecycle headings, causing a fix cycle on E03-S01 (#220). The builder followed the design doc rather than the GitHub adapter's actual implementation. Add to builder.md: "For byte-identical contracts, read the reference implementation source as the canonical format, not the design doc description."
- **Effort:** Low (builder.md instruction update)

### AD. Document ENVIRON pattern for awk in builder instructions

- **Source:** Backlog 111 (E01-S01 lesson, rec 3)
- **Recurrence:** 1 run (2 fix cycle rounds in the same story)
- **Priority:** Low
- **Description:** When passing untrusted string values to awk, builders must use `ENVIRON` instead of `-v` to avoid backslash escape interpretation. `awk -v var=value` processes `\n`, `\t`, `\s` as escape sequences, silently corrupting data containing backslashes. The safe pattern: `_MY_VAR="$value" awk 'BEGIN { val=ENVIRON["_MY_VAR"] } ...'`. Evidence: BL111 E01-S01 lesson `e01-foundation/2026-03-18-s01-awk-backslash-escape.md`. The fix was applied to `_local_fm_write` in round 1 but missed `_local_fm_append_label` in the same file, requiring round 2.
- **Effort:** Low (builder.md instruction update)

### AE. Flag anomalous dispatch durations in the state file

- **Source:** Backlog 227 retro (rec 1)
- **Recurrence:** 1 run (E01-S01 easy story took 91m due to usage limit/interruption)
- **Priority:** Low
- **Description:** When a dispatch's `duration_ms` exceeds a threshold relative to difficulty (e.g., easy > 30 min, medium > 60 min, hard > 120 min), the orchestrator should add a `"warning": "anomalous_duration"` field to the dispatch record. This helps the retro agent and telemetry scripts distinguish between genuine long builds and usage-limit-inflated timers. BL227 E01-S01 (easy config story) consumed 91m 2s when E01-S03 (also easy, same start time) completed in 5m 32s. The anomaly inflated all downstream metrics. Related to rec W (interruption tracking).
- **Effort:** Low (state.sh schema update + orchestrator convention)

### AF. Consider extracting pm.sh wrapper logic into pm-wrappers.sh

- **Source:** Backlog 227 retro (rec 2), E02-S02 review W1
- **Recurrence:** 1 run (pm.sh at 292 lines, 46% over 200-line convention)
- **Priority:** Low
- **Description:** After dual-write wrapper generation, `pm.sh` reached 292 lines. The wrapper generation logic (~100 lines: `_pm_generate_wrapper`, `_pm_generate_create_item_wrapper`, `_pm_generate_wrappers`, classification arrays, `_pm_external_fire_and_forget`, `_pm_is_local_only`) is a self-contained module that could be sourced separately. This is distinct from rec AB (test file convention) -- pm.sh is production code.
- **Effort:** Low (extract to separate file, add `source` call in pm.sh)

### AG. Add test file cleanup trap convention to builder instructions

- **Source:** Backlog 227 retro (rec 3)
- **Recurrence:** 4 stories in BL227 (W1 on 233, S3 on 236, S1/S3 on 237, W2/S3 on 238) + prior runs
- **Priority:** Medium -- recurred across 4 of 6 stories in a single backlog item
- **Description:** Reviewers flagged missing cleanup traps for temp files and mock symlinks in test files across 4 of 6 stories. The pattern is consistent: test files create temp files (`mktemp`) or mock symlinks in the real adapters directory, clean them up inline with `rm -f`, but lack a `trap cleanup EXIT` to handle early exits. Add to builder.md: "Test files that create temp files or mock symlinks MUST use `trap cleanup EXIT` to ensure cleanup on early exit, especially for symlinks in non-temp directories." Evidence: BL227 issues 233, 236, 237, 238.
- **Effort:** Low (builder.md instruction update)

### AH. Grep test files for hardcoded error messages when changing adapter stack

- **Source:** Backlog 227 retro (rec 4), E02-S01 review C1
- **Recurrence:** 1 run (test regression from adapter surface change)
- **Priority:** Low
- **Description:** When the public API surface shifts from one adapter to another (GitHub -> local as primary), tests that hardcode the old adapter's error strings break. E02-S01's loader refactor made the local adapter the primary public surface, but `test-board-sh.sh` still expected the GitHub adapter's `"Unknown status"` error message (local adapter uses `"invalid status"`). Builder should `grep -rn` for quoted error strings in test files when changing which adapter surfaces the public API. Evidence: BL227 E02-S01 critical C1 (issue 236).
- **Effort:** Low (builder.md instruction update)

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
| ii   | Stories with detailed acceptance criteria achieve low organic fix cycles           | Runs 5, 6, 9-14, BL105, BL106, Run 16, BL109, BL111, BL227 | 87+ stories tracked. BL227: 2/6 stories had fix cycles. E01-S02 (line count threshold not updated -- convention violation, not correctness bug). E02-S01 (test regression from adapter surface change + stale comment + guard gap -- genuine correctness issues). Organic fix cycle rate: 8/87 stories (9.2%). Pattern expanded: (5) adapter surface change breaks hardcoded test assertions (BL227). |
| iii  | CHANGELOG conflicts with per-epic PRs                                              | Run 5                            | Moot -- switched to single-PR model in Run 6.                                                                                                                                                                                                                                                         |
| iv   | Board status "drift" caused by GitHub default project automation                   | Runs 3-16                         | **Root cause found (Run 16):** GitHub's built-in "Pull request linked to issue" automation reverts Done→In Progress when the backlog PR references already-closed doc issues via `Closes` keywords. Not an API bug — an automation conflict. Fix: (1) don't use `Closes` on already-closed issues, (2) `reconcile-board.sh` for defense-in-depth. See CLAUDE.md "Link all issues to the PR" convention. |
| v    | `orchestrator.md` reduced from 1,323 to 503 lines (62%)                            | Runs 11, BL105, BL150            | Was ~1000 lines at Run 11, grew to 1,323 by BL105. BL150 extracted inline scripts to `state.sh`, deleted dead code (System Prompt Hardening), and condensed verbose sections. Now 503 lines. The monitoring threshold ("consider extraction at 1500 lines") is no longer relevant. |
| vi   | Reviewer doesn't reference the recommendations tracker for known patterns          | Run 11                           | Reviewer greps raw lesson files; the compiled tracker would be more efficient. Low priority -- current approach works.                                                                                                                                                                                |
| vii  | Average tokens per build story: convention work uses more tokens than content       | Runs 13, 14, BL105               | Content stories: Run 13 averaged 43K tokens/build, Run 14 averaged 43K (excl. fix cycles). Convention/docs stories (BL105): averaged 68K tokens/build. S02 (easy docs change) used 90K due to Edit tool worktree issues. Higher token usage likely reflects reading existing large files (orchestrator.md, CLAUDE.md) for context. |
| viii | Fix cycles add 70-100% overhead per affected story                                | Runs 14, 16, BL111, BL227        | Run 14: E01-S04 +181% (2 rounds), E02-S01 +66% (1 round). Total: $1.53 / $11.34 = 13.5%. Run 16: E02-S01 +100%, E02-S02 +79%, E02-S03 +71% (all single-round). Total: $2.85 / $13.78 = 20.7%. BL111: 5 fix cycle rounds across 4/9 stories. Total: $3.36 / $14.70 = 22.9%. BL227: 2 fix cycles across 2/6 stories (33%). Total: $0.94 / $13.28 = 7.1%. Lowest fix cycle cost share of the four tracked infrastructure runs. Both fix cycles were single-round. |
| ix   | Builders prioritize acceptance criteria over story descriptions when they conflict | Run 14                           | 2/4 planted bugs neutralized because builders followed AC. Correct behavior -- AC is the binding contract. Rec K (document as convention) declined: this only surfaced during deliberate bug planting, not organic usage. Already captured in builder.md as existing behavior ("Acceptance criteria take precedence over story descriptions"). |
| x    | Self-referential convention changes succeed without fix cycles                      | BL105                            | First run where agents modified their own instructions (orchestrator.md, CLAUDE.md, planner.md, config). 6/6 stories passed review on first attempt. Separation of concerns (designer/planner/builder/reviewer) works even when the target is the pipeline's own conventions.                          |
| xi   | Reviewer variants created mid-session are unusable until next session               | BL105                            | S01 created reviewer-sonnet.md and reviewer-opus.md, but Claude Code only loads agent files at session start. All 7 reviews used the base reviewer agent with Opus. Feature takes effect on the next run. Known platform limitation (CLAUDE.md "Dynamic agent files at runtime").                      |
| xii  | Infrastructure refactoring stories take 2-3x longer than content-creation stories | BL106, BL109, BL111, BL227       | BL106 average build: 11m 6s (infrastructure refactoring). BL109 average build: 5m 0s (adapter modules, greenfield). BL111 average build: 5m 44s (greenfield adapter, first build only). BL227 average build (excl. anomalous E01-S01): 7m 42s (refactoring existing adapter code, not greenfield). Content runs: ~3m 40s (Run 14). BL227 confirms: refactoring existing infrastructure takes ~2x greenfield time. The anomalous E01-S01 (91m) is excluded as a usage limit artifact. |
| xiii | Reviewer cost dominates total cost in infrastructure runs (47.8% of total)        | BL106                            | All reviewers inherit orchestrator's Opus model. Reviewers consumed $6.65 of $13.92 total (47.8%) despite only 28.7% of duration. For infrastructure where correctness is critical, Opus review is appropriate. For docs-only stories, may be overkill (see rec P). |
| xiv  | PR-level review catches structural bugs invisible to story-level reviews          | BL106                            | Premature `if __name__` block at line 1076 of test file caused 35/123 tests to be skipped. Each story reviewer only saw their own additions and missed the structural issue. The PR reviewer saw the full file and caught it. Validates two-tier review model. |
| xv   | Interactive design produces better architectural decisions than autonomous for refactoring | BL150                   | Design evolved from "split into reference docs" (original backlog proposal) to "extract inline scripts" through interactive Q&A. The designer's critical analysis revealed 61% of extractable content was "scripts written in markdown." Autonomous mode would have accepted the initial approach without this re-evaluation. For greenfield or content work, autonomous is efficient; for refactoring existing infrastructure, interactive design yields superior results. |
| xvi  | First organic fix cycle in the workflow was for a security pattern invisible to tests | BL150                        | E01-S01 had 2 fix cycle rounds for heredoc injection (5 critical issues). This is the first non-planted fix cycle in 53+ stories. The vulnerability (unquoted bash heredoc markers) is invisible to functional tests because bash variable expansion happens before Python execution. The reviewer demonstrated working exploits. This validates the review process: reviewers catch classes of bugs that tests cannot. |
| xvii | Incomplete fix cycle pattern: builders fix only cited locations, not file-wide pattern | BL150, BL111                  | BL150 E01-S01: fixed 3 of 5 vulnerable heredocs (the 3 cited by reviewer). BL111 E01-S01: fixed `_local_fm_write` with ENVIRON but left `_local_fm_append_label` using `-v` in the same file. Both required an additional fix cycle round. This "fix cited locations, not file-wide pattern" behavior cost ~6 min (BL150) and ~8 min (BL111) of additional wall clock. Second occurrence strengthens rec S. |
| xviii | Sonnet reviewer quality is consistently high, including on infrastructure code | BL105, BL150, Run 16, BL109, BL111, BL227 | 6th positive data point. BL227 added 3 Sonnet reviews on infrastructure code (issues 233, 235, both easy stories). Both reviews were thorough: Sonnet on #233 found 1 warning (temp file cleanup) and 2 suggestions; Sonnet on #235 found 3 warnings (missing error path tests, local+arithmetic style) and 3 suggestions. Both verdicts (APPROVE) were correct. 20+ Sonnet reviews total, all verdicts correct. |
| xix  | Infrastructure design costs dominate when usage limits force re-dispatches | BL109                          | BL109 design phase: 10 dispatches, $7.05 (37% of total). Each re-dispatch after usage limit consumed 40-75K tokens re-reading context. Sequential agent time was only 19m 20s, but wall clock was ~2 hours due to pauses. Compare: content runs (Runs 12-14) use 1-3 design dispatches at $0.50-$1.50. The cost profile is specific to autonomous infrastructure design with complex scope (13 functions, 3-layer architecture, agent audit). |
| xx   | PM abstraction adapter cost profile: Design 37%, Build 33%, Review 25%, Plan 5% | BL109                          | First adapter/abstraction infrastructure item. Design dominates due to adversarial triangulation pattern and usage limits. Build cost ($6.23) is comparable to content runs. Review cost ($4.72, 25%) is lower than BL106 (47.8%) because Sonnet reviews handled easy/medium stories. Plan phase efficient at $1.03 (11m 37s, single dispatch for 3 epics + 10 stories). |
| xxi  | Derivative adapter cost profile: Design 8%, Plan 8%, Build 43%, Review 42% | BL111                          | Second adapter item (local PM, builds on BL109's abstraction). Design+plan cost dropped from $8.08 (42% of BL109) to $2.26 (15% of BL111). Build cost ($6.29) is near-identical to BL109 ($6.23). Review cost ($6.15, 42%) is higher than BL109 ($4.72, 25%) due to more fix cycles (4/9 vs 1/10) driving re-reviews. When the function contract is already defined, design is cheap; the cost shifts to build+review. |
| xxii | Worktree path confusion: Read/Edit tools vs Bash CWD in worktree agents | BL111                          | When a builder is dispatched in a worktree, Read/Edit tools operate on the absolute path given (main repo root) while Bash CWD is the worktree. Edits using main repo root paths land in the main working tree, not the worktree. The builder on E03-S03 (#222) had edits silently lost when the orchestrator switched the main tree's branch. Prevention: builders in worktrees must use paths rooted at `$(pwd)/`, not the main repo root. See lesson `e03-composition-integration/2026-03-18-s03-worktree-path-confusion.md`. |
| xxiii | PM infrastructure cost progression: design cost drops as prior art accumulates | BL109, BL111, BL227            | Three PM backlogs show a clear pattern. Design+plan cost: BL109 $8.08 (42% of total, 10 design dispatches), BL111 $2.26 (15%, 1+1 dispatches), BL227 $2.55 (19%, 1+1 dispatches). Build cost is stable: BL109 $6.23, BL111 $6.29, BL227 $5.79. The first item (abstraction layer) is expensive because it defines the interface from scratch. Subsequent items that implement or extend that interface benefit from the existing design docs and function contracts. Total cost: BL109 $18.95, BL111 $14.70, BL227 $13.28 -- a downward trend. |
