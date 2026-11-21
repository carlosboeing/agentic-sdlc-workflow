---
title: "Agentic SDLC Pipeline — Critical Workflow Analysis"
type: analysis
status: resolved
authors: ["Carlos Boeing"]
date: 2026-03-14
agent: general
scope: Critical workflow analysis of the agentic SDLC pipeline — system-level audit across correctness, robustness, innovation, and work item taxonomy
---

# Agentic SDLC Pipeline — Critical Workflow Analysis

> Historical record (March 2026). Measurements come from controlled synthetic workloads and early infrastructure runs; see [case studies](../case-studies.md) for scoped findings.

## Executive Summary

This document presents a system-level analysis of the agentic SDLC pipeline after 11 autonomous runs. It examines the workflow across three axes — **correctness & consistency**, **robustness**, and **innovation & leverage** — then extends into a deep analysis of the **work item taxonomy** and its coupling throughout the system. The analysis reads every agent file, every script, the telemetry template, CLAUDE.md, the recommendations tracker, and the last 3 retro docs as primary sources.

**Key findings:**

- The pipeline is remarkably stable: 17 consecutive first-pass approvals across Runs 9–11, zero fix cycles, and consistent cost profiles (~$3–6 per run).
- However, the three-level work item hierarchy (backlog > epic > story) is **deeply coupled** into 15+ files across branch naming, labels, issue titles, sub-issue linking, telemetry aggregation, dispatch protocol, and state persistence — making it resistant to change.
- Two CLI scripts (`dispatch-workflow.sh` and `dispatch-story.sh`) implement the **v1 workflow** and would produce incorrect branch structure if used today.
- The orchestrator's phase numbering has a **sequencing paradox** where Phase 9 (post-merge cleanup) is numbered before Phases 10–11 (retro and telemetry), but must execute after them.
- There are actionable quick wins (5–10 minutes each) that would eliminate known failure modes.

---

## Current Capabilities

This section documents what the agentic SDLC workflow can do today, as validated across 11 autonomous runs.

### Agents

Six specialized agents in `.claude/agents/`, each with strict phase boundaries that prevent scope creep:

| Agent | Role | Model | Writes To |
|-------|------|-------|-----------|
| **Designer** | Brainstorms features, evaluates feasibility, writes design docs. Supports autonomous mode (derives requirements from backlog issue) and interactive mode (asks clarifying questions via brainstorming skill). | Inherited (opus) | `docs/2-design/` |
| **Planner** | Decomposes approved designs into epics and stories with difficulty labels, dependency graphs, and wave-based dispatch plans. Creates all GitHub Issues and configures the project board. | Inherited (opus) | `docs/3-plans/`, `docs/6-adrs/`, GitHub Issues |
| **Builder** | Implements stories using strict TDD (tests first, then implementation). Three model-routed variants: `builder-haiku` (easy), `builder-sonnet` (medium), `builder-opus` (hard). | Haiku / Sonnet / Opus | Production code and tests |
| **Reviewer** | Reviews code against a convention checklist (tool system, data, config, quality, testing, security, architecture). Posts structured findings with severity levels and a verdict (APPROVE / REQUEST_CHANGES / COMMENT). | Inherited (opus) | Review comments on issues/PRs |
| **Orchestrator** | Drives the full lifecycle from backlog issue to merged PR. Dispatches all other agents, manages GitHub state (board, issues, branches, PRs), posts telemetry, and handles error recovery. | Inherited (opus) | GitHub state only |
| **Retro** | Synthesizes lessons, telemetry, and review findings into a retrospective document. Proposes convention changes backed by evidence from multiple stories. | Inherited (opus) | `docs/4-reviews/`, convention changes |

### Workflow Lifecycle (12 Phases)

The orchestrator executes these phases in sequence for each backlog item:

```
Phase 0:  Detect mode, create integration branch, check for existing artifacts
Phase 1:  Design (conditional) — dispatch designer, auto-merge PR
Phase 2:  Plan (conditional) — dispatch planner, auto-merge PR, set stories to Todo
Phase 3:  Read the plan — extract epics, stories, dependency graph
Phase 4:  Build dependency graph — identify parallel waves, create story branches
Phase 5:  Dispatch builders — model-routed, parallel via worktree isolation
Phase 6:  Review stories — mandatory per-story review, fix cycles if needed
Phase 7:  Merge story branches — story→epic→integration, with branch cleanup
Phase 8:  Open backlog PR — single PR to main with Closes list for all issues
Phase 9:  Post-merge cleanup — stale branches, worktrees, state directories
Phase 10: Dispatch retro — retrospective doc + convention change proposals
Phase 11: Backlog-level telemetry — full lifecycle summary on issue + PR
```

### Dispatch & Parallelism

- **Model routing:** Stories are labeled `difficulty/easy`, `difficulty/medium`, or `difficulty/hard` by the planner. The orchestrator maps these to `builder-haiku`, `builder-sonnet`, or `builder-opus` respectively.
- **Parallel dispatch:** Independent stories (no shared dependencies in the plan's Mermaid graph) are dispatched simultaneously using the Agent tool with `isolation: "worktree"`. Each parallel builder gets an isolated copy of the repository. Validated up to 3-way parallelism (Run 11 Wave 3).
- **Wave-based execution:** Stories are grouped into waves based on the dependency graph. All stories in a wave dispatch in parallel; waves execute sequentially. Story branches are created from a recorded epic base commit before each wave to prevent cross-contamination.

### Branch Strategy

```
main
└── backlog/<N>-<slug>          ← integration branch (ONE PR to main)
    ├── (design doc committed)
    ├── (plan committed)
    ├── epic/eNN-slug           ← epic branch (off integration branch)
    │   └── eNN-sNN/slug        ← story branch (off epic branch)
    └── (retro, changelog, lessons committed after stories complete)
```

- One PR per backlog item (squash merge to main).
- Design/plan docs committed on `docs/<slug>` branches targeting the integration branch.
- Epic branches merge into the integration branch using `--no-ff`.
- Story branches are deleted after merging into their epic; epic branches after merging into integration.

### GitHub Integration

- **Project board management:** All issues tracked on a GitHub Project board with 6 statuses (Backlog → Planned → Todo → In Progress → In Review → Done). Board transitions are serialized — the GitHub Projects API does not handle concurrent updates reliably.
- **Sub-issue hierarchy:** Three-level nesting via GitHub's `addSubIssue` API (backlog → epic → story). Design/plan/retro issues also linked as sub-issues of the backlog item.
- **Label system:** Hierarchy labels (`hierarchy/backlog`, `hierarchy/epic`, `hierarchy/story`), backlog grouping labels (`backlog/<N>-<slug>`), type labels, and difficulty labels.
- **Issue naming:** `[#<backlog>/ENN] Epic title` for epics, `[#<backlog>/ENN-SNN] Story title` for stories.
- **Sentinel:** GitHub Actions workflow runs AI-powered security review on all PRs to `main`.

### Telemetry

- **Per-story:** Posted as issue comments by the orchestrator after each builder completes. Includes model, duration, tokens, speed, estimated cost, and tool uses.
- **Per-epic:** Aggregate of story metrics with wall-clock duration (accounting for parallelism), posted on the epic issue.
- **Backlog-level (full lifecycle):** Summary table (all phases), per-dispatch breakdown, duration with parallelism metrics, Mermaid Gantt timeline, and cost disclaimer. Appended to the backlog PR description.
- **Rendering:** All telemetry is rendered from `scripts/templates/telemetry.md` — a single source of truth with conditional blocks for different telemetry modes.
- **Pricing:** Live rates fetched from Anthropic's pricing page at session start via `scripts/fetch-pricing.sh`, with hardcoded fallbacks.

### State Persistence & Recovery

- **Orchestrator state file:** `.claude/state/<backlog>/orchestrator.json` (gitignored) captures session metadata, pricing, phase progress, epic/story status, and an append-only dispatch log. Enables instant recovery on session interruption without re-querying GitHub.
- **Idempotent restart:** The orchestrator can be re-run on a partially completed backlog item. It checks for existing "Ready for Review" comments, merged branches, and existing artifacts to skip completed work.
- **Fallback:** If the state file is missing (different machine, manual deletion), the orchestrator queries GitHub for issue state and branch status.

### Error Handling

- **Builder failure:** Retry up to 2 times, then halt with a failure comment on the issue. Telemetry is captured even from failed dispatches.
- **Review rejection:** Re-dispatch builder to fix on the same branch, then re-review. Maximum 2 fix cycles before requesting human intervention.
- **Resumed agents:** When an agent is interrupted and resumed, metrics from both invocations are summed defensively.
- **Board drift:** `item-set-status.sh` includes post-mutation verification with retry. `check-board-drift.sh` provides timed re-verification diagnostics (+10s, +30s).
- **Rate limits:** Per-issue GraphQL queries (~1 point each) replaced heavy `item-list` queries (~200+ points) after Run 10.

### Lesson System

- **Write-on-discovery:** All agents write lesson files immediately when encountering bugs, unexpected behavior, or missing conventions.
- **File format:** YAML frontmatter (date, author, story, tags, severity) + What Happened / Root Cause / Prevention sections.
- **Folder structure:** `docs/4-reviews/lessons/<backlog>-<slug>/eNN-<epic-slug>/YYYY-MM-DD-sNN-<slug>.md`
- **Three-tier retention:** Active (current epic, agents grep freely) → Compiled (retro doc is primary reference) → Archived (3–5 epics later, moved to `archive/`).
- **Cross-cutting discovery:** Tag-based grep enables finding lessons by role (`tags:.*builder`, `tags:.*orchestrator`, etc.).
- **Recommendations tracker:** `docs/4-reviews/retro-recommendations.md` consolidates all retro recommendations with status (Outstanding / Implemented / Observation).

### Self-Documentation

All agents are instructed to update CLAUDE.md and their own agent files when they discover undocumented conventions, incorrect instructions, or commands that need unexpected flags. Changes are committed alongside implementation work, not deferred.

### Helper Scripts

| Script | Purpose |
|--------|---------|
| `item-create.sh` | Create backlog item with full board setup (issue + board + status + label) |
| `item-set-status.sh` | Set project board status with per-issue GraphQL, retry, and verification |
| `item-start.sh` | Post "Work Started" comment + set board to In Progress |
| `item-review.sh` | Post "Ready for Review" comment + set board to In Review |
| `item-telemetry.sh` | Post telemetry (story, epic, or backlog level) from template |
| `item-close.sh` | Close issue + set board to Done |
| `cleanup-post-merge.sh` | Remove stale branches, worktrees, state directories |
| `check-board-drift.sh` | Diagnostic: set status, re-verify at +10s and +30s |
| `validate-logs.sh` | Report on board-status, orchestrator, and drift logs |
| `setup-labels.sh` | Create all labels (idempotent) |
| `fetch-pricing.sh` | Fetch current Anthropic API token pricing |
| `dispatch-story.sh` | CLI dispatch for standalone terminal use (v1, partially stale) |
| `dispatch-workflow.sh` | Full lifecycle CLI dispatch (v1, fully stale) |

### Operational Profile (from 11 Runs)

| Metric | Value |
|--------|-------|
| Total autonomous runs | 11 |
| Consecutive first-pass approvals (Runs 9–11) | 17 |
| Typical run duration | 29–61 minutes (design through retro) |
| Typical run cost (subagent dispatches only) | ~$2.50–$5.60 |
| Typical stories per run | 5–6 |
| Dispatches per run | 12–14 (1 designer, 1 planner, N builders, N reviewers) |
| Max validated parallelism | 3-way (Run 11 Wave 3) |
| Orchestrator overhead | 28–51% of wall-clock time |
| Haiku token consumption vs sonnet | 3–4x more tokens at comparable cost |
| Fix cycles (Runs 9–11) | 0 |

### Design Evolution Timeline

The workflow has evolved through 7 design iterations and 11 autonomous test runs:

| Date | Document | Key Contribution |
|------|----------|-----------------|
| 2026-03-08 | [v1 Design](../2-design/2026-03-08-agentic-sdlc-design.md) | Established the blueprint: 4 agents (designer, planner, builder, reviewer), GitHub Issues as source of truth, difficulty-based model routing, helper scripts for telemetry. **Manual human orchestration.** |
| 2026-03-08 | [v1 Plan](../3-plans/2026-03-08-agentic-sdlc-plan.md) | 14-task implementation: numbered docs directories, helper scripts, agent definitions, CLAUDE.md workflow section, Sentinel update. |
| 2026-03-09 | [v2 Design](../2-design/2026-03-09-agentic-sdlc-v2-design.md) | Replaced the human orchestrator with a Claude Code agent. Added the retro agent (self-improvement loop). Introduced lesson system, self-documentation, per-story review, parallel dispatch via worktrees. Key insight: *"agents don't need to return data to the orchestrator — work products persist in the repo and on GitHub."* |
| 2026-03-09 | [v2 Plan](../3-plans/2026-03-09-agentic-sdlc-v2-plan.md) | 10-story implementation across 2 epics: dispatch scripts + lesson conventions (E01), orchestrator + retro agents (E02). |
| 2026-03-10 | [GitHub Issue Categorization](../2-design/2026-03-10-agentic-sdlc-github-issue-categorization-design.md) | Introduced `hierarchy/*` labels for level identification. Retired per-epic `epic/*` labels. Defined the three-level hierarchy with cross-tool mapping, decomposition rules, and status flow. |
| 2026-03-10 | [Issue Templates](../2-design/2026-03-10-agentic-sdlc-issue-templates-design.md) | Standardized issue structure across all three levels. Backlog = "the brief" (Overview, Requirements, Context), Epic = "organizational glue" (story table, AC), Story = "the micro-spec" (self-contained Design + AC). Key principle: *"design detail lives in the design doc, execution detail lives in the story, epics are just folders."* |
| 2026-03-10 | [Plugin Architecture](../2-design/2026-03-10-agentic-sdlc-plugin-architecture.md) | Defined MCP tool interfaces for `project-board`, `code-hosting`, and `docs-platform`. Proposed a layered architecture where agents call generic MCP tools, and provider MCP servers (GitHub, Linear, Jira, Azure DevOps) implement them. Mix-and-match providers (e.g., Jira + GitHub + Confluence). |
| 2026-03-10 | Self-Orchestration Plan | Designed the host project as a thin relay over the orchestrator — host-specific C# dispatch tools for subprocess management, workflow persistence, and progress relay. 3 epics, 9 stories. |
| 2026-03-11 | [Work Item Taxonomy](../2-design/2026-03-11-agentic-sdlc-workitem-taxonomy.md) | Comprehensive research across 9 PM tools and 4 methodologies. **Decision: Goal > Epic > Task.** "Goal" replaces "Backlog Item" (universal, cross-domain), "Task" replaces "Story" (domain-neutral, template-driven richness). Not yet implemented in the codebase. |
| 2026-03-11 | [Extraction Design](../2-design/2026-03-11-agentic-sdlc-extraction-design.md) | Master plan for extracting the workflow into a standalone package. Defined PM Adapter and Doc Adapter interfaces. Proposed local-first storage (`.sdlc/` folder with YAML frontmatter), ephemeral dashboard, CLI entry point (`sdlc <command>`), and 5-phase migration path. |
| 2026-03-13 | Orchestrator Logging | Two-layer diagnostic logging: board status script logging (post-mutation verification) and orchestrator workflow logging via Claude Code hooks. Implemented and merged. |
| 2026-03-14 | Board Drift Detection | Diagnostic script (`check-board-drift.sh`) for investigating board status persistence bug. Timed re-verification at +10s and +30s intervals. Implemented in Run 11. |

### Planned but Not Yet Implemented

Several design docs describe capabilities that are designed but not yet built:

**1. Work Item Taxonomy Rename (Goal > Epic > Task)**

The [taxonomy design doc](../2-design/2026-03-11-agentic-sdlc-workitem-taxonomy.md) proposes renaming the hierarchy from `Backlog Item > Epic > Story` to `Goal > Epic > Task`. The rationale: "Goal" is universally understood across domains (engineering, marketing, product), "Task" is domain-neutral and its richness is defined by the template, not the name. This rename was approved but **never propagated** to CLAUDE.md, agent files, scripts, labels, or issue titles. The codebase still uses the v1 terminology everywhere.

**2. Extraction & Plugin Architecture**

The [extraction design](../2-design/2026-03-11-agentic-sdlc-extraction-design.md) and [plugin architecture](../2-design/2026-03-10-agentic-sdlc-plugin-architecture.md) propose:

- **PM Adapter interface** — 12 operations (`pm_create_item`, `pm_set_status`, `pm_post_comment`, etc.) with a local file-based default and GitHub as an opt-in upgrade
- **Doc Adapter interface** — 6 operations for document storage with local filesystem default and Notion/Confluence as opt-in
- **Local PM storage** — `.sdlc/` folder with YAML-frontmatter markdown files, folder-based hierarchy, sequential ID counter, and history files for comments/telemetry
- **Dashboard** — Ephemeral HTTP server serving a self-contained SPA with Kanban board, activity feed, and telemetry summary. Auto-refreshes on file changes. CLI fallback (`sdlc board`) for terminal-only environments
- **CLI entry point** — `sdlc <command>` wrapping all adapter calls
- **Intent-based agent instructions** — Agents say "set status to in_progress" not "`gh project item-edit --project-id <project-id>`"
- **Plugin packaging** — Claude Code plugin with agents, skills, hooks, and MCP servers bundled together

None of these are implemented. The system remains GitHub-coupled with hardcoded `gh` CLI commands in all agent files.

**3. Issue Templates**

The [issue templates design](../2-design/2026-03-10-agentic-sdlc-issue-templates-design.md) defines standardized structures for all three issue levels. Key design decisions:
- Stories are self-contained micro-specs — builders read ONE issue and have everything needed
- Design section on stories scales with difficulty (omitted for easy, expected for hard)
- Epics use tables (not checkboxes) for story lists — shows difficulty and dependencies at a glance
- No `---` separators for planner-appended content — natural continuation of the body

These templates are partially implemented (planners follow the general structure) but not enforced via GitHub Issue Templates (`.github/ISSUE_TEMPLATE/`), and some formatting conventions (e.g., no `---` separator for dependency graphs) are inconsistently followed across runs.

---

## Part I: Workflow System Analysis

### 1. Correctness & Consistency

#### 1.1 Phase Symmetry

Each workflow phase was checked for: tracked GitHub Issue, board status transitions, telemetry capture, inclusion in the `Closes` list, and a defined deliverable.

| Phase | GitHub Issue | Board Transitions | Telemetry | In `Closes` List | Deliverable |
|-------|:-----------:|:-----------------:|:---------:|:-----------------:|:-----------:|
| **Design** | Yes (`type/docs`) | In Progress → Done | Yes (backlog aggregate) | Yes | Design doc + PR |
| **Plan** | Yes (`type/docs`) | In Progress → Done | Yes (backlog aggregate) | Yes | Plan + Issues + PR |
| **Build** | Yes (`hierarchy/story`) | Todo → In Progress → In Review | Yes (per-story) | Yes | Code + tests + commits |
| **Review** | No separate issue | No board tracking | Yes (backlog aggregate) | N/A | Review comments |
| **Retro** | Yes (`type/docs`) | In Progress → Done | Partial | **Gap** (see below) | Retro doc + conventions |

**Gaps found:**

1. **Retro issue not in `Closes` list.** Phase 10 creates the retro issue AFTER Phase 8 opens the backlog PR. The retro issue doesn't exist when the PR is created, so it's missing from the `Closes` clause. No instruction exists to edit the PR body to add it.

2. **Design/plan/retro issues lack per-issue telemetry.** Their metrics appear only in the backlog-level aggregate. Story issues get three comments (Work Started, Ready for Review, Telemetry), but design/plan/retro issues get none of these. This is a visibility gap, not a functional bug.

3. **Review phase has no tracked issue.** This is by design — reviews are sub-steps of each story. But it means review work isn't independently trackable on the board.

#### 1.2 Convention Propagation

**Builder branch diagram omits integration branch.** `builder.md` lines 76–88 show:

```
main
└── epic/eNN-slug              ← epic integration branch (off main)  ← WRONG
    └── eNN-sNN/slug           ← story branch (off epic branch)
```

CLAUDE.md specifies the actual hierarchy: `main → backlog/<N>-<slug> → epic/eNN-slug → eNN-sNN/slug`. The builder's diagram says "off main" for epics, but the convention is "off the integration branch." If a builder ever needed to create an epic branch, it would branch from the wrong place.

**Phase 3 uses stale plan matching pattern.** `orchestrator.md` Phase 3 (line 224) uses `grep -rl "<backlog-issue-number>" docs/3-plans/` — the same raw content grep that was fixed for design docs in Phase 0 after Run 10. Should use `grep -rl "^backlog: <backlog-issue-number>$" docs/3-plans/`.

**Status option IDs exist in 2 places.** CLAUDE.md has the canonical table; `item-set-status.sh` has its own copy (lines 49–57). This is necessary (scripts can't read CLAUDE.md at runtime) but creates a maintenance risk.

**Gantt color tagging rules are correctly duplicated.** CLAUDE.md and `orchestrator.md` both carry the Gantt color table. This is valid — the orchestrator needs them in its own context.

**Pricing fallback rates are inconsistent.** `fetch-pricing.sh` defaults: opus $15/$75 input/output (blended ~$30/M). `item-telemetry.sh` hardcoded rates: opus $5/$25 (blended ~$10/M). These are 3x apart. The web fetch normally provides live rates, so this only matters when both the web fetch fails AND `--rate` isn't passed — but when it does, costs would be reported at 3x the correct value (or 1/3, depending on which is right).

#### 1.3 Script Coverage

| Script | In CLAUDE.md | Referenced by Agents | Status |
|--------|:------------:|:--------------------:|--------|
| `item-create.sh` | Yes | orchestrator | OK |
| `item-set-status.sh` | Yes | designer, planner, builder, orchestrator | OK |
| `item-start.sh` | Yes | builder | OK |
| `item-review.sh` | Yes | builder | OK |
| `item-telemetry.sh` | Yes | orchestrator | OK |
| `item-close.sh` | Yes | orchestrator | OK |
| `cleanup-post-merge.sh` | Yes | orchestrator | OK |
| `check-board-drift.sh` | Yes | **Not referenced by any agent** | Gap |
| `validate-logs.sh` | Yes | **Not referenced by any agent** | Gap |
| `setup-labels.sh` | Yes | Not referenced (initial setup only) | OK |
| `fetch-pricing.sh` | Yes | orchestrator | OK |
| `dispatch-story.sh` | Yes | orchestrator (CLI mode only) | **Stale** |
| `dispatch-workflow.sh` | Yes | orchestrator (CLI mode only) | **Stale** |

**Key issues:**

- `check-board-drift.sh` was built in Run 11 specifically to diagnose board drift, but no agent is instructed to call it.
- `validate-logs.sh` is a diagnostic tool that the retro agent could use during input gathering but doesn't know about.
- Both dispatch scripts are fully stale (see §1.4).

No agent describes manual commands where a script already handles the task — the script coverage is good for the in-session workflow.

#### 1.4 Stale Content

**`dispatch-workflow.sh` implements the v1 workflow.** It creates epic branches from `main` (not the integration branch), opens PRs from epic→main (not integration→main), never creates a `backlog/<N>-<slug>` branch, hardcodes `--model sonnet` for designers/planners (should inherit opus), and has no integration branch concept. This script would produce an incorrect branch structure if used.

**`dispatch-story.sh` tells builders to self-merge.** Line 134: "After completing the story, merge it back into the epic branch (not `main`)." The current convention explicitly prohibits this — builders must NOT merge; the orchestrator merges after review.

**`fetch-pricing.sh` hardcoded fallback rates don't match `item-telemetry.sh`.** See §1.2 above.

**35+ lesson files from Runs 2–6 are candidates for archiving.** By the three-tier retention model, lessons from issues 57, 89, 106, 122, 146, 162 are 6+ runs old. Their learnings are compiled into retro docs and most are implemented as conventions. They should be moved to `lessons/archive/` per the documented retention policy.

---

### 2. Robustness

#### 2.1 Workflow Gaps (End-to-End Trace)

An end-to-end trace of Phases 0–11 identifies these points where the orchestrator must improvise:

**Phase ordering paradox (Phases 8–11).** The numbered sequence is:

| Phase | Name | Happens... |
|-------|------|-----------|
| 8 | Open Backlog PR | Before merge |
| 9 | Post-Merge Cleanup | **After** human merges |
| 10 | Dispatch Retro Agent | Before merge (must be in PR) |
| 11 | Backlog-Level Telemetry | Before merge (appended to PR) |

The actual execution order is 8 → 10 → 11 → *human merges* → 9. But the numbering suggests 8 → 9 → 10 → 11. The orchestrator must know that Phase 9 runs last despite its number. This has worked for 11 runs because the orchestrator is smart enough to infer the correct order, but it's an unnecessary source of ambiguity.

**PR `docs/` head branch matching is fragile.** Phases 1–2 find design/plan PRs with `gh pr list --head "docs/"`. If a designer or planner names their branch differently (e.g., `design/...`), the search fails silently.

**`protected-files` label timing.** Phase 8 creates the PR, THEN checks for sacred files and adds the label. The Sentinel workflow triggers on PR creation. If Sentinel runs before the label is applied, stricter review doesn't activate.

**Retro issue not in PR `Closes` list.** Phase 10 creates the retro issue after Phase 8 opens the PR. No instruction exists to edit the PR body. The retro issue remains open after merge unless manually closed.

**Phase 3 plan matching is stale.** Uses raw `grep` instead of YAML frontmatter matching (same bug that was fixed for design docs in Run 10).

#### 2.2 Error Path Coverage

| Phase | Failure Mode | Documented? | Gap |
|-------|-------------|:-----------:|-----|
| Design | Designer dispatch fails | No | No retry/halt instruction |
| Design | PR merge fails | Yes | Halt + post comment |
| Plan | Planner dispatch fails | No | No retry/halt instruction |
| Plan | PR merge fails | Yes | Halt |
| Build | Builder dispatch fails | Yes | Retry twice, then halt |
| Build | Builder hits usage limit | Yes | Resume via Agent tool |
| Review | Reviewer finds critical issues | Yes | Fix cycle, max 2 rounds |
| Review | Reviewer produces invalid verdict | No | No parsing validation |
| Merge | Merge conflict | **No** | Not documented in orchestrator.md |
| Board | Board update fails | Yes | `item-set-status.sh` retry + verification |
| Board | Rate limit hit | Yes | CLAUDE.md rate limit section |
| Retro | Retro agent fails | Partial | `dispatch-workflow.sh` says "run manually later" but orchestrator.md doesn't address it |
| Telemetry | `item-telemetry.sh` fails | No | No fallback |
| PR | PR creation fails | No | No fallback |
| General | Session interruption | Yes | State file resume |

**Key gaps:** No failure handling for designer/planner dispatch, no merge conflict handling in orchestrator.md, no telemetry script failure fallback.

---

### 3. Innovation & Leverage

#### 3.1 Untapped Capabilities

Given the available tools (Agent tool with worktree isolation, parallel dispatch, GitHub API, telemetry scripts, state persistence):

1. **Self-healing board reconciliation.** `check-board-drift.sh` exists but isn't integrated. The orchestrator could invoke it after every board transition and auto-remediate drift.

2. **Parallel review dispatch.** Run 11 validated 3-way parallel reviews, but `orchestrator.md` doesn't document this as a supported pattern. Reviews after a parallel build wave could be dispatched in parallel too.

3. **Pre-computed dependency graphs.** The planner outputs Mermaid diagrams that the orchestrator must parse. A machine-readable JSON dependency graph alongside the Mermaid would eliminate parsing ambiguity.

4. **Predictive story sizing.** 11 runs of telemetry data could estimate story durations based on difficulty label and story characteristics, enabling better wave scheduling.

5. **Quality gates between phases.** No automated check exists to verify that the plan covers all design requirements, or that built stories cover all plan items. A dedicated validation step could catch drift earlier.

#### 3.2 Friction Points (from Retros and Lessons)

| Friction Point | Source | Impact | Potential Fix |
|---------------|--------|--------|--------------|
| Orchestrator overhead 29–51% of wall-clock | Runs 10–11 | 13–31 min per run | Telemetry aggregation script; reduce inline computation |
| Missing issue comments in parallel waves | Runs 4, 11 | Incomplete audit trail | Post-wave verification script (wave-verify.sh) |
| Haiku 3–4x more tokens than sonnet | Runs 8–11 | Inflated telemetry numbers (cost-neutral) | Observation only — no action needed |
| Changelog is a manual orchestrator step | All runs | Extra orchestrator overhead | Automated changelog generation |
| Retro agent gathers from 6+ sources | All runs | Slow gathering phase | Consolidation script |
| `orchestrator.md` approaching 1000 lines | Run 11 observation | Harder to maintain | Extract reference material to guide doc |

#### 3.3 Missing Agents or Roles

| Proposed Agent | Currently Handled By | Benefit |
|---------------|---------------------|---------|
| **Board reconciler** | Orchestrator inline | Removes ~15 lines of post-wave logic per wave |
| **Telemetry aggregator** (script) | Orchestrator inline | Eliminates manual arithmetic, prevents calculation errors |
| **Changelog writer** | Orchestrator inline | Consistent formatting, reduces orchestrator overhead |

---

## Part II: Work Item Taxonomy Analysis

> **Note:** A [Work Item Taxonomy design doc](../2-design/2026-03-11-agentic-sdlc-workitem-taxonomy.md) was written on 2026-03-11, proposing a rename from `Backlog Item > Epic > Story` to **`Goal > Epic > Task`**. That design was approved but **never implemented** — the codebase still uses the original terminology everywhere. This section audits the coupling that makes that rename (and any structural change) difficult, and proposes a path forward that addresses the user's goals of flexibility, clarity, and cross-tool portability.

### 4. Current Taxonomy: Coupling Audit

The three-level hierarchy (**Backlog Item > Epic > Story**) is not just a naming convention — it's encoded into the system's data model, state machine, and dispatch protocol. An exhaustive audit found coupling in **15 categories across 10+ files**.

#### 4.1 Coupling Heatmap

| Coupling Point | Tightness | Files Affected | Refactoring Effort |
|---------------|-----------|:--------------:|-------------------|
| Branch naming (`backlog/`, `epic/`, `eNN-sNN/`) | Tight | 6 | Medium — define patterns in config |
| Labels (`hierarchy/backlog`, `hierarchy/epic`, `hierarchy/story`) | Very Tight | 5 | Hard — enforces traversal logic |
| Issue title format (`[#N/ENN-SNN]`) | Very Tight | 4 | Hard — regex parsers depend on format |
| Sub-issue linking (3-level `addSubIssue`) | Very Tight | 4 | Very Hard — architectural |
| Epic status aggregation (2-level rollup) | Very Tight | 3 | Hard — needs N-level recursion |
| Telemetry aggregation (STORY vs BACKLOG modes) | Very Tight | 3 | Hard — template + script refactor |
| Dispatch protocol (stories = dispatch units) | Tight | 3 | Hard — wave logic assumes story granularity |
| Orchestrator state schema (epic/story JSON) | Tight | 2 | Medium — schema v2 migration |
| Script parameters (`--epic-branch`, regex filters) | Moderate | 4 | Medium — add optional params |
| Agent instructions ("exactly three levels deep") | Very Tight | 6 | Very Hard — rewrite phase boundaries |
| Plan document structure (epic/story breakdown) | Tight | 3 | Medium — new templates |
| Retro document structure (per-epic folder) | Tight | 2 | Medium — parameterize paths |
| Board status option IDs | Loose | 2 | None needed |
| Cleanup script regex patterns | Tight | 1 | Medium — parameterize patterns |
| Parallel dispatch isolation (story = worktree) | Moderate | 2 | Hard — task-level adds complexity |

#### 4.2 Specific Coupling Points (Exhaustive)

**Branch naming (6 files):**

| File | Pattern | What It Assumes |
|------|---------|----------------|
| CLAUDE.md L77–82 | `backlog/<N>-<slug>` | First-level item number in branch name |
| CLAUDE.md L77–82 | `epic/eNN-slug` | Exactly `e` + 2 digits for second level |
| CLAUDE.md L77–82 | `eNN-sNN/slug` | `e` + 2 digits then `-s` + 2 digits for third level |
| `dispatch-story.sh` L82–91 | Regex: `E[0-9]+-S[0-9]+` | Branch discovery depends on this exact format |
| `dispatch-workflow.sh` L44, L70 | Regex: `epic/\|e[0-9]` | Cleanup logic matches these patterns |
| `cleanup-post-merge.sh` L44, L55, L70 | Regex: `backlog/\|epic/\|e[0-9]\|docs/` | Would fail to clean branches from a new level |

**Labels (5 files):**

| File | Label | Purpose |
|------|-------|---------|
| CLAUDE.md L152–156 | `hierarchy/backlog`, `hierarchy/epic`, `hierarchy/story` | Defines exactly 3 levels |
| `setup-labels.sh` L35–37 | Creates exactly 3 hierarchy labels | No 4th label created |
| `planner.md` L120, L135, L138 | `gh issue create --label "hierarchy/story"` | Hardcoded in creation code |
| `dispatch-workflow.sh` L320, L329, L361, L388 | Discovers issues by `hierarchy/epic`, `hierarchy/story` | Would miss a new level |
| `builder.md` L28–29 | Filters by `hierarchy/story` + `backlog/<N>-<slug>` | Assumes no deeper level |

**Sub-issue linking (4 files):**

| File | Relationship | Constraint |
|------|-------------|-----------|
| CLAUDE.md L176–180 | Backlog → [Design, Plan, Epic1, Epic2, ...] | Backlog is parent of epics |
| CLAUDE.md L176–180 | Epic → [Story1, Story2, ...] | Stories are children of epic, NOT backlog |
| `planner.md` L39–45 | `addSubIssue` stories→epic | Enforced in creation code |
| CLAUDE.md L176–180 | "Hard constraint: exactly three levels deep" | Explicit prohibition on 4th level |

**Telemetry (3 files):**

| File | Mode | Assumption |
|------|------|-----------|
| `item-telemetry.sh` L197 | `--summary` → BACKLOG mode | Only 2 rendering modes exist |
| `templates/telemetry.md` L12–15 | BACKLOG vs STORY conditionals | Template hardcodes 2 modes |
| `orchestrator.md` L397–408 | "When all stories in an epic are complete, post telemetry on the epic issue" | Exactly 2-level rollup |

**State schema:**

```json
{
  "epics": {
    "e01": {
      "stories": {
        "112": { "status": "reviewed", "build": {...}, "review": {...} }
      }
    }
  }
}
```

This schema has `epics` containing `stories` — two explicit hierarchy levels below the backlog. Adding a level (e.g., tasks under stories) would require schema version migration.

#### 4.3 Impact Assessment: Adding a 4th Level

If a 4th level were added (e.g., `backlog > epic > story > task`):

| System | Change Required | Effort |
|--------|----------------|--------|
| Branch naming | New pattern: `eNN-sNN-tNN/slug` | Medium |
| Labels | New label: `hierarchy/task` | Low |
| Issue titles | New format: `[#N/ENN-SNN-TNN]` | Medium |
| Sub-issue linking | Stories become parents of tasks | Medium |
| Status aggregation | 3-level recursive rollup (task→story→epic) | Hard |
| Telemetry | 3 rendering modes (TASK, STORY, BACKLOG), new rollup | Hard |
| Dispatch protocol | Task-level dispatch, task-level worktrees | Hard |
| State schema | v2 with `tasks: {}` under each story | Medium |
| Orchestrator phases | New sub-phases for task dispatch/review/merge | Hard |
| Agent instructions | Rewrite phase boundaries for 4 agents | Hard |
| **Total files requiring changes** | | **15+** |

---

### 5. PM Tool Hierarchy Comparison

#### 5.1 Native Hierarchy Levels by Tool

| Tool | Level 1 (Strategic) | Level 2 (Grouping) | Level 3 (Work) | Level 4 (Sub-work) | Max Depth | Configurable? |
|------|:-------------------:|:------------------:|:--------------:|:------------------:|:---------:|:-------------:|
| **Jira (Standard)** | — | Epic | Story/Task | Sub-task | 3 | No (fixed) |
| **Jira (Premium)** | Initiative* | Epic | Story/Task | Sub-task | Unlimited* | Yes |
| **Azure DevOps** | Epic | Feature | User Story/PBI | Task | 4 default, 7+ custom | Yes |
| **GitHub Projects** | — | Issue (labeled) | Sub-issue | Sub-sub-issue | 8 (sub-issues) | No (untyped) |
| **Trello** | — | — | Card | Checklist item | 2 | No (flat) |
| **Linear** | Initiative | Project | Issue | Sub-issue | 4 | Partial |
| **Shortcut** | Objective | Epic | Story | Task (checklist) | 4 | No |
| **Asana** | Portfolio | Project | Task | Subtask | 5+ (subtasks) | Partial |

\* Jira Premium required for levels above Epic.

#### 5.2 Terminology Cross-Reference

| Concept | Jira | Azure DevOps | GitHub | Trello | Linear | Shortcut | Asana |
|---------|------|-------------|--------|--------|--------|----------|-------|
| Strategic goal | Initiative* | — | — | — | Initiative | Objective (Strategic) | Portfolio |
| Large deliverable | Epic | Epic | Issue (labeled) | Board | Project | Objective (Tactical) | Project |
| Medium grouping | — | Feature | Issue (labeled) | List | — | Epic | Section |
| Work unit | Story/Task | User Story/PBI | Issue | Card | Issue | Story | Task |
| Sub-work | Sub-task | Task | Sub-issue | Checklist | Sub-issue | Task | Subtask |

#### 5.3 Where Tools Diverge Most

1. **"Epic" means different things.** In Jira, it's the highest default grouping. In Azure DevOps, it sits ABOVE Feature. In Shortcut, it sits BELOW Objective. In GitHub and Trello, it doesn't exist natively.

2. **"Task" is the most overloaded term.** In Jira, it's a peer of Story (same level). In Azure DevOps, it's the LOWEST level (below User Story). In Shortcut, it's a checklist item inside a Story. In Asana, it's the PRIMARY work item. **Avoid using "Task" as a hierarchy level name.**

3. **"Project" is dangerously overloaded.** It means a team workspace (Asana, GitHub), a delivery container (Linear), or an entire instance boundary (Jira). **Never use "Project" as a hierarchy level name.**

4. **Strategic layer varies wildly.** Jira needs Premium for Initiatives. Azure DevOps has no concept above Epic without customization. GitHub has nothing. This layer is the least portable.

5. **Nesting depth ranges from 0 to unlimited.** Trello has no native hierarchy. GitHub supports 8 levels of sub-issues. Jira Premium supports unlimited custom levels. Any taxonomy must handle this range.

#### 5.4 Least Ambiguous Cross-Tool Vocabulary

Based on consistency of meaning across all 7 tools:

| Term | Ambiguity | Why |
|------|:---------:|-----|
| **Initiative** | Low | When it exists, always means "strategic goal above epics." Rarely misunderstood. |
| **Epic** | Medium | Usually means "large grouping" but its position varies (top in Jira, second in Azure DevOps, third in Shortcut). |
| **Story** | Medium-Low | Almost always means "a single deliverable unit of work." Jira, Shortcut, and Scrum use it consistently. Azure DevOps calls it "User Story." |
| **Task** | **High** | Means completely different things in every tool. **Avoid as a hierarchy level name.** |
| **Subtask** | Low | Consistently means "a child of a work item" everywhere it exists. |
| **Issue** | Low-Medium | GitHub and Linear use it as the universal work item. Clear in context but generic. |
| **Project** | **High** | Overloaded across every tool. **Never use as a hierarchy level name.** |

---

### 6. Taxonomy Redesign Proposal

> **Prior art:** The [Work Item Taxonomy design doc](../2-design/2026-03-11-agentic-sdlc-workitem-taxonomy.md) already proposed **Goal > Epic > Task** after evaluating 8 alternatives across 9 tools and 4 methodologies. That decision remains valid for the default 3-level configuration. This section extends it with depth flexibility and configurability — addressing the user's goal of a system that works with any PM tool and allows the planner to choose the appropriate depth.

#### 6.1 Design Principles

Based on the research above and the existing taxonomy design doc, a redesigned taxonomy should be:

1. **Tool-agnostic.** Use vocabulary that maps cleanly to every PM tool without semantic collisions.
2. **Depth-flexible.** Allow 2–4 levels, with the planner deciding based on feature complexity.
3. **User-configurable.** Level names, branch patterns, label prefixes, and title formats should come from a config file, not hardcoded constants.
4. **Recursively aggregatable.** Status rollup, telemetry aggregation, and board management should work with N levels, not just 2 or 3.
5. **Backward-compatible.** The current 3-level hierarchy (backlog > epic > story) should be expressible as one configuration of the new system.

#### 6.2 Open Question: Bottom-Level Naming

The [taxonomy design doc](../2-design/2026-03-11-agentic-sdlc-workitem-taxonomy.md) selected **Task** over **Story** for the bottom level (4–2 on a stress test). However, this decision warrants re-evaluation before implementation, particularly around cross-tool mapping conflicts. Points for a future deep dive:

| Candidate | Strengths | Weaknesses | Cross-Tool Risk |
|-----------|-----------|------------|----------------|
| **Task** (current decision) | Domain-neutral, universal vocabulary, works for marketing/ops/infra | Most overloaded term in PM tools — means different things in Jira (peer of Story), Azure DevOps (lowest child level), Shortcut (checklist item), Asana (primary work item) | High — your "Task" maps to Jira "Sub-task" and Azure DevOps "User Story", creating semantic confusion |
| **Story** (current implementation) | Well-understood in agile, strong engineering culture fit, implies a self-contained deliverable | Engineering-biased ("Story: Design Facebook ad creative" reads awkwardly), not natural for non-dev teams | Medium — not native in Linear, Asana, or Trello, but understood universally in agile contexts |
| **Item** | Completely neutral, no semantic collisions with any tool, mirrors "work item" vocabulary | Generic — doesn't signal the richness of a self-contained micro-spec, could feel too abstract | Low — no tool uses "Item" as a hierarchy level name (Monday uses it but at a different abstraction) |
| **Ticket** | Informal but widely understood, natural for support/ops teams | Too informal for some contexts, implies a request rather than a deliverable | Low — no tool uses it as a hierarchy level, but "ticket" has helpdesk connotations |

**Key questions for the deep dive:**

1. **Does the name need to signal richness?** "Story" and "Task" both imply something substantive. "Item" doesn't — but the template defines richness, not the name. Is that enough?
2. **How much does cross-tool mapping friction matter in practice?** If users mostly stay within one tool, the mapping table is documentation they read once. If they switch tools frequently, semantic collisions cause real confusion.
3. **Who is the primary audience for the name?** If it's AI agents, the name barely matters (they follow instructions regardless). If it's humans scanning a board, the name needs to be instantly understood.
4. **Should the name be configurable per-project?** If the system supports configurable level names (see §6.3), the default name matters less — teams can rename "Task" to "Story" in their config. The default just needs to be the least controversial starting point.

**Recommendation:** Defer final naming decision until the configurable hierarchy (§6.3) is designed. The config system makes the default name a preference, not a constraint. For the deep dive, test each candidate against 5 real-world scenarios (product feature, bug bash, infrastructure migration, marketing campaign, research spike) and score on instant comprehension.

#### 6.3 Proposed Hierarchy Model

Instead of fixed level names, use a **depth-indexed model** with configurable display names:

```
Level 0: Root work item (the feature/initiative — always exactly 1)
Level 1..N: Decomposition levels (configurable, min 1, max 3 levels below root)
Level N (leaf): Dispatch unit (the atomic work item that a builder receives)
```

**Default configuration (current behavior):**

```yaml
# .claude/workflow-config.yaml (or equivalent)
hierarchy:
  levels:
    - name: "Backlog Item"    # Level 0 (root)
      label: "hierarchy/backlog"
      branch_prefix: "backlog"
    - name: "Epic"            # Level 1 (grouping)
      label: "hierarchy/epic"
      branch_prefix: "epic"
    - name: "Story"           # Level 2 (leaf / dispatch unit)
      label: "hierarchy/story"
      branch_pattern: "{parent_tag}-s{nn}/{slug}"
  constraints:
    min_levels: 2  # root + at least 1 decomposition
    max_levels: 4  # root + at most 3 decompositions
    leaf_is_dispatch_unit: true
```

**Alternative configurations:**

Two-level (simple features):
```yaml
hierarchy:
  levels:
    - name: "Feature"
      label: "hierarchy/feature"
      branch_prefix: "feature"
    - name: "Story"
      label: "hierarchy/story"
      branch_pattern: "s{nn}/{slug}"
```

Four-level (complex features):
```yaml
hierarchy:
  levels:
    - name: "Initiative"
      label: "hierarchy/initiative"
      branch_prefix: "initiative"
    - name: "Epic"
      label: "hierarchy/epic"
      branch_prefix: "epic"
    - name: "Story"
      label: "hierarchy/story"
      branch_pattern: "{parent_tag}-s{nn}/{slug}"
    - name: "Subtask"
      label: "hierarchy/subtask"
      branch_pattern: "{parent_tag}-t{nn}/{slug}"
```

#### 6.4 Key Design Decisions

**Decision 1: "Leaf level = dispatch unit" is the invariant.**

Regardless of depth, the deepest level is always what gets dispatched to a builder. This keeps the dispatch protocol simple — the orchestrator doesn't need to know whether it's dispatching a "story" or a "subtask," it dispatches the leaf.

**Decision 2: Status aggregation is recursive.**

Instead of hardcoded "epic status = aggregate of stories," the rule becomes: "a parent's status = aggregate of its children's statuses." This works for any depth.

```
if any child is In Progress → parent is In Progress
else if all children are In Review → parent is In Review
else if all children are Done → parent is Done
```

**Decision 3: Telemetry aggregation is bottom-up.**

Instead of 2 modes (STORY vs BACKLOG), telemetry is posted at every level:
- Leaf level: per-dispatch metrics
- Each parent level: aggregate of children's metrics
- Root level: full lifecycle summary

The template gains a single mode that renders based on whether `--children` data is provided, not on a fixed BACKLOG/STORY distinction.

**Decision 4: Branch naming derives from config.**

Instead of hardcoding `backlog/`, `epic/`, `eNN-sNN/`, the branch prefix for each level comes from the config. The cleanup script reads the same config to know which patterns to sweep.

**Decision 5: The planner proposes the depth.**

The planner examines the feature's complexity and proposes how many levels to use (within the min/max constraints). The orchestrator validates the proposal against the config. This keeps simple features at 2 levels and allows complex features to use 3–4.

#### 6.5 Mapping to PM Tools

| Workflow Level | GitHub | Jira | Azure DevOps | Linear | Asana |
|---------------|--------|------|-------------|--------|-------|
| Root (Level 0) | Issue + `hierarchy/root` label | Epic (or Initiative if Premium) | Epic | Initiative or Project | Project or Portfolio |
| Grouping (Level 1) | Issue + `hierarchy/group` label, sub-issue of root | Story (grouped under Epic) | Feature | Issue (in Project) | Task (in Project) |
| Leaf (Level 2) | Issue + `hierarchy/leaf` label, sub-issue of group | Sub-task | User Story or Task | Sub-issue | Subtask |

The config file would include a `tool_mapping` section that maps the abstract levels to tool-specific concepts, enabling the same workflow to target different PM backends.

#### 6.6 Migration Path

A migration from the current hardcoded 3-level system to a configurable taxonomy would proceed in phases:

**Phase 1: Introduce the config file.** Create `.claude/workflow-config.yaml` with the current 3-level hierarchy as the default. No behavior change yet — just externalizing the constants.

**Phase 2: Parameterize scripts.** Update `cleanup-post-merge.sh`, `dispatch-story.sh`, `setup-labels.sh` to read level names, branch prefixes, and label names from the config instead of hardcoding them.

**Phase 3: Parameterize agents.** Update `planner.md`, `builder.md`, `orchestrator.md` to reference config-driven level names. Replace "exactly three levels deep" with "min `{min_levels}`, max `{max_levels}` levels as defined in config."

**Phase 4: Recursive aggregation.** Rewrite status aggregation and telemetry rollup as recursive functions that work with N levels.

**Phase 5: Planner depth selection.** Add instructions to `planner.md` for choosing the appropriate depth based on feature complexity, with guardrails (min 2, max 4).

**Phase 6: Tool-specific adapters.** Build the mapping layer that translates abstract levels to GitHub Issues, Jira Epics, Azure DevOps Features, etc.

---

## Part III: Consolidated Findings

### 7. Key Observations

These are structural observations about the system that don't fit neatly into a fix table but inform how to think about the workflow going forward.

**Agent files are executable specifications, not documentation.** In traditional software, you have source code + docs, and documentation drift is a cosmetic problem. In this system, the agent `.md` files ARE the program — they're the instructions that determine agent behavior at runtime. An inconsistency between `builder.md` and `CLAUDE.md` isn't a documentation bug, it's a runtime bug that manifests as incorrect agent behavior. This makes "convention propagation" the equivalent of keeping API contracts in sync across microservices. Every edit to a convention must be treated as a code change that requires grep-verification across all consumers.

**The phase ordering is a DAG, not a sequence.** The workflow has a human-in-the-loop synchronization point (PR merge) that splits the pipeline into pre-merge and post-merge segments. But the phase numbering (0–11) treats it as a linear sequence. The actual execution topology is a DAG: Phases 8→10→11 run pre-merge, then the human merges, then Phase 9 runs post-merge. The orchestrator has been working around this for 11 runs by implicitly reordering phases — a sign that the abstraction (numbered phases) doesn't match the actual topology. Renumbering (as proposed in Quick Win H) fixes the symptom; the deeper fix is acknowledging that post-merge work is a separate lifecycle stage, not a numbered phase.

**The pricing inconsistency is a "two-failure" bug.** The inconsistent hardcoded fallback rates between `fetch-pricing.sh` ($30/M for opus) and `item-telemetry.sh` ($10/M for opus) only manifest when the Anthropic pricing page is unreachable AND the `--rate` flag isn't passed from the state file. Both conditions must fail simultaneously. This is exactly the kind of bug that survives for months because the happy path always works — the web fetch succeeds, the state file provides rates, and the hardcoded fallbacks are never exercised. Worth fixing precisely because it will bite at the worst time (during an outage when you most need accurate cost data).

**The taxonomy is a simplicity-vs-flexibility trade-off.** The current system optimizes for simplicity (fixed 3 levels, hardcoded everywhere) at the cost of flexibility. The PM tool ecosystem requires the opposite — configurable depth, tool-specific naming, adaptable mapping. The proposed depth-indexed model with configurable display names resolves this by making the "number of levels" a configuration parameter rather than an architectural constant. This is analogous to the database pattern of schema-on-read vs schema-on-write: the current system enforces the schema at write time (planner must create exactly 3 levels), while a configurable system would enforce constraints at read time (orchestrator validates the structure against configured rules). The migration path matters more than the end state — each step must leave the system functional.

### 8. Prioritized Fix Table

| # | Issue | Type | Effort | Impact |
|---|-------|------|--------|--------|
| **1** | `dispatch-workflow.sh` and `dispatch-story.sh` implement v1 workflow | stale | Medium | High |
| **2** | Builder branch diagram omits integration branch | bug | Low | High |
| **3** | Phase ordering paradox (8→9→10→11 vs actual 8→10→11→merge→9) | gap | Medium | High |
| **4** | Retro issue not added to PR `Closes` list | gap | Low | Medium |
| **5** | Phase 3 uses stale plan matching pattern | bug | Low | Medium |
| **6** | Inconsistent hardcoded pricing fallback rates between scripts | bug | Low | Medium |
| **7** | No failure handling for designer/planner dispatch | gap | Low | Medium |
| **8** | No merge conflict handling in orchestrator.md | gap | Low | Medium |
| **9** | Status option IDs duplicated without cross-reference note | observation | Low | Low |
| **10** | `check-board-drift.sh` not integrated into orchestrator workflow | gap | Low | Low |
| **11** | `validate-logs.sh` not referenced by retro agent | gap | Low | Low |
| **12** | 35+ lesson files from Runs 2–6 are archival candidates | stale | Low | Low |
| **13** | `protected-files` label timing gap on PR creation | observation | Low | Low |
| **14** | 3-level hierarchy hardcoded in 15+ files (blocks taxonomy flexibility) | architectural | High | High |

### 9. Quick Wins (< 30 minutes each)

| # | Fix | Effort | Files |
|---|-----|--------|-------|
| A | Fix builder branch diagram to show integration branch | 5 min | `builder.md` + 3 variants |
| B | Fix Phase 3 plan matching to use YAML frontmatter | 5 min | `orchestrator.md` |
| C | Add designer/planner dispatch failure handling | 10 min | `orchestrator.md` |
| D | Add merge conflict handling to Phase 7 | 10 min | `orchestrator.md` |
| E | Document PR body edit for retro issue in Phase 10 | 5 min | `orchestrator.md` |
| F | Align hardcoded pricing fallbacks between scripts | 10 min | `fetch-pricing.sh` or `item-telemetry.sh` |
| G | Add `validate-logs.sh` to retro agent gathering inputs | 5 min | `retro.md` |
| H | Renumber phases for correct execution order (8→9=retro→10=telemetry→11=cleanup) | 10 min | `orchestrator.md` |

### 10. Big Ideas

| # | Idea | Problem Solved | Effort | Impact |
|---|------|---------------|--------|--------|
| I | **Telemetry aggregator script** — reads state file, outputs `--summary`, `--breakdown`, `--gantt` | Eliminates manual orchestrator arithmetic (~50 lines) | Medium | High |
| II | **Board reconciliation script** (`verify-wave.sh`) | Eliminates missing-comment pattern (Runs 4, 11) | Medium | High |
| III | **Machine-readable dependency graph** (JSON alongside Mermaid) | Eliminates orchestrator Mermaid parsing | Medium | High |
| IV | **Retire or rewrite CLI dispatch scripts** | Eliminates stale v1 code that could confuse users | Low–High | Medium |
| V | **Extract orchestrator reference material** to `docs/5-guides/` | Reduces orchestrator.md from ~1000 to ~500 lines | Medium | Medium |
| VI | **Cross-run performance dashboard** (`docs/4-reviews/performance.md`) | Enables trend detection, addresses recommendations G and H | Low | Medium |
| VII | **Configurable work item taxonomy** (see §6) | Unlocks tool-agnostic, depth-flexible hierarchy | High | Very High |

---

## Appendix A: PM Tool Hierarchy — Full Comparison Matrix

### A.1 Nesting Capabilities

| Tool | Native Depth | Max Configurable | Typed Levels? | Custom Levels? |
|------|:-----------:|:----------------:|:-------------:|:--------------:|
| Jira (Standard) | 3 | 3 (fixed) | Yes | No |
| Jira (Premium) | 3+ | Unlimited | Yes | Yes (above Epic) |
| Azure DevOps | 4 | ~7 (5 custom portfolio) | Yes | Yes (above Epic) |
| GitHub Projects | 8 | 8 (sub-issues) | No (untyped) | No |
| Trello | 2 | 2 (flat) | No | No (power-ups add depth) |
| Linear | 4 | 4 | Yes | Partial (Initiatives gate) |
| Shortcut | 4 | 4 (fixed) | Yes | No |
| Asana | 5+ | 5+ (subtasks) | Partial | Partial (portfolio nesting) |

### A.2 Terminology Ambiguity Scores

| Term | Score (1=unambiguous, 5=avoid) | Recommendation |
|------|:-----------------------------:|---------------|
| Initiative | 1 | Safe to use for strategic level |
| Epic | 3 | Use with caution — position varies by tool |
| Story | 2 | Generally safe — well understood in agile context |
| Task | **5** | **Avoid** — means different things in every tool |
| Subtask | 1 | Safe — consistently means "child of work item" |
| Issue | 2 | Safe in technical contexts; generic but clear |
| Feature | 2 | Azure DevOps uses it as a hierarchy level; safe elsewhere |
| Project | **5** | **Avoid** — overloaded in every tool |
| Milestone | 3 | Renamed in Shortcut; not used by most tools |
| Objective | 2 | Shortcut-specific but unambiguous |

### A.3 Minimum Viable Cross-Tool Hierarchy

The smallest hierarchy that maps cleanly to every PM tool (including Trello without power-ups):

| Abstract Level | Purpose | Trello | GitHub | Jira | Azure DevOps | Linear | Shortcut | Asana |
|---------------|---------|--------|--------|------|-------------|--------|----------|-------|
| **Group** | Organizes related work | Board/List | Label/Milestone | Epic | Feature/Epic | Project | Epic | Project |
| **Item** | Unit of deliverable work | Card | Issue | Story | User Story/PBI | Issue | Story | Task |
| **Sub-item** | Breakdown within item | Checklist | Sub-issue | Sub-task | Task | Sub-issue | Task (checklist) | Subtask |

This 3-level model (Group > Item > Sub-item) is the lowest common denominator. Tools with deeper support (Azure DevOps, Jira Premium, GitHub) can use additional levels; tools with shallower support (Trello) flatten the upper levels.

---

*Analysis based on: all 9 agent files in `.claude/agents/`, all 13 scripts in `scripts/`, `scripts/templates/telemetry.md`, `CLAUDE.md`, `docs/4-reviews/retro-recommendations.md`, and retro docs from Runs 9–11. PM tool data sourced from official documentation and web research as of 2026-03-14.*
