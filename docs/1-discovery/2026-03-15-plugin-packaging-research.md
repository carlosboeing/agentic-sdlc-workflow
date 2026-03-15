---
date: 2026-03-15
author: analysis
scope: Research and brainstorming for packaging the agentic SDLC workflow as a Claude Code plugin
---

# Plugin Packaging Research & Brainstorming

## Context

The agentic SDLC workflow has been validated across 11 test runs with 100% completion rate and a 17-story zero-fix streak. The next step is making the workflow configurable and eventually packaging it as a Claude Code plugin for community use.

Key insight: although designed for software development, the test runs prove the workflow handles creative content (markdown docs, fictional reports) equally well. The pipeline is domain-agnostic: **decompose work > plan it > dispatch parallel workers > review quality > learn from the run**.

---

## Claude Code Plugin Architecture

### What Plugins Can Package

| Component | Plugin directory | Description |
|-----------|-----------------|-------------|
| Agents | `agents/` | Specialized subagents (orchestrator, builder, reviewer, etc.) |
| Skills | `skills/` | Model-invoked capabilities with SKILL.md |
| Commands | `commands/` | Custom slash commands |
| Hooks | `hooks/hooks.json` | Event handlers (SessionStart, PostToolUse, etc.) |
| MCP servers | `.mcp.json` or `plugin.json` | External tool integration |
| Scripts | Referenced from hooks/skills | Shell scripts for automation |

### Key Findings

- **No native plugin settings/config mechanism.** There's no `plugin.settings` field, no settings UI for plugins. Configuration is an application-level concern — you design it using files, env vars, or CLAUDE.md.
- **`${CLAUDE_PLUGIN_ROOT}`** is the only plugin-aware env var — use it for all paths in hooks, MCP servers, scripts.
- **All paths in plugin.json must be relative** and start with `./`.
- **`.claude-plugin/` contains ONLY manifests** — skills, commands, agents go at plugin root.
- **Plugins are loaded at session start** — no hot-reloading of agent files.

### Plugin Configuration Pattern (chosen)

**Approach: Config file with code-level defaults (Approach 2)**

- A JSON config file in the consumer project (`.claude/agentic-sdlc-config.json`)
- Scripts and agents have sensible defaults baked in
- Users only provide what's required (GitHub project info) or what they want to override
- No separate defaults file, no layered merge logic
- Minimal config to get started:

```json
{
  "github": { "projectNumber": 7, "owner": "carlosboeing" }
}
```

**Why not other approaches:**
- Full config (no defaults): Bad onboarding — 20+ fields to fill
- Env vars: Don't scale for complex/nested config
- CLAUDE.md injection: Redundant — agents can read JSON directly
- Layered config (3 files): Unnecessary complexity for now; easy to add later

### Config Sections (chosen)

| Section | What it centralizes | Default behavior |
|---------|-------------------|-----------------|
| `github` | Project number, owner, project ID | **Required** — no sensible default |
| `boardStatus` | Status option IDs | Default to current project's IDs |
| `modelRouting` | difficulty > model mapping | easy: sonnet, medium: sonnet, hard: opus |
| `workflow` | Behavioral toggles | Auto-merge plans, don't skip retro, max 3 parallel |
| `pricing` | Fallback token rates per model | Current Anthropic rates |

Deferred: `labels` (hierarchy/*, difficulty/*) and `branches` (naming patterns) — more structural, less value from centralizing now.

---

## Competitive Landscape (as of 2026-03-15)

### Direct Competitors

| Plugin | Repo | Overlap | Key Difference |
|--------|------|---------|----------------|
| **CCPM** | automazeio/ccpm | High — GitHub Issues, parallel agents, worktrees, PRD>Epic>Task>Code | No review/retro loop, no telemetry, no self-healing conventions, no board management |
| **Ruflo** (fka Claude Flow) | ruvnet/ruflo | Medium — multi-agent orchestration, model routing | Much broader scope (swarm intelligence, IPFS distribution). Platform/framework, not a workflow |
| **claude-code-workflow-orchestration** | barkain/claude-code-workflow-orchestration | Medium — task decomposition, parallel agents | Lighter weight — no GitHub integration, no review/retro, no telemetry |

### Names Already Taken

`agents`, `workflow`, `orchestration`, `ccpm`, `ruflo`, `claude-flow`, `task-master`, `dev-workflows`, `full-stack-orchestration`, `pipeline`, `claude-code-workflows`, `agentsys`, `cadence` (used by catlog22)

### Name Candidates (unclaimed as of 2026-03-15)

| Name | Vibe | Notes |
|------|------|-------|
| `forge` | Making/crafting things | Short, memorable, uncommon in CC plugin space |
| `rally` | Coordinating toward a goal | PM connotation (Rally was a PM tool) |
| `dispatch` | Sending workers to do jobs | Descriptive of core mechanic |
| `conveyor` | Assembly line / pipeline | Visual metaphor for workflow stages |
| `workbench` | Where things get made | Generic but evocative |

### What Makes This Workflow Unique

None of the competitors have the **full lifecycle with quality gates**: design > plan > build > review > retro > telemetry. CCPM is closest but stops at "code + commit." The self-healing convention loop (retro proposes changes > next run loads them) is unique — it's what drove the 17-story zero-fix streak.

---

## Proposed Plugin Structure (future)

```
agentic-sdlc-plugin/
+-- .claude-plugin/
|   +-- plugin.json
+-- agents/
|   +-- orchestrator.md
|   +-- designer.md
|   +-- planner.md
|   +-- builder.md
|   +-- builder-sonnet.md
|   +-- builder-opus.md
|   +-- reviewer.md
|   +-- retro.md
+-- skills/
|   +-- sdlc-workflow/
|       +-- SKILL.md          <- teaches Claude the methodology
+-- commands/
|   +-- dispatch.md           <- /dispatch <issue>
|   +-- board-status.md       <- /board-status <issue> <status>
|   +-- new-backlog.md        <- /new-backlog
|   +-- telemetry.md          <- /telemetry <issue>
+-- hooks/
|   +-- hooks.json
+-- scripts/
|   +-- issue-set-status.sh
|   +-- issue-telemetry.sh
|   +-- ...
+-- templates/
|   +-- telemetry.md
+-- README.md
```

Consumer project config: `.claude/agentic-sdlc-config.json`

---

## Incremental Path Toward Plugin

| Step | What | Value Now | Plugin Prerequisite |
|------|------|-----------|-------------------|
| 1 | Extract config from hardcoded values into `.claude/agentic-sdlc-config.json` | Eliminates 5-file duplication, makes routing configurable | Yes — foundation for all config |
| 2 | Move scripts alongside agents (under `.claude/` or plugin root) | Better organization | Yes — scripts must travel with plugin |
| 3 | Add slash commands for common operations | UX improvement | Nice-to-have |
| 4 | Create SKILL.md that teaches the methodology | Replaces CLAUDE.md workflow sections | Yes — core of the plugin |
| 5 | Package as plugin with plugin.json | Distributable | Final step |
| 6 | Add `/sdlc-setup` command for onboarding | Community adoption UX | Nice-to-have |

---

## Sources

- [CCPM - Claude Code Project Manager](https://github.com/automazeio/ccpm)
- [Ruflo - Agent Orchestration Platform](https://github.com/ruvnet/ruflo)
- [claude-code-workflow-orchestration](https://github.com/barkain/claude-code-workflow-orchestration)
- [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code)
- [awesome-claude-code-toolkit](https://github.com/rohitg00/awesome-claude-code-toolkit)
- [Anthropic Official Plugins](https://github.com/anthropics/claude-plugins-official)
- [Claude Code Plugins Docs](https://code.claude.com/docs/en/plugins-reference)
- [Claude Code Settings Docs](https://code.claude.com/docs/en/settings)
