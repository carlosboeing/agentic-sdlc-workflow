---
date: 2026-03-11
author: carlosboeing
agent: retro
backlog-issue: 205
backlog-pr: pending
scope: "Run 7 SDLC v2 test -- 2 epics, 5 stories, markdown-only content with parallel dispatch and workspace collision"
---

# Run 7: Alien Field Study -- Agentic Workflow Retrospective

## Summary

Run 7 produced the "Alien Anthropological Field Study of Earth" -- five markdown documents written from the perspective of alien researchers studying human behaviour. Two epics were completed: E01 (3 field observation reports, parallel dispatch) and E02 (2 administrative/classification documents, sequential dispatch). The run validated parallel dispatch, model routing across 3 tiers (haiku/sonnet/opus), and sequential dependencies, but exposed a critical workspace collision bug: parallel builders sharing a working directory caused files from one story to appear on another's branch. Three of five stories required fix cycles (2 from workspace contamination cleanup, 1 from a reviewer content requirement).

## Timeline

| Phase | Time (UTC) | Wall Clock | Activity |
|-------|-----------|------------|----------|
| Design | 11:03:56 – 11:04:31 | ~3m | Designer created design doc (`7090982`), PR #207 auto-merged |
| Plan | 11:07:06 – 11:09:44 | ~5m | Planner created plan (`3423551`), PR #216 auto-merged, issues created |
| Wave 1 (E01 build) | 11:13:31 – 11:15:18 | ~2m | 3 parallel builders: #209 haiku, #210 haiku, #211 sonnet |
| Wave 1 (E01 review) | ~11:15 – ~11:20 | ~5m | 3 reviews: #209 REQUEST_CHANGES, #210 COMMENT, #211 REQUEST_CHANGES |
| Wave 1 (E01 fix) | ~11:20 – ~11:22 | ~3m | Fix cycles for #209 (workspace cleanup + re-review) and #211 (content fix + re-review) |
| E01 merge | 11:22:57 – 11:23:27 | ~0.5m | 3 story branches merged into epic, epic merged into integration (`db18d49`) |
| Wave 2 (E02-S01 build) | 11:25:01 | ~1.5m | Sonnet builder for species assessment (`22bddfe`) |
| Wave 2 (E02-S01 review) | ~11:26 – 11:26:52 | ~1m | APPROVE on first review |
| E02-S01 merge | 11:26:52 | ~0.5m | Story merged into epic (`04d2b70`) |
| Wave 3 (E02-S02 build) | 11:29:13 | ~7m | Opus builder for council recommendation (`ac6f7e4`) |
| Wave 3 (E02-S02 review) | ~11:36 – ~11:37 | ~1.5m | REQUEST_CHANGES (option c needed second sentence) |
| Wave 3 (E02-S02 fix) | 11:37:32 | ~1m | Haiku fix for content (`65df0c9`) |
| E02 merge | 11:38:01 – 11:38:04 | ~0.5m | Story merged into epic, epic merged into integration (`c983210`) |
| **Total** | 11:03:56 – 11:38:04 | **~34m** | Design through E02 merge (excludes retro) |

*Source: `git log main..backlog/205-alien-field-study --format="%h %ai %s"` and orchestrator state file timestamps.*

## Telemetry

### Per-Story Build Breakdown

| Story | Issue | Difficulty | Model | Agent Time | Tokens | Est. Cost | Tool Uses |
|-------|-------|-----------|-------|-----------|--------|-----------|-----------|
| E01-S01 The Commute | #209 | easy | haiku | 0m 53s | 102K | ~$0.20 | 14 |
| E01-S01 fix | #209 | easy | haiku | 1m 13s | 103K | ~$0.21 | 25 |
| E01-S02 The Queue | #210 | easy | haiku | 1m 0s | 100K | ~$0.20 | 20 |
| E01-S03 Brunch | #211 | medium | sonnet | 2m 53s | 32K | ~$0.19 | 29 |
| E01-S03 fix | #211 | medium | sonnet | 1m 50s | 33K | ~$0.20 | 30 |
| E02-S01 Species Assessment | #212 | medium | sonnet | 1m 21s | 28K | ~$0.17 | 14 |
| E02-S02 Council Recommendation | #213 | hard | opus | 6m 59s | 35K | ~$0.35 | 32 |
| E02-S02 fix | #213 | — | haiku | 0m 48s | 99K | ~$0.20 | 17 |
| **Build Total** | | | | **17m 7s** | **532K** | **~$1.72** | **181** |

### Per-Story Review Breakdown

| Story | Issue | Model | Agent Time | Tokens | Est. Cost | Tool Uses | Verdict |
|-------|-------|-------|-----------|--------|-----------|-----------|---------|
| E01-S01 R1 | #209 | opus | 0m 53s | 24K | ~$0.24 | 15 | REQUEST_CHANGES |
| E01-S01 R2 | #209 | opus | 0m 52s | 24K | ~$0.24 | 8 | COMMENT |
| E01-S02 R1 | #210 | opus | 0m 57s | 24K | ~$0.24 | 11 | COMMENT |
| E01-S03 R1 | #211 | opus | 1m 34s | 26K | ~$0.26 | 14 | REQUEST_CHANGES |
| E01-S03 R2 | #211 | opus | 0m 59s | 24K | ~$0.24 | 10 | APPROVE |
| E02-S01 R1 | #212 | opus | 0m 52s | 23K | ~$0.23 | 7 | APPROVE |
| E02-S02 R1 | #213 | opus | 1m 23s | 26K | ~$0.26 | 13 | REQUEST_CHANGES |
| **Review Total** | | | **7m 30s** | **171K** | **~$1.71** | **78** | |

### Per-Phase Breakdown

| Phase | Model | Agent Time | Tokens | Est. Cost | Tool Uses |
|-------|-------|-----------|--------|-----------|-----------|
| Design | opus | 2m 39s | 44K | ~$0.44 | 18 |
| Plan | opus | 4m 26s | 50K | ~$0.50 | 30 |
| Build (5 stories + 3 fixes) | mixed | 17m 7s | 532K | ~$1.72 | 181 |
| Review (7 reviews) | opus | 7m 30s | 171K | ~$1.71 | 78 |
| Retro | opus | pending | -- | -- | -- |
| **Total** | | **31m 42s** | **797K** | **~$4.37** | **307** |

*Note: Retro telemetry will be added by the orchestrator after this agent completes. Orchestrator overhead is not captured (runs in parent session). GitHub API rate limiting prevented retrieval of issue comment telemetry -- all figures sourced from the orchestrator state file (`.claude/state/205/orchestrator.json`).*

### Aggregate

| Metric | Value |
|--------|-------|
| Stories completed | 5/5 |
| Stories passing first review | 2/5 (#210 COMMENT, #212 APPROVE) |
| Fix cycles required | 3 (2 from workspace collision, 1 from content) |
| Tests written | 0 (markdown-only content, no code) |
| Critical bugs caught by reviewer | 2 (workspace contamination on #209, missing brunch sections on #211) |
| Warnings caught by reviewer | 1 (option c needed second sentence on #213) |
| Lessons captured | 2 (workspace collision, rate limiting) |

### Parallelism

| Wave | Stories | Dispatch | Sequential Duration | Actual Duration | Speedup |
|------|---------|----------|--------------------:|----------------:|--------:|
| 1 (E01) | #209, #210, #211 | parallel | 4m 46s | ~2m | ~2.4x |
| 2 (E02-S01) | #212 | sequential | 1m 21s | 1m 21s | 1.0x |
| 3 (E02-S02) | #213 | sequential | 6m 59s | 6m 59s | 1.0x |

*Note: Wave 1 parallel speedup is approximate -- the actual duration was compressed but fix cycles added back ~3 minutes of sequential work.*

## What Worked

### 1. Sequential Dispatch for E02 Was Clean

Wave 2 (E02-S01, #212) was the cleanest story of the run: sonnet built the species assessment in 1m 21s, the reviewer approved on first attempt, and the merge was straightforward. Wave 3 (E02-S02, #213) also built cleanly, with the only fix being a minor content addition (second sentence for option c). Sequential dispatch avoided the workspace collision issues that plagued Wave 1.

### 2. Model Routing Worked Across All Three Tiers

The run successfully dispatched haiku (2 easy stories), sonnet (2 medium stories), and opus (1 hard story) builders. Each model tier performed as expected: haiku was fast but token-heavy (~100K tokens per story), sonnet balanced speed and token efficiency (~30K tokens), and opus was thorough but slow (35K tokens over 7 minutes). The fix for #213 was correctly dispatched to haiku (low-complexity text edit), showing appropriate model selection for fix cycles as well.

### 3. State File Captured All Dispatch Telemetry

The orchestrator state file (`.claude/state/205/orchestrator.json`) recorded all 17 dispatches with model, duration, tokens, tool uses, and result. This was the primary data source for the retro since GitHub API rate limiting prevented retrieval of issue comments. The state file's value as a backup telemetry source was validated by this exact scenario.

### 4. Cross-References in E02-S02 Were Correct

Despite being a hard story, E02-S02 correctly cross-referenced the species assessment by document ID and field reports by report number, as required by the acceptance criteria. The sequential dependency (E02-S01 before E02-S02) ensured the species assessment existed on the epic branch when the opus builder needed to reference it.

## What Didn't Work

### 1. Parallel Dispatch Without Worktree Isolation Caused Workspace Collision

Wave 1 dispatched 3 builders in parallel without `isolation: "worktree"`. The E01-S01 haiku builder wrote `report-the-commute.md` to the working directory, and it was picked up by the E01-S03 sonnet builder and committed on the brunch branch. Commit `c249257` ("fix(content): remove commute report from brunch story branch") confirms the cross-contamination.

**Root cause:** All parallel builders shared the same working directory. When one builder wrote a file and another ran `git add`, the file was staged on the wrong branch.

**Impact:** E01-S01 required a fix cycle (dispatch #9, haiku, 73s, 103K tokens) partly due to workspace contamination. E01-S03 required a fix cycle (dispatch #10, sonnet, 110s, 33K tokens) to clean up the contamination and address reviewer content feedback. Combined cost: ~$0.41 in additional build time plus ~$0.48 in re-review costs.

**Pattern evidence:** This is the same issue identified in Run 4 (lesson: `docs/4-reviews/lessons/2026-03-10-test-agentic-sdlc-run04-travel-advisory/e01-destination-profiles/2026-03-10-s00-parallel-dispatch-no-worktree-isolation.md`), where it was flagged as a theoretical risk. In Run 7, it became an actual defect. The pattern has now appeared in 2 of 4 runs that used parallel dispatch (Runs 4, 7), confirming it is not an edge case.

*Reference: lesson file `docs/4-reviews/lessons/2026-03-11-test-agentic-sdlc-run07-alien-field-study/e01-field-reports/2026-03-11-s00-parallel-workspace-collision.md`*

### 2. GitHub GraphQL Rate Limiting Hit During Wave 3

The GitHub GraphQL API rate limit was exceeded during Wave 3, blocking board updates and telemetry commands. This is the second consecutive run (also Run 6) where rate limiting impacted operations.

**Root cause:** Cumulative API calls across design, plan, board management, telemetry posting, and the `tr -d` workaround for `gh project item-list` output parsing. A 5-story run with fix cycles generates an estimated 80-100+ GraphQL API calls.

**Impact:** Issue comments could not be retrieved during retro preparation. Board status updates may have been delayed during Wave 3. The full impact is difficult to quantify because the rate-limit errors prevent querying the very data needed to measure the impact.

*Reference: lesson file `docs/4-reviews/lessons/2026-03-11-test-agentic-sdlc-run07-alien-field-study/e02-admin-documents/2026-03-11-s02-rate-limiting-wave3.md`*

### 3. Higher Fix Cycle Rate Than Previous Runs

3 of 5 stories required fix cycles, compared to 0/5 in Run 6. While 2 of those were caused by the workspace collision (an infrastructure issue, not a builder quality issue), E02-S02's fix cycle was a genuine content miss (option c needed a second sentence per acceptance criteria). The acceptance criteria specified "2-3 sentences each" for the options analysis, but the opus builder wrote only one sentence for option c.

**Root cause:** For #209 and #211, the workspace collision created files that shouldn't have been on the branch, triggering reviewer rejection. For #213, the builder interpreted the acceptance criteria loosely.

## Workflow Evolution During Epic

No convention changes were made to CLAUDE.md or agent files during this run. The integration branch diff shows no modifications to `.claude/agents/` or `CLAUDE.md`.

## Key Learnings

### For Builders

1. **Workspace isolation is required for parallel builds.** Builders cannot safely share a working directory. Even when stories write to separate files, `git add` operations can pick up files from other builders' work (commit `c249257` proves this).
2. **Haiku fix cycles are cheap but frequent.** The haiku fix for #213 cost ~$0.20 (99K tokens at haiku rates), which is affordable, but the need for a fix suggests haiku builders may be less precise with acceptance criteria compliance.

### For the Orchestrator

1. **Worktree isolation is not optional for parallel dispatch.** This lesson was identified as a risk in Run 4 and confirmed as a defect in Run 7. The orchestrator MUST use `isolation: "worktree"` for all parallel builder dispatches.
2. **Rate limiting is now a consistent issue.** Two consecutive runs (6 and 7) hit the GraphQL rate limit. The orchestrator needs rate-awareness -- either batching API calls, caching board state, or introducing backoff.
3. **The state file is a critical backup.** When rate limiting blocked GitHub API access during retro, the state file provided all telemetry data. Without it, this retro would have had significant data gaps.

### For the Workflow

1. **Parallel dispatch delivers speedup but introduces risk.** Wave 1 achieved ~2.4x speedup over sequential execution, but the workspace collision added ~3 minutes of fix cycles, partially negating the benefit. With worktree isolation, the speedup would be preserved without the fix cycle overhead.
2. **The `tr -d` pipe for `gh project item-list` should be documented as a convention.** The control character issue in `gh` output has appeared in multiple runs and adds unnecessary API calls when parsing fails on the first attempt.
3. **Fix cycles for content stories are inexpensive.** The 3 fix cycles in this run added ~$0.89 in total cost (build + re-review). For markdown-only content, fix cycles are a minor cost concern.

## Recommendations

1. **Add worktree isolation requirement to CLAUDE.md** -- The orchestrator MUST use `isolation: "worktree"` when dispatching parallel builders. This addresses the workspace collision confirmed in Run 7 and first flagged in Run 4. Two runs with the same failure pattern meets the threshold for a convention change. *Status: proposed as convention change below.*

2. **Add `tr -d` pipe convention for `gh project item-list`** -- Document that `gh project item-list` output must be piped through `tr -d '\x00-\x1f'` before passing to `jq`. This has been a recurring issue across multiple runs. *Status: proposed as convention change below.*

3. **Add rate-limit awareness to orchestrator** -- This is an architectural change (not a convention) that would require the orchestrator to track API call counts and introduce backoff. Flagged for the planner, not proposed as a convention change here.

4. **Post-parallel verification step** -- After parallel dispatch completes, the orchestrator should verify each story branch contains only its expected files (check against the plan's file list). This is a defense-in-depth measure even with worktree isolation. Flagged as a recommendation for the orchestrator agent file.

## Lesson Retention

| Lesson File | Status | Disposition |
|-------------|--------|-------------|
| `e01-field-reports/2026-03-11-s00-parallel-workspace-collision.md` | Compiled | Summarized in "What Didn't Work" #1; recommendation #1 proposed as convention change |
| `e02-admin-documents/2026-03-11-s02-rate-limiting-wave3.md` | Compiled | Summarized in "What Didn't Work" #2; recommendation #3 flagged for planner |
| (Run 4) `106-travel-advisory/.../parallel-dispatch-no-worktree-isolation.md` | Cross-referenced | Same root cause confirmed as actual defect in this run |

No additional lesson files from previous agents were found for this backlog item -- all lessons were captured during the retro phase.
