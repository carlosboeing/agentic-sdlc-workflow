---
title: "Appendix: Agentic SDLC as a Claude Code Plugin"
type: design
authors: ["Carlos Boeing"]
date: 2026-03-10
agent: designer
status: draft
parent: 2026-03-09-agentic-sdlc-v2-design.md
---

# Appendix: Agentic SDLC as a Claude Code Plugin

> Historical record (March 2026). Measurements come from controlled synthetic workloads and early infrastructure runs; see [case studies](../case-studies.md) for scoped findings.

> Appendix to [Agentic SDLC Workflow v2](2026-03-09-agentic-sdlc-v2-design.md)

## Motivation

The host project SDLC workflow (orchestrator, designer, planner, builder, reviewer, retro) is currently tightly coupled to GitHub. Every script, agent instruction, and convention embeds `gh` CLI commands, GitHub-specific `jq` queries, project board option IDs, and GitHub vocabulary (issues, PRs, labels).

This coupling creates two problems:

1. **Swapping tools is a full rewrite.** Moving from GitHub Issues to Linear, or from GitHub Projects to Jira, means rewriting every script, every agent `.md` file, and re-mapping concepts (work items vs issues, iterations vs milestones).

2. **The workflow itself is valuable beyond the host project.** The agentic SDLC pattern — specialized agents for each phase, difficulty-based model routing, living lessons, self-improvement loops — is general-purpose. Packaging it as a CC plugin would let any team adopt it with their own tool stack.

## Current Coupling

Three layers bind the workflow to GitHub:

| Layer | Examples | Impact of swap |
|-------|----------|---------------|
| **Scripts** | `gh issue list`, `gh pr create`, `gh project item-edit`, `item-start.sh`, `item-telemetry.sh` | Rewrite every script |
| **Agent instructions** | Literal `gh` commands and `jq` queries in orchestrator, planner, designer `.md` files | Rewrite every agent file |
| **Concepts** | "Issues", "PRs", "labels", "project board option IDs" baked into CLAUDE.md and conventions | Re-map vocabulary throughout |

Additionally, `dispatch-workflow.sh` and the orchestrator agent duplicate orchestration logic — the script as deterministic bash, the agent as LLM-interpreted prose. Both embed the same GitHub-specific operations.

## Proposed Architecture

### Layered Design

```
┌─────────────────────────────────────────────┐
│  CC Plugin: "agentic-sdlc"                  │
│                                             │
│  Agents    orchestrator, designer,          │
│            planner, builder, reviewer,     │
│            retro                            │
│                                             │
│  Skills    brainstorming, writing-plans,    │
│            TDD, debugging, etc.             │
│                                             │
│  Config    provider mapping + project setup  │
└────────────────┬────────────────────────────┘
                 │ calls generic MCP tools
┌────────────────▼────────────────────────────┐
│  MCP Tool Interfaces (defined by plugin)    │
│                                             │
│  "project-board"   list_stories,            │
│                    update_status,           │
│                    create_epic, ...         │
│                                             │
│  "code-hosting"    create_pr, merge_pr,     │
│                    merge_branch, ...        │
│                                             │
│  "docs-platform"   create_doc, search, ...  │
│                    (optional — filesystem    │
│                    default for repo-based)   │
└────────────────┬────────────────────────────┘
                 │ implemented by
┌────────────────▼────────────────────────────┐
│  Provider MCP Servers (swap in/out)         │
│                                             │
│  ┌──────────┐ ┌────────┐ ┌───────────────┐ │
│  │ GitHub   │ │ Linear │ │ Azure DevOps  │ │
│  │ Issues + │ │ +      │ │ Boards +      │ │
│  │ PRs +    │ │ GitHub │ │ Repos +       │ │
│  │ Projects │ │ PRs    │ │ Pipelines     │ │
│  └──────────┘ └────────┘ └───────────────┘ │
│  ┌──────────┐ ┌────────┐ ┌───────────────┐ │
│  │ Jira +   │ │ Notion │ │ GitLab        │ │
│  │ GitHub   │ │ + ...  │ │ (all-in-one)  │ │
│  └──────────┘ └────────┘ └───────────────┘ │
└─────────────────────────────────────────────┘
```

### Mix-and-Match Providers

Real teams don't use one vendor for everything. A typical setup might be:

- **Jira** for project tracking + **GitHub** for code hosting + **Confluence** for docs
- **Linear** for tracking + **GitHub** for code + **Notion** for docs
- **Azure DevOps** for everything (all-in-one)
- **GitHub** for everything (the current the host project setup)

The interface separation (`project-board`, `code-hosting`, `docs-platform`) lets users compose providers independently. Each interface maps to one or more MCP servers. The plugin config declares which server handles which interface.

### CC Plugin Structure

Claude Code plugins can ship agents, skills, hooks, and MCP server configurations — the exact combination needed:

| Plugin component | Maps to |
|-----------------|---------|
| **Agents** | Orchestrator, designer, planner, builder, reviewer, retro `.md` files |
| **Skills** | Brainstorming, writing-plans, TDD, debugging, code review |
| **Hooks** | Pre-commit test runs, post-merge cleanup |
| **MCP servers** | Reference GitHub provider; users configure their own |
| **Config** | Project setup, provider mapping, model routing preferences |

## MCP Tool Interfaces

The plugin defines these interfaces. Provider MCP servers implement them.

### project-board

Manages work items (stories, epics, backlog items) and their lifecycle.

| Tool | Parameters | Returns | Notes |
|------|-----------|---------|-------|
| `pm_list_stories` | `epic_id: string` | `[{id, title, difficulty, state, labels}]` | Filtered to stories only (not epics) |
| `pm_get_story` | `id: string` | `{id, title, body, difficulty, state, labels, parent_id}` | Full story details including acceptance criteria |
| `pm_create_story` | `title, body, labels[], parent_id` | `{id, url}` | Creates and links to parent |
| `pm_create_epic` | `title, body, labels[], parent_id` | `{id, url}` | Creates and links to backlog item |
| `pm_update_status` | `id, status: "backlog"\|"planned"\|"todo"\|"in_progress"\|"in_review"\|"done"` | `{success}` | Generic statuses mapped to provider-specific values |
| `pm_close_item` | `id, reason?: string` | `{success}` | Closes with optional reason |
| `pm_discover_epic` | `backlog_id: string` | `{slug, label, branch, issue_id}` | Finds epic from backlog item |
| `pm_post_comment` | `id, body: string` | `{comment_id}` | For telemetry, review findings, status updates |
| `pm_get_comments` | `id` | `[{author, body, created_at}]` | For idempotent restart checks |
| `pm_create_label` | `name, description?, color?` | `{success}` | Idempotent — no-op if exists |

### code-hosting

Manages branches, pull/merge requests, and code review.

| Tool | Parameters | Returns | Notes |
|------|-----------|---------|-------|
| `code_create_pr` | `head, base, title, body` | `{id, number, url}` | Creates pull/merge request |
| `code_merge_pr` | `id, strategy: "merge"\|"squash"\|"rebase"` | `{success, sha}` | Merges and optionally deletes source branch |
| `code_list_prs` | `state?: "open"\|"merged"\|"closed", head?: string` | `[{id, number, state, head, base}]` | Filter by state and/or head branch |
| `code_get_pr` | `id` | `{id, number, state, title, body, head, base, mergeable}` | Full PR details |
| `code_post_review` | `pr_id, body, verdict: "approve"\|"request_changes"\|"comment"` | `{review_id}` | For reviewer agent findings |

Git operations (branch creation, merging, pushing) remain as direct `git` commands — they're provider-agnostic already.

### docs-platform (optional)

For teams that store docs outside the repo (Confluence, Notion). Default implementation: filesystem (markdown files in the repo), which requires no MCP server.

| Tool | Parameters | Returns | Notes |
|------|-----------|---------|-------|
| `docs_create` | `title, content, location, type: "design"\|"plan"\|"retro"\|"adr"` | `{id, url}` | Creates doc in the platform |
| `docs_search` | `query, location?` | `[{id, title, url, snippet}]` | Search by content or metadata |
| `docs_update` | `id, content` | `{success}` | Update existing doc |

## Agent Instruction Changes

Agent `.md` files become **intent-based** instead of **command-based**:

```markdown
# Before (GitHub-coupled orchestrator)
1. Read stories:
   gh issue list --label "epic/$SLUG" --state open --limit 50 --json number,title,labels

2. Update board status:
   ITEM_ID=$(gh project item-list <project-number> --owner <owner> --format json --limit 100 \
     | jq -r '.items[] | select(.content.number == 42) | .id')
   gh project item-edit --project-id "<project-id>" --id "$ITEM_ID" \
     --field-id "<status-field-id>" \
     --single-select-option-id "47fc9ee4"

# After (provider-agnostic orchestrator)
1. Read stories:
   Call pm_list_stories with epic_id

2. Update board status:
   Call pm_update_status with id and status "in_progress"
```

The agent instructions shrink significantly. Provider-specific complexity (option IDs, `jq` queries, pagination) moves into the MCP server.

## Script Consolidation

With MCP tools handling project management and code hosting operations, the current scripts either shrink or disappear:

| Current script | MCP replacement | Remaining purpose |
|---------------|----------------|-------------------|
| `item-start.sh` | `pm_update_status(id, "in_progress")` + `pm_post_comment(id, "Work Started")` | None — agents call MCP directly |
| `item-review.sh` | `pm_update_status(id, "in_review")` + `pm_post_comment(id, "Ready for Review")` | None |
| `item-telemetry.sh` | `pm_post_comment(id, formatted_telemetry)` | Telemetry formatting logic (could be a skill or utility) |
| `issue-merged.sh` | `pm_close_item(id)` + `pm_update_status(id, "done")` | None |
| `dispatch-story.sh` | Orchestrator agent calls builder subagent directly | None |
| `dispatch-workflow.sh` | Orchestrator agent is the workflow | None — or thin CLI wrapper that invokes `claude --agent orchestrator` |

The helper scripts were necessary because agents couldn't reliably construct complex `gh` + `jq` pipelines. With MCP tools, the operations are simple tool calls that agents handle natively.

## Migration Path

### Phase 1: Helper Script Extraction (near-term)

Extract shared operations from `dispatch-workflow.sh` into focused helper scripts that both the script and the orchestrator agent can call. This is a consolidation step — no architecture change.

New scripts:
- `scripts/epic-discover.sh <backlog-issue>` — returns epic slug, label, branch, issue number
- `scripts/story-list.sh <epic-label>` — returns story numbers with metadata
- `scripts/story-merge.sh <story-branch> <epic-branch>` — merge with conflict handling
- `scripts/epic-pr.sh <epic-branch> <backlog-issue> [story-issues...]` — creates PR with Closes links

Update orchestrator agent to call these scripts instead of inlining equivalent logic.

### Phase 2: GitHub MCP Server (mid-term)

Build a GitHub-specific MCP server implementing the `project-board` and `code-hosting` interfaces defined above. Replace helper scripts and inline `gh` commands with MCP tool calls.

- Implement the tool interfaces as a Node.js or Python MCP server
- Configure the MCP server in `.claude/settings.json` or plugin config
- Update agent `.md` files to use MCP tool calls instead of `gh` commands
- Retire helper scripts as their operations move into the MCP server
- Keep `dispatch-workflow.sh` as a thin CLI entry point (or remove it)

### Phase 3: CC Plugin Extraction (long-term)

Extract agents, skills, and the GitHub MCP server from the host project into a standalone CC plugin.

- Package agent `.md` files, skills, and hooks into the plugin format
- Ship the GitHub MCP server as the reference provider
- Define plugin config schema (project name, provider mapping, model routing preferences)
- Document the MCP tool interfaces as the provider contract
- the host project becomes a consumer of the plugin (dogfooding)

### Phase 4: Additional Providers (community)

Build or accept community-contributed MCP servers for other platforms:

- Linear + GitHub (code hosting separate from tracking)
- Jira + GitHub/GitLab
- Azure DevOps (all-in-one: boards, repos, pipelines)
- GitLab (all-in-one: issues, MRs, CI)
- Notion/Confluence for docs-platform interface

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| MCP over code-level abstraction (`IProjectBoard`) | Consumers are LLM agents, not C# code. Agents consume MCP tools natively. A code interface would still require shell-outs — the abstraction would leak. |
| Three interfaces, not one | Teams mix providers (Jira + GitHub + Confluence). One monolithic interface forces all-or-nothing adoption. |
| `docs-platform` is optional | Most teams store docs in the repo. Only teams using Confluence/Notion need this interface. Filesystem is the zero-config default. |
| Git operations stay as direct commands | `git` is already provider-agnostic. Wrapping it in MCP adds indirection without value. Only hosting-platform operations (PRs, reviews) need abstraction. |
| Generic status values | `"in_progress"` instead of option ID `47fc9ee4`. The MCP server maps generic → provider-specific. Agents never see provider internals. |
| Plugin ships reference provider | The GitHub MCP server ships with the plugin so it works out of the box. Other providers are optional add-ons. |

## Open Questions

1. **Plugin config UX** — How does a user configure which MCP server handles which interface? Per-project `.claude/settings.json`? Plugin-specific config file?
2. **Provider capability gaps** — Not all providers support all operations (e.g., Linear has no "project board" concept like GitHub Projects). How do we handle missing capabilities — error, fallback, or degrade gracefully?
3. **Auth management** — Each MCP server needs its own auth (GitHub token, Jira API key, Linear API key). Should the plugin manage a unified credential store, or delegate to each server?
4. **Schema evolution** — As the MCP tool interfaces evolve, how do we version them without breaking existing providers?
5. **Telemetry formatting** — `item-telemetry.sh` has significant formatting logic (cost calculation, speed, breakdown tables). Should this be a skill, a utility in the plugin, or part of the MCP server?
