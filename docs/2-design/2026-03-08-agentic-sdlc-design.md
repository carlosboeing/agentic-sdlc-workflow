# Agentic SDLC Workflow for NeuralNorris

**Status:** Approved
**Date:** 2026-03-08
**Author:** Carlos + Claude

## Overview

Introduce a structured AI-agent-driven software development lifecycle (SDLC) for NeuralNorris, adapted from the Agentic SDLC Framework proven in the parenting-game project. The system uses four specialized agents, GitHub Issues/Projects as the single source of truth, difficulty-based model routing for cost control, and helper scripts for telemetry.

## Decisions Summary

| Decision | Choice |
|----------|--------|
| Agent count | 4 core: designer, architect, builder, reviewer |
| Task tracking | GitHub Issues/Projects (full adoption, replaces BACKLOG.md) |
| Docs structure | Numbered SDLC phases (migrate existing files) |
| Sentinel + reviewer | Complementary — Sentinel for security on all PRs, reviewer for code quality |
| Model routing | easy→Haiku, medium→Sonnet, hard→Opus |
| Helper scripts | Bash (consistent with parenting-game) |
| Branch strategy | `epic/eNN-slug` → `eNN-sNN/slug`, no `norris/` prefix |
| Sentinel trigger | All PRs to main |
| Orchestration | Manual (human dispatches agents) |
| External dependencies | None — workflow works with just the repo + `gh` CLI |

---

## 1. Agent Architecture

Four agents in `.claude/agents/`, each with strict separation of concerns.

### designer — Creative Vision & Feature Design

- **Role:** Product thinker who understands NeuralNorris's architecture and VISION.md
- **Responsibilities:**
  - Brainstorm features, evaluate feasibility against the existing architecture
  - Write design docs to `docs/2-design/`
  - Check GitHub Issues before brainstorming to understand project state
  - Reference `docs/5-guides/PROJECT.md` and `docs/1-discovery/VISION.md` for context
- **Does NOT:** Write code, create issues, or make planning decisions
- **Tools:** Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, Agent

### architect — System Design & Planning

- **Role:** Senior .NET architect who knows the NeuralNorris dependency graph
- **Responsibilities:**
  - Create implementation plans from approved designs → `docs/3-plans/`
  - Break plans into epics and stories with careful difficulty classification
  - Create GitHub Issues with labels (epic, difficulty, type)
  - Design C# interfaces, abstractions, and DI registrations with precision
  - Classify difficulty with due diligence (see classification checklist below)
- **Does NOT:** Write production code or test code
- **Tools:** Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, Agent

### builder — Production Code & TDD Implementation

- **Role:** Senior C# developer executing stories via TDD
- **Responsibilities:**
  - Implement one story at a time from GitHub Issues
  - Follow TDD: write xUnit tests first → implement → refactor
  - Use NSubstitute for mocking, Arrange/Act/Assert pattern
  - Follow naming convention: `Method_Condition_ExpectedResult`
  - Create atomic commits using conventional commits
  - Run `issue-start.sh` at start, `issue-review.sh` at end
  - Branch off epic branches, never commit to `main`
- **Does NOT:** Create issues, modify plans, or make architectural decisions
- **Tools:** Read, Write, Edit, Grep, Glob, Bash, Agent
- **Constraints:** Files under 200 lines, no `object` or `dynamic` types, follow existing DI patterns

### reviewer — Code Quality & Convention Enforcement

- **Role:** Code reviewer who knows NeuralNorris conventions deeply
- **Responsibilities:**
  - Review PRs for architecture adherence, code quality, test coverage
  - Check NeuralNorris-specific conventions:
    - `ITool` + `IKernelTool` contracts for new tools
    - DI registration patterns
    - `DateTimeOffset` stored as Unix milliseconds
    - snake_case tool names
    - `NNConfig` binding for configuration
    - Test naming: `Method_Condition_ExpectedResult`
  - Flag silent failures, missing error handling at system boundaries
  - Verify test coverage for new public APIs
- **Does NOT:** Modify code, create issues, or make design decisions
- **Tools:** Read, Grep, Glob, Bash (for `dotnet build`/`dotnet test`)

### Separation of concerns

| Agent | Writes code | Creates issues | Writes docs | Reviews code |
|-------|:-----------:|:--------------:|:-----------:|:------------:|
| designer | | | x | |
| architect | | x | x | |
| builder | x | | | |
| reviewer | | | | x |

---

## 2. Documentation Structure

Migrate from the current flat structure to numbered SDLC phases.

### New structure

```
docs/
  CHANGELOG.md             # Build history (stays at docs root)
  1-discovery/             # Ideas, brainstorms
    VISION.md              # (moved from docs/)
  2-design/                # Feature design docs
    agent-orchestration.md # (moved from designs/)
    self-aware-norris.md   # (moved from designs/)
  3-plans/                 # Implementation plans
    2026-03-07-agent-orchestration.md  # (moved from plans/)
    2026-03-08-self-aware-norris.md    # (moved from plans/)
  4-reviews/               # Code reviews, retros
  5-guides/                # How-to docs, reference
    PROJECT.md             # (moved from docs/)
  6-adrs/                  # Architecture Decision Records
```

### Migration summary

| Current location | New location |
|---|---|
| `docs/designs/*.md` | `docs/2-design/` |
| `docs/plans/*.md` | `docs/3-plans/` |
| `docs/VISION.md` | `docs/1-discovery/VISION.md` |
| `docs/PROJECT.md` | `docs/5-guides/PROJECT.md` |
| `docs/BACKLOG.md` | Retired (GitHub Issues replaces it) |
| `docs/CHANGELOG.md` | `docs/CHANGELOG.md` (stays) |

### File naming conventions

- Design docs: `YYYY-MM-DD-<topic>.md`
- Plans: `YYYY-MM-DD-<topic>-plan.md`
- ADRs: `NNNN-<title>.md` (e.g., `0001-sqlite-over-postgres.md`)

### Agent-to-phase mapping

| Agent | Writes to |
|---|---|
| designer | `2-design/` |
| architect | `3-plans/`, `6-adrs/` |
| reviewer | `4-reviews/` |
| builder | Code only |

---

## 3. GitHub Integration

### Labels taxonomy

| Category | Labels | Color |
|---|---|---|
| **Epic** | `epic/e01-name`, `epic/e02-name`, ... | blue |
| **Type** | `type/feature`, `type/bug`, `type/refactor`, `type/test`, `type/docs` | green |
| **Difficulty** | `difficulty/easy`, `difficulty/medium`, `difficulty/hard` | orange |

No status labels — GitHub Issues open/closed state and GitHub Project board columns handle status.

### Issue naming convention

- **Epic issue:** `[E01] Epic title` — tracks overall progress, contains story checklist
- **Story issue:** `[E01-S01] Story title` — atomic unit of work, assigned difficulty label

### GitHub Project

- Single project board: **"NeuralNorris Development"**
- Columns: Backlog → In Progress → Review → Done
- Project automations move cards when status changes

### Helper scripts (`scripts/`)

| Script | Purpose |
|---|---|
| `issue-start.sh <number> --model <model> --agent <agent>` | Comment on issue with start timestamp, model, agent |
| `issue-review.sh <number> <commit-hash>` | Comment with completion info, move to Review column |
| `issue-telemetry.sh <number> --model <model> --duration <ms> --commit <hash>` | Post telemetry metrics as issue comment |
| `issue-merged.sh <number>` | Close issue, move to Done column |
| `setup-labels.sh` | Create all labels in the repo (idempotent) |

### Telemetry

Two-point tracking on each issue:
- **Start comment:** timestamp, model, agent name
- **End comment:** duration, commit hash, completion status
- Enables: cost analysis per epic, model routing validation, throughput tracking

---

## 4. Branch Strategy & Safety

### Three-level hierarchy

```
main
  └── epic/e01-memory-search
        ├── e01-s01/vector-embedding-model
        ├── e01-s02/similarity-search-query
        └── e01-s03/memory-search-tool
```

### Rules

- **main** — always deployable, protected
- **epic/eNN-slug** — integration branch for an epic, created from `main`
- **eNN-sNN/slug** — story branch, created from its epic branch
- Stories merge into their epic branch via PR
- Epic merges into `main` via PR when all stories complete

### Safety layers

| Layer | Mechanism |
|---|---|
| Instructions | Agent definitions — separation of concerns, no direct commits to `main` |
| Scripts | Helper scripts enforce telemetry and status tracking |
| Sentinel | Triggers on all PRs to main (branch filter removed) |
| Pre-commit hook | Existing `dotnet test` hook — no broken code committed |

### Parallel work

- Multiple builders can work on parallel stories within the same epic (separate story branches)
- Independent epics can run in parallel if no dependency exists
- Epic dependency graph defined in the implementation plan

---

## 5. Difficulty Routing & Dispatch

### Routing table

| Difficulty | Model | Typical NeuralNorris tasks |
|---|---|---|
| **Easy** | Haiku | Config property additions, simple tests, docs, single-file bug fixes, adding a tool parameter |
| **Medium** | Sonnet | New tool implementation following existing patterns, standard EF migrations, Blazor component updates, multi-file changes within one project |
| **Hard** | Opus | New abstractions/interfaces, cross-project changes, orchestration logic, Blazor + backend wiring, security-sensitive code, DevOps tool additions |

### Architect's classification checklist

Before assigning difficulty, the architect considers:

1. **How many projects are touched?** (1 = easier, 2+ = harder)
2. **Does it require new abstractions?** (new interface/base class = hard)
3. **Does it involve DI registration changes?** (cross-cutting = harder)
4. **Does it require EF migrations?** (schema change = at least medium)
5. **Is it security-sensitive?** (auth, encryption, path traversal = hard)
6. **Does an existing pattern exist to follow?** (yes = easier, no = harder)

### Dispatch protocol (manual)

1. Read difficulty label from GitHub Issue
2. Map to model per routing table
3. Dispatch builder via Agent tool with model parameter
4. Builder runs `issue-start.sh` → implements → runs `issue-review.sh`
5. Review the PR
6. Post telemetry via `issue-telemetry.sh`

---

## 6. CLAUDE.md Updates

New "Development Workflow" section added to CLAUDE.md covering:

- Agent roles and `.claude/agents/` reference
- "For All Agents" rules: check GitHub Issues first, never start without an issue, conventional commits
- Branch conventions: `epic/eNN-slug` → `eNN-sNN/slug`
- Documentation conventions: numbered phases, agent-to-phase mapping, naming
- GitHub conventions: label taxonomy, issue naming, helper scripts
- Dispatch protocol: difficulty → model → dispatch

Existing sections (Build & Run, Architecture, Testing, CI) remain unchanged.

---

## 7. Sentinel Update

Single change to `.github/workflows/sentinel.yml`:

Remove the `norris/` branch name filter so Sentinel triggers on all PRs to `main`. The workflow body remains unchanged — it still fetches the diff, calls Claude for security review, and posts findings.

---

## What This Does NOT Include

- Orchestrator automation (manual dispatch for now)
- Changes to the core NeuralNorris architecture
- New runtime features or tools
- Changes to existing tests or CI pipeline (beyond Sentinel trigger)
