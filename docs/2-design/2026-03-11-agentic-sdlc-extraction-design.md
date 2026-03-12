---
date: 2026-03-11
author: Carlos + Claude
status: draft
related:
  - 2026-03-09-agentic-sdlc-v2-design.md
  - 2026-03-10-agentic-sdlc-plugin-architecture.md
  - 2026-03-11-agentic-sdlc-workitem-taxonomy.md
  - 2026-03-10-agentic-sdlc-issue-templates-design.md
---

# Design: Agentic SDLC Workflow Extraction & Packaging

## Overview

The NeuralNorris project contains an agentic SDLC workflow — specialized agents for design, architecture, building, review, and retrospectives, orchestrated through a structured lifecycle with telemetry, lessons, and convention evolution. This workflow is valuable beyond NeuralNorris and should be extracted into a standalone, project-agnostic package that anyone can adopt.

This document captures the design decisions for extracting the workflow, defining adapter interfaces for pluggable PM and document storage backends, establishing a local-first default that works with zero configuration, and providing a dashboard for human visibility.

## Problem Statement

The SDLC workflow is currently coupled to NeuralNorris in three ways:

1. **Project knowledge** — Agent files contain .NET/C#/Blazor architecture knowledge, `NN.*` namespaces, DI patterns, and NeuralNorris-specific conventions
2. **GitHub coupling** — Scripts, agents, and CLAUDE.md embed `gh` CLI commands, GitHub Project board IDs, status option IDs, and GitHub-specific vocabulary
3. **Local docs coupling** — Design docs, plans, lessons, and retros are stored in a `docs/` folder structure committed to git

The extraction must separate **process** (how work flows) from **knowledge** (what the codebase looks like) and **integrations** (which PM/doc tools are used).

## Design Principles

1. **Local-first, zero-config default.** The workflow must work out of the box with no external services, no API keys, no accounts. External integrations are opt-in upgrades.
2. **Adapter pattern for PM and Docs.** Define clean interfaces; swap implementations without changing workflow logic.
3. **Agents reference abstract operations.** Agent instructions say "create a task" not "run `gh issue create`". The adapter resolves the concrete command.
4. **Project knowledge stays in each project's CLAUDE.md.** Agents read the project's CLAUDE.md for tech stack, build commands, and conventions — the framework agents carry no tech-stack opinions.
5. **The repo is the source of truth.** External PM/Doc tools are sync targets for visibility, not the canonical store.

## Inventory: What Gets Extracted

### Files that move to the framework

| Category | Files | Norris-specific content to strip |
|----------|-------|----------------------------------|
| **Agents** | `.claude/agents/orchestrator.md`, `planner.md`, `designer.md`, `builder.md`, `builder-{haiku,sonnet,opus}.md`, `reviewer.md`, `retro.md` | All `.NET`, `NN.*`, `ITool`, `IKernelTool`, Blazor, EF Core, SQLite, DI pattern references; all `gh` CLI commands and board IDs |
| **Scripts** | `scripts/issue-start.sh`, `issue-review.sh`, `issue-telemetry.sh`, `issue-merged.sh`, `dispatch-story.sh`, `dispatch-workflow.sh`, `setup-labels.sh`, `fetch-pricing.sh` | `REPO="gavinkilbride/NeuralNorris"`, project board IDs, status option IDs |
| **Templates** | `scripts/templates/telemetry.md` | Already generic |
| **Config** | `.claude/settings.json`, `.claude/settings.local.json`, `.claude/.gitignore` | `dotnet` command allowlists (tech-stack specific) |
| **Workflows** | `.github/workflows/sentinel.yml`, `auto-close-issues.yml` | Repo references, NeuralNorris security checklist |
| **CLAUDE.md** | Workflow convention sections (~60% of current file) | Project architecture, build commands, testing conventions, dependency graph |

### Files that stay in NeuralNorris

| Category | Files | Why |
|----------|-------|-----|
| **Project CLAUDE.md sections** | Build & Run, Architecture, Testing, CI, Project Documentation | Tech-stack and project-specific |
| **Project docs** | `docs/5-guides/PROJECT.md`, `docs/1-discovery/VISION.md`, all feature design/plan docs | NeuralNorris-specific content |
| **Feature artifacts** | `docs/2-design/*`, `docs/3-plans/*`, `docs/4-reviews/*`, `docs/6-adrs/*` | Content is project-specific (the folder convention is reusable) |
| **Launch config** | `.claude/launch.json` | VS Code debug config for NeuralNorris |

### CLAUDE.md separation

The current `CLAUDE.md` splits into two concerns:

| Section | Destination | Type |
|---------|------------|------|
| Build & Run | Project `CLAUDE.md` | Project-specific |
| Architecture | Project `CLAUDE.md` | Project-specific |
| Testing Conventions | Project `CLAUDE.md` | Project-specific |
| CI | Project `CLAUDE.md` | Project-specific |
| Project Documentation (paths) | Project `CLAUDE.md` | Project-specific |
| Development Workflow (agent roles) | Framework `CLAUDE.md.template` | Reusable |
| Branch Conventions | Framework `CLAUDE.md.template` | Reusable |
| PM Conventions (currently GitHub) | Framework `CLAUDE.md.template` | Reusable (adapter-referenced) |
| Work Item Hierarchy | Framework `CLAUDE.md.template` | Reusable |
| Dispatch Protocol | Framework `CLAUDE.md.template` | Reusable |
| Integration Branch / PR Strategy | Framework `CLAUDE.md.template` | Reusable |
| Doc Conventions | Framework `CLAUDE.md.template` | Reusable (adapter-referenced) |
| Lesson Conventions | Framework `CLAUDE.md.template` | Reusable |
| Known Claude Code Limitations | Framework `CLAUDE.md.template` | Reusable |
| Convention Change Propagation | Framework `CLAUDE.md.template` | Reusable |
| Agent File Maintenance | Framework `CLAUDE.md.template` | Reusable |
| Board status IDs, project IDs | Adapter config (GitHub adapter) | GitHub-specific |

## Architecture: Adapter Interfaces

Two pluggable interfaces separate the workflow from external systems.

### PM Adapter (Project Management)

Manages work items, hierarchy, status, comments, and labels.

| Operation | Purpose | GitHub impl | Local impl |
|-----------|---------|-------------|------------|
| `pm_create_item <type> <title> <labels...>` | Create goal/epic/task | `gh issue create` | Create `.sdlc/` markdown file |
| `pm_read_item <id>` | Read item details | `gh issue view` | Parse markdown frontmatter |
| `pm_close_item <id>` | Close/resolve item | `gh issue close` | Set `status: done` in frontmatter |
| `pm_list_items <filters...>` | List items by label/status | `gh issue list --label` | Grep across `.sdlc/` frontmatter |
| `pm_link_parent_child <parent> <child>` | Establish hierarchy | `addSubIssue` GraphQL | Implicit via folder structure |
| `pm_create_label <name> <color> <desc>` | Create label/tag | `gh label create` | No-op (labels are strings in frontmatter) |
| `pm_set_status <id> <status>` | Transition board status | `gh project item-edit` | Update `status:` in frontmatter |
| `pm_get_status <id>` | Read current status | `gh issue view --json` | Parse `status:` from frontmatter |
| `pm_post_comment <id> <body>` | Post comment/telemetry | `gh issue comment` | Append timestamped file to `history/` |
| `pm_read_comments <id>` | Read all comments | `gh issue view --json comments` | Read files from `history/` |
| `pm_append_body <id> <markdown>` | Append to item description | `gh issue edit --body` | Append to markdown file body |
| `pm_create_pr <head> <base> <title> <body>` | Create pull request | `gh pr create` | No-op (local merges are `git merge`) |
| `pm_merge_pr <number> <strategy>` | Merge pull request | `gh pr merge` | No-op |

Status values are generic across all adapters:

```
backlog → planning → ready → in_progress → review → done
                                ↑              │
                                └── rejected ──┘
```

### Doc Adapter (Document Storage)

Manages design docs, plans, ADRs, lessons, retros, and changelogs.

| Operation | Purpose | Local impl | Notion impl (future) |
|-----------|---------|------------|---------------------|
| `doc_write <category> <slug> <content>` | Create document | Write to `docs/<category>/YYYY-MM-DD-slug.md` | Create Notion page |
| `doc_read <category> <slug>` | Read document | Read file | Fetch page content |
| `doc_search <category> <pattern>` | Find documents | `grep -rl` in `docs/` | Notion search API |
| `doc_exists <category> <pattern>` | Check existence | File exists check | Page exists check |
| `doc_submit_for_review <category> <slug>` | Submit for approval | Git branch + notify human | Share page + set status |
| `doc_is_approved <category> <slug>` | Check approval | Check if status is `done` / PR merged | Check page approval status |

Doc categories: `design`, `plan`, `adr`, `lesson`, `retro`, `changelog`, `guide`.

## Decision: Local PM Storage

### Decision: File-based task tracking (Option A)

**Alternatives considered:**

| Option | Description | Verdict |
|--------|-------------|---------|
| **A: Markdown files with YAML frontmatter** | `.sdlc/` folder with hierarchical folders, frontmatter for metadata | **Selected** |
| **B: GitHub Issues only (no Projects)** | Use `gh issue` with label-based status | Rejected — requires GitHub, not zero-config |
| **C: Single markdown checklist** | One `BOARD.md` file with structured checklist | Rejected — merge conflicts from parallel agents, doesn't scale |
| **D: SQLite database** | `.sdlc/board.db` with proper tables | Rejected — not human-readable, agents can't read directly, git diffs useless |
| **E: No default PM** | Require external tool from day one | Rejected — breaks zero-config promise |

### Rationale for Option A

- **Agents can read/write directly** — standard `Read`/`Write`/`Edit` tools, no CLI dependency
- **Graceful degradation** — if adapter functions fail, agents can manually edit files
- **Human-browsable** — open in any editor, scan folder structure
- **Git-trackable** — full history of status transitions, readable diffs
- **Zero dependencies** — no database, no runtime, no accounts

### Local PM folder structure

```
.sdlc/
├── .counter                              # Next sequential ID (simple integer)
├── .index.yml                            # ID → path mapping (auto-maintained)
├── backlog/
│   └── 001-calendar-tool/                # Goal (auto-incrementing ID prefix)
│       ├── item.md                       # Goal definition
│       ├── epics/
│       │   ├── e01-core/
│       │   │   ├── epic.md               # Epic definition
│       │   │   └── tasks/
│       │   │       ├── s01-api.md         # Task
│       │   │       └── s02-ui.md          # Task
│       │   └── e02-integration/
│       │       ├── epic.md
│       │       └── tasks/
│       │           └── s01-tests.md
│       └── history/                      # Comments, telemetry, activity log
│           ├── 2026-03-09T14:30-s01-started.md
│           ├── 2026-03-09T15:45-s01-review.md
│           └── 2026-03-09T15:50-s01-telemetry.md
```

### Work item file format

```markdown
---
id: 3
type: task                               # goal | epic | task
status: in_progress                      # backlog | planning | ready | in_progress | review | done | rejected
labels: [type/feature, difficulty/easy]
parent: e01-core
created: 2026-03-09T14:00:00Z
updated: 2026-03-09T15:30:00Z
---

# [#001/E01-S01] Calendar API endpoints

## Overview

Implement the GET and POST endpoints for calendar events...

## Acceptance Criteria

- [ ] GET /api/events returns list
- [ ] POST /api/events creates event
```

### ID system

Dual identification:
- **Sequential counter** (`.sdlc/.counter`) — for cross-references in commits and comments (`#7`)
- **Folder path** — canonical location, human-readable (`001-calendar-tool/epics/e01-core/tasks/s01-api.md`)
- **Index file** (`.sdlc/.index.yml`) — auto-maintained mapping between IDs and paths

### Hierarchy

Folder structure IS the hierarchy — no separate linking step needed:
- `backlog/001-calendar-tool/` = Goal
- `backlog/001-calendar-tool/epics/e01-core/` = Epic (child of Goal)
- `backlog/001-calendar-tool/epics/e01-core/tasks/s01-api.md` = Task (child of Epic)

### Approval gate

Status-based, consistent across all adapters:
- Designer/Planner sets item status to `review`
- Human runs `sdlc approve <id>` → sets status to `done`
- Orchestrator checks `pm_get_status <id>` before proceeding to next phase

For GitHub adapter: PR merge = approval (existing pattern preserved).

### `.sdlc/` committed to git

Default: **committed** (tracked in source control).
- Work items are project artifacts — team members and future sessions need visibility
- Git history provides audit trail of status transitions
- Agents in parallel sessions can discover current state

## Decision: Dashboard

### The constraint

Multiple agents work in parallel and update `.sdlc/` files concurrently. The dashboard must:
- Not be written by agents (avoids write conflicts)
- Show live data (not stale snapshots)
- Require no background service
- Provide rich visualization (Kanban board, telemetry, timelines)

### Decision: Ephemeral HTTP server with dynamic file reading

**Alternatives considered:**

| Option | No server | All browsers | Live data | Rich UI |
|--------|-----------|-------------|-----------|---------|
| **Static HTML regeneration** | Yes | Yes | No (stale on write conflicts) | Yes |
| **File System Access API** | Yes | No (Chrome/Edge only) | Yes | Yes |
| **Ephemeral HTTP server** | No (foreground process) | Yes | **Yes** | **Yes** |
| **CLI TUI (terminal)** | Yes | N/A | Yes | Limited |
| **VS Code webview** | Yes | N/A (VS Code only) | Yes | Yes |

### How it works

1. Human (or orchestrator, or hook) runs `sdlc dashboard`
2. A minimal HTTP server starts on `localhost:<port>`
3. Serves a self-contained SPA (`dashboard.html`) with embedded CSS/JS
4. SPA fetches `/api/items`, `/api/history`, etc. — endpoints that read `.sdlc/` files live
5. Auto-refreshes on interval (polling) or via filesystem watcher + SSE
6. Browser opens automatically
7. Server exits on Ctrl+C or idle timeout

**Key property:** Agents never touch the dashboard. They write `.sdlc/` files. The dashboard reads those files on demand. Zero write conflicts.

### Dashboard features

- **Kanban board** — visual column layout (backlog, planning, ready, in progress, review, done)
- **Item detail** — click to expand, see description, acceptance criteria, history
- **Activity feed** — recent status changes, comments, telemetry (from `history/` files)
- **Telemetry summary** — cost, tokens, duration per item
- **Dependency graph** — embedded Mermaid rendering
- **Auto-refresh** — polls for file changes, updates board live

### Dashboard launch options

The dashboard can be started in multiple ways — not just CLI:

| Trigger | How | When |
|---------|-----|------|
| **CLI command** | `sdlc dashboard` or `./scripts/sdlc-dashboard.sh` | Human wants to check in manually |
| **Orchestrator auto-start** | Orchestrator launches dashboard in Phase 0 (setup), kills on completion | Human watches agents work during a workflow run |
| **Claude Code hook** | `SessionStart` hook triggers dashboard when orchestrator agent is invoked | Automatic — no human action needed |
| **Claude Code skill** | `/dashboard` slash command | Human invokes from Claude Code session |
| **VS Code extension** (future) | Extension auto-starts server, renders in webview panel | Integrated into IDE — no separate browser tab |

All triggers launch the same `sdlc-dashboard.sh` script — different entry points, same dashboard.

### CLI fallback

For terminal-only environments (SSH, CI, headless):

```bash
sdlc board    # Renders ASCII Kanban in terminal
```

```
┌─ Backlog ──────┬─ Ready ──────────┬─ In Progress ───┬─ Review ────────┬─ Done ──────────┐
│                │ [#4] E01-S02     │ [#3] E01-S01    │                 │ [#1] Design doc │
│                │ Calendar UI      │ Calendar API    │                 │ [#2] Plan       │
│                │ 🟡 medium        │ 🟢 easy · haiku │                 │                 │
└────────────────┴──────────────────┴─────────────────┴─────────────────┴─────────────────┘
```

### Evolution path

```
Phase 1: Ephemeral server
         sdlc dashboard → browser → live Kanban board
         sdlc board → CLI table fallback

Phase 2: Add WebSocket for real-time push
         Agents write files → fs watcher → WS push → board updates instantly

Phase 3: VS Code extension wraps same UI
         Webview panel connects to localhost server
         Extension auto-starts server when workspace has .sdlc/
```

## Proposed Package Structure

```
claude-sdlc/                              # New standalone repo
├── README.md                             # Getting started guide
│
├── core/                                 # THE FRAMEWORK (project-agnostic)
│   ├── CLAUDE.md.template                # Workflow conventions with {{PLACEHOLDERS}}
│   │
│   ├── agents/                           # Generic agent definitions
│   │   ├── orchestrator.md
│   │   ├── planner.md
│   │   ├── designer.md
│   │   ├── builder.md
│   │   ├── builder-haiku.md
│   │   ├── builder-sonnet.md
│   │   ├── builder-opus.md
│   │   ├── reviewer.md
│   │   └── retro.md
│   │
│   ├── scripts/
│   │   ├── sdlc.sh                       # CLI entry point: sdlc <command> [args]
│   │   ├── sdlc-dashboard.sh             # Dashboard server launcher
│   │   ├── common.sh                     # Config loader + adapter resolver
│   │   ├── fetch-pricing.sh              # Anthropic pricing fetcher
│   │   └── templates/
│   │       ├── telemetry.md              # Telemetry rendering template
│   │       └── dashboard.html            # Self-contained dashboard SPA
│   │
│   └── workflows/                        # Optional GitHub Actions
│       ├── sentinel.yml
│       └── auto-close-issues.yml
│
├── adapters/
│   ├── pm/
│   │   ├── interface.md                  # PM adapter contract
│   │   ├── local/                        # DEFAULT — file-based task tracking
│   │   │   ├── pm-commands.sh            # All pm_* functions (reads/writes .sdlc/)
│   │   │   └── setup.sh                  # Creates .sdlc/ folder structure
│   │   └── github/                       # Opt-in — GitHub Issues + Projects
│   │       ├── pm-commands.sh            # All pm_* functions (wraps gh CLI)
│   │       ├── config.sh                 # REPO, PROJECT_ID, FIELD_ID, STATUS_IDS
│   │       └── setup.sh                  # Interactive: creates project, captures IDs
│   │
│   └── docs/
│       ├── interface.md                  # Doc adapter contract
│       ├── local/                        # DEFAULT — docs/ folder in git
│       │   └── docs-commands.sh          # All doc_* functions
│       └── notion/                       # Future opt-in
│           ├── docs-commands.sh
│           └── setup.sh
│
├── sdlc.config.default                   # Ships with pm=local, docs=local
├── install.sh                            # Copies framework into target project
└── examples/
    └── neuralnorris/                     # Reference: how NeuralNorris uses the framework
        ├── sdlc.config
        └── project-claude-section.md     # Example project-specific CLAUDE.md section
```

### Default config

```bash
# sdlc.config.default
SDLC_PM_ADAPTER=local           # local | github | jira | azure-boards
SDLC_DOCS_ADAPTER=local         # local | notion | confluence
SDLC_PROJECT_NAME=""            # Auto-detected from git repo name if blank
```

## CLI Entry Point

A single `sdlc` command wraps adapter calls:

```bash
# Setup
sdlc setup                               # Interactive setup wizard
sdlc connect github                      # Switch PM adapter to GitHub
sdlc connect notion --docs               # Switch Doc adapter to Notion

# Work item management
sdlc create goal "Calendar tool"         # Creates goal
sdlc create epic 1 "Core API"            # Creates epic under goal #1
sdlc create task 1 e01 "GET endpoint"    # Creates task under epic
sdlc status 3 in_progress                # Transitions status
sdlc approve 6                           # Approves a design/plan
sdlc close 3                             # Closes item

# Visibility
sdlc board                               # CLI Kanban board
sdlc dashboard                           # Opens browser dashboard (ephemeral server)

# Telemetry
sdlc telemetry 3 --model sonnet --duration 45000 --tokens 12000
sdlc comment 3 "Work started"            # Posts comment/history entry
```

## Agent Instruction Changes

Agents become intent-based instead of command-based:

### Before (GitHub-coupled)

```markdown
# In orchestrator.md
Set story to In Progress:
ITEM_ID=$(gh project item-list 1 --owner gavinkilbride --format json --limit 100 \
  | jq -r '.items[] | select(.content.number == 42) | .id')
gh project item-edit --project-id "PVT_kwHOAAywgM4BRGeY" --id "$ITEM_ID" \
  --field-id "PVTSSF_lAHOAAywgM4BRGeYzg_By8o" \
  --single-select-option-id "308bbc1e"
```

### After (adapter-agnostic)

```markdown
# In orchestrator.md
Set task to In Progress:
./scripts/sdlc.sh status <task-id> in_progress
```

### Tech-stack delegation

```markdown
# Before (in builder.md)
Run `dotnet test` to verify. Use xUnit + NSubstitute. Check NN.Core for interfaces.

# After (in builder.md)
Read the project's CLAUDE.md for build commands, test framework, and architecture conventions.
```

## Migration from NeuralNorris

### Phase 1: Create the new repo

1. Create `claude-sdlc` repo
2. Copy workflow files into `core/`
3. Move GitHub-specific parts into `adapters/pm/github/`
4. Create local PM adapter in `adapters/pm/local/`
5. Create local doc adapter in `adapters/docs/local/`

### Phase 2: Strip project knowledge

1. Remove all `.NET`, `NN.*`, Blazor, EF Core, SQLite references from agent files
2. Remove all `gh` CLI commands from agent files — replace with `sdlc.sh` calls
3. Add "Read the project's CLAUDE.md" delegation instructions
4. Keep process instructions (TDD workflow, lesson writing, branch conventions)

### Phase 3: Parameterize scripts

1. Create `common.sh` that sources `sdlc.config` and loads the right adapter
2. Replace hardcoded `REPO`, project IDs, status IDs with adapter function calls
3. Create `sdlc.sh` CLI entry point

### Phase 4: Build dashboard

1. Build ephemeral HTTP server (`sdlc-dashboard.sh`)
2. Build `dashboard.html` SPA (Kanban board, item detail, activity feed, telemetry)
3. Add orchestrator auto-launch hook
4. Build `sdlc board` CLI fallback

### Phase 5: Test with NeuralNorris

1. NeuralNorris adopts the framework + GitHub adapter
2. Project-specific sections stay in NeuralNorris's `CLAUDE.md`
3. Verify full workflow still works end-to-end

## Open Questions

1. **Distribution model** — Claude Code plugin vs template repo vs installable CLI? Plugin is best long-term (native agent/skill/hook support), but template repo is fastest to ship. Could start as template, evolve to plugin.

2. **How opinionated vs configurable?** — The 3-level hierarchy (Goal/Epic/Task), 6-agent model, TDD requirement, specific phase gates — should adopters opt out of phases or simplify? Leaning towards opinionated defaults with escape hatches.

3. **Multi-repo support** — Does the workflow assume one repo = one project? Monorepo with multiple `.sdlc/` directories? Cross-repo goals?

4. **Naming** — `claude-sdlc`? `agentic-sdlc`? Something else?

5. **Frontmatter parsing robustness** — Shell script `grep`/`sed` works for controlled format. Long-term, a small Python/Node script or Go binary for YAML parsing would be more robust. What's the right dependency to accept?

6. **Dashboard technology** — What runtime for the ephemeral server? Python (`http.server`), Node, Deno, Go binary? Python has broadest install base; Go binary has zero dependencies.

7. **Sync to external PM** — When a user connects GitHub/Jira after starting with local PM, how do existing `.sdlc/` items migrate? One-time sync script? Ongoing bidirectional sync?

## Next Steps: Brainstorming Backlog

The following topics need further brainstorming and decisions before implementation can begin. Pick up from here in the next session.

### 1. Distribution model

How should the framework be packaged and shared?

- **Claude Code plugin** — native integration (agents, skills, hooks, MCP servers ship together). Best long-term, but plugin system is still evolving.
- **Template repo** — GitHub "Use this template" button. Fastest to ship, but no upstream updates.
- **Installable CLI** — `npm install -g agentic-sdlc` or `brew install`. Clean UX, but heavy packaging.
- **Git submodule** — updatable and versioned, but submodule DX is painful.
- Could start as template repo and evolve to plugin. Discuss trade-offs, pick one.

### 2. How opinionated vs configurable?

The framework currently prescribes: 3-level hierarchy (Goal/Epic/Task), 6 agent roles, TDD in the builder, specific phase gates (design → plan → build → review → retro), lesson conventions, branch naming.

- Should adopters be able to skip phases? (e.g., no design phase for small projects)
- Should the agent set be configurable? (e.g., drop the designer, merge planner + planner)
- Should TDD be optional or enforced?
- Should the 3-level hierarchy be reducible to 2 levels for simpler projects?
- Leaning towards "opinionated defaults with escape hatches" — but need to define what the escape hatches look like.

### 3. Multi-repo support

- Does the workflow assume one repo = one project?
- Could a monorepo have multiple `.sdlc/` directories (one per package/service)?
- Could a Goal span multiple repos? (e.g., "Build OAuth" touches API repo + frontend repo)
- What changes in the adapter interface to support this?

### 4. Naming

- `claude-sdlc` — ties to Claude (vendor-specific?)
- `agentic-sdlc` — generic, but vague
- Something else? Should the name reflect that it's AI-agent-operated, not just a human PM tool?

### 5. Frontmatter parsing robustness

The local PM adapter needs to read/write YAML frontmatter in shell scripts. Options:
- `grep`/`sed` — zero dependencies, works for controlled single-line format, fragile on edge cases
- Python script — broad install base, robust YAML parsing, adds runtime dependency
- Node script — same trade-off as Python, less universal on servers
- Go binary — zero runtime dependencies, fast, but requires compilation and distribution
- Discuss: what dependency is acceptable for a "zero-config" tool?

### 6. Dashboard technology

The ephemeral HTTP server needs a runtime. Options:
- **Python** (`http.server` + custom handler) — broadest install base, ships with macOS/Linux
- **Node/Deno** — good for building the SPA, but not always pre-installed
- **Go binary** — zero dependencies, fast startup, but needs compilation per platform
- **Bash + `nc`/`socat`** — extreme minimalism, but painful to build a real API
- Consider: should the dashboard SPA be a separate concern (built with a JS framework) served by a minimal backend? Or a single self-contained script?

### 7. Sync to external PM

When a user starts with local PM (`.sdlc/` files) and later connects GitHub/Jira:
- One-time migration script? (`sdlc sync --to github` — creates issues from `.sdlc/` files)
- Ongoing bidirectional sync? (complex — conflict resolution, eventual consistency)
- One-way push only? (local → external, local remains source of truth)
- Or: just start fresh in the external tool and archive `.sdlc/`?
- This is a "nice to have" — not required for v1, but the adapter interface should not preclude it.

### 8. Adapter interface: shell functions vs MCP tools

Two approaches for the adapter layer (discussed in the plugin architecture appendix):
- **Shell functions** (`pm_create_item`, `doc_write`) — scripts source the adapter, call functions. Simple, works today.
- **MCP tools** (`pm_list_stories`, `docs_create`) — agents call MCP tools directly. Cleaner for agents, but requires building MCP servers.
- Could be evolutionary: shell functions for v1, MCP tools for v2 (plugin phase).
- Discuss: should both coexist? Should the shell functions be thin wrappers around MCP tool calls?

### 9. Approval gate design

The design/plan approval gate works differently per adapter:
- **Local:** `sdlc approve <id>` (human CLI command)
- **GitHub:** PR merge = approval
- **Jira:** Status transition or custom field
- **Notion:** Page property change
- Need to define the abstract contract clearly so all adapters can implement it consistently.
- Also: should the orchestrator block and poll, or should there be a callback/webhook mechanism?

### 10. Code hosting as a separate concern

The plugin architecture appendix defines a `code-hosting` interface (PRs, merges, reviews). Currently this is GitHub-only. Consider:
- Is code hosting always git-based? (yes, for this workflow)
- Is the PR/MR abstraction necessary, or can git operations stay as raw `git` commands?
- What about GitLab MRs, Bitbucket PRs, Azure Repos PRs?
- The branch strategy (integration branch, epic branches, story branches) is git-native and adapter-agnostic. Only PR creation/merging needs abstraction.

## Related Documents

- [Agentic SDLC v2 Design](2026-03-09-agentic-sdlc-v2-design.md) — Original workflow design
- [Plugin Architecture Appendix](2026-03-10-agentic-sdlc-plugin-architecture.md) — MCP-based adapter interfaces
- [Work Item Taxonomy](2026-03-11-agentic-sdlc-workitem-taxonomy.md) — Goal → Epic → Task naming decision
- [Issue Templates](2026-03-10-agentic-sdlc-issue-templates-design.md) — Template structure for work items
