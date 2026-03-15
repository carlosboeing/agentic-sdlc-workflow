---
date: 2026-03-14
author: retro
backlog-issue: 41
backlog-pr: pending
scope: Run 11 -- board drift detection infrastructure + Incident Reports from Fairy Tale HR -- 2 epics, 6 stories, 4 dispatch waves
---

# Board Drift Detection (Run 11) -- Agentic Workflow Retrospective

## Summary

Run 11 delivered two workstreams across 2 epics and 6 stories: a board drift detection diagnostic script (`check-board-drift.sh`) with validation integration, and four "Incident Reports from Fairy Tale HR" content files. The primary test objective -- investigating the board status persistence bug -- was met: the drift detection infrastructure was created and is ready for diagnostic use. All 6 stories passed review on first attempt (5 APPROVE, 1 COMMENT), no re-dispatches were needed, and no merge conflicts occurred. Wave 3 successfully exercised 3-way parallel dispatch with worktree isolation. All three difficulty levels (easy/medium/hard) and all three builder models (haiku/sonnet/opus) were used.

## Timeline

| Phase | Time (UTC) | Wall Clock | Activity |
|-------|-----------|------------|----------|
| Orchestrator setup | 02:34 -- 02:34 | ~1m | Session init, pricing fetch, state file creation |
| Design | 02:34 -- 02:39 | ~5m | Designer produced design doc, PR #43 merged (`694ef13`) |
| Plan | 02:39 -- 02:47 | ~8m | Planner created plan + 8 issues, PR #53 merged (`e11489e`) |
| Wave 1: E01-S01 (build + review) | 02:47 -- 02:52 | ~5m | Sonnet build (2m14s) + opus review (2m7s). APPROVE. |
| Wave 2: E01-S02 (build + review) | 02:53 -- 02:59 | ~6m | Haiku build (2m13s) + opus review (2m59s). APPROVE. |
| E01 merge | 02:59 -- 03:00 | ~1m | Story branches into epic, epic into integration (`154dfed`) |
| Wave 3: E02-S01/S02/S03 (parallel builds + reviews) | 03:03 -- 03:09 | ~6m | 3 parallel builders (haiku/haiku/sonnet, worktree isolation), then 3 reviews. APPROVE/COMMENT/APPROVE. |
| Wave 4: E02-S04 (build + review) | 03:12 -- 03:19 | ~7m | Opus build (3m25s) + opus review (3m15s). APPROVE. |
| E02 merge | 03:07 -- 03:17 | ~10m | 4 story branches into epic, epic into integration (`1c9b69c`) |
| **Total** | 02:34 -- 03:19 | **~45m** | Full lifecycle excluding retro and changelog |

*Source: `git log main..backlog/41-board-drift-detection --format="%h %ai %s"` and orchestrator state file `.claude/state/41/orchestrator.json`.*

## Telemetry

### Per-Story Breakdown

| Story | Issue | Difficulty | Build Model | Build Time | Build Tokens | Build Cost | Review Time | Review Tokens | Review Cost | Total Cost |
|-------|-------|-----------|------------|-----------|-------------|-----------|------------|--------------|------------|-----------|
| E01-S01 (Drift Script) | #45 | medium | sonnet | 2m 14s | 49K | ~$0.29 | 2m 7s | 51K | ~$0.51 | ~$0.80 |
| E01-S02 (Validate Logs) | #46 | easy | haiku | 2m 13s | 122K | ~$0.24 | 2m 59s | 39K | ~$0.39 | ~$0.64 |
| E02-S01 (Glass Slipper) | #47 | easy | haiku | 49s | 105K | ~$0.21 | 2m 48s | 41K | ~$0.41 | ~$0.62 |
| E02-S02 (Beanstalk) | #48 | easy | haiku | 1m 0s | 105K | ~$0.21 | 1m 34s | 29K | ~$0.29 | ~$0.50 |
| E02-S03 (Enchantment) | #49 | medium | sonnet | 2m 15s | 34K | ~$0.20 | 2m 27s | 31K | ~$0.31 | ~$0.51 |
| E02-S04 (Sleeping Beauty) | #50 | hard | opus | 3m 25s | 38K | ~$0.38 | 3m 15s | 54K | ~$0.54 | ~$0.92 |
| **Story Total** | | | | **12m 0s** | **454K** | **~$1.54** | **15m 10s** | **244K** | **~$2.44** | **~$3.98** |

*All reviewers used opus. Costs computed using Anthropic API blended rates (opus $10/M, sonnet $6/M, haiku $2/M).*

### Design/Plan Phases

| Phase | Model | Agent Time | Tokens | Est. Cost | Tool Uses |
|-------|-------|-----------|--------|-----------|-----------|
| Design | opus | 4m 22s | 77K | ~$0.77 | 27 |
| Plan | opus | 7m 27s | 84K | ~$0.84 | 44 |
| **Phase Total** | | **11m 49s** | **161K** | **~$1.61** | **71** |

### Aggregate

| Metric | Value |
|--------|-------|
| Stories completed | 6/6 |
| Tests written | 7 test groups in `test-validate-logs.sh` (204 lines) |
| Critical issues caught by reviewer | 0 |
| Warnings caught by reviewer | 5 (W1-W2 on #45, W1-W2 on #46, W1 on #48, W1 on #49) |
| Fix cycles required | 0 |
| Total dispatches | 14 (1 designer, 1 planner, 6 builders, 6 reviewers) |
| Total tokens (all dispatches) | 858K |
| Total estimated cost (all dispatches) | ~$5.58 |
| Full lifecycle wall-clock | ~45 minutes (design through last review, excluding retro) |
| Build+review wall-clock | ~32 minutes (Wave 1 through Wave 4 completion) |
| Orchestrator overhead | ~13 minutes (setup, branch mgmt, merges, board transitions) |

*Note: Orchestrator's own token consumption runs in the parent session and is not captured in dispatch telemetry. The ~$5.58 total covers only subagent dispatches.*

## What Worked

### 1. Zero Fix Cycles for the Third Consecutive Run

All 6 stories passed review on first attempt with no re-dispatches needed. Combined with Run 9's 5/5 and Run 10's 6/6, this extends the streak to 17 consecutive first-pass stories across 3 runs. The single COMMENT verdict (story #48, beanstalk growth) noted a missing explicit "giants" reference but did not block merge. Evidence: all 6 review comments on issues #45-#50 show APPROVE or non-blocking COMMENT verdicts.

### 2. Three-Way Parallel Dispatch with Worktree Isolation (Wave 3)

Wave 3 dispatched three builders in parallel (haiku for #47, haiku for #48, sonnet for #49) using worktree isolation. All three completed successfully with no cross-contamination and no merge conflicts. Sequential agent time was 4m 4s (49s + 60s + 135s); wall-clock time was ~2m 15s (limited by sonnet on #49), yielding a 1.8x parallel speedup. Evidence: dispatch IDs 7, 8, 9 in the state file all show `started_at: "2026-03-14T03:03:00Z"` and `result: "success"`.

### 3. All Three Difficulty Levels Produced Clean Results

The run exercised all three model tiers: haiku for 3 easy stories (#46, #47, #48), sonnet for 2 medium stories (#45, #49), and opus for 1 hard story (#50). All produced first-pass approvals (or non-blocking comments). The opus builder on #50 (Sleeping Beauty) compressed 7 required narrative threads into 53 summary words while maintaining perfect bureaucratic tone -- the reviewer called it "the strongest tone execution across all four reports." Evidence: reviewer comment on #50 confirmed 17/17 acceptance criteria passed with zero warnings.

### 4. Reduced Orchestrator Overhead

Orchestrator overhead was ~13 minutes of the 45-minute total (~29%), compared to ~31 minutes of 61 minutes (~51%) in Run 10. The primary improvement came from the `issue-set-status.sh` per-issue GraphQL fix (commit `9fe34b5`, implemented between Runs 10 and 11), which eliminated the rate limit exhaustion that added ~6 minutes of workaround time in Run 10. Evidence: no rate limit errors appear in the Run 11 dispatch log.

### 5. Content Quality Across All Models

All four incident reports maintained consistent template structure (23 lines each), consistent formatting (em-dash witness attributions, italic policy footers), and consistent bureaucratic tone. The reviewer verified word counts within the 60-100 range for all reports: 89 (haiku), 81 (haiku), 93 (sonnet), 99 (opus). Despite using three different models, the output was structurally uniform. Evidence: reviewer comments on #47-#50 all note template compliance.

## What Didn't Work

### 1. Missing Issue Comments on Parallel Haiku Builders

Two of the three Wave 3 parallel builders failed to post expected issue comments. Story #47 (haiku) is missing both "Work Started" and "Ready for Review" comments. Story #48 (haiku) is missing the "Work Started" comment. Story #49 (sonnet, same wave) has all three expected comments. This matches the pattern first observed in Run 4 (recommendation D in the retro tracker), where parallel builders failed to post comments due to API contention. Root cause: the haiku builder scripts (`issue-start.sh`, `issue-review.sh`) call the GitHub API, and concurrent API calls from parallel worktree builders can fail silently. The orchestrator posted telemetry on all stories, so the gap is limited to issue-start/issue-review comments. Evidence: `gh issue view 47 --json comments` shows only Telemetry and Review comments; `gh issue view 48` shows Ready for Review, Telemetry, and Review but no Work Started.

### 2. Haiku Token Consumption Remains 3-4x Higher Than Sonnet

Consistent with Runs 8, 9, and 10, haiku builders consumed significantly more tokens than sonnet for comparable tasks. E01-S02 (haiku, easy script extension) used 122K tokens vs E01-S01 (sonnet, medium script creation) at 49K tokens. For content stories, the three haiku builds averaged 111K tokens vs sonnet's 34K on E02-S03. The cost difference is absorbed by haiku's lower per-token rate ($0.24 avg vs $0.25 avg), making this a persistent but cost-neutral pattern. Evidence: state file shows haiku builders (#46: 122K, #47: 105K, #48: 105K) vs sonnet builders (#45: 49K, #49: 34K). This is now a 4-run trend (Runs 8-11).

### 3. Reviewer Warnings About Design Doc Divergence (E01-S01)

The reviewer on story #45 (drift detection script) found that the stdout output format diverged from the design doc specification in several ways: different delimiters (`=== Board Drift Detection Check ===` vs spec's `=== Board Drift Check ===`), expanded field names, and missing closing delimiter. While the log file format matched the spec exactly (which is what downstream tools parse), the stdout cosmetic divergence was flagged as W1. This is a minor instance of the builder producing a "better" implementation that doesn't exactly match the spec. Root cause: the builder interpreted the design doc as guidance rather than prescription for the stdout format. Evidence: reviewer comment on #45, warning W1.

## Workflow Evolution During Epic

| Commit | Change | Trigger |
|--------|--------|---------|
| `9fe34b5` (pre-Run 11) | Replaced `item-list` with per-issue GraphQL in `issue-set-status.sh` | Run 10 rate limit exhaustion |
| `8df7de5` (pre-Run 11) | Fixed self-referential placeholders in `issue-create-backlog.sh` | Run 10 lesson |
| `e6ee36a` (pre-Run 11) | Created `issue-create-backlog.sh` for consolidated backlog setup | Run 10 lesson |

No CLAUDE.md or agent file changes were committed during Run 11 itself. Three infrastructure improvements were committed between Runs 10 and 11, all addressing Run 10 findings. The per-issue GraphQL change (`9fe34b5`) directly resolved the rate limit exhaustion that added 6 minutes of overhead in Run 10.

## Key Learnings

### For Builders

1. When parallel builders run in worktree isolation, the `issue-start.sh` and `issue-review.sh` scripts may fail to post issue comments due to concurrent GitHub API calls. This does not affect the build itself -- only the audit trail on the issue. The orchestrator compensates by posting telemetry afterward. Evidence: stories #47 and #48 missing comments in Wave 3.

2. The design doc stdout format should be treated as prescriptive unless explicitly marked as "suggested." Story #45's builder deviated from the specified stdout format (while matching the log format exactly), prompting reviewer warning W1. When in doubt, match the spec exactly and propose improvements in a follow-up.

### For the Orchestrator

1. The `issue-set-status.sh` per-issue GraphQL fix (`9fe34b5`) successfully eliminated rate limit exhaustion. Orchestrator overhead dropped from 51% (Run 10) to 29% (Run 11) of wall-clock time. The remaining 13 minutes of overhead is primarily branch management, merge operations, and board transitions -- likely irreducible.

2. Post-wave comment verification (recommendation D in the retro tracker) remains unimplemented. Wave 3 lost 3 issue comments across 2 stories. The orchestrator should verify expected comments exist after parallel waves and post missing ones retroactively.

3. The `gh project item-add` command does not set a default status. The orchestrator must always follow up with `issue-set-status.sh <N> backlog` after adding an item to the project. Evidence: lesson `e00-setup/2026-03-14-s00-board-item-add-no-default-status.md`.

### For the Workflow

1. **Seventeen consecutive first-pass approvals** (Runs 9-11) confirms the builder-reviewer loop is stable for both infrastructure and content tasks. The acceptance criteria format with explicit checklists produces reliable output regardless of model tier.

2. **Haiku token consumption pattern is now established across 4 runs** (Runs 8-11). Haiku consistently uses 3-4x more tokens than sonnet for comparable tasks, with comparable costs due to the 3x price difference. No model routing change is warranted.

3. **The per-issue GraphQL optimization paid immediate dividends.** Run 10's recommendation 2 (replace `item-list` with per-issue queries) was implemented pre-Run 11 and reduced orchestrator overhead by ~18 minutes compared to Run 10. This validates the "implement infra fixes between runs" cadence.

4. **Missing issue comments in parallel waves is a persistent pattern.** First observed in Run 4, confirmed in Run 11. Two separate data points now support implementing post-wave comment verification (recommendation D).

## Recommendations

1. **Implement post-wave comment verification** -- After each parallel wave completes, the orchestrator should query all stories in the wave for expected comments ("Work Started", "Ready for Review") and post missing ones retroactively. This has now been observed in Run 4 (#114) and Run 11 (#47, #48) -- two independent occurrences across 8 runs. Evidence: lesson from Run 4 (rec D), Run 11 stories #47 and #48 missing comments. (Proposed as convention change to `orchestrator.md`.)

2. **Add `gh project item-add` status follow-up convention** -- Document in CLAUDE.md that `gh project item-add` does not set a default status. The pattern `item-add` + `issue-set-status.sh <N> backlog` must always be used together. Evidence: lesson `e00-setup/2026-03-14-s00-board-item-add-no-default-status.md`. (Proposed as convention change.)

3. **Continue tracking autonomous lifecycle duration** -- Run 11 completed in ~45 minutes (design through last review), down from ~61 minutes in Run 10. Current baseline: Run 5 ~30m, Run 6 ~28m, Run 8 ~40m, Run 9 ~29m, Run 10 ~61m (rate limit overhead), Run 11 ~45m. This aligns with outstanding recommendation G.

4. **Continue tracking haiku token efficiency** -- Four runs of consistent data (Runs 8-11) show haiku uses 3-4x more tokens than sonnet for comparable tasks at comparable cost. No model routing change warranted, but the baseline is firmly established across 4 runs (observation i in the retro tracker).

5. **Board drift detection script is ready for diagnostic use** -- The orchestrator should invoke `scripts/check-board-drift.sh <issue-number> <status>` after board transitions in future runs to collect drift timing data. This was the primary test objective and the infrastructure is now in place. The script has not yet been exercised against a real board transition in a live run (it was the output of this run, not the tooling used during it).

## Lesson Retention

One lesson file was written during this epic:

| Lesson | File | Status |
|--------|------|--------|
| `gh project item-add` no default status | `e00-setup/2026-03-14-s00-board-item-add-no-default-status.md` | Absorbed into recommendation 2 (proposed convention change) |

No lessons were written by builders or reviewers during this run. The retro identified two additional patterns (missing parallel comments, design doc format divergence) from reviewer comments rather than lesson files.

All lesson files remain on disk for traceability. This retro doc is the primary reference for Run 11 learnings going forward.
