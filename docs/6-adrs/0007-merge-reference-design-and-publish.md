---
created: "2026-11-21"
updated: "2026-11-21"
title: "ADR-0007: Merge the reference design into this repository and publish it"
type: adr
status: approved
authors:
  - "Carlos Boeing"
  - "claude-opus-5-5 (claude-code)"
scope: [release, repository-structure, history]
related:
  - ../4-reviews/2026-11-20-public-release-assessment.md
  - ../architecture.md
  - ../../blueprint/README.md
---

# ADR-0007: Merge the reference design into this repository and publish it

## Status

Approved. The maintainer chose this option on 2026-11-21. This record was written afterwards from that decision and has not yet been read by the maintainer.

## Context

Two bodies of work describe the same idea:

| Work | What it is | Strength as public evidence | Problems found in November 2026 |
|---|---|---|---|
| Reference design | A six-role agentic SDLC design written in one session in March 2026, before the implementation, in a separate repository | Role contracts, scoped context, human merge authority, a self-critique that anticipated later changes | Never run. The starter kit did not load and its pipeline loop never ended. A sample hook approved every Bash command. External metrics read as observed. |
| This repository | The working orchestrator and role agents, built over 12 days in March 2026 | 86 commits, 296 issues, 68 pull requests, lessons and retrospectives, telemetry that reversed a design decision, 11 self-hosted backlog items | Overstated front page, an undetected regression, no CI, owner-specific configuration, private references and synthetic outputs in the tree |

Constraints that shaped the choice:

- **Reader.** A reviewer decides in about two minutes. Every extra repository on the path costs attention.
- **History.** GitHub keeps a read-only `refs/pull/<n>/head` ref for every pull request, so rewriting history and force-pushing would not remove earlier content from a repository published in place.
- **Currency.** Most mechanisms built by hand in March now ship as platform features ([state-of-practice research](../1-discovery/2026-11-20-state-of-practice-research.md)), so the value to publish is the operating model and the evidence, not the orchestrator code.
- **Maintained successors.** The method is maintained in [agentic-toolkit](https://github.com/carlosboeing/agentic-toolkit) and [crossrev](https://github.com/carlosboeing/crossrev); a new repository should not compete with them.

## Options considered

| Option | Shape | Two-minute read | Evidence kept | Cost |
|---|---|---|---|---|
| 1. Both public | Reference design and implementation as two cross-linked repositories | Weak: two stops, the first a design that never ran | Full | Medium; every design page needs a historical banner |
| 2. Merge into this repository (chosen) | Reference design imported under `blueprint/` with its commits; one README tells design, build, measure, revise | Strong: one stop, the design reads as the prelude to a real build | Full: commits, branches, issues, pull requests | Medium |
| 3. New front-door repository | A fresh repository presenting a modern workflow and linking both old ones as evidence | Strong front door, but three repositories plus the toolkit | Full but spread out | High; a polished repository with no history invites skepticism and duplicates the toolkit |
| 4. Curated release only | Selected sanitized diffs and records in a fresh repository; both originals stay private | Strong front door | Partial: claims cannot be checked against raw commits, issues and pull requests | High |

## Decision

Option 2. The reference design is imported under [`blueprint/`](../../blueprint/README.md) with its history preserved and marked historical and unexecuted. This repository becomes the single public repository for the work.

- **History is kept as it is.** Commits, branches and pull-request refs written before November 2026 are not rewritten.
- **The published tree is cleaned.** Private references, owner-specific configuration, synthetic workload outputs and their per-run designs and plans are removed from the current tree. They remain reachable in history.
- **The origin is told generically** as engineering practice from large teams applied to coding agents.
- **The original reference-design repository stays private and archived.**
- **The March implementation is repaired, not extended:** green tests, CI, a safe first run and honest framing. New work goes through the [real-task evaluation](../3-plans/2026-11-20-real-task-backlog-plan.md).

## Consequences

| Consequence | Effect |
|---|---|
| One front door | The README carries the thesis, the gates, two lead case studies and the November 2026 revision |
| Full, checkable history | Readers can verify claims against commits, issues and pull requests, including the failures |
| Historical material in history | Synthetic outputs and earlier wording stay reachable through Git history and pull-request refs; the current tree does not show them |
| Two time frames | March 2026 records are labelled historical; current judgement lives in the [architecture](../architecture.md#november-2026-revision), the README and the evergreen docs |
| A March orchestrator at the center | Mitigated by the November 2026 revision and by naming the maintained successors |
| Remaining human gates | The visibility change, branch protection and a review of issue comments before publication are maintainer actions outside this decision's files |
