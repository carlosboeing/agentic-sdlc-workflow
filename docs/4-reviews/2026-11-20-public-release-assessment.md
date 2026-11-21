---
created: "2026-11-20"
updated: "2026-11-21"
title: "Public release assessment, November 2026"
type: review
status: draft
authors:
  - "Carlos Boeing"
  - "claude-opus-5-5 (claude-code)"
scope: [release, assessment, claim-calibration]
reviewed_by: []
related:
  - ../case-studies.md
  - ../architecture.md
  - ../1-discovery/2026-11-20-state-of-practice-research.md
  - ../3-plans/2026-11-20-real-task-backlog-plan.md
  - ../6-adrs/0007-merge-reference-design-and-publish.md
---

# Public release assessment, November 2026

A condensed record of the assessment that preceded the public release: what it found, which claims it recalibrated, what was changed, and what remains. The detailed failure narratives are in the [case studies](../case-studies.md); the platform comparison is in the [state-of-practice research](../1-discovery/2026-11-20-state-of-practice-research.md).

## Summary

The workflow was a real, working implementation with a dense record of failures, diagnoses and changed mechanisms, and its deterministic scripts were the strongest engineering evidence. It was not ready to publish. The front page overstated autonomy and quality, a regression had sat undetected on `main` since March, there was no CI, the configuration pointed at the owner's project board, unattended runs were documented with the permission bypass flag, and the tree carried private references and synthetic workload outputs at the top level. The verdict was "blocked, resolve first". The release preparation resolved the blockers without rewriting Git history.

## Scope and method

| Input | Detail |
|---|---|
| Workflow tree | Commit `5c4b571`: 536 files, 86 commits on `main`, full `git log --stat` history |
| GitHub record | 296 issues and 68 pull requests, read only |
| Test runs | A clean `git archive` export with `gh` removed from `PATH` and an empty `HOME` |
| Reference design | Imported under `blueprint/` from its own history at `cce3012` |
| Platform facts | Rechecked against current official documentation on 2026-11-20 |

## What the assessment found

### Strengths

| Strength | Evidence |
|---|---|
| An explicit rule for what is computed and what is judged, backed by an incident and by code | `CLAUDE.md` "Determinism First"; `compute-dispatches.py` with 252 offline tests |
| Telemetry used to disprove the author's own decision | Reviewer routing reverted in `d6e8799` ([case study 1](../case-studies.md#1-a-cost-saving-hypothesis-that-telemetry-disproved)) |
| Lessons, retrospectives and an adoption tracker that records declined proposals | 51 lesson files, 26 retrospectives, [retro recommendations tracker](retro-recommendations.md) |
| An honest split of synthetic and infrastructure results | Fix-cycle rate 7.8 percent across 9 synthetic runs against 28.6 percent across 5 infrastructure runs |
| Isolation rules grounded in real collisions | [Case study 3](../case-studies.md#3-parallel-builders-collided-then-isolation-tightened-in-four-steps) |
| Root-causing a race with an external system | [Case study 4](../case-studies.md#4-board-status-drift-traced-to-a-github-automation) |
| Self-hosting | 11 backlog items changed the workflow's own scripts and server through the workflow |
| Clean staging of abstractions | [ADR 0004](../6-adrs/0004-shadow-stack-migration.md), [ADR 0006](../6-adrs/0006-server-pm-adapter-pattern.md) |

### Blockers and weaknesses

| Finding | Consequence |
|---|---|
| The README claimed "fully autonomous", "zero human intervention" and "merge-ready" output | A skeptical reader discounts the repository in the first minute; the recorded runs contradict it |
| 623 of 635 server tests passing, 12 failing, 2 files unable to load, caused by retro commit `4d3ab9b` | The first thing a reviewer runs fails ([case study 2](../case-studies.md#2-a-retrospective-commit-that-reverted-reviewed-code)) |
| No CI | Tests ran only when an agent or a human ran them |
| `--dangerously-skip-permissions` documented as the recommended path; the allowlist held leftover rules from another stack and a blanket `Bash(gh *)` | Signals weak security judgement; current docs restrict bypass mode to isolated containers |
| Owner-specific board IDs in config, docs and tests | A clone would fail or write to the owner's board |
| Private project names and local paths in current files | Release hygiene and consent |
| Synthetic workload outputs and their designs at the top level, unlabelled | The repository reads as a toy |
| The five listed platform limitations: three no longer held, two could not be confirmed | The repository's own research-first lesson was not applied to its own manual |
| Role boundaries enforced by instructions only; control flow in a 662-line prompt; an 828-line `CLAUDE.md` | Control flow cannot be tested; a docs-only role changed code |
| Raw run state deleted after every merge | The March analyses cannot be recomputed from source data |
| Inconsistent run identifiers ("Run 15" names three different backlog items) | Metric tables are harder to audit |
| Residue: a removed file adapter's data, a tracked frontend build with a source map, content checks inside `scripts/lib/` | Looks like live state |

### Reference design findings

| Finding | Disposition |
|---|---|
| Never run end to end; written in one session before the implementation | Marked historical and unexecuted with a banner on every document |
| The starter kit's agent files did not load; its pipeline loop never ended | Small defects fixed; kit labelled illustrative |
| A sample hook approved every Bash command, including `rm -rf` | Replaced with a deny-list hook that otherwise defers to the normal permission flow |
| External metrics presented as observed | Attributed or relabelled |
| A self-audit that called two existing tools non-existent | Errata added |

## Claims recalibrated

| Former claim | Replacement |
|---|---|
| "A fully autonomous software development lifecycle with zero human intervention" | A human-governed agentic SDLC: agents carry an approved backlog item to one pull request that a human reviews and merges |
| "A single command produces a reviewed, tested, merge-ready pull request" | A single command can carry a backlog item to a reviewed pull request; in recorded runs humans made follow-up commits before merging |
| `--dangerously-skip-permissions` as the recommended path | Offline first run; supervised interactive run; `dontAsk` allowlist inside a container for unattended runs |
| "Self-improving system" | Retrospective-driven continuous improvement: the retro proposes, a human adopts or declines, a tracker records the outcome |
| "100% completion rate and zero code correctness failures" | Across 10 synthetic prose runs, all planned stories were completed, judged by an LLM reviewer against structural criteria |
| "17-story zero-fix streak, 100% first-pass approval" | Observed on prose workloads in Runs 9 to 11; infrastructure work ran at 28.6 percent on average and 67 percent on the largest build |
| "Infrastructure self-healing works" | Each recorded infrastructure failure led to a proposed convention change; recurrence was not measured and some classes recurred in new forms |
| "Mandatory review, no exceptions" | Every backlog PR is reviewed; per-story review is skipped only under the configured skip tier |
| "Idempotent restart" | Restart skips completed stories; reconstruction from GitHub is not implemented |
| "~500 tests" | 681 server tests, 252 telemetry tests and 34 offline shell suites, all passing after the fix |
| Per-run cost tables | Estimated API-equivalent value at a blended rate; caching and orchestrator tokens excluded |
| "Turns non-deterministic output into deterministic output" | Moves state, telemetry and board operations into tested scripts; phase sequencing remains instruction-following |

## What was changed for release

| Change | Commits |
|---|---|
| Reference design merged under `blueprint/` with its history; banners, errata, calibrated claims | `33515ac`, `cb44420` |
| Starter kit: approve-all hook replaced, agents and scripts repaired, allowlists tightened, labelled illustrative | `d860c05`, `44f4e1c`, `f7a94c8` |
| Synthetic outputs, per-run designs and plans, and file-adapter residue removed from the tree (kept in history) | `4b7c893` |
| Lesson folders renamed to neutral run names; private references removed from lifecycle records; historical notes added | `05d8014`, `f28f919`, `762ef6a` |
| Regression from `4d3ab9b` restored; server 681 of 681 | `72f7476` |
| Built frontend assets untracked | `00e2db0` |
| Permissions shaped for `dontAsk`, deny rules, logging hook fixed; allowlist narrowed after a security review | `4be6d23`, `57aabfa` |
| Owner board IDs removed; board work skipped when unconfigured | `93c7598` |
| Retro scope guard plus a post-retro test run in the orchestrator | `b5a4212` |
| CI with a single `required` gate and Dependabot | `ab3d57e` |
| Running-safely guide | `f5a6aa1` |
| Frontmatter normalized on the March records | `2a6fa56`, `cccb6d8` |
| README, architecture, methodology, case studies, ROADMAP, CHANGELOG, ADR 0007, community health files | This release's documentation commits |

## What remains

| Item | Where it is tracked |
|---|---|
| Control flow, wave scheduling and halts are prompt-driven | Real-task backlog A09 |
| Role boundaries enforced by instructions apart from the retro guard; no PreToolUse check against merging into `main` | A02 |
| The retro guard keys on the commit subject; no parent-is-head check | A03 |
| Raw run records not retained | A08 |
| `CLAUDE.md` far above the recommended length; stale limitations still listed with a caveat | A11 |
| Token-based cost estimates; budget library not wired in | A12 |
| Runtime service started by hand; MCP server predates the 2026-07-28 specification | A14; Deferred in the [ROADMAP](../ROADMAP.md) |
| No evaluation on real tasks and no external users | The [real-task backlog](../3-plans/2026-11-20-real-task-backlog-plan.md) |
| Content checks for the removed outputs are skipped, not deleted | Cleanup |
| Git history and GitHub pull-request refs keep pre-release content | Accepted by [ADR 0007](../6-adrs/0007-merge-reference-design-and-publish.md) |
| Repository visibility, branch protection and issue-comment review before publication | Maintainer actions outside this repository's files |
