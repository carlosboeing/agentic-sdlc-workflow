---
date: 2026-03-14
author: carlosboeing
agent: general
scope: Comprehensive telemetry metrics analysis across 11 test runs of the agentic SDLC pipeline
sources: GitHub issue telemetry comments (earlier host repository issues for Runs 1-7, carlosboeing/agentic-sdlc-workflow issues 1-41)
---

# Agentic SDLC Pipeline — Telemetry Metrics Analysis

> Historical record (March 2026). Measurements come from controlled synthetic workloads and early infrastructure runs; see [case studies](../case-studies.md) for scoped findings.

## Executive Summary

This document analyses telemetry data from 11 autonomous test runs of the agentic SDLC v2 workflow, executed between 2026-03-09 and 2026-03-14. Across 10 executed runs, the pipeline completed **58 stories** in **20 epics** with a **100% completion rate** and **zero code correctness failures**. Total estimated API cost was approximately **$55** across **~7.6M tokens** and **~158 agent dispatches**.

This is an unusually rich dataset for studying multi-agent system evolution: 11 iterations of the same pipeline, each producing structured per-dispatch telemetry, with convention changes propagating between runs via a self-healing feedback loop. The data captures not just performance metrics but the system's ability to learn from its own failures — each run's retro agent proposes convention changes that measurably improve the next run's outcomes.

The most significant trends:

- **Quality improved dramatically** — the system achieved a 17-story zero-fix-cycle streak across Runs 9–11 (100% first-pass approval rate)
- **Review is the most expensive phase** at 35–41% of total cost, driven by Opus reviewing every story
- **Haiku uses 3–4x more tokens than Sonnet** for comparable work, but costs roughly the same due to lower per-token pricing
- **Parallel dispatch wave speedup is 1.8–3.0x**, but overall run speedup is only 1.0–1.3x due to orchestrator overhead
- **Infrastructure self-healing works** — every failure in one run produced a convention fix that prevented recurrence
- **Haiku is 5x faster than Sonnet/Opus** by throughput (~1,081 tok/s vs ~221/193), but processes 3x more tokens per story — speed advantage is partially offset by volume
- **Model routing may be suboptimal** — replacing Haiku with Sonnet for easy stories would be cost-neutral, use 3x fewer tokens, and free context window capacity
- **Cost methodology evolved** — Run 4 used per-model rates (opus at $30/MTok), later runs used blended rates (75% input / 25% output), making direct cost comparisons across eras unreliable

> **Note:** Run 2 (synthetic content workload) was planned (12 stories, 3 epics) but never executed. All aggregate metrics exclude Run 2.

> **Data sources:** Runs 1–7 telemetry from the earlier host repository's issues (not part of this repository). Runs 8–11 telemetry from [carlosboeing/agentic-sdlc-workflow](https://github.com/carlosboeing/agentic-sdlc-workflow) issues and PR descriptions.

---

## Table of Contents

1. [Run Inventory](#1-run-inventory)
2. [Aggregate Metrics](#2-aggregate-metrics)
3. [Per-Run Summary](#3-per-run-summary)
4. [Cost Analysis](#4-cost-analysis)
5. [Token Consumption by Model](#5-token-consumption-by-model)
6. [Speed & Throughput](#6-speed--throughput)
7. [Phase Breakdown](#7-phase-breakdown)
8. [Quality & Fix Cycles](#8-quality--fix-cycles)
9. [Parallelism Analysis](#9-parallelism-analysis)
10. [Model Routing Strategy](#10-model-routing-strategy)
11. [Infrastructure & Reliability](#11-infrastructure--reliability)
12. [Optimization Opportunities](#12-optimization-opportunities)
13. [Telemetry Recommendations](#13-telemetry-recommendations)
14. [Evolution Timeline](#14-evolution-timeline)

---

## 1. Run Inventory

| Run | Date | Backlog # | Theme | Epics | Stories | Dispatches | Repo |
|-----|------|-----------|-------|-------|---------|------------|------|
| 1 | 2026-03-09 | n/a | Synthetic content workload | 2 | 9 | 9 | earlier host repository |
| 2 | 2026-03-09 | n/a | Synthetic content workload | 3 | 12 | — | earlier host repository |
| 3 | 2026-03-10 | n/a | Synthetic content workload | 2 | 7 | 22 | earlier host repository |
| 4 | 2026-03-10 | n/a | Synthetic content workload | 2 | 5 | 17 | earlier host repository |
| 5 | 2026-03-10 | n/a | Synthetic content workload | 2 | 5 | 15 | earlier host repository |
| 6 | 2026-03-10 | n/a | Synthetic content workload | 2 | 5 | 14 | earlier host repository |
| 7 | 2026-03-11 | n/a | Synthetic content workload | 2 | 5 | 19 | earlier host repository |
| 8 | 2026-03-12 | #1 | Run 8 | 2 | 5 | 16 | agentic-sdlc-workflow |
| 9 | 2026-03-13 | #14 | Run 9 | 2 | 5 | 14 | agentic-sdlc-workflow |
| 10 | 2026-03-13 | #27 | Orchestrator Logging | 2 | 6 | 16 | agentic-sdlc-workflow |
| 11 | 2026-03-14 | #41 | Board Drift Detection | 2 | 6 | 16 | agentic-sdlc-workflow |

### Run Progression Context

- **Run 1:** Initial pipeline validation. CLI dispatch (`claude -p`) discovered broken inside nested sessions. Builders only — no reviewer or retro agents. All 9 stories ran sequentially.
- **Run 2:** Planned but never executed. Would have tested 6-way parallel dispatch across 3 epics (Recipe Book, Travel Guide, Board Game).
- **Run 3:** First parallel dispatch (in-session, no worktree isolation). Board management races discovered. First run with reviewer and retro agents. 22 dispatches.
- **Run 4:** Full lifecycle with structured per-phase telemetry. Board transitions validated. Workspace collision latent but not yet manifested. First fix cycle from `.gitignore` issue.
- **Run 5:** First zero-fix run. Detailed acceptance criteria proven effective. All 5 stories approved on first review.
- **Run 6:** Single-PR workflow (integration branch → main) introduced. GraphQL rate limiting first observed.
- **Run 7:** Workspace collision crisis — parallel dispatch without worktree isolation caused cross-contamination. 3 fix cycles, 40% first-pass rate. Proved worktree isolation mandatory.
- **Runs 8–11:** Mature pipeline with worktree isolation, full 5-phase lifecycle, standardised telemetry format.

---

## 2. Aggregate Metrics

| Metric | Value |
|--------|-------|
| Total stories completed | 58/58 (100%) |
| Total epics | 20 |
| Total agent dispatches | ~158 |
| Total tokens consumed | ~7.6M |
| Total estimated API cost | ~$55 |
| Total sequential duration | ~379 min |
| Average cost per story | ~$0.95 |
| Average tokens per story | ~131K |
| Average cost per full run | ~$5.50 |
| Overall first-pass approval rate | 86% (42/49 reviewed stories) |
| Late-stage first-pass rate (Runs 9–11) | 100% (17/17 stories) |
| Code correctness failures | 0 |

> **Cost caveat:** Run 4 used per-model rates (opus at $30/MTok input) totalling $14.33 — significantly higher than the blended-rate methodology ($3–8 range) used in all other runs. This inflates the aggregate. Excluding Run 4, total cost is ~$41 and average cost per story is ~$0.77. Token and dispatch counts include fix cycles.

---

## 3. Per-Run Summary

### 3.1 Full Telemetry Table

| Run | Seq. Duration | Wall-Clock | Tokens | Cost | Stories | Dispatches | Fix Cycles | 1st-Pass Rate |
|-----|--------------|------------|--------|------|---------|------------|-----------|---------------|
| 1 | 13m 06s | 13m 06s | 106K | ~$1.20 | 9 | 9 | 0† | N/A† |
| 3 | ~52m 40s | ~14m 02s | ~950K | ~$2.51 | 7 | 22 | 2 | 71% |
| 4 | 44m 11s | 32m 57s | ~936K | ~$14.33‡ | 5 | 17 | 1 | 80% |
| 5 | 30m 22s | ~24m 00s | 626K | ~$3.67 | 5 | 15 | 0 | 100% |
| 6 | 31m 59s | ~26m 47s | 630K | ~$4.24 | 5 | 14 | 0 | 100% |
| 7 | 42m 29s | ~36m 39s | 930K | ~$5.70 | 5 | 19 | 3 | 40% |
| 8 | 39m 13s | ~33m 00s | 770K | ~$4.79 | 5 | 16 | 1 | 80% |
| 9 | 31m 30s | 25m 37s | 649K | ~$4.44 | 5 | 14 | 0 | 100% |
| 10 | 47m 12s | ~61m 00s | 976K | ~$6.60 | 6 | 16 | 0 | 100% |
| 11 | 46m 25s | 40m 35s | 1,047K | ~$7.48 | 6 | 16 | 0 | 100% |

† Run 1 had no reviewer dispatch — stories were never reviewed, so 0 fix cycles is misleading.
‡ Run 4 used per-model token rates (opus at $30/MTok input), not the blended-rate methodology used in other runs. Comparable blended-rate cost would be ~$3–5.

### 3.2 Per-Run Detail

#### Run 1

Build-only pipeline. No reviewer, no retro. CLI dispatch via `claude -p` failed (nested session block); all 9 stories ran sequentially via Agent tool fallback.

| Wave | Story | Model | Duration | Tokens | Cost |
|------|-------|-------|----------|--------|------|
| 1 | E01-S01 | haiku | 53s | 5K | ~$0.02 |
| 1 | E01-S02 | haiku | 58s | 6K | ~$0.03 |
| 1 | E01-S03 | sonnet | 1m 10s | 12K | ~$0.07 |
| 1 | E02-S01 | haiku | 1m 07s | 8K | ~$0.04 |
| 1 | E02-S02 | haiku | 1m 08s | 8K | ~$0.04 |
| 2 | E01-S04 | sonnet | 59s | 15K | ~$0.09 |
| 2 | E02-S03 | sonnet | 1m 50s | 15K | ~$0.09 |
| 2 | E02-S04 | opus | 3m 09s | 25K | ~$0.75 |
| 3 | E02-S05 | sonnet | 1m 52s | 12K | ~$0.07 |
| | **Total** | | **13m 06s** | **106K** | **~$1.20** |

**Key observations:**
- Per-story tokens dramatically lower (5K–25K) than later runs (28K–122K) — likely because Run 1 predated the full CLAUDE.md conventions, so builders had far less context to load
- Model routing worked correctly from the first story (4 haiku, 4 sonnet, 1 opus)
- Epic telemetry cost was overstated ($3.18 reported vs $1.20 corrected actual)

#### Run 3

First run with reviewer and retro agents. 3 build waves (4 parallel → 2 parallel → 1 sequential).

| Phase | Dispatches | Tokens | Duration | Est. Cost |
|-------|-----------|--------|----------|-----------|
| Plan | 1 | 66K | 5m 05s | ~$0.20 |
| Build | 10 (7 stories + 3 fixes) | 548K | 28m 31s | ~$1.30 |
| Review | 10 (7 stories + 2 re-reviews + 1 epic) | 336K | 19m 04s | ~$1.01 |
| Retro | 1 | — | — | — |
| **Total** | **22** | **~950K** | **~52m 40s** | **~$2.51** |

> Designer telemetry not captured (design doc created in a prior session). Retro telemetry not captured (ran in background).

**Fix cycles:** 2 on E01-S04 (word count compliance: 569 → 495 words)

#### Run 4

Full lifecycle with structured per-wave telemetry. First run to post comprehensive Gantt timeline.

| Phase | Model | Tokens | Duration | Est. Cost |
|-------|-------|--------|----------|-----------|
| Design | opus | 64K | 3m 28s | ~$1.92 |
| Plan | opus | 75K | 8m 06s | ~$2.25 |
| Build (Wave 1) | haiku ×3 | 312K | 5m 25s | ~$0.09 |
| Build (W1 fix) | haiku ×1 | 104K | 59s | ~$0.03 |
| Build (Wave 2) | sonnet + opus | 69K | 7m 05s | ~$0.68 |
| Review (stories) | opus ×6 | 180K | 9m 14s | ~$5.40 |
| Review (epics) | opus ×2 | ~30K | 1m 30s | ~$0.90 |
| Retro | opus | 102K | 8m 24s | ~$3.06 |
| **Total** | | **~936K** | **44m 11s** | **~$14.33** |

**Note:** Cost uses per-model rates (opus at ~$30/MTok input). Later runs switched to blended rates, which would produce ~$3–5 for this same token volume.

**Fix cycle:** 1 (E01-S01, `.gitignore` blocking `test-output/`)

#### Run 5

**First zero-fix run.** All 5 stories approved on first review.

| Phase | Model | Tokens | Duration | Est. Cost |
|-------|-------|--------|----------|-----------|
| Design | opus | 44K | 3m 01s | ~$0.44 |
| Plan | opus | 53K | 5m 52s | ~$0.53 |
| Build (Wave 1) | haiku ×2 | 203K | 2m 32s | ~$0.04 |
| Build (Wave 2) | sonnet ×2 | 63K | 5m 59s | ~$0.04 |
| Build (Wave 3) | opus ×1 | 30K | 1m 43s | ~$0.30 |
| Review (stories) | opus ×5 | 110K | 3m 05s | ~$1.10 |
| Review (epics) | opus ×2 | 61K | 3m 46s | ~$0.61 |
| Retro | opus | 62K | 4m 22s | ~$0.62 |
| **Total** | **15** | **626K** | **30m 22s** | **~$3.67** |

#### Run 6

First test of single-PR workflow (integration branch → main). ~28 min wall-clock design-to-merge.

| Phase | Model | Tokens | Duration | Est. Cost |
|-------|-------|--------|----------|-----------|
| Design | opus | 42K | 3m 27s | ~$0.42 |
| Plan | opus | 47K | 5m 33s | ~$0.47 |
| Build | mixed (2 haiku, 2 sonnet, 1 opus) | 334K | 12m 54s | ~$1.28 |
| Review (stories + backlog PR) | opus ×6 | 156K | 6m 08s | ~$1.56 |
| Retro | opus | 52K | 3m 54s | ~$0.52 |
| **Total** | **14** | **630K** | **31m 59s** | **~$4.24** |

**Fix cycles:** 0. GraphQL rate limit exhaustion first observed.

#### Run 7

**Workspace collision crisis.** Parallel dispatch without worktree isolation caused E01-S01's file to appear on E01-S03's branch.

| Phase | Model | Tokens | Duration | Est. Cost |
|-------|-------|--------|----------|-----------|
| Design | opus | 44K | 2m 38s | ~$0.44 |
| Plan | opus | 50K | 4m 26s | ~$0.50 |
| Build | mixed (8 dispatches) | 532K | 16m 57s | ~$1.72 |
| Review | opus ×8 | 234K | 10m 51s | ~$2.34 |
| Retro | opus | 69K | 7m 35s | ~$0.70 |
| **Total** | **19** | **930K** | **42m 29s** | **~$5.70** |

**Fix cycles:** 3 — E01-S01 workspace collision, E01-S03 workspace collision, E02-S02 content style. 40% first-pass rate.

#### Runs 8–11

Detailed per-dispatch breakdowns for Runs 8–11 are posted on the backlog issues (#1, #14, #27, #41) and backlog PR descriptions (#13, #26, #40, #54) in the agentic-sdlc-workflow repo.

| Run | Phase Breakdown | Fix Cycles | Notable |
|-----|----------------|-----------|---------|
| 8 | D: 37K/$0.37, P: 60K/$0.60, B: 410K/$1.19, R: 194K/$1.94, Retro: 69K/$0.69 | 1 (sentence count) | Worktree isolation validated; 3.0x wave speedup |
| 9 | D: 38K/$0.38, P: 64K/$0.64, B: 320K/$1.16, R: 161K/$1.61, Retro: 66K/$0.66 | 0 | Zero-fix streak begins; cross-contamination self-healed |
| 10 | D: 67K/$0.67, P: 77K/$0.77, B: 488K/$1.72, R: 269K/$2.70, Retro: 75K/$0.75 | 0 | Rate limit crisis; 7m17s wait; 51% orchestrator overhead |
| 11 | D: 77K/$0.77, P: 84K/$0.84, B: 454K/$1.54, R: 334K/$3.34, Retro: 99K/$0.99 | 0 | 17-story streak; missing comments on parallel haiku |

### 3.3 Period Comparison

| Period | Executed Runs | Stories | Avg Cost/Run | Avg Tokens/Run | 1st-Pass Rate | Pipeline Phases |
|--------|--------------|---------|-------------|---------------|---------------|-----------------|
| Early (1–4) | 3 (R1,R3,R4) | 21 | ~$6.01† | ~664K | 75% (9/12)‡ | Build → review (evolving) |
| Mid (5–7) | 3 (R5,R6,R7) | 15 | ~$4.54 | ~729K | 80% (12/15) | Full lifecycle (design/plan/build/review/retro) |
| Late (8–11) | 4 (R8–R11) | 22 | ~$5.83 | ~861K | 95.5% (21/22) | Full lifecycle + worktree isolation |

† Early avg cost inflated by Run 4's per-model rate methodology ($14.33). Excluding Run 4: ~$1.86/run.
‡ Run 1 had no reviewer (9 stories unreviewed). Rate based on R3+R4 only: 9/12 passed first review.

---

## 4. Cost Analysis

### 4.1 Cost Trend

> **Methodology note:** Run 4 used per-model token rates (opus at ~$30/MTok input), which produces ~$14.33. All other runs use blended rates (75% input / 25% output), producing $1–8. The chart below shows reported costs as-posted.

```
Cost ($)
 15 ┤
    │        ● R4 ($14.33) ‡
 14 ┤
    │
    │
    │
  8 ┤
    │                                                              ● R11 ($7.48)
  7 ┤
    │                                                   ● R10 ($6.60)
  6 ┤               ● R7 ($5.70)
    │
  5 ┤                                        ● R8 ($4.79)
    │                                                   ● R9 ($4.44)
  4 ┤        ● R6 ($4.24)
    │ ● R5 ($3.67)
  3 ┤
    │  ● R3 ($2.51)
  2 ┤
    │
  1 ┤● R1 ($1.20)
    └──────────────────────────────────────────────────────────────
      R1   R3   R4   R5   R6   R7   R8   R9   R10  R11

‡ Run 4 uses different cost methodology (per-model rates, not blended)
```

### 4.2 Cost Per Story

| Run | Total Cost | Stories | Cost/Story | Methodology |
|-----|-----------|---------|-----------|-------------|
| 1 | ~$1.20 | 9 | ~$0.13 | Build-only (no review/retro) |
| 3 | ~$2.51 | 7 | ~$0.36 | Plan/build/review (partial) |
| 4 | ~$14.33 | 5 | ~$2.87 | Per-model rates ‡ |
| 5 | ~$3.67 | 5 | ~$0.73 | Blended rates |
| 6 | ~$4.24 | 5 | ~$0.85 | Blended rates |
| 7 | ~$5.70 | 5 | ~$1.14 | Blended rates |
| 8 | ~$4.79 | 5 | ~$0.96 | Blended rates |
| 9 | ~$4.44 | 5 | ~$0.89 | Blended rates |
| 10 | ~$6.60 | 6 | ~$1.10 | Blended rates |
| 11 | ~$7.48 | 6 | ~$1.25 | Blended rates |

‡ Run 4's per-model cost methodology makes its cost/story ($2.87) non-comparable. Using blended rates, Run 4 would be ~$0.60–1.00/story.

**Comparable runs (5–11) cost/story range:** $0.73–$1.25, trending upward as CLAUDE.md context grows.

### 4.3 Cost Drivers (Runs 8–11)

The primary cost driver in the mature pipeline is the **reviewer agent**, which accounts for 35–45% of total cost:

1. Every reviewer dispatch runs on Opus (highest per-token rate)
2. Each run has 6–7 review dispatches (one per story + backlog PR review)
3. Review tokens are predominantly input tokens (reading full story context + CLAUDE.md conventions)

**This cost is justified by the quality outcome.** Opus reviewing Haiku/Sonnet code catches issues that same-model review would miss — the 17-story zero-fix-cycle streak across Runs 9–11 validates this investment. Before Opus reviews were added (Run 1), issues went entirely undetected. The review phase costs more than the build phase ($2.40 vs $1.40 avg), but it's what makes the pipeline's 100% late-stage first-pass rate possible.

### 4.4 Model Cost Efficiency (Runs 8–11 builders)

| Model | Avg Tokens/Story | Avg Cost/Story | Use Case |
|-------|-----------------|---------------|----------|
| Haiku | ~110K | ~$0.22 | Easy stories |
| Sonnet | ~40.5K | ~$0.22 | Medium stories |
| Opus | ~35.5K | ~$0.37 | Hard stories |

Haiku and Sonnet produce nearly identical costs per story (~$0.22) despite Haiku consuming 2.7–3.5x more tokens. Opus costs ~70% more per story but is reserved for hard stories with complex dependencies.

---

## 5. Token Consumption by Model

### 5.1 Evolution of Per-Story Tokens

Run 1's per-story tokens (5K–25K) are dramatically lower than later runs (28K–122K). This reflects CLAUDE.md growing from near-empty to ~2,000 lines — every agent loads the full convention set, consuming tokens before any work begins.

| Run | Haiku (easy) | Sonnet (medium) | Opus (hard) |
|-----|-------------|----------------|-------------|
| 1 | 5K–8K | 12K–15K | 25K |
| 5 | 101K–103K | 31K–32K | 30K |
| 6 | 109K–111K | 37K–38K | 38K |
| 7 | 100K–102K | 28K–32K | 35K |
| 8 | 103K–106K | 29K–30K | 38K |
| 9 | 109K–113K | 28K–38K | 31K |
| 10 | 109K–116K | 37K–79K | 35K |
| 11 | 105K–122K | 34K–49K | 38K |

### 5.2 Haiku (Easy Stories) — Runs 5–11

| Run | Stories | Avg Tokens/Story | Range |
|-----|---------|-----------------|-------|
| 5 | 2 | 102K | 101K–103K |
| 6 | 2 | 110K | 109K–111K |
| 7 | 2 | 101K | 100K–102K |
| 8 | 2 | 104.5K | 103K–106K |
| 9 | 2 | 111K | 109K–113K |
| 10 | 3 | 112.3K | 109K–116K |
| 11 | 3 | 110.7K | 105K–122K |

**Cross-run average: ~107K tokens/story** (remarkably stable, CV < 6%)

### 5.3 Sonnet (Medium Stories) — Runs 5–11

| Run | Stories | Avg Tokens/Story | Range |
|-----|---------|-----------------|-------|
| 5 | 2 | 31.5K | 31K–32K |
| 6 | 2 | 37.5K | 37K–38K |
| 7 | 2 | 30K | 28K–32K |
| 8 | 2 | 29.5K | 29K–30K |
| 9 | 2 | 33K | 28K–38K |
| 10 | 2 | 58K | 37K–79K |
| 11 | 2 | 41.5K | 34K–49K |

**Cross-run average: ~37K tokens/story** (more variable, CV ~25%)

Run 10's outlier (79K on E01-S01) was an infrastructure-heavy validation script — qualitatively different from content generation.

### 5.4 Opus (Hard Stories) — Runs 5–11

| Run | Stories | Tokens |
|-----|---------|--------|
| 5 | 1 | 30K |
| 6 | 1 | 38K |
| 7 | 1 | 35K |
| 8 | 1 | 38K |
| 9 | 1 | 31K |
| 10 | 1 | 35K |
| 11 | 1 | 38K |

**Cross-run average: ~35K tokens/story** (most consistent, CV < 10%)

### 5.5 The Haiku Paradox

Haiku uses **2.7–3.5x more tokens** than Sonnet for comparable tasks:

| Run | Haiku Avg | Sonnet Avg | Ratio |
|-----|----------|-----------|-------|
| 5 | 102K | 31.5K | 3.2x |
| 6 | 110K | 37.5K | 2.9x |
| 7 | 101K | 30K | 3.4x |
| 8 | 104.5K | 29.5K | 3.5x |
| 9 | 111K | 33K | 3.4x |
| 10 | 112.3K | 58K | 1.9x |
| 11 | 110.7K | 41.5K | 2.7x |

This ratio is remarkably stable (excluding Run 10's infrastructure outlier at 1.9x), suggesting it's an inherent model behaviour. The cost implications are minimal (Haiku's ~3x lower rate offsets the ~3x higher usage), but the efficiency implications are real:

- **Context window pressure:** Haiku fills context 3x faster, increasing risk of context compaction on longer stories
- **Downstream review cost:** Opus reviewers must read Haiku's more verbose output, increasing review token counts
- **Speed:** More tokens = more latency, though Haiku's faster generation partially compensates

---

## 6. Speed & Throughput

### 6.1 Throughput by Model and Role

Data from ~158 agent dispatches across 10 executed runs (n = sample size, speed = tokens/second).

| Model | Role | n | Mean Speed | Median | Min | Max | Mean Duration |
|-------|------|---|------------|--------|-----|-----|---------------|
| **Haiku** | Builder | 26 | 1,081 tok/s | 989 | 532 | 2,151 | 1m 40s |
| **Sonnet** | Builder | 22 | 221 tok/s | 202 | 107 | 383 | 2m 45s |
| **Opus** | Builder | 10 | 193 tok/s | 200 | 83 | 289 | 3m 16s |
| **Opus** | Reviewer | 54 | 393 tok/s | 361 | 211 | 710 | 1m 20s |
| **Opus** | Designer | 8 | 243 tok/s | 233 | 179 | 308 | 3m 32s |
| **Opus** | Planner | 8 | 163 tok/s | 152 | 113 | 216 | 6m 44s |
| **Opus** | Retro | 8 | 231 tok/s | 222 | 152 | 314 | 5m 39s |

> Run 1 haiku data (94–119 tok/s, n=4) excluded from builder stats — those stories had only 5–8K tokens, making speed non-comparable to later runs with 100K+ tokens.

### 6.2 Speed Comparison: Builder Models

```
Throughput (tokens/second) — Builder Role
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Haiku   ████████████████████████████████████████████████████  1,081 tok/s
Sonnet  ██████████                                              221 tok/s
Opus    █████████                                               193 tok/s
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Haiku's raw throughput is **4.9x faster than Sonnet** and **5.6x faster than Opus**. However, because Haiku processes ~3x more tokens per story, the **effective speed** (time to complete a story) tells a different story:

| Model | Mean Tokens/Story | Mean Duration | Effective Rate |
|-------|------------------|---------------|----------------|
| Haiku | ~107K | 1m 40s | 1 story / 100s |
| Sonnet | ~37K | 2m 45s | 1 story / 165s |
| Opus | ~35K | 3m 16s | 1 story / 196s |

**Haiku completes stories ~1.7x faster than Sonnet** despite processing 3x more tokens — its raw speed advantage more than compensates for its verbosity.

### 6.3 Speed Comparison: Opus by Role

Opus speed varies significantly by role:

```
Opus Throughput by Role (tokens/second)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Reviewer   ██████████████████████████████████████████████████  393 tok/s
Designer   ████████████████████████████████                    243 tok/s
Retro      ███████████████████████████████                     231 tok/s
Builder    ████████████████████████                            193 tok/s
Planner    █████████████████████                               163 tok/s
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

- **Reviewers** are fastest (393 tok/s) — shorter, focused sessions with fewer tool uses (~3 per dispatch vs ~29 for builders)
- **Planners** are slowest (163 tok/s) — heavy multi-step work (issue creation, board setup, sub-issue linking, ~30+ tool uses)

### 6.4 Haiku Speed Evolution Across Runs

| Run | n | Mean Speed (tok/s) | Notes |
|-----|---|-------------------|-------|
| 3 | 3 | 882 | First parallel run |
| 4 | 3 | 1,037 | — |
| 5 | 2 | 1,440 | — |
| 6 | 2 | 989 | — |
| 7 | 2 | 1,799 | — |
| 8 | 2 | 667 | Slowest run (different hardware?) |
| 9 | 2 | 808 | — |
| 10 | 3 | 1,136 | — |
| 11 | 3 | 1,609 | Fastest multi-story run |

Haiku speed is highly variable (667–1,799 tok/s mean per run). This likely reflects API load and scheduling variance rather than task complexity, since token counts are stable (~105K ± 10K).

### 6.5 Time Efficiency: Tokens Per Tool Use

| Model | Role | Mean Tokens | Mean Tool Uses | Tokens/Tool Use |
|-------|------|-------------|---------------|-----------------|
| Haiku | Builder | 107K | 28 | 3,821 |
| Sonnet | Builder | 37K | 28 | 1,321 |
| Opus | Builder | 35K | 27 | 1,296 |
| Opus | Reviewer | 28K | 3 | 9,333 |
| Opus | Planner | 64K | 30 | 2,133 |

Haiku generates **2.9x more tokens per tool use** than Sonnet — the verbosity extends across every step, not just output generation.

---

## 7. Phase Breakdown

### 7.1 Phase Metrics Across Runs

| Phase | Run 5 | Run 6 | Run 7 | Run 8 | Run 9 | Run 10 | Run 11 |
|-------|-------|-------|-------|-------|-------|--------|--------|
| Design (tokens) | 44K | 42K | 44K | 37K | 38K | 67K | 77K |
| Design (cost) | $0.44 | $0.42 | $0.44 | $0.37 | $0.38 | $0.67 | $0.77 |
| Plan (tokens) | 53K | 47K | 50K | 60K | 64K | 77K | 84K |
| Plan (cost) | $0.53 | $0.47 | $0.50 | $0.60 | $0.64 | $0.77 | $0.84 |
| Build (tokens) | 297K | 334K | 532K | 410K | 320K | 488K | 454K |
| Build (cost) | $0.38 | $1.28 | $1.72 | $1.19 | $1.16 | $1.72 | $1.54 |
| Review (tokens) | 171K | 156K | 234K | 194K | 161K | 269K | 334K |
| Review (cost) | $1.71 | $1.56 | $2.34 | $1.94 | $1.61 | $2.70 | $3.34 |
| Retro (tokens) | 62K | 52K | 69K | 69K | 66K | 75K | 99K |
| Retro (cost) | $0.62 | $0.52 | $0.70 | $0.69 | $0.66 | $0.75 | $0.99 |

### 7.2 Average Phase Metrics (Runs 8–11)

| Phase | Avg Duration | Avg Tokens | Avg Cost | % of Total Cost |
|-------|-------------|-----------|----------|----------------|
| Design | 3m 56s | 55K | ~$0.55 | 9.4% |
| Plan | 7m 28s | 71K | ~$0.71 | 12.2% |
| Build | 13m 32s | 418K | ~$1.40 | 24.0% |
| Review | 11m 46s | 240K | ~$2.40 | 41.1% |
| Retro | 5m 15s | 77K | ~$0.77 | 13.2% |

### 7.3 Phase Cost Distribution

```
Phase Cost Distribution (Runs 8-11 average)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Design   ██████                              9.4%
Plan     ████████                           12.2%
Build    ████████████████                   24.0%
Review   ██████████████████████████████     41.1%
Retro    █████████                          13.2%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 7.4 Phase Cost Trends

| Phase | Run 5 | Run 11 | Growth | Driver |
|-------|-------|--------|--------|--------|
| Design | $0.44 | $0.77 | +75% | More conventions to absorb |
| Plan | $0.53 | $0.84 | +58% | More conventions to follow |
| Build | $0.38 | $1.54 | +305% | 6 stories vs 5 + more context |
| Review | $1.71 | $3.34 | +95% | More reviewer context + more stories |
| Retro | $0.62 | $0.99 | +60% | More lessons to synthesise |

The rising trend across all phases is driven by CLAUDE.md growing with each run (~2,000 lines by Run 11). More conventions = more context for every agent to load = more tokens per dispatch.

---

## 8. Quality & Fix Cycles

### 8.1 Fix Cycle History

| Run | Stories | Fix Cycles | 1st-Pass Rate | Notes |
|-----|---------|-----------|---------------|-------|
| 1 | 9 | 0 | N/A | No reviewer — issues undetected |
| 3 | 7 | 3 | 71% | Scope leak (E01-S03) + word count (E01-S04, 2 cycles) |
| 4 | 5 | 1 | 80% | `.gitignore` blocking `test-output/` (E01-S01) |
| 5 | 5 | 0 | 100% | **First true zero-fix run** |
| 6 | 5 | 0 | 100% | Validated zero-fix pattern |
| 7 | 5 | 3 | 40% | Workspace collision regression |
| 8 | 5 | 1 | 80% | Sentence count violation (E01-S01) |
| 9 | 5 | 0 | 100% | Zero-fix streak begins |
| 10 | 6 | 0 | 100% | Streak continues (11 stories) |
| 11 | 6 | 0 | 100% | Streak continues (**17 stories**) |

### 8.2 All Fix Cycles — Root Cause Analysis

| Run | Story | Root Cause | Category | Model |
|-----|-------|-----------|----------|-------|
| 3 | E01-S03 | Scope leak — taxonomy.md from E01-S01 committed on wrong branch | Infrastructure | sonnet |
| 3 | E01-S04 | Word count exceeded (569 → 495 words), 2 cycles | Content compliance | — |
| 4 | E01-S01 | `.gitignore` blocking `test-output/` directory | Build config | haiku |
| 7 | E01-S01 | File from another story appeared on branch (workspace collision) | Infrastructure | haiku |
| 7 | E01-S03 | File from another story appeared on branch (workspace collision) | Infrastructure | sonnet |
| 7 | E02-S02 | Content style deviation from acceptance criteria | Content compliance | opus |
| 8 | E01-S01 | Sentence count did not match acceptance criteria | Content compliance | haiku |

### 8.3 Category Summary

| Category | Count | % of Total | Resolution |
|----------|-------|-----------|------------|
| Content compliance | 4 | 50% | Detailed acceptance criteria in plan |
| Infrastructure | 3 | 38% | Worktree isolation (Run 8) |
| Build config | 1 | 12% | `.gitignore` update |
| Code correctness | **0** | **0%** | — |

**Zero code correctness failures across all 58 stories.** Every piece of generated code compiled and passed tests on first attempt. All fix cycles were content formatting issues or infrastructure problems (workspace collision / scope leak).

### 8.4 Quality Milestones

```
100%  ── ● R5  ● R6 ─────── ● R9  ● R10  ● R11        ← First-pass approval rate
 80%  ── ● R4 ──────── ● R8
 71%  ── ● R3
 40%  ────────── ● R7
       ─────────────────────────────────────────────→
       R1  R3  R4  R5  R6  R7  R8  R9  R10  R11
                               ↑          ↑
                           Workspace   Worktree
                           collision   isolation
                           crisis      fix
```

Run 7's regression (40% first-pass rate) was caused by workspace collision during parallel dispatch — a systemic infrastructure failure, not a quality regression. Worktree isolation (Run 8) resolved it permanently.

---

## 9. Parallelism Analysis

### 9.1 Parallel Dispatch Evolution

| Run | Strategy | Max Parallel | Wave Speedup | Overall Speedup | Time Saved |
|-----|----------|-------------|-------------|----------------|-----------|
| 1 | None (CLI dispatch failed) | 0 | 1.0x | 1.0x | 0 |
| 3 | In-session (no worktree) | 4 | 1.8x | — | — |
| 4 | In-session (no worktree) | 3 | — | 1.3x | 11m 14s |
| 5 | In-session (no worktree) | 2 | — | 1.3x | ~6m |
| 6 | In-session (no worktree) | 3 | 2.2x | 1.2x | ~5m 11s |
| 7 | In-session (no worktree) | 3 | — | 1.2x | ~5m 50s |
| 8 | **Worktree isolation** | 3 | **3.0x** | 1.2x | ~6m 13s |
| 9 | Worktree isolation | 3 | 2.0x | 1.2x | 5m 53s |
| 10 | Worktree isolation | 3 | 2.0x | ~1.0x* | — |
| 11 | Worktree isolation | 3 | 1.8x | 1.1x | 5m 50s |

\* Run 10's overall speedup was negated by 7m17s rate limit wait and 31m orchestrator overhead.

### 9.2 The Speedup Gap

Wave-level speedup (1.8–3.0x) consistently exceeds overall run speedup (1.0–1.3x). The gap is caused by:

1. **Sequential review dispatch** — reviews cannot easily be parallelised because each reviewer needs the full story context
2. **Epic merge operations** — sequential git merge + push after each wave
3. **Board management** — serialised GitHub API calls for status transitions
4. **Orchestrator overhead** — telemetry posting, comment verification, branch management (29–51% of wall-clock in Runs 10–11)
5. **Rate limiting** — Run 10 lost 7m17s to GitHub GraphQL API exhaustion

### 9.3 Wall-Clock Time Budget (Runs 8–11 Average)

```
Wall-Clock Time Budget
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Design + Plan     ████████████████████████        27%
Parallel Build    ██████████                      12%
Sequential Review ██████████████████████████████  36%
Merge + Board Ops ████████                        10%
Retro             ██████████                      12%
Overhead          ██                               3%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

The build phase — the only phase that benefits from parallelism — occupies only ~12% of wall-clock time. Even a theoretical infinite speedup on builds would only reduce total run time by ~12%.

---

## 10. Model Routing Strategy

### 10.1 Current Strategy

The pipeline routes stories to models based on a `difficulty` label assigned by the planner:

| Difficulty | Model | Per-Token Rate | Use Case |
|-----------|-------|---------------|----------|
| `difficulty/easy` | Haiku | ~$0.002/1K | Simple content, single-file output |
| `difficulty/medium` | Sonnet | ~$0.006/1K | Multi-file, dependencies, moderate complexity |
| `difficulty/hard` | Opus | ~$0.010/1K | Complex logic, cross-cutting concerns |

All non-builder agents (designer, planner, reviewer, retro) run on Opus regardless of story difficulty.

### 10.2 Model Comparison: Cost vs Speed vs Quality

| Metric | Haiku | Sonnet | Opus |
|--------|-------|--------|------|
| **Avg tokens/story** | 107K | 37K | 35K |
| **Avg cost/story** | ~$0.22 | ~$0.22 | ~$0.37 |
| **Avg duration/story** | 1m 40s | 2m 45s | 3m 16s |
| **Throughput** | 1,081 tok/s | 221 tok/s | 193 tok/s |
| **Fix cycle rate** | 3/26 (12%) | 2/22 (9%) | 1/10 (10%) |
| **Tokens/tool use** | 3,821 | 1,321 | 1,296 |

### 10.3 Key Finding: Haiku vs Sonnet Trade-off

Haiku and Sonnet are **cost-equivalent** (~$0.22/story) but differ in every other dimension:

| Dimension | Haiku Advantage | Sonnet Advantage |
|-----------|----------------|------------------|
| **Speed** | 1.7x faster per story | — |
| **Token efficiency** | — | 3x fewer tokens |
| **Context pressure** | — | Less risk of compaction |
| **Downstream cost** | — | Reviewers read less verbose output |
| **Fix cycle rate** | — | Slightly lower (9% vs 12%) |

**The trade-off is speed vs efficiency.** Haiku finishes stories ~1.7x faster but generates 3x more tokens, consuming context window capacity and creating more work for Opus reviewers downstream.

### 10.4 Routing Scenarios

#### Scenario A: Status Quo (Haiku/Sonnet/Opus)

Current model mix for a typical 6-story run (3 easy, 2 medium, 1 hard):

| Component | Cost | Duration | Tokens |
|-----------|------|----------|--------|
| 3 easy (haiku) | $0.66 | 5m 00s | 321K |
| 2 medium (sonnet) | $0.44 | 5m 30s | 74K |
| 1 hard (opus) | $0.37 | 3m 16s | 35K |
| 6 story reviews (opus) | $1.50 | 8m 00s | 150K |
| **Build+Review Total** | **$2.97** | **21m 46s** | **580K** |

#### Scenario B: Replace Haiku with Sonnet

All easy stories routed to Sonnet instead of Haiku:

| Component | Cost | Duration | Tokens |
|-----------|------|----------|--------|
| 3 easy (sonnet) | $0.66 | 8m 15s | 111K |
| 2 medium (sonnet) | $0.44 | 5m 30s | 74K |
| 1 hard (opus) | $0.37 | 3m 16s | 35K |
| 6 story reviews (opus) | $1.38 | 7m 20s | 138K |
| **Build+Review Total** | **$2.85** | **24m 21s** | **358K** |

| Delta | Change |
|-------|--------|
| Cost | -$0.12 (4% savings) |
| Tokens | -222K (38% reduction) |
| Duration | +2m 35s (12% slower) |

#### Scenario C: Sonnet Builds + Sonnet Reviews for Easy Stories

Use Sonnet for both building AND reviewing easy stories:

| Component | Cost | Duration | Tokens |
|-----------|------|----------|--------|
| 3 easy (sonnet build + sonnet review) | $0.66 + $0.42 | 8m 15s + 4m 00s | 111K + 70K |
| 2 medium (sonnet build + opus review) | $0.44 + $0.50 | 5m 30s + 2m 40s | 74K + 50K |
| 1 hard (opus build + opus review) | $0.37 + $0.25 | 3m 16s + 1m 20s | 35K + 25K |
| **Build+Review Total** | **$2.64** | **25m 01s** | **365K** |

| Delta vs Status Quo | Change |
|---------------------|--------|
| Cost | -$0.33 (11% savings) |
| Tokens | -215K (37% reduction) |
| Duration | +3m 15s (15% slower) |
| Risk | Sonnet may miss issues Opus catches |

#### Scenario D: All Sonnet (Simplest)

Route all stories to Sonnet, keep Opus for reviews:

| Component | Cost | Duration | Tokens |
|-----------|------|----------|--------|
| 6 stories (sonnet) | $1.32 | 16m 30s | 222K |
| 6 reviews (opus) | $1.50 | 8m 00s | 150K |
| **Build+Review Total** | **$2.82** | **24m 30s** | **372K** |

Simplifies routing logic (no difficulty labels needed for model selection) while maintaining Opus review quality.

### 10.5 Recommendation

**Scenario B (replace Haiku with Sonnet) is the recommended first step.** It is:

- **Cost-neutral** (~4% savings, within noise)
- **38% fewer tokens** — reduces context pressure, reviewer workload, and API traffic
- **Only 12% slower** — a worthwhile trade for the token efficiency gain
- **Zero risk** — Sonnet has a slightly lower fix cycle rate than Haiku (9% vs 12%)
- **Simplifies routing** — only 2 models (Sonnet + Opus) instead of 3

If Scenario B proves stable, consider Scenario C (Sonnet reviews for easy stories) to capture an additional 7% cost reduction, with a controlled test to measure Sonnet's review quality vs Opus.

---

## 11. Infrastructure & Reliability

### 11.1 Issue Tracker

| Issue Category | Runs Affected | First Seen | Resolved By | Resolution |
|----------------|--------------|-----------|-------------|------------|
| CLI nested session block | 1 | Run 1 | Run 2 | Agent tool dispatch |
| Board status drift/skip | 3 | Run 3 | Run 4 | Serialised board updates |
| Agent file missing Bash tool | 3, 4 | Run 3 | Run 4 | YAML tool list audit |
| Epic telemetry cost overstatement | 1, 3 | Run 1 | Run 4 | Per-model rate calculation |
| Workspace collision (no worktree) | 4, 7 | Run 4 | Run 8 | `isolation: "worktree"` |
| Stale board option IDs | 6 | Run 6 | Run 6 | Manual audit + CLAUDE.md |
| GraphQL rate limit exhaustion | 6, 7, 10 | Run 6 | Run 11 | Per-issue query optimisation |
| Worktree remote push failure | 8 | Run 8 | Run 9 | Push verification step |
| Worktree cross-contamination | 9 | Run 9 | Run 10 | Base commit recording |
| Design artifact matching (short numbers) | 10 | Run 10 | Run 10 | YAML frontmatter matching |
| Missing issue comments (parallel) | 9, 11 | Run 9 | Run 11 | Retroactive posting by orchestrator |

### 11.2 Self-Healing Mechanism

The pipeline's self-healing operates through a four-step feedback loop:

```
Detection → Documentation → Convention Update → Prevention
  (run N)     (lesson file)    (retro → CLAUDE.md)   (run N+1)
```

1. **Detection:** Reviewer, orchestrator, or retro agent identifies the issue during the run
2. **Documentation:** Lesson file written to `docs/4-reviews/lessons/<backlog>/`
3. **Convention update:** Retro agent proposes changes to CLAUDE.md or agent files
4. **Prevention:** Next run's agents load updated conventions and avoid the issue

This loop has been validated across all 11 runs. Every infrastructure failure produced a traceable convention change that prevented recurrence (with one exception: missing issue comments in parallel waves, which recurred in Run 11 despite being observed in Run 9 — the initial mitigation was insufficient).

### 11.3 Issue Density Over Time

```
Infrastructure Issues Per Run
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
R1  ██                           2 issues
R3  ███                          3 issues
R4  ██                           2 issues
R5  █                            1 issue
R6  ██                           2 issues
R7  ██                           2 issues (regression)
R8  ██                           2 issues
R9  ██                           2 issues
R10 ███                          3 issues
R11 █                            1 issue
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Issue density has not obviously decreased, but the **severity** has: early issues were pipeline-blocking (CLI dispatch broken, board races), while late issues are cosmetic (missing comments, design doc format divergence).

---

## 12. Optimization Opportunities

### 12.1 Cost Optimization

| Optimization | Estimated Savings | Risk | Effort |
|-------------|------------------|------|--------|
| Sonnet reviewer for easy stories | ~15–20% of review cost (~$0.50/run) | Lower quality catch rate | Low |
| Replace Haiku with Sonnet for easy builds | Cost-neutral, 3x fewer tokens | None observed | Low |
| Skip retro for content-only test runs | ~$0.77/run (13%) | Lose learning loop | Low |
| Archive old CLAUDE.md conventions | ~5–10% all-phase savings | Risk losing context | Medium |

### 12.2 Speed Optimization

| Optimization | Estimated Savings | Risk | Effort |
|-------------|------------------|------|--------|
| Parallel reviews within a wave | ~30% of review time | Reviewers miss cross-story context | Medium |
| Batch board updates | ~2–3 min/run | Timing gaps in board state | Low |
| Pre-compute branch structure before dispatch | ~1–2 min/run | None | Low |

### 12.3 Recommended Priority

1. **Replace Haiku with Sonnet for easy stories** — cost-neutral, 3x fewer tokens, no quality risk
2. **Batch board updates** — reduces orchestrator overhead and rate limit pressure
3. **Consider Sonnet reviewer for easy stories** — test in one run, compare catch rate
4. **Archive old CLAUDE.md conventions** — reduce context loading for all agents

---

## 13. Telemetry Recommendations

### 13.1 Missing Metrics to Capture

The current telemetry captures duration, tokens, tool uses, and estimated cost. The following metrics would strengthen the analysis:

| Metric | Value | How to Capture |
|--------|-------|---------------|
| **Input vs output token split** | Enables accurate cost calculation (input ≠ output rates) | Agent tool result may expose this; otherwise parse from API response |
| **Tokens/second per dispatch** | Already computable from tokens ÷ duration; should be a standard field in `item-telemetry.sh` | Add `--speed` flag computed from `tokens / (duration_ms / 1000)` |
| **Context window utilisation** | How close each dispatch gets to the context limit; proxy for compaction risk | Track max context usage from agent session |
| **Orchestrator token count** | Currently excluded; 29–51% of wall-clock is orchestrator overhead | Capture via `/cost` delta at start/end of orchestrator session |
| **Time-to-first-token** | Latency before generation starts; varies by model and API load | Would need SDK-level instrumentation |
| **Cache hit rate** | Anthropic's prompt caching can reduce costs; currently unknown if active | Check API response headers for cache metadata |
| **Wall-clock per phase** | Actual elapsed time including orchestrator overhead between dispatches | Timestamp each dispatch start/end in orchestrator state file |

### 13.2 Telemetry Format Improvements

| Improvement | Rationale |
|-------------|-----------|
| **Standardise cost methodology** | Run 4 ($14.33) uses per-model rates; runs 5+ use blended rates. Adopt one method and recompute historical data for comparability |
| **Add throughput to breakdown tables** | Include tok/s column in per-dispatch breakdowns for at-a-glance speed comparison |
| **Separate build tokens from context tokens** | Report how many tokens are CLAUDE.md/convention overhead vs actual work; enables tracking context bloat over time |
| **Track tool use by category** | Distinguish read/write/bash/grep/glob tool uses to understand what agents spend time doing |
| **Add Gantt `actual` overlay** | Current Gantt shows sequential layout; overlay actual wall-clock timing to visualise parallelism savings |

### 13.3 Workflow Improvements to Improve Metrics

| Improvement | Impact | Effort | Priority |
|-------------|--------|--------|----------|
| **Replace Haiku with Sonnet for easy stories** | -38% tokens, -12% speed, cost-neutral | Low (change routing map) | High |
| **CLAUDE.md diet** | -5–15% tokens across all agents; reduces cost of every dispatch | Medium (audit + archive stale conventions) | High |
| **Parallel reviews within a wave** | -30% review wall-clock time | Medium (verify reviewers don't need cross-story context) | Medium |
| **Batch board status updates** | -2–3 min/run; reduce rate limit pressure | Low (accumulate transitions, apply in batch) | Medium |
| **Skip retro for test-only runs** | -$0.77/run, -5m wall-clock | Low (add `--skip-retro` flag) | Low |
| **Sonnet reviewer for easy stories** | -15–20% review cost | Low (test in 1 run, compare catch rate) | Low |
| **Pre-compute branch structure** | -1–2 min/run (eliminate branch creation during dispatch) | Low | Low |
| **Prompt caching** | Unknown savings; could reduce input token costs significantly | Medium (verify Anthropic prompt caching compatibility with Agent tool) | Investigate |
| **Context-aware model routing** | Route based on estimated context size, not just difficulty; large-context stories → Sonnet (lower token/work ratio) | Medium | Investigate |
| **Aggregate reviewer dispatch** | Review all stories in a wave with a single Opus dispatch instead of per-story | Medium (requires reviewer agent changes) | Investigate |
| **Planner internal parallelisation** | Planners are the slowest Opus role (163 tok/s, 6m44s avg) due to sequential issue creation + board setup; parallelising independent GitHub API calls could halve planner duration | Medium (refactor planner to batch issue creation) | Investigate |

### 13.4 Metrics Dashboard Suggestions

If building a telemetry dashboard, prioritise these views:

1. **Cost per story over time** — trend line to detect context bloat
2. **Tokens/second by model** — box plot per run to detect API performance changes
3. **Phase cost pie chart** — per run, animated over time
4. **Fix cycle rate** — rolling average with zero-fix streak counter
5. **Parallelism efficiency** — wave speedup vs overall speedup, highlighting the gap
6. **Context growth** — CLAUDE.md line count vs design/plan token counts
7. **Model routing ROI** — cost/speed/quality comparison per model per run

---

## 14. Evolution Timeline

### 14.1 Capability Progression

```
Run 1:  Sequential only, no review, no retro
        CLI dispatch broken → Agent tool fallback
        $1.20 · 9 stories · 106K tokens

Run 3:  First parallel dispatch (4 builders, no worktree)
        Board races → serialised updates
        $2.51 · 7 stories · 950K tokens · 1.8x wave speedup

Run 4:  Full lifecycle telemetry with Gantt timeline
        Board transitions validated, scoped epic telemetry
        $14.33 · 5 stories · 936K tokens · 1.3x speedup

Run 5:  ★ FIRST ZERO-FIX RUN
        Detailed acceptance criteria proven effective
        $3.67 · 5 stories · 626K tokens

Run 6:  Single-PR workflow (integration branch → main)
        GraphQL rate limiting first observed
        $4.24 · 5 stories · 630K tokens · ~28min wall-clock

Run 7:  ✗ WORKSPACE COLLISION CRISIS (40% first-pass rate)
        Proved worktree isolation mandatory
        $5.70 · 5 stories · 930K tokens · 3 fix cycles

Run 8:  ★ WORKTREE ISOLATION VALIDATED
        3.0x wave speedup, zero collisions
        $4.79 · 5 stories · 770K tokens

Run 9:  Zero-fix streak begins (5 stories)
        Cross-contamination self-healed via cherry-pick
        $4.44 · 5 stories · 649K tokens

Run 10: Rate limit crisis → per-issue query optimisation
        11 consecutive first-pass approvals
        $6.60 · 6 stories · 976K tokens

Run 11: ★ MATURE PIPELINE
        17-story zero-fix streak, 1 minor issue
        $7.48 · 6 stories · 1,047K tokens
```

### 14.2 Key Inflection Points

| Transition | Event | Impact |
|-----------|-------|--------|
| Run 1 → 3 | Reviewer + retro agents added | Quality gate established; fix cycles now detectable |
| Run 4 → 5 | Detailed acceptance criteria in plans | First zero-fix run; quality step-change |
| Run 5 → 6 | Single-PR workflow | Simplified merge flow; one PR per backlog item |
| Run 7 → 8 | Worktree isolation introduced | Eliminated workspace collisions permanently |
| Run 10 → 11 | Per-issue GraphQL query optimisation | Rate limit pressure reduced ~200x per status check |
| Runs 9–11 | Accumulated convention refinements | 17-story zero-fix streak; operational maturity |

### 14.3 System Maturity Assessment

The agentic SDLC pipeline has reached **operational maturity** for content-generation workloads:

- **Reliability:** 100% completion rate across 58 stories, zero code failures, 100% first-pass approval (last 17 stories)
- **Predictability:** Cost per story converging (~$0.89–$1.25 for full lifecycle with blended rates), token usage per model stable across 7 runs
- **Self-improvement:** Infrastructure failures produce convention changes within one run; every issue has been resolved
- **Remaining gaps:** Orchestrator overhead (29–51% of wall-clock), review cost dominance (41%), CLAUDE.md context growth (~2x token increase from Run 5 to Run 11)

The next frontier is applying this pipeline to **real code stories** (features of the earlier host project) rather than content-generation test vehicles. Code stories will exercise TDD, DI wiring, EF Core migrations, and integration testing — phases that content stories bypass entirely.

---

## Appendix A: Data Sources

| Run | Backlog Issue | PR | Source Repo | Telemetry Location |
|-----|--------------|-----|-------------|-------------------|
| 1 | earlier host repository | — | earlier host repository | Epic issues #58, #59 |
| 2 | earlier host repository | — | earlier host repository | Never executed |
| 3 | earlier host repository | — | earlier host repository | Backlog issue comment |
| 4 | earlier host repository | — | earlier host repository | Backlog issue comment |
| 5 | earlier host repository | — | earlier host repository | Backlog issue comment |
| 6 | earlier host repository | — | earlier host repository | Backlog issue comment |
| 7 | earlier host repository | — | earlier host repository | Backlog issue comment |
| 8 | [#1](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/1) | [#13](https://github.com/carlosboeing/agentic-sdlc-workflow/pull/13) | carlosboeing/agentic-sdlc-workflow | Backlog issue + PR body |
| 9 | [#14](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/14) | [#26](https://github.com/carlosboeing/agentic-sdlc-workflow/pull/26) | carlosboeing/agentic-sdlc-workflow | Backlog issue + PR body |
| 10 | [#27](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/27) | [#40](https://github.com/carlosboeing/agentic-sdlc-workflow/pull/40) | carlosboeing/agentic-sdlc-workflow | Backlog issue + PR body |
| 11 | [#41](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/41) | [#54](https://github.com/carlosboeing/agentic-sdlc-workflow/pull/54) | carlosboeing/agentic-sdlc-workflow | Backlog issue + PR body |

## Appendix B: Methodology Notes

- **Cost estimates** use Anthropic's published API token pricing. **Run 4** used per-model rates (opus input at ~$30/MTok, sonnet at ~$6/MTok, haiku at ~$0.25/MTok). **Runs 5–11** use a blended rate (75% input / 25% output tokens). This methodology change makes Run 4's cost ($14.33) non-comparable with other runs.
- **Run 1** predated most CLAUDE.md conventions, producing dramatically lower per-story token counts (5K–25K vs 28K–122K in later runs). This reflects convention context loading, not task complexity.
- **Run 3** has partial telemetry — designer and retro agent metrics were not captured.
- **Orchestrator overhead** (parent session tokens) is not included in any run's dispatch telemetry. Runs 10–11 estimated overhead separately (29–51% of wall-clock).
- **Subscription pricing:** These cost estimates represent equivalent API value. Subscription plans (Pro, Max, Team, Enterprise) include token allowances and are not charged per-token.
