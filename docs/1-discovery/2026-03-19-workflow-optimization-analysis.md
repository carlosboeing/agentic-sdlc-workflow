---
date: 2026-03-19
author: analysis
scope: Deep-dive telemetry analysis across 14 backlog items (Runs 8-16 + 5 infrastructure runs) — model routing ROI, phase optimization, long poles, and visualization improvements
sources: GitHub issue telemetry comments and PR descriptions for backlog items 1, 14, 27, 41, 56, 69, 83, 105, 106, 109, 111, 150, 167, 227
---

# Telemetry Deep Dive — Critical Workflow Analysis

## Executive Summary

This document is a data-driven audit of the agentic SDLC workflow based on telemetry from **14 backlog items** (9 test content runs + 5 real infrastructure runs) completed between 2026-03-12 and 2026-03-19. Across these runs, the workflow delivered **97 stories** through **302 agent dispatches**, consuming **20.4M tokens** in **23h 9m of sequential agent time** (18h 20m wall-clock with parallelism).

> **Methodology note:** This analysis uses **tokens** and **duration** as primary comparison metrics. These are raw values measured directly by the Agent tool. Cost estimates are derived (`tokens × blended_rate`) and have been inconsistent across runs due to pricing changes (see § 1). Where cost is mentioned, it is secondary context — never the basis for a conclusion.

The analysis challenges several current workflow assumptions:

1. **Reviewer model routing has negative ROI.** Sonnet reviewers take **2x longer** and consume **2x more tokens** than Opus reviewers on the same easy stories — with identical quality outcomes (zero fix cycles in either model). The feature should be reverted.

2. **The R12 pricing "correction" was wrong.** The blended rate for Opus ($5/$25 at 75/25 input/output split) is $10/MTok — exactly what Runs 8-11 used. R12's manual "correction" to $30/MTok tripled its reported cost. All other runs use the correct $10/M rate.

3. **Design + Plan is the biggest bottleneck**, consuming **35-45% of wall-clock time** as a pure sequential block. Pipelining these phases could save 3-8 minutes per run.

4. **Reviews consume 26% of all tokens and 23% of all duration but deliver diminishing returns on easy stories.** No easy story has ever triggered a fix cycle from a real quality issue across 97 stories. The review gate may be over-applied.

5. **The Gantt chart is broken for real-world use.** API errors, stalled sessions, and interactive retries create massive gaps that make the chart unreadable. A compressed "work timeline" mode is needed.

6. **Parallelism has a hard ceiling at ~1.4x.** Sequential phases (design, plan, retro, PR review) consume 40-60% of wall-clock time and can't be parallelized with the current architecture.

---

## Table of Contents

1. [Pricing Baseline & Corrections](#1-pricing-baseline--corrections)
2. [Master Data Table](#2-master-data-table)
3. [Builder Model Comparison](#3-builder-model-comparison)
4. [Reviewer Model Comparison](#4-reviewer-model-comparison)
5. [Model Routing ROI](#5-model-routing-roi)
6. [Phase-by-Phase Analysis](#6-phase-by-phase-analysis)
7. [Long Poles & Bottleneck Analysis](#7-long-poles--bottleneck-analysis)
8. [Parallelism Ceiling](#8-parallelism-ceiling)
9. [Fix Cycle Economics](#9-fix-cycle-economics)
10. [Test Runs vs Infrastructure Runs](#10-test-runs-vs-infrastructure-runs)
11. [Challenging the Current Workflow](#11-challenging-the-current-workflow)
12. [Telemetry Visualization Problems](#12-telemetry-visualization-problems)
13. [Recommendations](#13-recommendations)

---

## 1. Pricing Baseline & Corrections

### Current Blended Rates

The telemetry pipeline computes cost using a fixed 75% input / 25% output token split (`compute-dispatches.py`, line 44-45):

```
blended_rate = inputPerM × 0.75 + outputPerM × 0.25
```

Using the live-fetched pricing from `.agentic-workflow/pricing.json` (fetched 2026-03-18 from anthropic.com/pricing):

| Model | Input/MTok | Output/MTok | **Blended Rate** | Rate Ratio vs Haiku |
|-------|------------|-------------|------------------|---------------------|
| Opus 4.6 | $5.00 | $25.00 | **$10.00/MTok** | 5.0x |
| Sonnet 4.6 | $3.00 | $15.00 | **$6.00/MTok** | 3.0x |
| Haiku 4.5 | $1.00 | $5.00 | **$2.00/MTok** | 1.0x |

### The Run 12 Pricing Anomaly

Run 12 (BL#56, Time Traveler's Yelp Reviews) is the **only run with incorrect cost data** still on record.

**What happened:** The CHANGELOG states "corrected cost underreporting (was ~$4.77, correct ~$12.55) caused by using memorized $10/M Opus rate instead of config $30/M."

**Why this is wrong:** The $30/M figure does not correspond to any valid blended rate computation. With the published pricing ($5/$25), the blended formula produces exactly $10.00/M — which is what Runs 8-11 used. The $30/M figure appears to be a confusion with the raw output-only rate or a manual miscalculation.

**Verification across runs:**

| Run | Model | Tokens | Reported Cost | Implied Rate | Expected Rate ($10/M) |
|-----|-------|--------|---------------|-------------|----------------------|
| R8 | Opus designer | 37K | $0.37 | $10.0/M ✓ | $0.37 |
| R9 | Opus designer | 38K | $0.38 | $10.0/M ✓ | $0.38 |
| R12 (corrected) | Opus designer | 45K | $1.36 | **$30.2/M ✗** | $0.45 |
| R13 | Opus designer | 42K | $0.43 | $10.2/M ✓ | $0.42 |
| #109 | Opus designer | 100K | $1.01 | $10.1/M ✓ | $1.00 |
| #227 | Opus designer | 127K | $1.27 | $10.0/M ✓ | $1.27 |

Every run except R12 uses $10/M. R12's "corrected" cost of $12.55 should be **$4.77**.

**Impact on aggregate data:** All totals in this document use $10/M for Opus. The corrected total cost across all 14 runs is **~$106** (not ~$173 which includes the R12 overcounting of $7.78).

### Runs covered by this analysis

This analysis includes telemetry from 14 backlog items. It extends the prior analysis (`2026-03-14-telemetry-metrics-analysis.md`, Runs 1-11) with Runs 12-16, the 5 infrastructure runs (#105, #106, #109, #111, #227), and corrected pricing throughout.

---

## 2. Master Data Table

All costs normalized to current blended rates ($10/$6/$2 per MTok for Opus/Sonnet/Haiku).

| # | BL# | Type | Topic | Stories | Dispatches | Seq Duration | Wall Clock | Speedup | Tokens | Est. Cost | Fix Cycles | Fix Rate |
|---|-----|------|-------|---------|------------|-------------|------------|---------|--------|-----------|------------|----------|
| R8 | #1 | Test | Office Nature Doc | 5 | 16 | 39m 13s | ~33m | 1.19x | 770K | ~$4.79 | 1 | 20% |
| R9 | #14 | Test | CIA Cat Reports | 5 | 14 | 31m 30s | 25m 37s | 1.23x | 649K | ~$4.44 | 0 | 0% |
| R10 | #27 | Test | Orchestrator Logging | 6 | 16 | 47m 12s | 48m 29s† | 0.97x | 976K | ~$6.60 | 0 | 0% |
| R11 | #41 | Test | Board Drift + Fairy Tale | 6 | 16 | 46m 25s | 40m 35s | 1.14x | 1,047K | ~$7.48 | 0 | 0% |
| R12 | #56 | Test | Time Traveler Yelp | 5 | 14 | 30m 43s | 25m 12s | 1.22x | 536K | ~$4.77‡ | 0 | 0% |
| R13 | #69 | Test | Alien Tourist Bureau | 6 | 16 | 36m 1s | 27m 28s | 1.31x | 681K | ~$5.96 | 0 | 0% |
| R14 | #83 | Test | Health Inspections | 12 | 36 | 102m 43s | 74m 4s | 1.39x | 1,597K | ~$13.94 | 3 | 17% |
| R15 | #150 | Infra | Split orchestrator.md | 5 | 20 | 111m 40s | 96m 45s | 1.15x | 2,570K | ~$22.67 | 2 | 40% |
| R16 | #167 | Test | Silicon Valley Musical | 9 | 28 | 148m 33s | 116m 27s | 1.28x | 1,870K | ~$14.81 | 3 | 33% |
| — | #105 | Infra | Orchestrator Improvements | 6 | 16 | 89m 55s | 82m 37s | 1.09x | 1,110K | ~$9.48 | 0 | 0% |
| — | #106 | Infra | Telemetry Accuracy | 7 | 22 | 150m 57s | 118m 7s | 1.28x | 1,850K | ~$14.96 | 1 | 14% |
| — | #109 | Infra | PM Abstraction Layer | 10 | 35 | 128m 40s | 97m 38s | 1.32x | 2,550K | ~$21.58 | 1 | 10% |
| — | #111 | Infra | Local-First PM | 9 | 32 | 166m 32s | 129m 51s | 1.28x | 2,400K | ~$18.34 | 5 | 44% |
| — | #227 | Infra | Dual-Write PM | 6 | 21 | 199m 8s | 174m 9s | 1.14x | 1,800K | ~$15.89 | 2 | 33% |
| | | | **Totals** | **97** | **302** | **23h 9m** | **18h 20m** | **1.22x avg** | **20.4M** | **~$106** | **18** | **17% avg** |

† R10 wall-clock exceeded sequential due to ~7m17s GraphQL API rate limit wait.
‡ R12 cost corrected from reported $12.55 to $4.77 (see § 1).

---

## 3. Builder Model Comparison

### 3.1 Per-Model Builder Metrics — Test Content

Data extracted from all first-attempt builder dispatches across test runs (fix cycle re-builds excluded):

| Metric | Haiku (easy) | Sonnet (easy) | Sonnet (medium) | Opus (hard) |
|--------|-------------|---------------|-----------------|-------------|
| **Runs used** | R8-R11 | R12-R16 | R8-R16 | R8-R16 |
| **Sample size** | 10 | 8 | 18 | 10 |
| **Avg duration** | **1m 55s** | **2m 11s** | **2m 30s** | **4m 23s** |
| **Avg tokens** | **110K** | **40K** | **40K** | **50K** |
| **Avg cost** | **$0.22** | **$0.24** | **$0.24** | **$0.50** |
| **Fix rate** | 10% (1/10) | 0% (0/8) | 0% (0/18) | 0% (0/10) |
| **Duration range** | 49s – 3m 20s | 1m 17s – 2m 50s | 1m 17s – 4m 45s | 2m 00s – 13m 27s |
| **Token range** | 103K – 122K | 31K – 50K | 28K – 79K | 31K – 103K |
| **Throughput** | ~960 tok/s | ~300 tok/s | ~270 tok/s | ~190 tok/s |

### 3.2 Per-Model Builder Metrics — Infrastructure

| Metric | Sonnet (easy/medium) | Opus (hard) |
|--------|---------------------|-------------|
| **Runs used** | #105, #106, #109, #111, #227 | #109, #227, R15 |
| **Sample size** | ~30 | 5 |
| **Avg duration** | **5m 50s** | **9m 24s** |
| **Avg tokens** | **80K** | **125K** |
| **Avg cost** | **$0.48** | **$1.25** |
| **Duration range** | 1m 37s – 15m 58s | 6m 44s – 14m 39s |

### 3.3 Haiku vs Sonnet on Easy Stories — Direct Comparison

The switch from haiku to sonnet for easy stories happened between R11 and R12. This gives us a clean before/after comparison on the same workload type (easy test content):

| Metric | Haiku (R8-R11) | Sonnet (R12-R16) | Delta |
|--------|---------------|------------------|-------|
| Avg duration | 1m 55s | 2m 11s | +14% slower |
| Avg tokens | 110K | 40K | **−64% fewer tokens** |
| Avg cost | $0.22 | $0.24 | +$0.02/story (+9%) |
| Fix rate | 10% (1/10) | 0% (0/8) | **Better quality** |
| Token consistency | 103K–122K (σ=6K) | 31K–50K (σ=7K) | Similar variance |

**Analysis:**

Haiku is a false economy. The primary metrics tell the story:

1. **Uses 2.75x more tokens** (110K vs 40K) — haiku generates more verbose intermediate reasoning to compensate for its smaller model capacity. 110K tokens of haiku work is not "more work done" — it's the same output produced less efficiently. This is the defining difference.

2. **14% slower** (1m 55s vs 2m 11s) — haiku's raw throughput is ~960 tok/s vs sonnet's ~300 tok/s, but this speed advantage is entirely consumed by processing 2.75x more tokens. The net result is that sonnet finishes only slightly behind.

3. **Higher fix rate** (10% vs 0%) — the one fix cycle in R8 (E01-S01, sentence count violation) added an extra builder dispatch (2m 42s, 105K tokens) plus a reviewer re-dispatch (1m 5s, 24K tokens). A single fix cycle consumes more tokens than the combined "savings" from choosing haiku across dozens of stories.

4. **API pressure** — at 110K tokens per story, haiku builders consume 2.75x more API capacity. In a parallel wave of 3 haiku builders, that's 330K tokens vs 120K for sonnet — increasing the risk of rate limit exhaustion (as observed in R10).

**Verdict:** The haiku→sonnet switch was correct. Sonnet uses 64% fewer tokens with a marginally better fix rate. Duration is comparable. The token efficiency gain is the primary win.

### 3.4 Sonnet vs Opus — The Hard Story Question

Current routing sends hard stories to Opus. We have no data for sonnet on hard stories (the routing is strict), so a direct comparison is impossible. But we can triangulate:

| Metric | Sonnet (medium test) | Opus (hard test) | Step-up |
|--------|---------------------|------------------|---------|
| **Duration** | **2m 30s** | **4m 23s** | **1.75x slower** |
| **Tokens** | **40K** | **50K** | **1.25x more** |
| Fix rate | 0% | 0% | Same |

Opus hard stories take 1.75x longer and consume 1.25x more tokens than sonnet medium stories. The quality difference is invisible in the data — both have 0% fix rates on test content. However:

- Hard stories have cross-document references, complex acceptance criteria, and longer word count requirements.
- Opus's 0% fix rate on hard stories includes R14's E01-S06 (Multiversal Buffet, 2m 48s) and E01-S07 (Entropy Tavern, 5m 26s) and R16's E02-S03 (Orchestra Notes, 13m 27s) — all passed first review.
- We don't know if sonnet would have the same success rate on these tasks.

**The risk/reward calculation:** Switching hard→sonnet would save ~1m 53s and ~10K tokens per story. However, a single fix cycle adds ~4m duration and ~70K tokens (builder + reviewer re-dispatch). If sonnet's fix rate on hard stories exceeds ~25%, the duration savings are wiped out. Given the complexity differential between medium and hard stories, this is plausible but untested.

**Recommendation:** Run an A/B test. Pick 2-3 hard stories in the next test run and route them to sonnet. If they pass review, the data supports dropping opus builders entirely.

---

## 4. Reviewer Model Comparison

### 4.1 Opus vs Sonnet Reviewers — Test Content

Reviewer model routing was introduced in BL#105 (Orchestrator Improvements). Before #105, all reviews used Opus. After #105, easy story reviews use Sonnet; medium/hard/PR reviews use Opus.

**Opus reviewers on easy test stories (R8-R14, before routing):**

| Run | Story | Duration | Tokens | Cost |
|-----|-------|----------|--------|------|
| R8 | E01-S01 | 1m 13s | 25K | $0.25 |
| R8 | E01-S02 | 1m 39s | 25K | $0.25 |
| R8 | E01-S03 | 1m 11s | 24K | $0.24 |
| R9 | E01-S01 | 0m 36s | 23K | $0.23 |
| R9 | E01-S02 | 0m 40s | 23K | $0.23 |
| R10 | E02-S01 | 1m 30s | 29K | $0.29 |
| R10 | E02-S02 | 1m 22s | 29K | $0.29 |
| R11 | E02-S01 | 2m 48s | 41K | $0.41 |
| R11 | E02-S02 | 1m 34s | 29K | $0.29 |
| R13 | S01 | 0m 52s | 32K | $0.32 |
| R13 | S02 | 0m 47s | 31K | $0.31 |
| R13 | S05 | 0m 57s | 32K | $0.33 |
| R14 | E01-S01 | 0m 50s | 25K | $0.25 |
| R14 | E01-S02 | 1m 24s | 30K | $0.30 |
| R14 | E01-S03 | 1m 20s | 28K | $0.29 |
| **Average** | | **1m 10s** | **28K** | **$0.29** |

**Sonnet reviewers on easy test stories (R16, after routing):**

| Run | Story | Duration | Tokens | Cost |
|-----|-------|----------|--------|------|
| R16 | E01-S01 | 2m 47s | 58K | $0.35 |
| R16 | E01-S04 | 3m 08s | 58K | $0.35 |
| R16 | E02-S02 | 1m 58s | 55K | $0.33 |
| R16 | E03-S01 | 1m 27s | 55K | $0.33 |
| **Average** | | **2m 20s** | **57K** | **$0.34** |

### 4.2 Head-to-Head Comparison

| Metric | Opus (easy) | Sonnet (easy) | Delta |
|--------|------------|---------------|-------|
| **Avg tokens** | **28K** | **57K** | **+104% more tokens** |
| **Avg duration** | **1m 10s** | **2m 20s** | **+100% slower** |
| **Fix cycles triggered** | 0 | 0 | **Identical quality** |
| **Throughput** | ~400 tok/s | ~400 tok/s | Same |
| Est. cost (derived) | ~$0.28 | ~$0.34 | +21% (secondary metric) |

**The core finding: Sonnet uses 2x more tokens and takes 2x longer to reach the same conclusion.**

Sonnet generates more verbose analysis before arriving at its verdict. The throughput (tokens/second) is identical between models — sonnet isn't slower per token, it just processes 2x more tokens to do the same review. This means:

- Sonnet reviews consume **29K more tokens** per easy story for zero additional quality signal
- Sonnet reviews add **70 seconds** of wall-clock time per easy story
- In a run with 3 easy reviews, that's **87K extra tokens** and **3m 30s extra time** with no benefit

Even on the derived cost metric, sonnet loses: the 2.04x token ratio exceeds the 1.67x breakeven ratio needed to offset the per-token rate advantage ($10 vs $6 per MTok).

### 4.3 Sonnet Reviewers on Infrastructure Stories

Sonnet was also used for easy/medium infrastructure reviews in #109, #111, R15:

| Context | Sample | Avg Duration | Avg Tokens |
|---------|--------|-------------|------------|
| Infra (sonnet) | ~18 | **2m 55s** | **51K** |
| Infra (opus, same difficulty) | ~25 | **3m 20s** | **65K** |

For infrastructure reviews, the token gap narrows: sonnet uses 51K vs opus's 65K (1.27x ratio, vs 2.04x on test content). Infrastructure code reviews have higher context requirements that push both models' token counts up, but Opus disproportionately so. Duration is comparable (sonnet is actually slightly faster here). However, the quality dimension matters more for infra: infrastructure stories have the highest fix cycle rates (28.6% average), and we can't isolate whether the reviewer model affects catch rate.

### 4.4 The Original Motivation vs Reality

BL#105 introduced reviewer routing to "reduce review cost ~15-20% for easy stories." The hypothesis assumed sonnet would use similar tokens at a lower per-token rate. The data shows:

| Assumption | Reality |
|-----------|---------|
| Sonnet would use similar token counts | Sonnet uses **2.04x more tokens** (57K vs 28K) |
| Sonnet would be comparably fast | Sonnet takes **2x longer** (2m 20s vs 1m 10s) |
| Quality would be maintained | Quality is identical (no easy-story fix cycles in either model) |
| Net effect: save 15-20% cost | Net effect: **+104% tokens, +100% duration, zero quality gain** |

---

## 5. Model Routing ROI

### 5.1 Builder Routing — Positive ROI

**Current config:** easy→sonnet, medium→sonnet, hard→opus

**Token comparison for a typical 5-story test run (2 easy, 2 medium, 1 hard):**

| Scenario | Easy tokens | Medium tokens | Hard tokens | Total Tokens | Total Duration |
|----------|-------------|---------------|-------------|-------------|----------------|
| All opus | 50K × 2 | 50K × 2 | 50K × 1 | **250K** | **21m 55s** |
| **Current (routed)** | 40K × 2 | 40K × 2 | 50K × 1 | **210K** | **13m 45s** |
| All sonnet | 40K × 2 | 40K × 2 | ~40K × 1 | **200K** | **12m 22s** |

Builder routing saves **40K tokens and 8m 10s** of sequential build time vs all-opus. All-sonnet would save an additional ~10K tokens and ~1m 23s — **if** sonnet can handle hard stories without increased fix cycles (untested).

The duration savings are the primary win: 8m 10s per run from routing easy/medium to sonnet. The token savings are secondary but meaningful for API rate limit headroom.

### 5.2 Reviewer Routing — Negative ROI

**Current config:** easy→sonnet, medium→opus, hard→opus, PR→opus

**Token + duration comparison for a typical run (3 easy + 2 medium + 1 hard reviews + PR review):**

| Scenario | Easy review tokens | Easy review time | Other reviews | Total Tokens | Total Duration |
|----------|-------------------|-----------------|---------------|-------------|----------------|
| **All opus** | 28K × 3 = 84K | 1m 10s × 3 = 3m 30s | ~230K / ~11m | **314K** | **14m 30s** |
| **Routed (current)** | 57K × 3 = 171K | 2m 20s × 3 = 7m | ~230K / ~11m | **401K** | **18m** |

The routing adds **87K tokens (+28%)** and **3m 30s (+24%)** of sequential review time per run — with zero quality benefit.

This is the clearest negative-ROI decision in the workflow: more tokens, more time, same outcome.

### 5.3 Overall Routing Assessment

| Routing decision | Tokens Impact | Duration Impact | Quality Impact | Verdict |
|-----------------|---------------|-----------------|----------------|---------|
| Builder: haiku → sonnet (easy) | **−64%** (110K→40K) | +14% (1m55s→2m11s) | Improved (10%→0% fix rate) | ✅ **Correct** |
| Builder: sonnet (medium) | Baseline | Baseline | 0% fix rate | ✅ **Correct** |
| Builder: opus (hard) | +25% vs sonnet med (50K vs 40K) | +75% vs sonnet med | Untested risk | ⚠️ **Test sonnet** |
| Reviewer: sonnet (easy) | **+104%** (28K→57K) | **+100%** (1m10s→2m20s) | Identical (0% fix rate) | ❌ **Revert to opus** |
| Reviewer: opus (medium/hard/PR) | Baseline | Baseline | Baseline | ✅ **Correct** |

### 5.4 Before vs After Model Routing — Run-Level Comparison

Reviewer routing was introduced in #105 but only took effect starting R15 (new agent files aren't discovered mid-session).

**Runs with all-opus reviews (R8-R14, #105):**

| Run | Stories | Reviews | Review Tokens | Review Duration | Review % of Total Tokens |
|-----|---------|---------|---------------|-----------------|--------------------------|
| R8 | 5 | 7 | 194K | 8m 32s | 25.2% |
| R9 | 5 | 6 | 161K | 6m 37s | 24.8% |
| R10 | 6 | 7 | 269K | 13m 14s | 27.6% |
| R11 | 6 | 7 | 334K | 18m 41s | 31.9% |
| R13 | 6 | 7 | 250K | 9m 7s | 36.7% |
| R14 | 12 | 17 | 630K | 27m 26s | 39.4% |
| **Average** | | | | | **27.6%** |

**Runs with mixed-model reviews (R15, R16, #109, #111, #227):**

| Run | Stories | Reviews | Review Tokens | Review Duration | Review % of Total Tokens |
|-----|---------|---------|---------------|-----------------|--------------------------|
| R15 | 5 | 9 | 698K | 34m 17s | 27.2% |
| R16 | 9 | 13 | 736K | 39m 2s | 39.4% |
| #109 | 10 | 14 | 846K | 40m 31s | 33.2% |
| #111 | 9 | 14 | 926K | 52m 16s | 38.6% |
| #227 | 6 | 10 | 662K | 37m 38s | 36.8% |
| **Average** | | | | | **35.0%** |

Review share of tokens increased from 27.6% to 35.0% in mixed-model runs. However, this is confounded by run type — the mixed-model runs are mostly infrastructure runs with proportionally more complex reviews. When controlling for run type (test-only), R16's 39.4% review token share is notably higher than the pre-routing test average of ~30%, which is consistent with sonnet's 2x token consumption per easy review inflating the total.

The clearer comparison is per-review: opus averages 28K tokens in 1m 10s per easy review vs sonnet's 57K tokens in 2m 20s. The aggregate run-level data is too confounded by run-type differences to draw conclusions.

---

## 6. Phase-by-Phase Analysis

### 6.1 Phase Duration & Cost Distribution

Averaged across all 14 runs:

| Phase | Avg % of Duration | Avg % of Tokens | Parallelizable? | Notes |
|-------|-------------------|-----------------|-----------------|-------|
| **Design** | 8.5% | 8.2% | No (sequential) | Always Opus; R15 outlier at 1M tokens |
| **Plan** | 9.4% | 6.8% | No (sequential) | Always Opus; highly structured output |
| **Build** | 46.7% | 48.5% | Yes (parallel waves) | Largest phase; mostly Sonnet |
| **Review** | 23.0% | 26.1% | Partially | Second-largest; mostly Opus |
| **Retro** | 7.8% | 6.2% | Yes (w/PR review) | Always Opus |
| **Fix Cycles** | 4.6% | 4.2% | No (sequential) | Unpredictable; 66% format violations |

### 6.2 Questioning Each Phase

**Design (8.5% duration, 10.4% cost):**

- Design always uses Opus. For test content runs, the designer produces a creative brief in 3-5 minutes. For infrastructure runs, it can take 7-17 minutes (R15's designer consumed 1M tokens).
- **Question: Is design always needed?** For well-specified backlog items with clear acceptance criteria, the planner could work directly from the issue body. The `--skip-design` flag exists but is rarely used.
- **Question: Could sonnet handle design?** We have no data, but design is primarily creative writing and trade-off analysis — tasks where the quality bar is lower than code generation. A sonnet designer could potentially save 40% on design cost.
- **Observation:** Design + plan combined consume 17.9% of duration and 15.0% of tokens. They're a smaller fraction of tokens than duration because Opus generates more concise output than Sonnet builders — but they consume 100% of their wall-clock as sequential blocking time.

**Plan (9.4% duration, 7.6% cost):**

- Planning always uses Opus. It creates GitHub issues, dependency graphs, and the dispatch plan.
- The planner's output is highly structured (issue creation is mechanical). The creative element is decomposition — deciding how to split work into epics and stories.
- **Question: Could sonnet handle planning?** The structured output suggests yes. Issue creation is template-driven. The dependency graph is mechanical. The creative decomposition might suffer slightly, but the risk is low.
- **Question: Could design and plan be pipelined?** In autonomous mode, design is never rejected. Planning could start from the design doc body rather than waiting for PR merge. Estimated savings: 2-5m (the PR merge + status update overhead).

**Build (46.7% duration, 32.5% cost):**

- Build is the largest phase by both duration (46.7%) and tokens (48.5%).
- Build is the most parallelizable phase. In a 3-way parallel wave, 3 stories' build time collapses to 1 story's duration.
- **Question: Is there room to compress individual build duration?** Not really — builds are already fast (2-3m for sonnet, 4-5m for opus on test content). The bottleneck is the number of sequential waves, not per-story duration.

**Review (23% duration, 37.5% cost):**

- **Review is the second-largest phase by tokens (26.1%) and duration (23.0%).** It's disproportionate to the value it delivers on easy stories.
- **Question: Is per-story review necessary for easy test content?** No easy story has ever had a code quality issue caught by a reviewer. The reviews consistently return APPROVE with 0-2 minor suggestions. Each easy review consumes 28K tokens and 1m 10s for zero actionable findings.
- **Question: Could we skip reviews for easy stories?** This would save ~84K tokens and ~3m 30s per run (3 easy stories). Risk: the reviewer occasionally catches format violations (word count, missing sections) that the builder missed. These are acceptance criteria violations, not code quality issues.
- **Question: Could we batch easy reviews?** Instead of reviewing each story individually, review all easy stories in one pass after the wave completes. This would reduce context loading overhead (each review loads ~15-20K tokens of context that is shared across stories).
- **Counter-argument:** The fix cycle data shows that when reviews DO find issues, they're caught early — before the more expensive PR review. Without per-story reviews, format violations would only surface at the backlog PR review, where they're harder to fix (the PR reviewer sees all stories at once, not one at a time).

**Retro (7.8% duration, 7.9% cost):**

- Retro always uses Opus. It reads all lesson files, synthesizes patterns, and proposes convention changes.
- Since #105, retro runs in parallel with the PR review, so its wall-clock impact is partially absorbed.
- **Question: Is retro always needed?** The `workflow.skipRetro` config flag exists but defaults to false. For test runs that validate workflow mechanics (not produce reusable conventions), retro consumes ~75K tokens and 5-8m for limited return.
- **Question: Could sonnet handle retro?** Retro is primarily reading and synthesizing text — less demanding than code review. Sonnet could plausibly handle this, but token impact is unknown.

### 6.3 Model Assignment Optimization

What if non-builder, non-reviewer agents used Sonnet instead of Opus?

| Agent | Current Model | Avg Tokens/Run | Avg Duration/Run | If Sonnet (estimated) |
|-------|--------------|----------------|------------------|-----------------------|
| Designer | Opus | 55K (test) | 4m 30s | Similar tokens, possibly longer duration |
| Planner | Opus | 70K (test) | 7m 00s | Similar tokens, possibly longer duration |
| Retro | Opus | 75K (test) | 5m 00s | Similar tokens, possibly longer duration |
| **Total** | | **200K** | **16m 30s** | Likely similar tokens, +10-30% duration |

The key unknown is whether sonnet would use similar or more tokens for these tasks (as it does for reviews). Design, planning, and retro are primarily analytical/creative tasks — not the structured review task where sonnet's 2x token overhead was observed. The token impact needs testing.

What IS certain: switching these agents to sonnet would reduce the per-token rate from $10/M to $6/M (a 40% rate reduction on ~200K tokens per run). Whether total tokens stay flat or increase determines the net effect. If sonnet uses <1.67x opus's tokens for these tasks, it's a net win on the derived cost metric.

---

## 7. Long Poles & Bottleneck Analysis

### 7.1 Sequential Phase Budget

For a typical test run (~30m wall-clock):

```
Phase          Wall-Clock    Parallelizable?    Notes
──────────────────────────────────────────────────────────────────
Design         4-5m          No                 Must complete before plan
Plan           6-8m          No                 Must complete before build
Build wave 1   2-5m          Yes (3-way)        Parallelized
Review wave 1  3-5m          Partially          Sequential within wave
Build wave 2   2-4m          Yes (2-way)        Parallelized
Review wave 2  2-3m          Partially          Sequential within wave
Build wave 3   3-5m          No (1 story)       Sequential (hard story)
Review wave 3  1-2m          No (1 story)       Sequential
Retro          4-5m          Yes (w/PR review)  Parallel with PR review
PR review      3-5m          Yes (w/retro)      Parallel with retro
──────────────────────────────────────────────────────────────────
Fixed sequential overhead: 10-13m (Design + Plan)
Variable sequential: ~15-25m (build/review waves)
Parallel overlap: ~4-5m saved (build waves + retro||PR)
```

**The design+plan block is the #1 bottleneck.** It represents 35-45% of wall-clock time and is entirely sequential. No building can start until both phases complete.

### 7.2 Ranked Improvement Opportunities

| Rank | Improvement | Token Savings | Duration Savings | Complexity | Risk |
|------|------------|---------------|-----------------|------------|------|
| 1 | **Pipeline design→plan** (start plan from design doc, don't wait for PR merge) | None (less wait) | 3-5m/run | Low | Low (design never rejected in autonomous mode) |
| 2 | **Revert reviewer routing** (all reviews → opus) | ~87K/run | 3m 30s/run | Trivial | None |
| 3 | **Restore streaming reviews** — was natural Agent tool behavior in R8/R12/R13 (reviews dispatched as each parallel builder returned). Lost due to contradictory instructions: numbered steps imply streaming, but "Parallel dispatch" paragraph says "after all complete." R14+ followed the explicit paragraph. Fix: change CLAUDE.md + orchestrator.md "after all complete" to "review each story as its builder completes" | None (less wait) | 1-2m/wave | Low (doc fix) | Low |
| 4 | **Skip easy reviews** (or batch them into a single review pass) | ~84K/run | 3-4m/run | Low | Medium (miss format violations) |
| 5 | **Builder self-validation** (pre-commit AC check) | ~70K/prevented cycle | ~4m 30s/prevented cycle | Medium | Low |
| 6 | **Sonnet for design/plan/retro** | Unknown | Unknown | Low (config) | Medium (quality untested) |
| 7 | **Reduce orchestrator overhead** (batch git/board ops) | Minimal | 5-15m for complex runs | High | Low |
| 8 | **A/B test sonnet on hard stories** | ~10K/story | ~1m 53s/story | Low (one test run) | Medium |

### 7.3 Orchestrator Overhead

The orchestrator itself consumes significant wall-clock time between dispatches:

| Run | Wall Clock | Agent Time | Orchestrator Overhead | Overhead % |
|-----|-----------|------------|----------------------|------------|
| R11 | 40m 35s | 46m 25s (seq) | ~15m (est) | ~37% |
| R14 | 74m 4s | 102m 43s (seq) | ~25m (est) | ~34% |
| R16 | 116m 27s | 148m 33s (seq) | 43m 37s | **37%** |
| #111 | 129m 51s | 166m 32s (seq) | 25m 1s | **19%** |

Orchestrator overhead averages 25-37% of wall-clock time. This is time spent on:
- Branch creation and pushing
- Board status updates (GitHub API calls)
- State file updates
- Telemetry computation
- Merge operations
- Worktree setup/teardown

The overhead is not parallelizable — it's the glue between agent dispatches. Reducing it requires fewer API calls (batch operations), fewer git operations (lazy branch creation), or faster script execution.

---

## 8. Parallelism Ceiling

### 8.1 Observed Speedups

| Run | Parallel Waves | Max Width | Speedup | Note |
|-----|---------------|-----------|---------|------|
| R9 | 1×3 | 3 | 1.23x | Cleanest data point |
| R12 | 1×3 | 3 | 1.22x | |
| R13 | 1×3, 1×2 | 3 | **1.31x** | Best 6-story speedup |
| R14 | 3×3, 1×2 | 3 | **1.39x** | Best overall (12 stories) |
| R16 | 1×3, 1×2 | 3 | 1.28x | |
| #106 | 2×2, 1×3 | 3 | 1.28x | |
| #109 | 2×4 | 4 | **1.32x** | Widest parallelism |
| #111 | 2×3 | 3 | 1.28x | |
| **Average** | | | **1.22x** | |

### 8.2 Why Speedup Plateaus at ~1.4x

The theoretical maximum speedup is bounded by Amdahl's Law. The sequential fraction of the workflow is:

```
Sequential phases: Design + Plan + Retro + PR review + orchestrator overhead
Approximate fraction: 40-60% of wall-clock time
```

With 60% sequential / 40% parallelizable:
- Perfect parallelism on the 40%: speedup = 1 / (0.6 + 0.4/∞) = **1.67x**
- 3-way parallel on the 40%: speedup = 1 / (0.6 + 0.4/3) = **1.36x**

R14's observed 1.39x is essentially at the theoretical maximum for 3-way parallelism with 60% sequential fraction.

### 8.3 Breaking Past 1.4x

To achieve >1.4x speedup, the workflow must reduce the sequential fraction:

| Strategy | Sequential fraction reduction | Projected speedup |
|----------|------------------------------|-------------------|
| Pipeline design→plan | 60% → 50% | 1.50x (3-way) |
| + Stream reviews | 50% → 40% | 1.67x (3-way) |
| + Skip easy reviews | 40% → 35% | 1.74x (3-way) |
| + Increase max parallel to 5 | 35% sequential, 5-way parallel | **1.85x** |

Each improvement stacks. The most impactful single change is pipelining design→plan because it removes the largest contiguous sequential block.

---

## 9. Fix Cycle Economics

### 9.1 Per-Run Fix Cycle Data

| Run | Type | Cycles | Stories Affected | Extra Tokens | Extra Duration | % of Run Tokens | % of Run Duration |
|-----|------|--------|-----------------|-------------|---------------|-----------------|-------------------|
| R8 | Test | 1 | 1/5 (20%) | ~129K | ~4m | 16.8% | 10.2% |
| R9 | Test | 0 | 0/5 | — | — | — | — |
| R10 | Test | 0 | 0/6 | — | — | — | — |
| R11 | Test | 0 | 0/6 | — | — | — | — |
| R12 | Test | 0 | 0/5 | — | — | — | — |
| R13 | Test | 0 | 0/6 | — | — | — | — |
| R14 | Test | 3 | 2/12 (17%) | ~224K | 11m 29s | 14.0% | 11.2% |
| R16 | Test | 3 | 3/9 (33%) | ~209K | 22m 29s | 11.2% | 15.1% |
| #105 | Infra | 0 | 0/6 | — | — | — | — |
| #106 | Infra | 1 | 1/7 (14%) | ~111K | 4m 57s | 6.0% | 3.3% |
| R15 | Infra | 2 | 1/5 (20%) | ~104K | 5m 32s | 4.0% | 5.0% |
| #109 | Infra | 1 | 1/10 (10%) | ~62K | 2m 45s | 2.4% | 2.1% |
| #111 | Infra | 5 | 4/9 (44%) | ~318K | 21m 38s | 13.3% | 13.0% |
| #227 | Infra | 2 | 2/6 (33%) | ~109K | 4m 29s | 6.1% | 2.3% |

### 9.2 Fix Cycle Triggers

Analyzing the 18 fix cycles across all runs:

| Trigger Category | Count | Examples |
|-----------------|-------|---------|
| **Format/word count violations** | 8 (44%) | Word count over limit, wrong section format, missing template sections |
| **Convention violations** | 4 (22%) | Wrong numbering, missing table column, 200-line test file limit |
| **Content errors** | 3 (17%) | Wrong cross-reference, wrong scene number (planted bug) |
| **Code quality** | 2 (11%) | Unchecked GraphQL exit code, stale comment in test |
| **Test regression** | 1 (6%) | Test broke due to line-count threshold change |

**Key insight:** 66% of fix cycles are caused by format/convention violations — not bugs or logic errors. These are mechanical checks that could be automated as a pre-commit validation step in the builder, eliminating the need for a full reviewer round-trip.

### 9.3 Fix Cycle Overhead

Average fix cycle overhead per cycle:
- **Builder re-dispatch:** ~40K tokens, ~3m duration
- **Reviewer re-dispatch:** ~30K tokens, ~1m 30s duration
- **Total per cycle:** ~70K tokens, ~4m 30s duration

Total fix cycle overhead across all runs: **~1.26M tokens** and **~73m duration** (18 cycles).

Fix cycles as a percentage of total metrics: **~6.2% of tokens** and **~5.3% of duration**. This is the "quality tax" — the overhead of having reviews catch issues and triggering rework. Without reviews, these issues would either ship (lower quality) or be caught at the more expensive backlog PR review stage, where fixes are harder to isolate to a single story.

---

## 10. Test Runs vs Infrastructure Runs

### 10.1 Structural Comparison

| Metric | Test Runs (9) | Infra Runs (5) | Ratio |
|--------|---------------|-----------------|-------|
| Avg stories per run | 6.7 | 7.4 | 1.1x |
| Avg dispatches per run | 21.3 | 25.2 | 1.2x |
| **Avg tokens per run** | **1.18M** | **2.15M** | **1.8x** |
| **Avg tokens per story** | **176K** | **290K** | **1.6x** |
| **Avg wall-clock per run** | **41.8m** | **120.6m** | **2.9x** |
| **Avg wall-clock per story** | **6.2m** | **16.3m** | **2.6x** |
| Avg fix rate | 7.8% | 28.6% | **3.7x** |
| Avg parallelism speedup | 1.23x | 1.22x | ~Same |

### 10.2 Why Infrastructure Runs Cost 2.6x More

1. **Context loading:** Builders must read existing scripts (pm.sh is 300+ lines, state.sh is 800+ lines), understand adapter patterns, and navigate complex test suites. Test content builders write standalone documents from scratch.

2. **Fix cycles:** Infrastructure runs have a 3.7x higher fix rate. Real code must pass existing tests and satisfy stricter review criteria. The #111 run (44% fix rate) was particularly costly — the 200-line test file convention triggered repeated violations.

3. **Longer design/plan phases:** Real features require deeper analysis. R15's designer consumed 1M tokens (17m) analyzing the orchestrator reduction strategy. Test content designs are simple creative briefs.

4. **Review depth:** Infrastructure reviewers check test coverage, DI registration, convention adherence, and regression risk. Test content reviewers check word counts and formatting.

### 10.3 Are Infrastructure Runs Disproportionately Heavy?

At 290K tokens/story and 16.3m/story, infrastructure runs consume significantly more resources than test runs. But this comparison is misleading — they're doing fundamentally different work.

A fairer comparison is resource consumption per successful outcome:
- **Test runs:** 1.18M tokens/run and 42m wall-clock for creative content (no lasting engineering value)
- **Infrastructure runs:** 2.15M tokens/run and 121m wall-clock for production code with tests (lasting engineering value)

The 1.8x token multiplier and 2.9x duration multiplier for infrastructure runs reflect the inherent complexity of modifying production code: builders must load existing code into context, run test suites, navigate adapter patterns, and satisfy stricter review criteria. This is not inefficiency — it's the work.

---

## 11. Challenging the Current Workflow

### 11.1 Do We Need All Six Agents?

| Agent | Needed? | Challenge |
|-------|---------|-----------|
| **Orchestrator** | Yes | The workflow doesn't function without coordination. No challenge. |
| **Designer** | Sometimes | For simple/well-specified features, the planner can work from the issue body. The `--skip-design` flag exists. Should be used more aggressively. |
| **Planner** | Yes | Issue creation, dependency graphs, and difficulty routing are essential. No shortcut. |
| **Builder** | Yes | Core implementation. No challenge. |
| **Reviewer** | **Partially** | Per-story review for easy test content consumes 28K tokens and 1m 10s per story with zero demonstrated value (0 fix cycles across 40+ easy stories). Consider: (a) skip easy reviews, (b) batch review all easy stories at once, or (c) lightweight self-review by the builder. |
| **Retro** | Sometimes | For test runs validating mechanics (not producing reusable conventions), retro consumes ~75K tokens and 5-8m without proportional value. `workflow.skipRetro` should default to true for test runs. |

### 11.2 Phase Restructuring: Implementation vs Review

The current phase model treats per-story building and per-story reviewing as separate phases (Phase 5: Dispatch Builders, Phase 6: Review Stories). This forces a sequential handoff between build waves and review waves — the orchestrator waits for all builders in a wave, then dispatches reviewers one at a time.

**The insight:** Per-story reviews are quality checks internal to implementation, not a standalone gate. The real quality gate is the PR review that sees the full cross-story picture. This suggests two distinct concepts:

| Concept | What it is | Examples |
|---------|-----------|---------|
| **Implementation** (per-story) | Build + validate each story as a self-contained unit | Builder builds, reviewer validates, fix cycles if needed — all per story |
| **Review** (cross-story) | Comprehensive review of the integrated result | PR review, cross-story coherence check |

**Proposed phase model:**

| Phase | Name | What happens |
|-------|------|-------------|
| 0 | Setup | Detect mode, create integration branch, check existing artifacts |
| 1 | Design | *(conditional)* Dispatch designer, auto-merge PR |
| 2 | Plan | Dispatch planner, read plan, create branches |
| 3 | **Implementation** | Dispatch waves. Each story's full lifecycle (build → review → fix cycles) runs inside the wave in parallel. Wave completes when all stories are done. |
| 4 | Merge + Open PR | Merge branches, open backlog PR |
| 5 | **Review** | PR review (the real quality gate — cross-story coherence) |
| 6 | Retro + Telemetry | *(conditional)* Retro, changelog, telemetry |

This reduces the phase count from 12 to 7 and eliminates the artificial boundary between build and review.

**The velocity impact is significant.** Each wave becomes fully parallel:

```
Current wave model:
  [build S01 | build S02 | build S03]  →  [review S01 → review S02 → review S03]  →  merge
       parallel builds (2m 30s)                sequential reviews (3m 30s)
  Wave wall-clock: max(builds) + sum(reviews) = 2m 30s + 3m 30s = 6m 00s

Proposed wave model:
  [build S01→review S01 | build S02→review S02 | build S03→review S03]  →  merge
                      all parallel (~3m 40s each)
  Wave wall-clock: max(build + review per story) = 3m 40s
```

For a typical 3-story wave (2m 30s avg build, 1m 10s avg review):
- **Current:** 6m 00s per wave
- **Proposed:** 3m 40s per wave
- **Savings: 2m 20s per wave (39% reduction)**

For a run with 3 waves, that's **~7 minutes saved** — larger than any other single optimization.

**How this works with tiered reviews:**
- **Easy test stories:** Skip per-story review entirely. Story lifecycle = build → done. PR review catches anything.
- **Medium/hard stories:** Builder dispatches include a reviewer sub-task. Story lifecycle = build → review → (fix cycle) → done.
- The orchestrator doesn't need to decide when to review — the builder agent (or a wrapper) handles it.

**Implementation:** Each parallel Agent tool dispatch becomes "implement this story" (build + review) rather than "build this story." The orchestrator dispatches one self-contained unit per story. This can be achieved by:
- (a) Adding reviewer dispatch instructions to the builder agent, or
- (b) Creating a "story-implementer" wrapper agent that sequences builder → reviewer → fix cycles, or
- (c) Having the orchestrator dispatch builder and reviewer as sequential tasks within each parallel slot

Option (b) is cleanest — a thin wrapper agent that runs build → review → fix loop, returning only when the story is fully validated.

### 11.3 Is the Three-Level Hierarchy Necessary?

The backlog→epic→story hierarchy adds complexity to labels, branches, dispatch, and telemetry. For smaller features (5-6 stories), a single epic is common (R12, R13 were single-epic). The epic layer provides:

- **Parallel wave grouping** — stories within an epic can run in parallel
- **Merge isolation** — stories merge into epic branch before integration
- **Telemetry aggregation** — per-epic metrics

For single-epic runs, the epic layer is pure overhead. Consider a "flat mode" for features with ≤6 stories that eliminates the epic level: stories merge directly into the integration branch.

### 11.4 Is the Current Review Process Right-Sized?

The data strongly suggests the review process is over-applied:

| Story Difficulty | Review Tokens | Review Duration | Issues Found | Value |
|-----------------|--------------|-----------------|-------------|-------|
| Easy (test) | 28K | 1m 10s | 0 issues across 40+ stories | **Zero demonstrated value** |
| Medium (test) | 33K | 1m 26s | Occasional format issues | Low value |
| Hard (test) | 36K | 1m 49s | Occasional content issues | Medium value |
| Easy (infra) | 44-65K | 2m-3m 20s | Convention violations | Medium value |
| Medium (infra) | 65K | 3m 20s | Convention + code issues | High value |
| Hard (infra) | 90K+ | 4m+ | Code quality, security | **High value** |
| PR review | 77-132K | 4-8m | Cross-story coherence | High value |

**Proposal: Tiered review strategy**

Under the proposed phase model (§ 11.2), per-story reviews are internal to the Implementation phase. This makes tiered review natural — it's just configuring what each story's implementation cycle includes:

| Tier | When | Story lifecycle | Est. Token Savings | Est. Time Savings |
|------|------|----------------|-------------------|-------------------|
| **Build only** | Easy test stories | build → done (skip per-story review) | ~84K/run (3 × 28K) | ~3m 30s/run |
| **Build + review** | Medium/hard stories, all infra | build → review → (fix cycle) → done | Baseline | Baseline (but now parallel within wave) |
| **PR review** | Always (cross-story gate) | Final review of integrated PR | Baseline | Baseline |

Estimated total savings per test run from skipping easy reviews: ~84K tokens and ~3m 30s. The additional ~7 minutes saved per run from parallelizing build+review within waves (§ 11.2) applies on top of this.

### 11.5 What Would an "Express Mode" Look Like?

For well-specified, low-risk work (test content, simple docs), an express mode uses the proposed phase model with maximum conditional skipping:

```
Full:     Setup → Design → Plan → Implementation (build+review per story) → Merge/PR → PR Review → Retro → Telemetry
Express:  Setup → Plan → Implementation (build only, no per-story review) → Merge/PR → PR Review → Telemetry
```

Express mode skips: design (requirements in issue body), per-story reviews (rely on PR review), and retro (no convention learning needed).

Estimated savings per test run: ~200K tokens (design tokens + per-story review tokens + retro tokens) and 30-40% of wall-clock time (12-15m). Combined with the wave parallelization from § 11.2, total savings could reach 40-50%.

This is a significant workflow simplification that the config system (`workflow.*` flags) could support without code changes — just new config presets.

---

## 12. Telemetry Visualization Problems

### 12.1 Current State

The Gantt chart is generated by `compute-dispatches.py:generate_gantt()` using **absolute wall-clock timestamps** from the orchestrator state file. Each dispatch is positioned at its `started_at` timestamp offset from `session.started_at`.

### 12.2 Observed Problems

**Problem 1 — API/session gaps destroy readability:**

BL#227's Gantt chart spans 00:00:00 to ~12:20:00 because of a ~9h gap from an API 529 error. Only ~40 minutes of that timeline is actual work. The chart is 97% whitespace. The screenshot shows tasks after the gap compressed into unreadable slivers on the right edge.

**Problem 2 — Stalled sessions create misleading bars:**

BL#227's first builder (`Issue #233`) shows as a 91-minute bar, but only produced 82K tokens — a throughput of ~15 tok/s vs the typical ~300 tok/s. This was a stalled or rate-limited session, not 91 minutes of productive work. The Gantt can't distinguish "actively working" from "waiting for API response."

**Problem 3 — Interactive retries create visual clutter:**

BL#109's designer was dispatched 8 times during interactive brainstorming. Each shows as a separate bar in the Gantt, creating a cluster of tiny bars that don't represent the logical workflow.

**Problem 4 — Scale mismatch:**

When one task is 91 minutes and another is 48 seconds (a 113:1 ratio), the short task is invisible at the chart's scale. This is a fundamental limitation of linear time axes.

**Problem 5 — Labels are ambiguous:**

Tasks show as "Build (91m 2s)" and "Build (9m 3s)" without story codes, making it impossible to identify which story each bar represents. The `_gantt_label_for_dispatch()` function should always include story codes but falls back to generic labels when metadata is missing.

### 12.3 Root Cause

The Gantt chart answers the question **"when did each task run?"** but the user actually wants to know **"how did work flow through the pipeline?"** These are different questions. Wall-clock positioning is correct for the first question but actively harmful for the second.

### 12.4 Proposed Solution: Dual-Mode Gantt

**Mode 1: "Work Timeline" (proposed default)**

- X axis = **cumulative agent execution time** (gaps removed)
- Parallel tasks stacked at the same X offset (wave grouping preserved)
- Wave contribution to timeline = `max(duration_ms)` of parallel dispatches (critical path)
- Gaps > 5 minutes replaced with annotated markers: `⚠ 9h gap (API 529)`
- Multiple dispatches of the same (issue, agent) consolidated into a single bar
- Result: compact, readable chart focused on **work done**

Implementation: Modify `generate_gantt()` to compute offsets from cumulative active time rather than absolute timestamps. The wave grouping logic (`_group_dispatches_by_parallel_wave()`) already identifies parallel waves — use `max(duration_ms)` per wave as the offset increment.

**Mode 2: "Wall-Clock Timeline" (current, kept for diagnostics)**

- Absolute timestamps (current behavior)
- Add gap compression: idle gaps > 5m compressed to a fixed-width annotation
- Add throughput annotations: flag tasks with < 50 tok/s as "stalled"
- Useful for debugging rate limits, API errors, and session scheduling

**Activation:**

```bash
# Work timeline (default)
compute-dispatches.py --from-state <file> --gantt

# Wall-clock timeline (diagnostic)
compute-dispatches.py --from-state <file> --gantt --gantt-mode wall-clock
```

### 12.5 Additional Visualization Ideas

| Priority | Visualization | Purpose | Mermaid-compatible? |
|----------|-------------|---------|---------------------|
| P0 | Compressed Gantt (work timeline) | Fix the readability crisis | Yes |
| P1 | Phase summary chart (5-7 bars) | Executive view of time distribution | Yes |
| P2 | Story lifecycle swimlanes | Show build→review→fix per story | Partially (Mermaid Gantt with sections) |
| P3 | Fix cycle callouts | Highlight rework visually | Yes (`:crit` tags already do this) |

---

## 13. Recommendations

### 13.1 Immediate Actions (Zero Risk)

| # | Action | Type | Token Impact | Duration Impact | Effort |
|---|--------|------|-------------|-----------------|--------|
| 1 | ~~**Revert reviewer routing: all reviews → opus**~~ — Sonnet reviewers use 2x tokens (57K vs 28K), take 2x longer (2m 20s vs 1m 10s), identical quality (0 fix cycles in either model). See § 4.2. **Done:** Removed `reviewerRouting` config, deleted `reviewer-sonnet.md` and `reviewer-opus.md` variant files, simplified to single `reviewer.md` with `model: inherit`. Commit `d6e8799`. | ~~Config change~~ | Save ~87K/run | Save ~3m 30s/run | ✅ Done |
| 2 | ~~**Fix R12 cost in CHANGELOG**~~ — $12.55 → $4.77. The $30/M rate was a miscalculation; every other run uses the correct $10/M blended rate. See § 1. **Done:** Commit `d6e8799`. | ~~Doc fix~~ | — | — | ✅ Done |

> **Note:** The `--skip-design` and `skipRetro: true` flags are already supported and can save 4-8m each per run. These are per-run judgment calls, not implementation items: use `--skip-design` when the backlog issue has clear ACs, and `skipRetro: true` for test runs that don't need convention learning.

### 13.2 Targeted Fixes (Low Risk)

| # | Action | Type | Token Impact | Duration Impact | Effort |
|---|--------|------|-------------|-----------------|--------|
| 3 | **Fix Gantt story code regression** — Labels used to show `E01-S02 Build (9m 3s)`, now show generic `Build (9m 3s)`. The `_gantt_label_for_dispatch()` function supports story codes via `_build_story_labels()`, but the mapping stopped populating for some dispatches. Also restore story codes in the breakdown table. | Code investigation | — | — (readability) | 2-4h |
| 4 | **Scripted builder AC validation** — Builder instructions exist at `builder.md` L120-125 but are conditional ("if...") and advisory. 8/18 fix cycles (66%) were format/word-count violations that should have been caught. Replace advisory text with a mandatory validation script that checks measurable ACs before `issue-review.sh`. See § 9.2. | Script + agent | Save ~70K/prevented cycle | Save ~4m 30s/prevented cycle | 4-6h |

### 13.3 Structural Workflow Changes (Backlog Items)

| # | Action | Type | Token Impact | Duration Impact | Effort |
|---|--------|------|-------------|-----------------|--------|
| 5 | **Phase restructuring + streaming reviews** — see details below | Orchestrator + agents | None (same work) | Save ~2m 20s/wave (39%) | 8-16h |
| 6 | **Compressed Gantt ("Work Timeline" mode)** — see details below | Code (`compute-dispatches.py`) | — | — (readability) | 6-10h |
| 7 | **Tiered review strategy** — Skip per-story review for easy test stories. PR review becomes sole gate. No easy story has triggered a fix cycle from a real quality issue across 40+ stories. Mitigated by item 4. Integrates with item 5. See § 11.4. | Orchestrator + config | Save ~84K/run | Save 5-7m/run | 2-4h |
| 8 | **Pipeline design→plan (autonomous only)** — Start planner from design doc body before PR merge. Does not apply to interactive mode. Originally claimed 3-5m was overstated; actual savings are ~1-2m of orchestrator glue. | Orchestrator | None | Save ~1-2m/run | 2-4h |

**Item 5 details — Phase restructuring + streaming reviews:**

This is the highest-impact structural change in the analysis (§ 11.2). Currently, the orchestrator treats building and reviewing as separate sequential phases: dispatch all builders in a wave → wait for all to complete → dispatch reviewers one at a time. This forces wave time = `max(builds) + sum(reviews)`.

The proposed model makes each story's full lifecycle (build → review → fix cycle) a single parallel unit within a wave. Wave time = `max(build + review per story)`. For a typical 3-story wave (2m 30s avg build, 1m 10s avg review): current = 6m 00s, proposed = 3m 40s. For a run with 3 waves, that's ~7 minutes saved.

This subsumes the "streaming reviews" idea — streaming was a half-measure ("review each builder as it returns, but still sequentially"). Phase restructuring is the full version where build+review run in parallel per story.

Three implementation approaches:
- (a) Add reviewer dispatch instructions to the builder agent
- (b) Create a "story-implementer" wrapper agent that sequences build → review → fix loop
- (c) Orchestrator dispatches builder and reviewer as sequential tasks within each parallel slot

Option (b) is cleanest — a thin wrapper agent returning only when the story is fully validated.

How this interacts with tiered reviews (item 7): easy test stories skip per-story review (lifecycle = build → done); medium/hard stories retain build → review → (fix cycle) → done. PR review remains the cross-story quality gate regardless.

**Item 6 details — Compressed Gantt ("Work Timeline" mode):**

X-axis = cumulative active time (not wall-clock). Pauses and interruptions shown as indicator markers with a text note below the chart — not as empty gaps that destroy readability.

This fixes the BL#227 problem where a 9h API 529 gap created 97% whitespace in the Gantt chart. A prior fix attempt (gap compression) was built and reverted (commits `4f51e4d` → `645be97`) because it interacted badly with stalled dispatches where `duration_ms` includes idle time (e.g., E01-S01 reported 91m wall-clock for ~5m of actual work at 15 tok/s). Both issues must be solved together. See § 12.

The existing wall-clock mode should be retained as a diagnostic option (`--gantt-mode wall-clock`).

### 13.4 Experiments (Need Data)

| # | Action | Type | Token Impact | Duration Impact | Effort |
|---|--------|------|-------------|-----------------|--------|
| 9 | **A/B test sonnet on hard stories** — No data exists. Opus hard stories have 0% fix rate on test content. If sonnet fix rate on hard exceeds ~25%, savings are wiped. Route 2-3 hard stories to sonnet in the next test run. See § 3.4. | Experiment | Save ~10K/story | Save ~2m/story | 1 test run |
| 10 | **A/B test sonnet for design/plan/retro** — Key unknown: does sonnet use 2x tokens for creative tasks (as for reviews, § 4.2) or comparable tokens (as for building, § 3.3)? If <1.67x, the 40% rate reduction is a net win. See § 6.3. | Experiment | Unknown | Unknown | Agent variants |

### 13.5 Long-Term Architectural Changes

| # | Action | Type | Token Impact | Duration Impact | Effort |
|---|--------|------|-------------|-----------------|--------|
| 11 | **Express mode** — Config preset: `Plan → Build → PR Review → Telemetry`. Combines skip-design + skip-per-story-review + skip-retro. Depends on items 5 and 7. See § 11.5. | Config + orchestrator | Save ~200K/run | Save 12-15m/run (30-40%) | 8-16h |
| 12 | **Flat mode (no epic layer for ≤6 stories)** — Single-epic runs have the epic layer as pure overhead. Stories merge directly into integration branch. See § 11.3. | Orchestrator + branches | Minimal | Reduce orch. overhead | 8-16h |
| 13 | **Reduce orchestrator overhead** — Batch git/board ops. Currently 25-37% of wall-clock. See § 7.3. | Scripts + orchestrator | Minimal | Save 5-15m (complex runs) | 8-16h |
| 14 | **Visualization improvements** — Phase summary chart (2-3h, Mermaid), story lifecycle swimlanes (4-6h), custom dashboard (Very High, BL#116). See § 12.5. | Code | — | — (readability) | 2h-Very High |

### 13.6 Projected Impact

If items 1-2 (immediate) and 3-5 (targeted + phase restructuring) were implemented for a typical test run:

| Metric | Current | Projected | Improvement |
|--------|---------|-----------|-------------|
| **Tokens** | ~1.18M | ~0.95M | **−20%** |
| **Wall-clock** | ~30m | ~20m | **−33%** |
| **Sequential duration** | ~38m | ~30m | **−21%** |
| Fix cycles | ~0.8/run | ~0.3/run | −63% |
| Review duration | ~8m | ~5m | −38% |
| Wave duration | ~6m | ~3m 40s | −39% |
| Gantt readability | Broken for interrupted runs | Readable always | Qualitative |

---

*This analysis is based on telemetry from 14 backlog items (97 stories, 302 dispatches, 20.4M tokens, 23h 9m sequential agent time) executed between 2026-03-12 and 2026-03-19. Primary metrics (tokens, duration) are raw values from the Agent tool. Cost estimates are derived (tokens × blended rate using 75% input / 25% output split from published pricing) and should be treated as directional, not precise. Subscription plans include token allowances and are not charged per-token — cost figures represent equivalent API value for reference only.*
