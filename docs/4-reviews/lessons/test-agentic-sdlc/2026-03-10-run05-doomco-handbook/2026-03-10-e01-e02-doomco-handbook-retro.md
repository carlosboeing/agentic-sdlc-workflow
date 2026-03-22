---
date: 2026-03-10
author: carlosboeing
agent: retro
backlog-issue: 146
epic-prs: [158, 159]
scope: "Full autonomous SDLC v2 pipeline test (Run 5) -- 2 epics, 5 stories, 3 dispatch waves"
---

# DoomCo Handbook (Run 5) -- Agentic Workflow Retrospective

## Summary

Run 5 tested the full autonomous SDLC v2 pipeline end-to-end using a creative content brief (The Supervillain Employee Handbook) to avoid template bias from prior runs. The workflow produced 5 markdown files across 2 epics (Role Profiles, Company Policies) with 3 dispatch waves exercising all three model tiers (haiku, sonnet, opus). All 5 stories passed review on first attempt -- the first run with zero fix cycles. Total wall-clock time from orchestrator start to final PR merge was approximately 30 minutes including design, plan, build, review, merge, and telemetry phases.

## Timeline

| Phase | Time (UTC) | Wall Clock | Activity |
|-------|-----------|------------|----------|
| Design | 06:01:40 -- 06:04:42 | ~3m 1s | Designer created design doc, PR #148 merged at 06:05:03 |
| Plan | 06:05:00 -- 06:10:52 | ~5m 52s | Planner created plan + 7 issues, PR #157 merged at 06:11:28 |
| Label fix | ~06:11 -- ~06:13 | ~2m | Orchestrator retroactively added missing backlog labels to design/plan issues |
| Wave 1 build | 06:14:15 -- 06:15:28 | ~1m 36s | 2 parallel haiku builders: E01-S01 (#152), E01-S02 (#153) |
| Wave 1 review | ~06:15 -- ~06:16 | ~1m | 2 sequential reviews: both APPROVE |
| Wave 1 merge | ~06:16 -- ~06:17 | ~1m | Merge story branches into epic/e01-role-profiles |
| Wave 2 build | 06:17:45 -- 06:20:35 | ~3m 29s | 2 parallel sonnet builders: E01-S03 (#154), E02-S01 (#155) |
| Wave 2 review | ~06:20 -- ~06:21 | ~1m | 2 sequential reviews: both APPROVE |
| Wave 2 merge | ~06:21 -- ~06:23 | ~2m | Merge story branches into respective epic branches |
| Wave 3 build | 06:23:34 -- 06:24:40 | ~1m 43s | 1 sequential opus builder: E02-S02 (#156) |
| Wave 3 review | ~06:24 -- ~06:25 | ~1m | 1 review: APPROVE |
| Wave 3 merge | ~06:25 -- ~06:26 | ~1m | Merge story branch into epic/e02-company-policies |
| Epic reviews | ~06:26 -- ~06:30 | ~4m | E01 PR #158: COMMENT (3 warnings), E02 PR #159: APPROVE |
| PR merge | 06:30:30 -- 06:31:11 | ~1m | Both epic PRs squash-merged to main |
| **Total** | 06:01 -- 06:31 | **~30m** | Design through final PR merge |

*Source: git log timestamps, GitHub issue/PR timestamps, and orchestrator state file.*

## Telemetry

### Per-Story Breakdown

| Story | Issue | Difficulty | Model | Build Time | Build Tokens | Build Cost | Tool Uses |
|-------|-------|-----------|-------|-----------|-------------|-----------|-----------|
| E01-S01 | #152 | easy | haiku | 1m 35s | 102K | ~$0.21 | 27 |
| E01-S02 | #153 | easy | haiku | 56s | 100K | ~$0.20 | 20 |
| E01-S03 | #154 | medium | sonnet | 2m 30s | 31K | ~$0.19 | 28 |
| E02-S01 | #155 | medium | sonnet | 3m 28s | 31K | ~$0.19 | 32 |
| E02-S02 | #156 | hard | opus | 1m 43s | 29K | ~$0.30 | 17 |
| **Build Total** | | | | **10m 15s** | **297K** | **~$1.09** | **124** |

### Per-Phase Breakdown

| Phase | Agent | Model | Duration | Tokens | Est. Cost |
|-------|-------|-------|----------|--------|-----------|
| Design | designer | opus | 3m 1s | 43K | ~$0.44 |
| Plan | planner | opus | 5m 52s | 52K | ~$0.53 |
| Build (5 stories) | builders | mixed | 10m 15s | 297K | ~$1.09 |
| Story reviews (5) | reviewer | opus | 3m 5s | 130K | ~$1.30 |
| Epic reviews (2) | reviewer | opus | 3m 46s | 60K | ~$0.60 |
| **Grand Total** | | | **26m 0s** | **563K** | **~$3.96** |

*Note: Orchestrator overhead tokens are not captured (runs in parent session). The grand total represents subagent consumption only. Costs use Anthropic's published blended rate (75% input / 25% output).*

### Aggregate

| Metric | Value |
|--------|-------|
| Stories completed | 5/5 |
| Tests written | 0 (content-only run, no C# code) |
| Fix cycles needed | 0 (all 5 stories approved on first review) |
| Critical issues from story reviews | 0 |
| Warnings from story reviews | 0 |
| Epic review: E01 PR #158 | COMMENT -- 3 warnings (format inconsistency, horizontal rule, CHANGELOG scope) |
| Epic review: E02 PR #159 | APPROVE -- 2 warnings (lesson file placement, cross-reference gap) |
| Sequential build time | 10m 15s |
| Build wall-clock (with parallelism) | ~7m (3 waves) |
| Full lifecycle wall-clock | ~30m |

## What Worked

### 1. Zero Fix Cycles -- First-Pass Review Success

All 5 stories were approved by the reviewer on first attempt. No builder re-dispatch was needed. This is the first run in the SDLC v2 series to achieve this. The likely cause is the combination of highly specific acceptance criteria in the plan (each story had 10-13 verifiable criteria) and the simplicity of content-only stories (no code, no DI wiring, no test framework interactions).

### 2. Three-Wave Parallel Dispatch Worked Cleanly

The three-wave dispatch strategy executed exactly as planned:
- Wave 1: 2 parallel haiku builders (E01-S01, E01-S02) completed in ~1m 36s wall-clock vs ~2m 31s sequential
- Wave 2: 2 parallel sonnet builders (E01-S03, E02-S01) completed in ~3m 29s wall-clock vs ~5m 58s sequential
- Wave 3: 1 sequential opus builder (E02-S02) completed in ~1m 43s

No board transition failures, no merge conflicts between parallel branches, no race conditions. The orchestrator correctly serialized all board updates.

### 3. Model Routing Validated Across All Three Tiers

This was the first run to exercise all three model tiers in a single workflow: haiku (easy), sonnet (medium), opus (hard). Token consumption patterns were notable:
- Haiku stories consumed ~100K tokens each (high volume, low cost at ~$0.20/story)
- Sonnet stories consumed ~31K tokens each (moderate volume, ~$0.19/story)
- Opus consumed ~29K tokens (lowest volume, highest cost at ~$0.30/story)

Haiku used 3-4x more tokens than sonnet/opus for comparable tasks, likely due to more internal reasoning steps, but remained cheaper due to the 5x lower blended rate.

### 4. Content Consistency Contract Enabled Safe Parallelism

The plan's "Content Consistency Contract" section embedded shared facts (company name, department names, role names) directly into each story's acceptance criteria. This eliminated the need for parallel builders to read each other's output, enabling true independence. All cross-references resolved correctly despite being written by different models in different waves.

### 5. Orchestrator State File Provided Complete Telemetry

The `orchestrator.json` state file captured every dispatch with duration, tokens, tool uses, and result. This made retro data gathering straightforward -- no need to reconstruct from scattered issue comments. The `build_start_seconds` / `build_end_seconds` fields enabled accurate wall-clock calculation.

## What Didn't Work

### 1. Design/Plan Issues Missing Backlog Labels

The designer (issue #147) and planner (issue #149) created their issues without the `backlog/146-doomco-handbook` label. The orchestrator had to retroactively fix this. The backlog issue #146 itself was also initially missing the backlog label.

**Root cause:** Neither the designer nor planner agent instructions explicitly require adding the `backlog/<N>-<slug>` label to design doc and plan issues. The CLAUDE.md convention section lists the label pattern but does not specify that design/plan issues must carry it.

**Evidence:** Lesson file `docs/4-reviews/lessons/146-doomco-handbook/e01-role-profiles/2026-03-10-s00-design-plan-missing-backlog-label.md`.

### 2. CHANGELOG Merge Conflict on E02 PR

After E01 PR #158 was squash-merged to main, E02 PR #159 had a merge conflict in `docs/CHANGELOG.md` because both epic branches added entries at the same location. The orchestrator had to rebase E02 onto updated main before merging.

**Root cause:** Both epic branches were created from the same main commit (`99eefca`). When two separate PRs modify the same file at the same location, the second PR to merge will always conflict. This is inherent to the separate-PR-per-epic strategy.

**Impact:** Minor -- added ~1 minute of orchestrator time for the rebase. Not a correctness issue.

### 3. E01 Epic Review Found Format Inconsistency Across Stories

The E01 epic reviewer (dispatch #13, verdict: COMMENT) identified that the three role profiles used three different formats for Evil Performance Metrics: plain text (Mad Scientist), bold-label bullets (Henchman), and a markdown table (Executive Villain). The horizontal rule usage was also inconsistent.

**Root cause:** Each story was built by a different model (2 haiku, 1 sonnet) with no explicit format template for the metrics section. The acceptance criteria specified "3 metrics with target values" but did not prescribe the rendering format.

**Impact:** Cosmetic inconsistency. The warnings were not addressed before merge (orchestrator chose to proceed since they were non-blocking).

### 4. Lesson File Placed Under Wrong Epic Folder

The lesson about missing backlog labels was placed in `e01-role-profiles/` even though it pertains to the design/plan phases (which precede any epic). The E02 epic reviewer (dispatch #14) flagged this as warning W1.

**Root cause:** The lesson folder convention (`<backlog>/<eNN-slug>/`) assumes lessons belong to a specific epic. Pre-epic lessons (design, plan, orchestrator setup) have no natural home.

## Workflow Evolution During Epic

No CLAUDE.md or agent file changes were made during this epic. The workflow ran on conventions established in prior runs.

## Key Learnings

### For Builders
1. When parallel builders produce content that will be presented together (e.g., a handbook), the plan should specify the exact rendering format for shared structural elements (tables vs bullets vs plain text). Acceptance criteria that say "3 metrics with target values" leave format ambiguous.
2. Haiku consumes 3-4x more tokens than sonnet/opus for equivalent tasks but remains cost-effective due to lower per-token pricing.

### For the Orchestrator
1. Label verification should be a post-phase check after design and plan dispatches. The orchestrator should verify that all newly created issues carry the backlog label before proceeding.
2. When using separate epic PRs, anticipate CHANGELOG conflicts on the second PR. Either: (a) only add the CHANGELOG entry on the last epic branch, or (b) add it on the first and rebase later epics after merge.

### For the Workflow
1. Content-only stories with detailed acceptance criteria achieve zero fix cycles. This suggests that the primary driver of fix cycles in prior runs was code complexity (DI wiring, test framework interactions), not the SDLC process itself.
2. The three-tier model routing works as designed. Cost optimization is real: the 5-story build cost $1.09, compared to an estimated $3.75 if all stories had used opus.
3. The full lifecycle (design through merge) completed in ~30 minutes wall-clock for 5 stories. The build phase itself was ~14 minutes (including reviews and merges), with ~7 minutes of actual builder agent time.

## Recommendations

1. **Add backlog label requirement to designer/planner agent instructions** -- Both agents should explicitly add `backlog/<N>-<slug>` to design doc and plan issues. This is a recurring gap (first observed in this run). *Status: proposed for convention change.*

2. **Add pre-epic lesson folder convention** -- Create an `e00-setup/` subfolder convention for lessons that pertain to design/plan/orchestrator-setup phases before any epic begins. *Status: proposed for convention change.*

3. **Specify format templates in cross-story content plans** -- When multiple stories produce content with shared structural elements, the plan should include a format template (e.g., "use markdown tables for metrics sections"). This prevents the format divergence seen in E01's epic review.

4. **Consider CHANGELOG conflict mitigation** -- For multi-epic features with separate PRs, add the CHANGELOG entry only on the last epic branch to avoid conflicts. Alternatively, accept the rebase cost (~1 minute) as inherent to the strategy. *Status: observation, not a convention change -- situational.*
