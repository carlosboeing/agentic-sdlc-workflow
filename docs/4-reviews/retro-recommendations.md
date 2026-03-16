# Retro Recommendations Tracker

Consolidated tracker for all recommendations from workflow retrospectives. Updated manually after each retro — the retro agent should append new recommendations here, and the orchestrator should check this document before each run.

Last updated: 2026-03-15 (compiled from Runs 2–14)

---

## Outstanding (not yet implemented)

### G. Track autonomous lifecycle duration baseline

- **Source:** Run 9 (rec 4)
- **Recurrence:** 1 run (observation)
- **Priority:** Low
- **Description:** Establishing a baseline for autonomous run duration enables performance regression detection. Current data: Run 5 ~30m, Run 6 ~28m, Run 8 ~40m, Run 9 ~29m, Run 10 ~61m (rate limit overhead), Run 11 ~41m, Run 12 ~23m, Run 13 ~25m, Run 14 ~77m (12 stories, 3 fix cycles). No formal tracking mechanism exists.
- **Effort:** Low (add a duration row to the changelog or a tracking table in this document)

### I. Extract dispatch computation from issue-telemetry.sh

- **Source:** Run 12 (reviewer S4)
- **Recurrence:** 1 run (observation)
- **Priority:** Low
- **Description:** `issue-telemetry.sh` is 602 lines — 3x the 200-line guideline. The `--dispatches` and `--dispatches-from-state` features added ~230 lines of Python embedded in bash heredocs. Consider extracting the dispatch computation into a separate helper script (e.g., `scripts/lib/compute-dispatches.py`) that `issue-telemetry.sh` calls. This would improve readability and make the Python logic independently testable.
- **Effort:** Medium (refactor + update all callers)

### L. Track fix cycle overhead as a per-run metric

- **Source:** Run 14 (rec 5)
- **Recurrence:** 1 run (first run with fix cycles in v2)
- **Priority:** Low
- **Description:** Fix cycles in Run 14 added $1.53 (13.5% of total run cost) and 11m 29s of agent time across 3 fix cycles (E01-S04 x2, E02-S01 x1). As the workflow matures, tracking fix cycle rate and overhead per run would surface whether builder/reviewer instructions need tuning. Baseline: Run 14 = 3 fix cycles / 12 stories = 25% fix rate (inflated by deliberate bug planting).
- **Effort:** Low (add a row to telemetry summary or this tracker)

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
| 18  | Single-PR workflow (`backlog/<N>-<slug>` → `main`)                   | Run 6         | CLAUDE.md convention                              |
| 19  | Fix artifact matching to use YAML frontmatter grep                   | Run 10        | orchestrator.md updated                           |
| 20  | Replace `item-list` with per-issue GraphQL in `issue-set-status.sh`  | Run 10        | Pre-Run 11 commit `487b382`                       |
| 21  | `issue-create-backlog.sh` for consolidated backlog item setup        | Run 10 lesson | Pre-Run 11 commit `0785196`                       |
| 22  | Story branches created from recorded epic base before parallel waves | Run 9         | CLAUDE.md convention                              |
| 23  | Audit agent tool lists when instructions reference CLI commands      | Run 3         | CLAUDE.md convention                              |
| 24  | Post-wave comment verification for parallel builders                 | Runs 4, 11    | CLAUDE.md convention (Run 11)                     |
| 25  | Document `gh project item-add` does not set default status           | Run 11        | CLAUDE.md convention (Run 11)                     |
| 26  | GraphQL rate limit awareness convention in CLAUDE.md                 | Runs 6–8, 10  | CLAUDE.md (pre-Run 11), `issue-set-status.sh` fix |
| 27  | Remove duplicated status option IDs from orchestrator.md             | Run 6         | orchestrator.md (Run 11 post-run cleanup)         |
| 28  | Parallel review dispatch for independent stories                     | Run 6         | Validated in Run 11 Wave 3 (3 parallel reviews)   |
| 29  | Inline Gantt color tagging rules in orchestrator.md                  | Run 11        | orchestrator.md + CLAUDE.md (Run 11 post-run fix) |
| 30  | Move backlog In Progress transition to Phase 1 (Design)              | Run 12        | orchestrator.md (Run 12 retro)                    |
| 31  | Extend post-worktree cleanup to fix cycle dispatches                 | Run 14        | CLAUDE.md + orchestrator.md (Run 14)              |
| E   | Format templates for cross-story parallel content                    | Runs 5, 12    | planner.md "Format Templates" section (backlog #105) |
| F   | Document orchestrator override pattern for pre-fixed reviewer findings | Runs 9, 14  | orchestrator.md "Orchestrator Override Pattern" section (backlog #105) |
| 32  | Capture orchestrator overhead metrics (wall-clock heuristic)         | Run 10        | CLAUDE.md + orchestrator.md (backlog 105)         |


---

## Observations (no convention change warranted)


| #    | Observation                                                                        | Source                           | Notes                                                                                                                                                                                                                                                                                                |
| ---- | ---------------------------------------------------------------------------------- | -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| i    | Haiku uses 3–4x more tokens than Sonnet for comparable tasks                       | Runs 3, 6, 7, 8, 9, 10, 11       | Consistent across 7 runs. Cost is comparable due to 3x lower per-token rate. No model routing change warranted.                                                                                                                                                                                      |
| ii   | Content-only stories with detailed acceptance criteria achieve zero fix cycles     | Runs 5, 6, 9, 10, 11, 12, 13, 14 | Streak of 28 first-pass approvals (Runs 9-13) broken in Run 14 by deliberate bug planting. 10/12 Run 14 stories passed first attempt; 2 triggered fix cycles due to planted bugs (word count overflow, format contradiction). Organic (non-planted) fix cycle rate remains 0%.                       |
| iii  | CHANGELOG conflicts with per-epic PRs                                              | Run 5                            | Moot — switched to single-PR model in Run 6.                                                                                                                                                                                                                                                         |
| iv   | Board status persistence bug (mutations succeed, statuses revert later)            | Runs 3, 10, 12, 14               | Run 11 created `check-board-drift.sh`; Run 12 confirmed drift (all stories + closed issues reverted to In Progress). Run 14: all 18 issues reverted to In Progress despite successful `issue-set-status.sh` calls. Orchestrator now has mandatory post-run verification step -- confirmed essential. |
| v    | `orchestrator.md` approaching 1000 lines — largest agent file by 5x                | Run 11                           | State schema (~200 lines) and board management examples could move to a reference doc. Monitor for readability.                                                                                                                                                                                      |
| vi   | Reviewer doesn't reference the recommendations tracker for known patterns          | Run 11                           | Reviewer greps raw lesson files; the compiled tracker would be more efficient. Low priority — current approach works.                                                                                                                                                                                |
| vii  | Average tokens per build story trending downward for content-only tasks            | Runs 13, 14                      | Run 13 averaged 43K tokens/build. Run 14 averaged 43K tokens/build (excluding fix cycles) or 54K (including fix cycles). Baseline holds for non-fix-cycle stories.                                                                                                                                   |
| viii | Fix cycles more than double the cost of affected stories                           | Run 14                           | E01-S04: +181% overhead (2 fix cycles). E02-S01: +66% overhead (1 fix cycle). Total fix overhead: $1.53 / $11.34 = 13.5% of run cost. First data point -- track across future runs with organic (non-planted) fix cycles.                                                                            |
| ix   | Builders prioritize acceptance criteria over story descriptions when they conflict | Run 14                           | 2/4 planted bugs neutralized because builders followed AC. Correct behavior — AC is the binding contract. Rec K (document as convention) declined: this only surfaced during deliberate bug planting, not organic usage. Already captured in builder.md as existing behavior ("Acceptance criteria take precedence over story descriptions"). |


