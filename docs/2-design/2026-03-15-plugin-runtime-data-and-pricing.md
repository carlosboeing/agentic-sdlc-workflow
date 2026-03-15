---
date: 2026-03-15
author: orchestrator + human
status: draft
backlog: 56
scope: Design the runtime data directory structure and pricing architecture for the agentic workflow plugin
---

# Design: Plugin Runtime Data & Pricing Architecture

## Problem

The workflow plugin needs to store runtime data (per-run orchestrator state, cached pricing, logs) but has no clear convention for where this data lives. The current approach scatters files across `.claude/state/`, the config file, and script-level hardcoded defaults. Additionally, the pricing system has three competing sources of truth that disagree — causing a 2.6x cost underreport in Run 12.

## Competitive Research

### How other CC plugins handle runtime data

| Plugin | Stars | Runtime data location | Pattern |
|--------|-------|----------------------|---------|
| **claude-mem** ([thedotmack/claude-mem](https://github.com/thedotmack/claude-mem)) | 35K | `~/.claude-mem/` (global) + `plugin/data/` (project, gitignored) | Global user dir for settings/DB. Project-local for project-specific data. |
| **ruflo** ([ruvnet/ruflo](https://github.com/ruvnet/ruflo)) | 21K | `.claude-flow/`, `.agentic-flow/`, `.swarm/`, `/memory/`, `/coordination/` (project root, gitignored) | Multiple dot-directories at project root. Heavy use of local SQLite databases. |
| **ccpm** ([automazeio/ccpm](https://github.com/automazeio/ccpm)) | 7.6K | `ccpm/` directory copied into project's `.claude/` | Everything inside `.claude/` — context, epics, scripts, agents. Warning: conflicts with existing `.claude/` dirs. |
| **claude-workflow-v2** ([CloudAI-X/claude-workflow-v2](https://github.com/CloudAI-X/claude-workflow-v2)) | 1.3K | `.claude/` gitignored entirely | Static plugin — agents, hooks, skills, templates. No observed runtime state. |
| **flow-next** ([gmickel/gmickel-claude-marketplace](https://github.com/gmickel/gmickel-claude-marketplace)) | 545 | `.flow/` at project root | Plugin-named dot-directory. Partially committed (config, meta) + partially gitignored (checkpoints, receipts). Stores epics, tasks, specs as JSON. |
| **claude-orchestration** ([mbruhler/claude-orchestration](https://github.com/mbruhler/claude-orchestration)) | 198 | `temp-agents/`, `temp-scripts/` at plugin root | Flat gitignored directories for ephemeral generated files. |
| **superpowers** ([obra/superpowers](https://github.com/obra/superpowers)) | — | `.worktrees/` (project root) or `~/.config/superpowers/worktrees/` (global) | Two-tier: project-local dot-directory or global `~/.config/<plugin>/`. Asks user on first use. |
| **ed3d-plugins** ([ed3dai/ed3d-plugins](https://github.com/ed3dai/ed3d-plugins)) | 142 | N/A | Research-plan-implement workflow. Static plugin, no observed runtime state. |

### Patterns observed

1. **Project-scoped runtime data → dot-directory at project root** (`.flow/`, `.worktrees/`, `.claude-flow/`). Not inside `.claude/`.
2. **User-scoped persistent data → `~/.<plugin>/` or `~/.config/<plugin>/`** (global, survives across projects).
3. **Nobody nests plugin runtime data inside `.claude/`** — that directory is treated as CC platform territory. The exception (ccpm) explicitly warns about conflicts.
4. **Plugin-named directory** prevents collision with other plugins — `.flow/`, `.claude-flow/`, `.swarm/` are all namespaced.

## Design Decision

### Runtime data directory: `.agentic-workflow/`

A dot-directory at the project root, namespaced to the plugin. This follows the dominant pattern (flow-next, ruflo, superpowers) and avoids the `.claude/` conflict risk.

```
<project-root>/
  .agentic-workflow/           ← plugin runtime data (gitignored)
    pricing.json               ← cached pricing (cross-run, updated each run)
    runs/                      ← per-run orchestrator state
      <backlog-number>/
        orchestrator.json
    logs/                      ← workflow logs (future)
```

**Why `.agentic-workflow/` and not `.sdlc/`:** The workflow is used for content writing, documentation, and other non-SDLC workloads. "Agentic workflow" is more generic and better describes what the plugin does. The final plugin name is TBC.

**Gitignore:** The entire directory is gitignored. It contains only ephemeral and cached data — nothing that needs to be committed.

### Pricing architecture

Three-tier resolution with clear separation of concerns:

```
┌──────────────────────────────────┐
│  issue-telemetry.sh              │  ← Pure function, no pricing knowledge
│  Reads pricing from external     │
│  source, computes costs          │
└──────────┬───────────────────────┘
           │ reads (in priority order)
           │
  ┌────────┴────────┐
  │                 │
  ▼                 ▼
┌─────────────┐  ┌──────────────────────────────┐
│ Config      │  │ Cached pricing               │
│ (optional   │  │ .agentic-workflow/            │
│  override)  │  │   pricing.json               │
│             │  │                              │
│ For custom/ │  │ Written by fetch-pricing.sh  │
│ contract    │  │ on each run                  │
│ rates       │  └──────────┬───────────────────┘
└─────────────┘             │
                            │ populated by
                  ┌─────────┴───────────────────┐
                  │ fetch-pricing.sh             │
                  │                              │
                  │ Tier 1: Scrape               │
                  │   anthropic.com/pricing      │
                  │                              │
                  │ Tier 2: Community JSON        │
                  │   litellm model_prices JSON  │
                  │                              │
                  │ Tier 3: Local cache           │
                  │   (previous successful fetch) │
                  └──────────────────────────────┘
```

**Priority order for `issue-telemetry.sh`:**
1. **Config `pricing`** (if present in `agentic-sdlc-config.json`) → user override, skip fetching entirely
2. **Cached pricing** `.agentic-workflow/pricing.json` → normal path
3. **Neither exists** → cost column shows `—`, log a warning

**`fetch-pricing.sh` resolution chain:**
1. **Primary:** Scrape `https://www.anthropic.com/pricing` — HTML is parseable (Webflow, not JS-rendered content), picks latest version per model family
2. **Secondary:** Fetch `https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json` — community-maintained, reliable raw JSON, filter for `claude-opus-*`, `claude-sonnet-*`, `claude-haiku-*`
3. **Fallback:** Read existing `.agentic-workflow/pricing.json` from a previous successful fetch
4. **No data:** Exit with error, log warning — costs will show `—`

**When `fetch-pricing.sh` runs:** Orchestrator calls it in Phase 0 (session start). On success, it writes/updates `.agentic-workflow/pricing.json`. On failure, it falls back to cached data from a previous successful fetch.

**Plugin ships with a default `pricing.json`:** New users get reasonable defaults out of the box. Updated with each plugin release.

**Config `pricing` is an optional override:** If present, it completely replaces fetched rates (no merging). Intended for users with contract rates or air-gapped environments. Most users should delete the `pricing` section from their config entirely.

### tokenSplit

The `tokenSplit` (75% input / 25% output assumption) is baked into the script as a fixed constant, not user-configurable. Rationale:
- The Agent tool reports only total tokens, not the input/output split
- The 75/25 ratio is based on observed patterns across 12 test runs
- Cost estimates are already approximate (the disclaimer says so)
- Making this configurable adds surface area with negligible accuracy gain
- If a user truly cares about precision, they'd check their API dashboard

## What changes

| Current | New |
|---------|-----|
| `.claude/state/<N>/orchestrator.json` | `.agentic-workflow/runs/<N>/orchestrator.json` |
| `.claude/state/pricing.json` (didn't exist) | `.agentic-workflow/pricing.json` |
| `pricing` section required in config | `pricing` section optional (override only) |
| `fetch-pricing.sh` reads from config | `fetch-pricing.sh` scrapes web → writes cache |
| `issue-telemetry.sh` reads config `_cfg_blended_rate()` | `issue-telemetry.sh` reads cache file (config override if present) |
| `.claude/.gitignore` includes `state/` | Project `.gitignore` includes `.agentic-workflow/` |
| Hardcoded `$15/$75` Opus rates in config | Live rates from Anthropic ($5/$25 for Opus 4.6) |

## Out of scope (future)

- Moving `scripts/` into `.claude/` or plugin root (separate design)
- Moving `agents/` from `.claude/agents/` to plugin structure (separate design)
- Plugin packaging (`plugin.json`, marketplace) (see existing design doc)
- The final plugin name (TBC — "agentic workflow" is a working name)

## Open questions

1. **Should the plugin ship a default `pricing.json` that gets placed on install?** Or should the first run just fetch live? (Recommendation: ship a default so offline/air-gapped users have something.)
2. **Should logs move to `.agentic-workflow/logs/`?** Currently in `.claude/logs/`. (Recommendation: yes, in a future PR — keeps all plugin runtime data together.)
