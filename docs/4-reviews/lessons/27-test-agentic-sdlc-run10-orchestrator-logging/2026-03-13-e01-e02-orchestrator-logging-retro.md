---
date: 2026-03-13
author: retro
backlog-issue: 27
backlog-pr: pending
scope: Run 10 — validate two-layer diagnostic logging + Nature Documentary Season 2 content — 2 epics, 6 stories, 4 dispatch waves
---

# Orchestrator Logging (Run 10) — Agentic Workflow Retrospective

## Summary

Run 10 implemented logging infrastructure validation (a validation script and design doc reconciliation) and produced four new Nature Documentary episodes, across 2 epics and 6 stories dispatched in 4 waves. The primary test objective — validating the two-layer diagnostic logging system (board-status.log + orchestrator.log via Claude Code hooks) — was met: the validation script was created and the design doc was reconciled with the actual implementation. All 6 stories passed review on first attempt (zero fix cycles), continuing the trend established in Run 9. Two significant pre-build issues were encountered: a design artifact matching bug that caused false-positive phase skipping, and GraphQL API rate limit exhaustion from heavy `item-list` queries.

## Timeline

| Phase | Time (UTC) | Wall Clock | Activity |
|-------|-----------|------------|----------|
| Orchestrator setup | 04:04 – 04:05 | ~1m | Session init, pricing fetch, state file creation |
| Design | 04:05 – 04:13 | ~8m | Designer produced design doc, PR #29 merged (`453c36f`) |
| Plan | 04:13 – 04:23 | ~10m | Planner created plan + 8 issues, PR #39 merged (`1684d9d`). Rate limit hit during board setup. |
| Orchestrator overhead | 04:23 – 04:29 | ~6m | Epic/story branch creation, board transitions (worked around rate limit with REST fallback) |
| Wave 1: E01-S01 (build + review) | 04:29 – 04:36 | ~7m | Sonnet build (3m27s) + opus review (2m42s). APPROVE. |
| Wave 2: E01-S02 (build + review) | 04:38 – 04:42 | ~4m | Haiku build (1m52s) + opus review (1m40s). APPROVE. |
| E01 merge | 04:41 – 04:42 | ~1m | Story branches into epic, epic into integration (`b695515`) |
| Wave 3: E02-S01/S02/S03 (parallel builds + reviews) | 04:45 – 04:52 | ~7m | 3 parallel builders (haiku/haiku/sonnet, worktree isolation), then 3 parallel reviews. All APPROVE. |
| Wave 4: E02-S04 (build + review) | 04:55 – 04:59 | ~4m | Opus build (2m35s) + opus review (1m15s). APPROVE. |
| E02 merge | 04:54 – 04:55 | ~1m | 4 story branches into epic, epic into integration (`589dd35`) |
| Lessons + changelog | 04:55 – 05:05 | ~10m | Orchestrator committed lessons, changelog entry (`b6a8c36`) |
| **Total** | 04:04 – 05:05 | **~61m** | Full lifecycle excluding retro |

*Source: `git log main..backlog/27-orchestrator-logging --format="%h %ai %s"` and orchestrator state file `.claude/state/27/orchestrator.json`.*

## Telemetry

### Per-Story Breakdown

| Story | Issue | Difficulty | Build Model | Build Time | Build Tokens | Build Cost | Review Time | Review Tokens | Review Cost | Total Cost |
|-------|-------|-----------|------------|-----------|-------------|-----------|------------|--------------|------------|-----------|
| E01-S01 (Validation Script) | #33 | medium | sonnet | 3m 27s | 79K | ~$0.48 | 2m 42s | 45K | ~$0.45 | ~$0.93 |
| E01-S02 (Design Doc Reconciliation) | #34 | easy | haiku | 1m 52s | 116K | ~$0.23 | 1m 40s | 39K | ~$0.39 | ~$0.62 |
| E02-S01 (Thermostat Wars) | #35 | easy | haiku | 1m 47s | 112K | ~$0.22 | 1m 29s | 29K | ~$0.29 | ~$0.51 |
| E02-S02 (Reply-All Incident) | #36 | easy | haiku | 1m 22s | 109K | ~$0.22 | 1m 22s | 29K | ~$0.29 | ~$0.51 |
| E02-S03 (Lunch Thief) | #37 | medium | sonnet | 3m 07s | 37K | ~$0.22 | 1m 38s | 30K | ~$0.30 | ~$0.52 |
| E02-S04 (Habitat Assessment) | #38 | hard | opus | 2m 35s | 35K | ~$0.35 | 1m 15s | 28K | ~$0.28 | ~$0.63 |
| **Story Total** | | | | **14m 10s** | **488K** | **~$1.72** | **10m 06s** | **200K** | **~$2.00** | **~$3.72** |

*All reviewers used opus. Costs computed using Anthropic API blended rates (opus $10/M, sonnet $6/M, haiku $2/M).*

### Design/Plan Phases

| Phase | Model | Agent Time | Tokens | Est. Cost | Tool Uses |
|-------|-------|-----------|--------|-----------|-----------|
| Design | opus | 4m 58s | 67K | ~$0.67 | 38 |
| Plan | opus | 8m 37s | 77K | ~$0.77 | 58 |
| **Phase Total** | | **13m 35s** | **144K** | **~$1.44** | **96** |

### Aggregate

| Metric | Value |
|--------|-------|
| Stories completed | 6/6 |
| Tests written | 0 (markdown + shell scripts, no C# code) |
| Critical issues caught by reviewer | 0 |
| Warnings caught by reviewer | 6 (W1-W3 on #33, W1 on #34, W1 on #35, W1 on #36) |
| Fix cycles required | 0 |
| Total dispatches | 14 (1 designer, 1 planner, 6 builders, 6 reviewers) |
| Total tokens (all dispatches) | 831K |
| Total estimated cost (all dispatches) | ~$5.15 |
| Actual wall-clock time | ~61 minutes (design through changelog, excluding retro) |
| Build+review wall-clock time | ~30 minutes (Wave 1 through Wave 4) |
| Orchestrator overhead | ~31 minutes (setup, branch mgmt, merges, rate limit workaround, lessons) |

*Note: Orchestrator's own token consumption runs in the parent session and is not captured in dispatch telemetry. The ~$5.15 total covers only subagent dispatches.*

## What Worked

### 1. Zero Fix Cycles Across All 6 Stories (Second Consecutive Run)

All 6 stories passed review on first attempt. Combined with Run 9's 5/5 first-pass approvals, this is 11 consecutive stories across 2 runs without a fix cycle. The reviewer found 6 warnings total but none blocking. Evidence: all 6 review comments posted on issues #33-#38 show `APPROVE` verdicts. This validates that the acceptance criteria format and builder agent instructions are producing consistently compliant output.

### 2. Three-Way Parallel Dispatch with Worktree Isolation (Wave 3)

Wave 3 dispatched three builders in parallel (haiku for #35, haiku for #36, sonnet for #37) using worktree isolation. All three completed successfully with no cross-contamination — an improvement over Run 9 which had one contamination incident (E01-S03, #20). Sequential agent time for the three builds was 6m 16s; wall-clock time was ~3m 7s (limited by the longest builder, sonnet on #37), yielding a 2.0x parallel speedup. Evidence: dispatch IDs 7, 8, 9 in the state file all show `started_at: "2026-03-13T04:45:00Z"` and `result: "success"`.

### 3. All Three Difficulty Levels Exercised and Validated

The run used all three model tiers: haiku for 3 easy stories (#34, #35, #36), sonnet for 2 medium stories (#33, #37), and opus for 1 hard story (#38). All produced first-pass approvals. The hard story (#38, Habitat Assessment) required reading an existing file for cross-references (HC-CLASS-001 from Run 8) and maintaining dual voice (bureaucratic + documentary) — opus handled both correctly. Evidence: reviewer comment on #38 confirmed 15/15 acceptance criteria passed.

### 4. Lesson Capture by Multiple Agents

Four lesson files were written by two different agent roles (orchestrator and builder) during the run, covering three distinct failure modes. This is the first run where builders proactively wrote lessons (the `grep -c` exit code pitfall in #33 and design-implementation drift in #34). Prior runs relied on the retro agent to capture all learnings retrospectively.

### 5. Design Doc Reconciliation Pattern

Story E01-S02 (#34) established a reconciliation pattern: when implementation diverges from design (as it often does with new/evolving APIs), a dedicated story reconciles the design doc by updating code blocks, noting discrepancies, and adding a "Post-Implementation Notes" section. The reviewer noted this produced a clean, referenceable artifact. Evidence: commit `e7acff5` updated the design doc with 57 insertions, 7 deletions.

## What Didn't Work

### 1. Design Artifact Matching Used Unreliable Grep

During Phase 0, the orchestrator ran `grep -rl "27" docs/2-design/` to check for existing design docs. This matched files containing the number "27" as incidental text (word counts, line numbers) but belonging to different backlog items. The orchestrator incorrectly concluded the design phase could be skipped. Root cause: the orchestrator agent's Phase 0 instructions (`orchestrator.md` line 113) specify raw content grep instead of targeting YAML frontmatter. Design docs have a `backlog:` frontmatter field that uniquely identifies the owning backlog item, but the grep doesn't filter on it. Evidence: lesson file `docs/4-reviews/lessons/27-test-agentic-sdlc-run10-orchestrator-logging/e00-setup/2026-03-13-s00-design-artifact-matching.md`.

### 2. GraphQL API Rate Limit Exhaustion

The planner's 58 API calls (creating issues, adding to project board, setting statuses) depleted the GitHub GraphQL rate limit (5000 points/hour). After the planner completed, the orchestrator couldn't set stories to Todo because `issue-set-status.sh` uses `gh project item-list` which fetches all 200+ project items — a heavy query costing many points per call. The script calls it twice per invocation (lookup + verification), compounding the problem. The orchestrator worked around this by using direct REST API calls via `gh api`, but the workaround added ~6 minutes of orchestrator overhead. Evidence: lesson file `docs/4-reviews/lessons/27-test-agentic-sdlc-run10-orchestrator-logging/e00-setup/2026-03-13-s00-rate-limit-item-list.md`.

### 3. Builder Scripts Failed During Rate Limit Window

The builder scripts `issue-start.sh` and `issue-review.sh` internally call `issue-set-status.sh`, which in turn uses `gh project item-list`. During the rate limit window, these scripts failed silently or produced errors. The orchestrator compensated by making board transitions directly, but this created a window where the defense-in-depth pattern (scripts + orchestrator both update board) broke down. This is a downstream consequence of issue 2 above.

### 4. Haiku Token Consumption Remains 3x Higher Than Sonnet

Consistent with Runs 8 and 9, haiku builders consumed significantly more tokens than sonnet for comparable tasks: haiku on #34 (easy, design doc edits) used 116K tokens vs sonnet on #37 (medium, multi-section narrative) at 37K tokens. The cost difference is smaller due to haiku's lower per-token rate ($0.23 vs $0.22), but the pattern is persistent. Three runs of data now show this consistently. Evidence: state file `epics.e01.stories.34.build.tokens: 116110` vs `epics.e02.stories.37.build.tokens: 36555`.

## Workflow Evolution During Epic

| Commit | Change | Trigger |
|--------|--------|---------|
| (none) | No convention changes during this epic | N/A |

No CLAUDE.md or agent file changes were committed during this backlog item. The conventions inherited from Run 9 were sufficient for all build phases. The orchestrator adapted to rate limit exhaustion via ad-hoc workarounds rather than convention changes.

## Key Learnings

### For Builders

1. The `grep -c` command returns exit code 1 when there are zero matches (POSIX spec, not an error). Shell scripts using `set -e` or `||` fallbacks must account for this. The `n=$(...) || n=0` pattern is correct; the `$(...) || echo 0` pattern produces double output. Evidence: lesson `e01-logging-infra/2026-03-13-s01-grep-c-exit-code.md`, story #33.
2. When implementing against new/evolving platform APIs (like Claude Code hooks), the actual format often diverges from design specs. Builders should document actual API format in commits and flag discrepancies for reconciliation. Evidence: lesson `e01-logging-infra/2026-03-13-s02-design-implementation-drift.md`, story #34.

### For the Orchestrator

1. Design artifact matching via `grep -rl "<number>" docs/2-design/` is unreliable for short numbers. Use `grep -rl "^backlog: <number>$" docs/2-design/` to target YAML frontmatter, or query GitHub for the `type/docs` issue with the `backlog/<N>-*` label. Evidence: lesson `e00-setup/2026-03-13-s00-design-artifact-matching.md`.
2. The `gh project item-list` command is a heavy GraphQL query. After a planner session with many API calls, the rate limit may be exhausted. Use per-issue GraphQL queries (`repository.issue.projectItems`) or cache item IDs to reduce API cost. Evidence: lesson `e00-setup/2026-03-13-s00-rate-limit-item-list.md`.
3. Orchestrator overhead (~31 minutes of 61-minute total) accounted for over half the wall-clock time this run. The rate limit workaround contributed ~6 minutes, but branch management, merge operations, and lesson/changelog commits also added significant time.

### For the Workflow

1. **Eleven consecutive first-pass approvals** (5 in Run 9 + 6 in Run 10) suggests the builder-reviewer loop is stable. The acceptance criteria format with explicit checklists and word count ranges produces reliable output. This does not mean the reviewer is unnecessary — the 6 warnings caught in Run 10 demonstrate ongoing value.
2. **Haiku token consumption pattern is now established across 3 runs.** Haiku consistently uses 3-4x more tokens than sonnet for comparable tasks, but costs are comparable due to the 3x price difference. The workflow should continue using haiku for easy stories — the cost-efficiency is acceptable and the token overhead is an API-level concern, not a quality concern.
3. **Rate limit management is a workflow-level concern.** The planner's 58 tool uses in this run were not unusually high, but combined with the heavy `item-list` queries in subsequent phases, they exhausted the budget. The fix belongs in the scripts (lighter queries) rather than in the planner (fewer API calls).

## Recommendations

1. **Fix artifact matching in orchestrator agent** — Change the Phase 0 design doc check from `grep -rl "<backlog-number>" docs/2-design/` to `grep -rl "^backlog: <backlog-number>$" docs/2-design/`. Similarly for plan doc check in `docs/3-plans/`. This prevents false-positive phase skipping when short numbers appear as incidental text. Evidence: lesson `e00-setup/2026-03-13-s00-design-artifact-matching.md`. (Proposed as convention change.)

2. **Replace `item-list` with per-issue GraphQL in `issue-set-status.sh`** — The current `gh project item-list` approach fetches all project items, costing many GraphQL points per call. Replace with a targeted query: `repository(owner:..., name:...) { issue(number: N) { projectItems(first: 1) { nodes { id } } } }`. This reduces per-call cost from ~200+ points to ~1 point. Evidence: lesson `e00-setup/2026-03-13-s00-rate-limit-item-list.md`. (Not proposed as convention change — this is a code change to `issue-set-status.sh`, outside the retro agent's scope.)

3. **Add rate limit awareness convention** — Document in CLAUDE.md that the GitHub GraphQL API has a 5000 points/hour budget, and that heavy commands (`gh project item-list`, `gh project item-add`) consume significant points. Agents should prefer lightweight per-issue queries when available. (Proposed as convention change.)

4. **Continue tracking haiku token efficiency** — Three runs of consistent data (Runs 8, 9, 10) show haiku uses 3-4x more tokens than sonnet for comparable tasks at comparable cost. No model routing change is warranted yet, but this baseline is now established.

5. **Consider capturing orchestrator overhead metrics** — Orchestrator overhead was 51% of wall-clock time this run (31m of 61m). While some overhead is inherent (branch management, merges), the rate limit workaround added avoidable time. Tracking this metric across runs would surface efficiency regressions.

## Lesson Retention

Four lesson files were written during this epic:

| Lesson | File | Status |
|--------|------|--------|
| Design artifact matching | `e00-setup/2026-03-13-s00-design-artifact-matching.md` | Absorbed into recommendation 1 (proposed convention change) |
| GraphQL rate limit exhaustion | `e00-setup/2026-03-13-s00-rate-limit-item-list.md` | Absorbed into recommendations 2-3 (script change + convention change) |
| `grep -c` exit code pitfall | `e01-logging-infra/2026-03-13-s01-grep-c-exit-code.md` | Retained — shell scripting knowledge, not a convention change candidate |
| Design-implementation drift | `e01-logging-infra/2026-03-13-s02-design-implementation-drift.md` | Retained — process observation, single occurrence, not a convention change candidate |

All lesson files remain on disk for traceability. This retro doc is the primary reference for Run 10 learnings going forward.
