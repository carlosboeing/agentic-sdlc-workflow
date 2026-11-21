---
title: "Case studies: failures and the mechanisms they changed"
type: reference
authors: ["Carlos Boeing", "claude-opus-5-5 (claude-code)"]
last_reviewed: 2026-11-21
---

# Case studies: failures and the mechanisms they changed

Seven failures from the March 2026 runs and the November 2026 release work, each in the same form: what failed, how it was diagnosed, which mechanism changed, what happened later, and where the evidence is. They are the main reason this repository is worth reading: each one shows a design decision meeting a real run.

## How to read the numbers

- **Workloads.** "Synthetic" means a controlled prose workload (themed documents with word counts and cross-references) built to drive orchestration paths such as parallel waves, fix cycles and board updates. "Infrastructure" means a backlog item that changed the workflow's own scripts or runtime service. The two are reported separately and never pooled.
- **Runs.** Runs 1 to 7 took place before the workflow moved into this repository. Their lessons are here; their issues are not. Run numbers after that refer to backlog issues in this repository, listed in the [CHANGELOG](CHANGELOG.md).
- **Samples.** Every number below is "observed in these runs", with its sample size where the source states one. None is a benchmark.
- **Cost.** Cost figures are estimated API-equivalent value: tokens times a blended rate at March 2026 prices, excluding prompt caching and the orchestrator's own tokens.
- **Commits.** Short SHAs refer to this repository's history. Squash-merged backlog PRs keep their per-story commits on GitHub as `refs/pull/<n>/head`.

| # | Case | Workload | Changed |
|---|---|---|---|
| 1 | [A cost-saving hypothesis that telemetry disproved](#1-a-cost-saving-hypothesis-that-telemetry-disproved) | Synthetic | Reviewer routing removed |
| 2 | [A retrospective commit that reverted reviewed code](#2-a-retrospective-commit-that-reverted-reviewed-code) | Infrastructure | CI, retro scope guard, post-retro test run |
| 3 | [Parallel builders collided, then isolation tightened in four steps](#3-parallel-builders-collided-then-isolation-tightened-in-four-steps) | Both | Worktree per dispatch, branches from a recorded base |
| 4 | [Board status drift traced to a GitHub automation](#4-board-status-drift-traced-to-a-github-automation) | Both | PR-body convention, board reconciliation script |
| 5 | [A wall-clock bug that produced the determinism-first rule](#5-a-wall-clock-bug-that-produced-the-determinism-first-rule) | Synthetic | Telemetry computed by tested code |
| 6 | [A design invalidated by a platform limit](#6-a-design-invalidated-by-a-platform-limit) | Infrastructure | Mandatory feasibility check against current docs |
| 7 | [A 67 percent fix-cycle rate from an untested startup path](#7-a-67-percent-fix-cycle-rate-from-an-untested-startup-path) | Infrastructure | Startup-wiring integration tests |

## 1. A cost-saving hypothesis that telemetry disproved

| Step | What happened |
|---|---|
| Failure | Backlog item 105 routed reviews of easy stories from Opus to the cheaper Sonnet, expecting to cut review cost by 15 to 20 percent. The expectation assumed Sonnet would use about the same number of tokens at a lower rate. |
| Diagnosis | A telemetry analysis across 14 backlog items (8 synthetic runs and 6 infrastructure items; the analysis itself grouped item 150 with the synthetic runs) compared reviewers on easy synthetic stories. 4 Sonnet reviews in Run 16 averaged 57K tokens and 2m 20s. 15 Opus reviews across Runs 8 to 14 averaged 28K tokens and 1m 10s. Throughput per token was the same; Sonnet produced more analysis before its verdict. Neither set triggered a fix cycle. The analysis states its method: tokens and duration are primary, cost is derived and "never the basis for a conclusion". |
| Mechanism change | Commit `d6e8799` deleted the two reviewer variant files, the `reviewerRouting` config and its dispatch logic, leaving one `reviewer` agent. The same commit reversed an earlier Run 12 cost "correction" ($4.77 to $12.55) that the analysis had shown used a wrong rate. The cost goal was pursued instead by skipping per-story review of easy stories while keeping the PR-level review (backlog item 243). |
| Later outcome | Tiered review ran in Runs 15 and 17. The skip saved an estimated $2 per run, an estimate from two synthetic runs. |
| Scope | Small samples from different runs, prose workloads and March 2026 models. On infrastructure stories (about 18 Sonnet and 25 Opus reviews) Sonnet used fewer tokens (51K against 65K), so the finding is specific to the workload. Zero fix cycles measures neither missed defects nor review quality. |
| Evidence | [Workflow optimization analysis, sections 4 and 5](1-discovery/2026-03-19-workflow-optimization-analysis.md); commit `d6e8799`; [ADR 0002](6-adrs/0002-agentic-sdlc-builder-agent-model-routing.md) for the builder routing that stayed |

## 2. A retrospective commit that reverted reviewed code

| Step | What happened |
|---|---|
| Failure | Backlog item 116 built the runtime service: 6 epics, 18 stories. To save time, the PR reviewer and the retrospective ran in parallel, each in its own worktree (commit `cd2e0b6`). The retro commit `4d3ab9b`, labelled `docs(retro)`, landed 55 seconds after a PR-review fix (`4634d58`). Besides the two retro documents it changed 37 files (161 lines added, 859 removed) and reverted that fix and earlier work: the document API schema and route, frontend type fixes, the `pm.sh` server fallback, part of the startup-wiring test and the item's CHANGELOG entry. The PR reviewer had read an earlier snapshot. The repository had no CI. The squash merge carried the revert to `main`, and later backlog item 364 built on top of it. |
| Diagnosis | Found in November 2026 during the pre-release assessment. Running the server suite from a clean `git archive` export gave 623 of 635 tests passing, 12 failing and 2 files unable to load. Diffing the commits on the pull request's head ref against their parents isolated `4d3ab9b`. The inferred mechanism, not proven: the retro worktree committed a stale snapshot of the tree on top of the advancing integration branch. The written rule "the retro only adds docs" was an instruction with no check behind it, and the agents had no tool restrictions since commit `3dcfad7`. |
| Mechanism change | `72f7476` restored the reverted code and reconciled it with backlog item 364. `ab3d57e` added CI: server, telemetry and offline shell jobs behind one `required` gate. `b5a4212` added [`check-retro-scope.sh`](../scripts/check-retro-scope.sh), which fails any `docs(retro)` commit that touches paths outside `docs/`, `CLAUDE.md` and `.claude/agents/` (since November 21, 2026 also `docs(conventions)` commits, the retro agent's other subject); CI runs it on every push and pull request, and the orchestrator now runs it plus the full test suite after the retro and halts if either fails. |
| Later outcome | Server 681 of 681, telemetry 252 of 252 and offline shell 36 of 36 pass on the release branch. No workflow run has executed since the controls landed, so they are tested by their own unit tests only. |
| Remaining gap | The guard keys on the commit subject, so a code-changing commit with another subject passes it; CI catches that only if a test fails. A check that a retro commit's parent is the current head of the integration branch is item A03 of the [real-task backlog](3-plans/2026-11-20-real-task-backlog-plan.md). |
| Evidence | Commits `cd2e0b6`, `4634d58`, `4d3ab9b`, `72f7476`, `ab3d57e`, `b5a4212`; [pull request #362](https://github.com/carlosboeing/agentic-sdlc-workflow/pull/362); [CI workflow](../.github/workflows/ci.yml); [public release assessment](4-reviews/2026-11-20-public-release-assessment.md) |

## 3. Parallel builders collided, then isolation tightened in four steps

| Step | What happened |
|---|---|
| Failure | Parallel builders shared one working directory. Run 4 flagged the risk. In Run 7, three parallel builders checked out different branches in the same directory and one story's file was committed on another story's branch; that run had 3 fix cycles and 40 percent first-pass approval. Later forms: in Run 9 a story branch started from a sibling story's head instead of the epic base; in Run 14 a stale worktree file leaked into a fix-cycle commit; in backlog item 105 checkouts collided with another backlog item's branches and a commit landed on the wrong branch. |
| Diagnosis | Each failure had a different trigger with one cause: agents sharing mutable git state, either the working tree, a lazily chosen branch base or leftover files. |
| Mechanism change | Four steps, each from a recorded run: a git worktree for every parallel builder (Run 8, `8939c97`); all epic and story branches created up front from one base commit recorded in the state file (Run 9, `c7d2eda`); cleanup of worktree debris before merges and fix cycles (Run 14); a worktree for every dispatch in autonomous mode, first exercised in Run 15 (`6a27e97`). Git operations in parallel work run as one chained command with explicit `git add` paths. |
| Later outcome | Run 8 recorded no collision across 3 parallel builders. Backlog item 116 ran 66 dispatches (designer, planner, 32 builder and 32 reviewer dispatches, as its retrospective counts them) with no branch contamination (one run). The class kept recurring in new forms: a worktree-isolated planner wrote local work items into its ephemeral worktree (Run 15), file paths were confused between worktree and main checkout (backlog items 105 and 111), and the orchestrator itself still shares the main checkout (issue #149). By November 2026, Claude Code provides worktree isolation, base-ref selection and automatic sweeps natively; the base-commit and merge-ordering rules are still needed. |
| Evidence | Lessons [Run 4](4-reviews/lessons/synthetic-workloads/2026-03-10-run04/e01-epic-1/2026-03-10-s00-parallel-dispatch-no-worktree-isolation.md), [Run 7](4-reviews/lessons/synthetic-workloads/2026-03-11-run07/e01-epic-1/2026-03-11-s00-parallel-workspace-collision.md), [Run 14](4-reviews/lessons/synthetic-workloads/2026-03-15-run14/e01-epic-1/2026-03-15-s04-fix-cycle-worktree-contamination.md), [Run 15](4-reviews/lessons/synthetic-workloads/2026-03-20-run15/e00-setup/2026-03-20-s00-worktree-pm-isolation.md), [backlog item 111](4-reviews/lessons/111-local-first-pm/e03-composition-integration/2026-03-18-s03-worktree-path-confusion.md); [CLAUDE.md](../CLAUDE.md) "In-session dispatch" and "Post-worktree cleanup" |

## 4. Board status drift traced to a GitHub automation

| Step | What happened |
|---|---|
| Failure | Across Runs 3 to 16, issues on the Projects board moved back from Done to In Progress after the orchestrator had set them. It looked like an unreliable API. |
| Diagnosis | Run 11 added a diagnostic script that sets a status and re-reads it after 10 and 30 seconds (`8d08407`). Run 16 found the root cause: GitHub's built-in "Pull request linked to issue" project automation fires when the backlog PR body uses `Closes #N`, including for issues that were already closed, and moves them back. |
| Mechanism change | `Closes` is used only for open issues; already-closed design, plan and retro issues are listed as "Related (already closed)". A [reconciliation script](../scripts/reconcile-board.sh) computes the expected status of every issue from the state file and fixes differences after the PR opens and at phase boundaries (`8da9c87`). |
| Later outcome | Backlog item 116 recorded no board drift over 66 dispatches (one run). Drift was not measured systematically after the fix. Since November 2026 the board is optional and board operations are skipped when none is configured. |
| Evidence | [Retro recommendations tracker](4-reviews/retro-recommendations.md), observation iv; [CLAUDE.md](../CLAUDE.md) "Link all issues to the PR"; [`check-board-drift.sh`](../scripts/check-board-drift.sh); [Run 11 lesson](4-reviews/lessons/synthetic-workloads/2026-03-14-run11-board-drift-detection/e00-setup/2026-03-14-s00-board-item-add-no-default-status.md) |

## 5. A wall-clock bug that produced the determinism-first rule

| Step | What happened |
|---|---|
| Failure | Run 14 posted a wall-clock duration of 102m 43s, equal to the sequential sum of its 36 dispatches; the critical path through its parallel waves was 74m 4s. The orchestrator had tracked time with a shell timer that reset across subshells. A human caught it in review before merge. Separately, Run 12's cost had been "corrected" from $4.77 to $12.55 with a rate recalled from memory, which a later cross-run check showed was wrong. |
| Diagnosis | The state file already held every dispatch's start time and duration. The agent was asked to remember or estimate values that a script could derive. |
| Mechanism change | The "Determinism First" rule in [CLAUDE.md](../CLAUDE.md): when a value can be computed from recorded data, compute it. Wall-clock is computed from dispatch start times, taking the maximum within a parallel group and summing across groups. Telemetry moved into [`compute-dispatches.py`](../scripts/lib/compute-dispatches.py) with tests (backlog item 106, `c9e67aa`), run state into `state.sh` with a JSON schema (backlog item 150, `e76b494`), and prices into a live fetch with a blended-rate rule (Run 13). |
| Later outcome | The telemetry module has 252 offline tests, which run in CI. A multi-pass review experiment in backlog item 106 pointed the same way: two orchestrator passes that judged review findings had 40 and 67 percent error rates and dismissed the same valid finding twice, while a pass that computed its answer had none (one experiment). |
| Remaining gap | The rule covers computation, not control flow: phase order, wave dispatch and halts still depend on the orchestrator following its prompt. |
| Evidence | [Run 14 lesson](4-reviews/lessons/synthetic-workloads/2026-03-15-run14/e00-setup/2026-03-15-s00-wall-clock-equals-sequential.md); [Run 12 lesson](4-reviews/lessons/synthetic-workloads/2026-03-15-run12/e00-setup/2026-03-15-s00-telemetry-cost-underreporting.md); [multi-pass review research](1-discovery/2026-03-16-multi-pass-review-research.md); commits `c9e67aa`, `e76b494`, `d6e8799` |

## 6. A design invalidated by a platform limit

| Step | What happened |
|---|---|
| Failure | The first design for backlog item 243 (phase restructuring) had builders dispatch their own reviewers, and an ADR recorded it as accepted. In March 2026 a Claude Code subagent could not start another subagent, so the design could not run. Two dispatch cycles, about 20 minutes and 260K tokens, went into it before the limit surfaced. |
| Diagnosis | The designer reasoned from what it believed about the platform and treated the absence of a documented limit as permission. The same pattern showed elsewhere: for 14 runs the telemetry used 3 of about 10 fields the Agent tool returned. |
| Mechanism change | The first design was abandoned ([pull request #264](https://github.com/carlosboeing/agentic-sdlc-workflow/pull/264) closed) and a second one runs reviews in parallel from the orchestrator (`1ba2459`). The designer must now check every platform capability it relies on against current documentation and record the check. Explicit tool lists were removed from the agents so that every role could search the web (`3dcfad7`). |
| Later outcome | By November 2026 subagents nest up to three levels by default, so the first design is now feasible. Applying the same research-first rule to this repository's own list of platform limitations showed that three of its five entries no longer hold and the other two could not be confirmed ([architecture](architecture.md#known-platform-limitations-then-and-now)). Removing the tool lists also removed a guard: it is part of why a retrospective agent could change code in case 2. |
| Evidence | Lessons [research first](4-reviews/lessons/2026-03-19-phase-restructuring/e00-setup/2026-03-19-s00-research-first-not-assume-first.md), [nesting limit](4-reviews/lessons/2026-03-19-phase-restructuring/e00-setup/2026-03-19-s00-subagent-nesting-hard-cap.md), [never skip design](4-reviews/lessons/2026-03-19-phase-restructuring/e00-setup/2026-03-19-s00-never-skip-design-for-complex-work.md); [phase restructuring design](2-design/2026-03-19-phase-restructuring.md) |

## 7. A 67 percent fix-cycle rate from an untested startup path

| Step | What happened |
|---|---|
| Failure | In backlog item 116, 12 of 18 stories needed fix cycles, against a tracked average of about 11 percent across more than 100 earlier stories. The daemon started with only its health route: the startup path never created a database or passed it to the application factory. |
| Diagnosis | Unit tests injected the database straight into the factory, so they bypassed the production startup sequence. Each story passed its tests; the wiring between them had none. Fix cycles cost an estimated $17.45 of the item's roughly $50 (35 percent). |
| Mechanism change | Startup-wiring integration tests that start the server the way the daemon does and call live endpoints ([`startup-wiring.test.ts`](../server/tests/api/startup-wiring.test.ts)); tracker recommendation AR adds the convention to builder instructions for server stories. |
| Later outcome | Backlog item 364 had 1 fix cycle in 5 stories (one run, small sample). Part of the wiring test was later deleted by the retro commit in case 2 and restored in `72f7476`. |
| Evidence | [Lesson](4-reviews/lessons/116-workflow-runtime-service/e02-item-routes/2026-03-22-s01-startup-wiring-di-blindspot.md); [speed and quality analysis](1-discovery/2026-03-23-workflow-speed-quality-architecture.md); [retro recommendations tracker](4-reviews/retro-recommendations.md), recommendation AR and observation xxviii; [backlog item 116 retrospective](4-reviews/lessons/116-workflow-runtime-service/2026-03-22-workflow-runtime-service-retro.md) |

## What the cases have in common

| Pattern | Cases |
|---|---|
| A rule stated as an instruction failed until code checked it | 2, 3, 5 |
| Measurement overturned an expectation | 1, 5, 7 |
| A platform fact assumed rather than checked | 6, and the stale limitations it later exposed |
| The fix moved state or computation out of the model's memory | 3, 4, 5 |
| A fix introduced the next failure | Removing tool lists (6) enabled case 2; parallel review and retro saved time and caused case 2 |
