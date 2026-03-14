# Retro Recommendations Tracker

Consolidated tracker for all recommendations from workflow retrospectives. Updated manually after each retro — the retro agent should append new recommendations here, and the orchestrator should check this document before each run.

Last updated: 2026-03-14 (compiled from Runs 2–11)

---

## Outstanding (not yet implemented)

### A. Add GraphQL rate limit awareness convention to CLAUDE.md

- **Source:** Run 6 (rec 3), Run 7 (rec 3), Run 8 (rec 4), Run 10 (rec 3)
- **Recurrence:** 4 runs
- **Priority:** High
- **Description:** Document the GitHub GraphQL API's 5000 points/hour budget in CLAUDE.md. Note that `gh project item-list` costs ~200+ points per call, and agents should prefer lightweight per-issue queries when available. The `issue-set-status.sh` script fix (Run 11 prep) reduces the problem at the script level, but the awareness convention is still missing — agents making raw `gh api graphql` calls have no guidance on cost.
- **Effort:** Low (a paragraph in CLAUDE.md)

### B. Remove duplicated status option IDs from orchestrator.md

- **Source:** Run 6 (rec 2)
- **Recurrence:** 1 run (but risk is ongoing)
- **Priority:** Low
- **Description:** The planner.md correctly references CLAUDE.md as the single source of truth for option IDs, but `orchestrator.md` still duplicates the option ID table. If the project board is reconfigured, these copies will drift — as happened in Run 6 when the planner had stale IDs. Either remove the duplicate table from orchestrator.md and reference CLAUDE.md, or add a note that CLAUDE.md is authoritative.
- **Effort:** Low (edit orchestrator.md)

### C. Parallel review dispatch for independent stories

- **Source:** Run 6 (rec 4)
- **Recurrence:** 1 run (observation)
- **Priority:** Medium
- **Description:** Reviews for independent stories within the same wave are currently dispatched sequentially after all builds complete. Dispatching reviews in parallel (same pattern as builds) could compress wall-clock time by ~50% per wave's review phase. For example, Run 6 Wave 1 had ~3 minutes of sequential reviews that could have been ~1 minute in parallel.
- **Effort:** Medium (orchestrator.md update + orchestrator behavior change)
- **Risk:** Reviewer agents don't modify code, so worktree isolation is unnecessary. Main risk is GitHub API rate limits from concurrent issue comment posts.

### D. ~~Post-wave comment verification~~ (IMPLEMENTED in Run 11 retro)

- **Source:** Run 4 (rec 6), Run 11 (rec 1)
- **Recurrence:** 2 runs (Run 4 issue #114, Run 11 issues #47 and #48)
- **Priority:** Low
- **Description:** After a parallel wave, the orchestrator should verify that every story has all expected issue comments (Work Started, Ready for Review). Missing comments should be posted retroactively.
- **Implemented:** Added to CLAUDE.md "Board transitions in autonomous mode" as item 5. Run 11 retro.

### E. Format templates for cross-story parallel content

- **Source:** Run 5 (rec 3)
- **Recurrence:** 1 run (Run 5 E01 format inconsistency)
- **Priority:** Low
- **Description:** When multiple stories produce content with shared structural elements (e.g., metrics sections, rating tables), the planner should specify the exact rendering format (e.g., "use markdown tables for metrics") to prevent cosmetic divergence between parallel builders. Run 5's E01 epic had three different formats for the same structural element because different models chose different representations.
- **Effort:** Low (planner guideline)

### F. Document orchestrator override pattern for pre-fixed reviewer findings

- **Source:** Run 9 (rec 2)
- **Recurrence:** 1 run (single occurrence)
- **Priority:** Low
- **Description:** When the orchestrator has already fixed an issue before reviewer dispatch (e.g., cherry-picking to fix cross-contamination), and the reviewer flags the pre-fix state, the orchestrator may override the verdict with documented evidence. This pattern worked in Run 9 but is not a recognized convention. Needs more data before formalizing.
- **Effort:** Low (orchestrator.md documentation)
- **Status:** Waiting for more data — single occurrence is insufficient for a convention.

### G. Track autonomous lifecycle duration baseline

- **Source:** Run 9 (rec 4)
- **Recurrence:** 1 run (observation)
- **Priority:** Low
- **Description:** Establishing a baseline for autonomous run duration enables performance regression detection. Current data: Run 5 ~30m, Run 6 ~28m, Run 8 ~40m, Run 9 ~29m, Run 10 ~61m (rate limit overhead), Run 11 ~45m. No formal tracking mechanism exists.
- **Effort:** Low (add a duration row to the changelog or a tracking table in this document)

### H. Capture orchestrator overhead metrics

- **Source:** Run 10 (rec 5)
- **Recurrence:** 1 run (observation)
- **Priority:** Low
- **Description:** Orchestrator overhead was 51% of wall-clock time in Run 10 (31m of 61m). The rate limit workaround contributed ~6 minutes, but branch management, merge operations, and lesson/changelog commits also add significant time. Tracking this metric across runs would surface efficiency regressions. Currently, only subagent telemetry is captured — the orchestrator's own consumption runs in the parent session.
- **Effort:** Medium (requires capturing `/cost` output at session start/end)

---

## Implemented


| #   | Recommendation                                                       | Source        | Implemented In                |
| --- | -------------------------------------------------------------------- | ------------- | ----------------------------- |
| 1   | Orchestrator owns all board transitions in autonomous mode           | Run 3         | CLAUDE.md, orchestrator.md    |
| 2   | Add `Bash` to planner agent tool list                                | Run 3         | Commit `cfb2231`              |
| 3   | Add `Bash` to designer agent tool list                               | Run 4         | Subsequent agent update       |
| 4   | Require `isolation: "worktree"` for parallel builder dispatch        | Runs 4, 7     | CLAUDE.md convention          |
| 5   | Builder agents must not merge story branches into epic               | Run 4         | Builder agent instructions    |
| 6   | Add `git add -f` guidance for gitignored `test-output/` paths        | Run 4         | Builder agent instructions    |
| 7   | Add `backlog/<N>-<slug>` label to design/plan issues                 | Run 5         | Designer/planner instructions |
| 8   | Add `e00-setup/` lesson folder convention for pre-epic lessons       | Run 5         | CLAUDE.md lesson conventions  |
| 9   | Builders must verify word counts before committing                   | Run 3         | Builder agent instructions    |
| 10  | Cross-story consistency contracts in plans                           | Runs 3, 5     | Planner convention            |
| 11  | `tr -d '\x00-\x1f'` pipe for `gh project item-list` output           | Run 7         | CLAUDE.md convention          |
| 12  | Worktree cleanup step after parallel dispatch                        | Run 8         | CLAUDE.md convention          |
| 13  | Builder must push to remote in worktree mode                         | Run 8         | CLAUDE.md convention          |
| 14  | CLI dispatch scope clarified (standalone terminal only)              | Run 2         | CLAUDE.md convention          |
| 15  | All story issues included in backlog PR `Closes` list                | Run 2         | CLAUDE.md convention          |
| 16  | `--cost` flag on `issue-telemetry.sh` for mixed-model epics          | Run 2         | Script updated                |
| 17  | Reviewer dispatch is mandatory (no skip option)                      | Run 2         | CLAUDE.md + orchestrator.md   |
| 18  | Single-PR workflow (`backlog/<N>-<slug>` → `main`)                   | Run 6         | CLAUDE.md convention          |
| 19  | Fix artifact matching to use YAML frontmatter grep                   | Run 10        | orchestrator.md updated       |
| 20  | Replace `item-list` with per-issue GraphQL in `issue-set-status.sh`  | Run 10        | Pre-Run 11 commit `487b382`   |
| 21  | `issue-create-backlog.sh` for consolidated backlog item setup        | Run 10 lesson | Pre-Run 11 commit `0785196`   |
| 22  | Story branches created from recorded epic base before parallel waves | Run 9         | CLAUDE.md convention          |
| 23  | Audit agent tool lists when instructions reference CLI commands      | Run 3         | CLAUDE.md convention          |
| 24  | Post-wave comment verification for parallel builders                 | Runs 4, 11    | CLAUDE.md convention (Run 11) |
| 25  | Document `gh project item-add` does not set default status           | Run 11        | CLAUDE.md convention (Run 11) |


---

## Observations (no convention change warranted)


| #   | Observation                                                                    | Source                 | Notes                                                                                                           |
| --- | ------------------------------------------------------------------------------ | ---------------------- | --------------------------------------------------------------------------------------------------------------- |
| i   | Haiku uses 3–4x more tokens than Sonnet for comparable tasks                   | Runs 3, 6, 7, 8, 9, 10, 11 | Consistent across 7 runs. Cost is comparable due to 3x lower per-token rate. No model routing change warranted. |
| ii  | Content-only stories with detailed acceptance criteria achieve zero fix cycles | Runs 5, 6, 9, 10, 11       | 17 consecutive first-pass approvals (Runs 9–11). Builder-reviewer loop is stable for markdown and script tasks. |
| iii | CHANGELOG conflicts with per-epic PRs                                          | Run 5                       | Moot — switched to single-PR model in Run 6.                                                                    |
| iv  | Board status persistence bug (mutations succeed, statuses revert later)        | Runs 3, 10                  | Run 11 created diagnostic script `check-board-drift.sh`; not yet exercised in a live run.                       |


