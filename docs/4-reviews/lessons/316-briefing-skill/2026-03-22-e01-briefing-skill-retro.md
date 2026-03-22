---
date: 2026-03-22
author: carlosboeing
agent: retro
backlog-issue: 316
backlog-pr: 324
scope: Pure AI-driven /briefing skill with context-aware project orientation
---

# Briefing Skill Implementation -- Agentic Workflow Retrospective

## Summary

Backlog 316 delivered a new `/briefing` Claude Code skill that provides structured project orientation with two modes (briefing between cycles, debrief during open PRs), three depth levels, and 13 configurable data sources. The feature was implemented across 1 epic with 2 stories (1 easy config change, 1 medium prompt engineering), both approved on first review with zero fix cycles. This was the first pure AI-driven skill in the workflow -- no scripts, no tests, no production code -- validating that the SDLC pipeline handles prompt engineering workloads efficiently.

## Timeline

| Phase | Time (UTC) | Wall Clock | Activity |
|-------|-----------|------------|----------|
| Phase 0: Setup | 06:23:49 | ~0m 23s | State init, pricing fetch, branch setup |
| Phase 1: Design | -- | skipped | Design doc existed pre-session (`docs/2-design/2026-03-22-briefing-skill.md`) |
| Phase 2: Plan | 06:24:12 -- 06:29:03 | ~4m 51s | Planner created plan doc, 2 issues (319, 320), dependency graph |
| Phase 3: Build W1 | 06:31:06 -- 06:35:25 | ~4m 19s | Builder (sonnet): E01-S01 config schema (`22ba735`) |
| Phase 3: Review W1 | 06:35:57 -- 06:37:10 | ~1m 13s | Reviewer (opus): S01 APPROVE, 0 critical, 0 warnings, 1 suggestion |
| Phase 3: Build W2 | 06:38:09 -- 06:41:57 | ~3m 48s | Builder (sonnet): E01-S02 SKILL.md (`fd9a212`) |
| Phase 3: Review W2 | 06:42:45 -- 06:45:40 | ~2m 55s | Reviewer (opus): S02 APPROVE, 0 critical, 0 warnings, 3 suggestions |
| Phase 4: Merge + PR | 06:45:40 -- 06:47:27 | ~1m 47s | Merge stories into epic, epic into integration, changelog, PR 324 |
| Phase 5-6: Review + Retro | 06:47:27 -- | -- | PR review and retro dispatched in parallel |
| **Total** | 06:23:49 -- 06:47:27 | **~23m 38s** | |

*Source: `orchestrator.json` dispatch timestamps + git log (`af0af0d` at 06:47:27 UTC).*

## Telemetry

### Per-Story Breakdown

| Story | Issue | Difficulty | Model Used | Agent Time | Tokens | Est. Cost | Tool Uses |
|-------|-------|-----------|------------|-----------|--------|-----------|-----------|
| E01-S01 (build) | #319 | easy | sonnet | 4m 19s | 38K | ~$0.23 | 13 |
| E01-S01 (review) | #319 | easy | opus | 1m 13s | 48K | ~$0.49 | 15 |
| E01-S02 (build) | #320 | medium | sonnet | 3m 48s | 64K | ~$0.39 | 24 |
| E01-S02 (review) | #320 | medium | opus | 2m 55s | 68K | ~$0.68 | 30 |
| **Story Total** | | | | **12m 15s** | **218K** | **~$1.79** | **82** |

### Full Dispatch Breakdown

| Dispatch | Agent | Issue | Duration | Tokens | Est. Cost | Tool Uses | Result |
|----------|-------|-------|----------|--------|-----------|-----------|--------|
| 1 | Planner (opus) | #317 | 4m 51s | 67K | ~$0.67 | 45 | success |
| 2 | Builder (sonnet) | #319 | 4m 19s | 38K | ~$0.23 | 13 | success |
| 3 | Reviewer (opus) | #319 | 1m 13s | 48K | ~$0.49 | 15 | APPROVE |
| 4 | Builder (sonnet) | #320 | 3m 48s | 64K | ~$0.39 | 24 | success |
| 5 | Reviewer (opus) | #320 | 2m 55s | 68K | ~$0.68 | 30 | APPROVE |
| **Total** | | | **17m 8s** | **287K** | **~$2.46** | **127** | |

*Cost estimates use Anthropic's published API token pricing with a blended rate (75% input / 25% output tokens).*

### Aggregate

| Metric | Value |
|--------|-------|
| Stories completed | 2/2 |
| Tests written | 0 (pure prompt engineering -- no testable code) |
| Fix cycles | 0 |
| Critical issues found by reviewers | 0 |
| Warnings found by reviewers | 0 |
| Suggestions found by reviewers | 4 (1 on S01, 3 on S02) |
| Total dispatches | 5 (1 planner, 2 builders, 2 reviewers) |
| Orchestrator overhead (estimated) | ~6m 30s |
| Total wall clock (setup through PR open) | ~23m 38s |

## What Worked

### 1. Clean first-pass approvals across all stories

Both stories were approved on first review with zero critical issues and zero warnings. This is the cleanest review outcome in the project's history -- most runs have at least one warning. The planner's acceptance criteria were precise (character-for-character schema match for S01, 14 explicit ACs for S02), and the builders followed them exactly. Evidence: reviewer comments on issues #319 and #320 both show `APPROVE` with empty critical/warnings tables.

### 2. Efficient sequential dispatch for dependent stories

The dependency (S02 depends on S01's config schema) made parallelism impossible, yet the total build+review time was only 12m 15s for both stories. The sequential pipeline had minimal gaps between dispatches: S01 build finished at 06:35:25, reviewer started at 06:35:57 (32s gap); S01 review finished at 06:37:10, S02 build started at 06:38:09 (59s gap). Orchestrator transitions were fast. Evidence: dispatch timestamps in `orchestrator.json`.

### 3. Design doc written externally reduced wall clock by an estimated 10-15 minutes

The design doc existed before the session started (approved externally, committed in `e5261f8`). This allowed the orchestrator to skip the design phase entirely. For a size/S feature, the design phase would have consumed at least one Opus dispatch (~5-15 min depending on complexity). The planner still delivered a high-quality plan (164 lines, clear structural decisions), demonstrating that pre-approved design docs feed cleanly into the pipeline. Evidence: `phases.design.status: "skipped"` in state file.

### 4. Prompt engineering stories work well in the SDLC pipeline

This was the first backlog item that delivered a pure AI prompt file (374-line SKILL.md) rather than code or scripts. The pipeline's review process adapted well -- the S02 reviewer verified all 14 acceptance criteria, confirmed read-only safety of all bash commands in the skill file, and validated cross-reference to the design doc's 13 data sources. The review was substantive despite there being no tests to run. Evidence: S02 review comment on issue #320 with full AC verification table.

### 5. Planner structural decisions avoided unnecessary overhead

The planner explicitly documented why 1 epic (not 2) and 2 stories (not 1 or 3) were the right decomposition. The plan's rationale -- "splitting SKILL.md by mode would create 60%+ overlap" and "config change is < 5 minutes of work" -- proved correct. Neither story exceeded 5 minutes of build time. Evidence: plan doc `docs/3-plans/2026-03-22-briefing-skill-plan.md`, section 2.

## What Didn't Work

### 1. No backlog-level telemetry posted before retro dispatch

The backlog issue (#316) has zero comments. The orchestrator posted epic-level telemetry on issue #318 but did not post backlog-level telemetry on issue #316 before dispatching the retro. The retro agent must reconstruct aggregate metrics from the state file rather than reading them from a telemetry comment. This is a recurring gap -- see recommendation AP in `retro-recommendations.md`. The backlog PR description also lacks the full lifecycle telemetry summary at this point.

### 2. Reviewer cost exceeds build cost

Reviewers consumed $1.17 (48% of story cost) vs builders at $0.62 (25% of story cost), with the remaining 27% going to the planner. For an easy config change (S01), the Opus reviewer ($0.49) cost more than double the Sonnet builder ($0.23). The reviewer found zero issues -- the review was thorough but the story was trivially correct. This reinforces observation xxiv (tiered review) and recommendation P (model routing for docs-only reviewers). An easy config-only story is a strong candidate for Sonnet reviewer routing.

### 3. State file `epics.e01.stories` left empty

The state file's `epics.e01.stories` dict is `{}` despite both stories completing successfully. This is the same gap identified in recommendation AI -- the orchestrator does not populate story metadata during branch setup. The impact here is minor (only 2 stories, easy to trace manually), but for larger features this makes automated story-to-dispatch correlation impossible.

## Workflow Evolution During Epic

No convention changes were made to CLAUDE.md or agent files during this backlog item.

| Commit | Change | Trigger |
|--------|--------|---------|
| `51997f6` | Added missing `backlog: 316` frontmatter to design doc | Phase detection requires frontmatter grep |

*The design doc was written externally and lacked the `backlog` frontmatter field. The orchestrator fixed this before proceeding to the plan phase.*

## Key Learnings

### For Builders

1. Prompt engineering stories (SKILL.md) benefit from the same structured acceptance criteria as code stories. The S02 builder implemented all 14 ACs systematically, producing a 374-line skill file that matched the design doc faithfully.
2. Config-only stories (S01) are fast and clean when the schema is fully specified in the plan. S01 took 4m 19s with 13 tool uses -- the builder added the JSON block, validated with `jq`, and committed.

### For the Orchestrator

1. Pre-approved design docs eliminate an entire phase. When a design exists before the session, detecting it via frontmatter grep and skipping design saves significant wall clock and cost (estimated 10-15 min and $0.50-$1.50 for a size/S feature).
2. Sequential dispatch is appropriate for small features with dependencies. With only 2 stories and a hard dependency, there was nothing to parallelize. The orchestrator correctly dispatched sequentially rather than attempting to force parallelism.

### For the Workflow

1. **Pure-prompt features validate the pipeline's generality.** The SDLC workflow handles prompt engineering deliverables (no code, no tests, no scripts) as effectively as traditional code features. The review process adapted naturally -- reviewers checked AC compliance, safety properties (read-only commands), and design doc fidelity.
2. **Small features (size/S) complete in under 25 minutes wall clock.** BL316 is the fastest complete backlog item in project history: ~23m 38s from session start to PR open, with $2.46 total cost across 5 dispatches. This sets a baseline for size/S features.
3. **Reviewer model routing for easy stories remains an open opportunity.** The Opus reviewer on S01 (easy, config-only) cost $0.49 for a story with zero issues. A Sonnet reviewer would have cost approximately $0.15-$0.20 based on observation xviii (Sonnet reviewer quality is consistently high). Across two stories, the potential saving is modest (~$0.30), but it compounds across runs.

## Recommendations

1. **No convention changes proposed.** This was a clean, small feature with zero fix cycles, zero critical issues, and no novel failure modes. No patterns emerged that warrant new conventions.

2. **Reinforce recommendation AI (populate `epics.*.stories` in state file)** -- observed again in this run. The `stories` dict was empty for E01 despite both stories completing. Third occurrence (after BL242 and Run 17).

3. **Reinforce observation xxiv (tiered review saves cost)** -- S01 (easy, config-only) consumed $0.49 in Opus review for zero findings. Sonnet reviewer would have been sufficient. This run adds a data point to the case for Sonnet reviewer routing on easy stories (recommendation P).

4. **Add size/S baseline to observations** -- BL316 establishes the first clean size/S baseline: 23m 38s wall clock, $2.46 cost, 5 dispatches, 0 fix cycles. Future size/S features can be compared against this.

## Lesson Retention

No individual lesson files were created during this backlog item. No pre-existing lessons are relevant. This retro doc is the sole record for BL316.
