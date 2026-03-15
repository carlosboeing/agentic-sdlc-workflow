---
date: 2026-03-15
author: retro
backlog-issue: 56
backlog-pr: pending
scope: "Run 12 — Validate configurable workflow settings (PR 55) via Time Traveler's Yelp Reviews content workload"
---

# Time Traveler's Yelp Reviews — Agentic Workflow Retrospective

## Summary

Run 12 validated the configurable workflow settings introduced in PR 55 (`.claude/agentic-sdlc-config.json`, shared `scripts/lib/config.sh`, model routing, pricing, YAML frontmatter plan detection). The single epic produced 5 stories (2 easy/sonnet, 2 medium/sonnet, 1 hard/opus), all of which passed review on the first attempt — extending the zero-fix-cycle streak to 22 consecutive first-pass approvals (Runs 9-12). One lesson was captured: the backlog issue should transition to In Progress when the design phase begins, not when builders start.

## Timeline

| Phase | Time (UTC) | Wall Clock | Activity |
|-------|-----------|------------|----------|
| Design | 05:29 – 05:30 | ~1m | Designer committed design doc (`9a1da53`), PR 58 merged (`a068a2b`) |
| Plan | 05:32 – 05:36 | ~4m | Planner committed plan (`c7c22ee`), PR 66 merged (`a13a01b`) |
| Wave 1 Build (parallel) | 05:38 – 05:40 | ~2m | S01, S02, S03 dispatched in 3-way parallel with worktree isolation |
| Wave 1 Review | 05:40 – 05:43 | ~3m | All 3 stories reviewed (opus), all APPROVE, merged to epic |
| Wave 2 Build | 05:44 – 05:45 | ~1m | S04 Moon Landing built (sonnet) |
| Wave 2 Review | 05:45 – 05:47 | ~2m | S04 reviewed (opus), APPROVE, merged to epic |
| Wave 3 Build | 05:47 – 05:49 | ~2m | S05 Comparative Guide built (opus), cross-referenced all 4 reviews |
| Wave 3 Review | 05:49 – 05:51 | ~2m | S05 reviewed (opus), cross-references verified, APPROVE, merged to epic |
| Wrap-up | 05:51 – 05:52 | ~1m | Epic merged to integration branch, lesson committed, changelog added |
| **Total** | 05:29 – 05:52 | **~23m** | |

*Source: git log timestamps (AEST converted to UTC) and GitHub issue comment timestamps.*

## Telemetry

### Per-Story Breakdown

| Story | Issue | Difficulty | Model Used | Agent Time | Tokens | Est. Cost | Tool Uses |
|-------|-------|-----------|------------|-----------|--------|-----------|-----------|
| E01-S01 (Great Fire) | #61 | easy | sonnet | 2m 26s | 50K | ~$0.30 | 36 |
| E01-S02 (Great Pyramid) | #62 | easy | sonnet | 2m 7s | 35K | ~$0.21 | 30 |
| E01-S03 (Magna Carta) | #63 | medium | sonnet | 1m 46s | 33K | ~$0.20 | 21 |
| E01-S04 (Moon Landing) | #64 | medium | sonnet | 1m 17s | 31K | ~$0.18 | 16 |
| E01-S05 (Comparative Guide) | #65 | hard | opus | 2m 0s | 35K | ~$1.06 | 16 |
| **Builder Subtotal** | | | | **9m 36s** | **184K** | **~$1.95** | **119** |
| Reviewer (S01) | #61 | — | opus | 51s | 24K | ~$0.24 | — |
| Reviewer (S02) | #62 | — | opus | 47s | 24K | ~$0.24 | — |
| Reviewer (S03) | #63 | — | opus | 1m 13s | 34K | ~$0.34 | — |
| Reviewer (S04) | #64 | — | opus | 58s | 25K | ~$0.25 | — |
| Reviewer (S05) | #65 | — | opus | 1m 6s | 28K | ~$0.28 | — |
| **Reviewer Subtotal** | | | | **4m 55s** | **135K** | **~$1.35** | — |
| Designer | — | — | opus | 3m 36s | 45K | — | — |
| Planner | — | — | opus | 5m 10s | 47K | — | — |
| **Epic Total** | | | | **~24m** | **411K** | **~$2.59** _(builders + reviewers only)_ | **119** |

*Note: Designer and planner cost data not available — no `--cost` or `--rate` flags were passed for those dispatches. Epic telemetry on issue #60 reports $1.24 for builders only (partial figure, pre-reviewer aggregation). The $2.59 total comes from the epic breakdown on issue #60 which includes both builders and reviewers. Tool use counts for reviewers and design/plan phases were not captured.*

### Aggregate

| Metric | Value |
|--------|-------|
| Stories completed | 5/5 |
| Tests written | 0 (content-only workload, no code) |
| Critical bugs caught by reviewer | 0 |
| Warnings caught by reviewer | 0 |
| Suggestions (nice to have) | 3 (historical detail in S02, anachronism note in S03, paraphrase note in S05) |
| Fix cycles | 0 |

## What Worked

### 1. Zero fix cycles across all 5 stories

All 5 stories received APPROVE verdicts on first review, with no warnings. The reviewers found only 3 minor suggestions across the entire epic, none of which blocked merge. This extends the zero-fix-cycle streak for content-only stories to 22 consecutive first-pass approvals (Runs 9-12). Evidence: issue comments on #61-#65 all show single-review APPROVE.

### 2. Parallel Wave 1 with worktree isolation — clean execution

The 3-way parallel dispatch (S01, S02, S03) completed without any cross-contamination, missing comments, or branch issues. All story branches were pushed to remote, all issue comments (Work Started, Ready for Review) were present, and no post-worktree cleanup issues were observed. This contrasts with earlier runs (Run 4 issue #114, Run 11 issues #47-#48) where parallel dispatch caused missing comments. Evidence: all 3 stories in Wave 1 have complete issue comment sets.

### 3. Config-driven workflow validated end-to-end

Run 12's primary purpose was validating PR 55's configurable workflow settings. Model routing correctly dispatched `builder-sonnet` for easy/medium stories and `builder-opus` for the hard story. Scripts successfully read from `.claude/agentic-sdlc-config.json`. Evidence: telemetry on #61-#64 shows `claude-sonnet-4-6`, while #65 shows `opus` — matching the config routing rules.

### 4. Cross-reference verification in S05

The hard story (S05 Comparative Guide) required cross-referencing all 4 prior reviews. The reviewer verified every cross-reference against the source review files — all reviewer pseudonyms, star ratings, specific phrases, and factual details matched. This validates the dependency-ordered dispatch (S05 ran after S01-S04) and demonstrates that content-aware cross-referencing works when dependencies are correctly sequenced. Evidence: reviewer comment on #65 includes a 4-row cross-reference verification table, all PASS.

### 5. Compact wall-clock time

The entire run from design commit to changelog commit took approximately 23 minutes wall-clock. With 5 stories, 5 reviews, a design phase, and a plan phase, this represents efficient throughput — especially with Wave 1's 3-way parallelism compressing 3 builds into ~2 minutes of wall time.

## What Didn't Work

### 1. Backlog status transition timing

The orchestrator set the backlog issue (#56) to In Progress only at Phase 5 (before builder dispatch), leaving it at Backlog status during the entire design and plan phases. This is incorrect — design and planning are active work on the backlog item. The root cause is `orchestrator.md` Phase 5 containing the first In Progress instruction for the backlog issue, with no equivalent instruction in Phase 1 or Phase 2. Evidence: lesson file `e00-setup/2026-03-15-s00-backlog-in-progress-timing.md`.

### 2. Builder cwd reset pitfall (E01-S02)

The E01-S02 builder noted that each Bash tool call resets the working directory, requiring git operations to be chained in a single call. This is a known Claude Code platform behavior documented in CLAUDE.md (parallel dispatch git safety section), but it surprised the builder during sequential work. The convention is already documented for parallel dispatch safety but not explicitly called out as a general builder pitfall. Evidence: user-reported observation from E01-S02 builder session.

## Workflow Evolution During Epic

No convention changes were made to CLAUDE.md or agent files during this epic. The only new artifact was the lesson file for backlog In Progress timing.

| Commit | Change | Trigger |
|--------|--------|---------|
| `f6bd272` | Lesson: backlog In Progress should start at design phase | Orchestrator observed incorrect board status during design/plan phases |

## Key Learnings

### For Builders
1. The Bash tool resets the working directory between calls. Chain git operations in a single `&&` call even during sequential (non-parallel) work to avoid unexpected cwd changes.
2. Content-only stories with detailed acceptance criteria in the issue body consistently achieve first-pass review approval — 22 consecutive approvals across Runs 9-12.

### For the Orchestrator
1. The backlog issue should be set to In Progress at the start of Phase 1 (Design), not Phase 5 (Build). Design and planning are active work on the backlog item and should be reflected in the board status.
2. Post-wave comment verification continues to be important — Run 12 showed clean results (all comments present), but prior runs (4, 11) demonstrate this is not guaranteed.

### For the Workflow
1. Configurable workflow settings (PR 55) are validated and working correctly: model routing, pricing, plan detection via YAML frontmatter grep, and script config reading all function as designed.
2. The single-epic, content-only workload pattern continues to be a reliable test harness for validating infrastructure changes without code complexity.

## Recommendations

1. **Move backlog In Progress transition to Phase 1 (Design)** — The board should reflect that work has started when any phase begins, not just when builders are dispatched. Update `orchestrator.md` Phase 0 or Phase 1 to call `issue-set-status.sh <backlog-issue> in-progress`. Evidence: lesson `e00-setup/2026-03-15-s00-backlog-in-progress-timing.md`. _(Proposed as convention change.)_

2. **Add Run 12 to the Test Run History table** — Update the CLAUDE.md Test Run History table to include Run 12. _(Proposed as convention change.)_

3. **Update zero-fix-cycle observation baseline** — Observation ii in `retro-recommendations.md` should be updated from "17 consecutive" (Runs 9-11) to "22 consecutive" (Runs 9-12) first-pass approvals.

## Lesson Retention

The following lesson file from this epic has been compiled into this retro doc:

| Lesson File | Status | Notes |
|---|---|---|
| `e00-setup/2026-03-15-s00-backlog-in-progress-timing.md` | Proposed | Recommendation 1 — convention change to `orchestrator.md` |

Per the three-tier retention model, this retro doc is now the primary reference for Run 12 learnings. The raw lesson file remains on disk for traceability.
