---
title: "Design: Plugin Runtime Data & Pricing Architecture"
type: design
authors: ["Carlos Boeing"]
date: 2026-03-15
agent: orchestrator
status: approved
backlog: 56
scope: Design the runtime data directory structure and pricing architecture for the agentic workflow plugin
---

# Design: Plugin Runtime Data & Pricing Architecture

> Historical record (March 2026). Measurements come from controlled synthetic workloads and early infrastructure runs; see [case studies](../case-studies.md) for scoped findings.

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

---

## Complete file inventory

Everything that makes the workflow work, categorized by type:

### Static files (committed to source control)

| Current location | Purpose |
|-----------------|---------|
| `.claude/agents/orchestrator.md` | Workflow orchestration agent |
| `.claude/agents/designer.md` | Feature design agent |
| `.claude/agents/planner.md` | Implementation planning agent |
| `.claude/agents/builder.md` | Story builder (base) |
| `.claude/agents/builder-sonnet.md` | Builder variant (sonnet model) |
| `.claude/agents/builder-opus.md` | Builder variant (opus model) |
| `.claude/agents/builder-haiku.md` | Builder variant (haiku model) |
| `.claude/agents/reviewer.md` | Code review agent |
| `.claude/agents/retro.md` | Retrospective agent |
| `.claude/hooks/log-tool.sh` | PostToolUse hook for orchestrator logging |
| `.claude/hooks/log-filter.conf` | Allowlist for which commands to log |
| `.claude/settings.json` | CC platform settings (hooks config) |
| `.claude/agentic-sdlc-config.json` | Plugin config (GitHub project, board IDs, model routing, pricing override) |
| `scripts/item-set-status.sh` | Set board status for an issue |
| `scripts/item-telemetry.sh` | Post telemetry to issues/PRs |
| `scripts/item-create.sh` | Create backlog item with board setup |
| `scripts/item-start.sh` | Post "Work Started" comment |
| `scripts/item-review.sh` | Post "Ready for Review" comment |
| `scripts/item-close.sh` | Close issue and set board to Done |
| `scripts/fetch-pricing.sh` | Fetch/cache API pricing |
| `scripts/dispatch-story.sh` | CLI dispatch for story builders |
| `scripts/dispatch-workflow.sh` | CLI full lifecycle orchestration |
| `scripts/cleanup-post-merge.sh` | Post-merge branch/state cleanup |
| `scripts/check-board-drift.sh` | Diagnostic: detect board status drift |
| `scripts/validate-logs.sh` | Report on log files |
| `scripts/setup-labels.sh` | Create GitHub labels (idempotent) |
| `scripts/lib/config.sh` | Shared config reader library |
| `scripts/templates/telemetry.md` | Telemetry comment template |
| `CLAUDE.md` | Workflow conventions and instructions (~604 lines) |

### Runtime files (gitignored, ephemeral)

| Current location | Purpose | Written by |
|-----------------|---------|-----------|
| `.claude/state/<N>/orchestrator.json` | Per-run workflow state | Orchestrator |
| `.claude/logs/board-status.log` | Board status change log | `item-set-status.sh` |
| `.claude/logs/orchestrator.log` | Orchestrator activity log | `log-tool.sh` hook |
| `.claude/logs/board-drift.log` | Board drift detection log | `check-board-drift.sh` |
| `.claude/worktrees/` | Worktree artifacts | CC Agent tool |
| `.dispatch/story-<N>.md` | CLI dispatch prompt files | `dispatch-story.sh` |

### Proposed plugin structure

```
<project-root>/
│
│   ── Static (committed) ──────────────────────────────────
│
├── .claude/
│   ├── settings.json                    ← CC platform (hooks config)
│   ├── agentic-sdlc-config.json         ← Plugin config (rename TBC)
│   ├── agents/                          ← Agent definitions (9 files)
│   │   ├── orchestrator.md
│   │   ├── designer.md
│   │   ├── planner.md
│   │   ├── builder.md / builder-{sonnet,opus,haiku}.md
│   │   ├── reviewer.md
│   │   └── retro.md
│   └── hooks/                           ← Hook scripts
│       ├── log-tool.sh
│       └── log-filter.conf
│
├── scripts/                             ← Workflow scripts
│   ├── item-set-status.sh
│   ├── item-telemetry.sh
│   ├── item-create.sh
│   ├── item-start.sh
│   ├── item-review.sh
│   ├── item-close.sh
│   ├── fetch-pricing.sh
│   ├── dispatch-story.sh
│   ├── dispatch-workflow.sh
│   ├── cleanup-post-merge.sh
│   ├── check-board-drift.sh
│   ├── validate-logs.sh
│   ├── setup-labels.sh
│   ├── lib/
│   │   └── config.sh                   ← Shared config reader
│   └── templates/
│       └── telemetry.md                 ← Telemetry comment template
│
├── CLAUDE.md                            ← Workflow conventions
│
│   ── Runtime (gitignored) ────────────────────────────────
│
└── .agentic-workflow/                   ← All plugin runtime data
    ├── pricing.json                     ← Cached pricing (cross-run)
    ├── runs/                            ← Per-run state
    │   └── <backlog-number>/
    │       └── orchestrator.json
    ├── logs/                            ← Workflow logs
    │   ├── board-status.log
    │   ├── orchestrator.log
    │   └── board-drift.log
    ├── dispatch/                        ← CLI dispatch prompts
    │   └── story-<N>.md
    └── worktrees/                       ← Worktree artifacts
```

**Note on future plugin packaging:** When this becomes a CC plugin, the static files (agents, scripts, hooks, templates) will move into the plugin package. The runtime directory (`.agentic-workflow/`) stays in the consumer project. The config file may move to the plugin root with project-specific overrides in the consumer. This is a future design — see `docs/1-discovery/2026-03-15-plugin-packaging-research.md`.

---

## Decisions

### 1. Runtime data directory: `.agentic-workflow/`

A dot-directory at the project root, namespaced to the plugin. This follows the dominant pattern (flow-next, ruflo, superpowers) and avoids the `.claude/` conflict risk.

```
<project-root>/
  .agentic-workflow/                 ← plugin runtime data (gitignored)
    pricing.json                     ← cached pricing (cross-run, updated each run)
    runs/                            ← per-run orchestrator state
      <backlog-number>/
        orchestrator.json
    logs/                            ← workflow logs
```

**Why `.agentic-workflow/` and not `.sdlc/`:** The workflow is used for content writing, documentation, and other non-SDLC workloads. "Agentic workflow" is more generic and better describes what the plugin does. The final plugin name is TBC.

**Gitignore:** The entire directory is gitignored. It contains only ephemeral and cached data — nothing that needs to be committed.

**Migration:** Move everything from `.claude/state/` and `.claude/logs/` into `.agentic-workflow/`. Update `.claude/.gitignore` to remove `state/` and `logs/`. Add `.agentic-workflow/` to the project root `.gitignore`.

**Plugin ships a default `pricing.json`:** New users get reasonable pricing out of the box. The default file is updated with each plugin release so it stays approximately current. When the orchestrator runs `fetch-pricing.sh`, it overwrites this with live data.

### 2. Pricing: web-fetched, locally cached, config-overridable

#### Source of truth: Anthropic's pricing page

Pricing data is dynamic — it changes when Anthropic releases new models or adjusts rates. The script should not contain hardcoded rates. Instead:

```
┌──────────────────────────────────┐
│  item-telemetry.sh              │  ← Pure function, no pricing knowledge
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

#### `item-telemetry.sh` reads pricing (priority order)

1. **Config `pricing`** (if present in `agentic-sdlc-config.json`) → user override, skip cache entirely
2. **Cached pricing** `.agentic-workflow/pricing.json` → normal path (written by `fetch-pricing.sh`)
3. **Neither exists** → cost column shows `—`, log a warning explaining why

#### `fetch-pricing.sh` fetches and caches (resolution chain)

1. **Tier 1 — Primary:** Scrape `https://www.anthropic.com/pricing`. The HTML is parseable (Webflow site with pricing in rendered content). Parse model names, versions, input/output rates. Pick the latest version per model family (Opus, Sonnet, Haiku).
2. **Tier 2 — Secondary:** Fetch `https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json`. Community-maintained, reliable raw JSON. Filter for latest `claude-opus-*`, `claude-sonnet-*`, `claude-haiku-*` entries.
3. **Tier 3 — Fallback:** Read existing `.agentic-workflow/pricing.json` from a previous successful fetch. The file persists across runs, so a successful fetch in Run 11 covers a failed fetch in Run 12.
4. **No data:** Exit with error, log warning. `item-telemetry.sh` will show `—` for costs and post a message explaining why costs couldn't be calculated.

On successful fetch (Tier 1 or 2), the script writes/updates `.agentic-workflow/pricing.json`.

#### When `fetch-pricing.sh` runs

The orchestrator calls it in **Phase 0** (session start), before any agents are dispatched. This ensures pricing is available for all telemetry posts during the run.

#### Config `pricing` is an optional override

If `pricing` exists in `agentic-sdlc-config.json` and is properly set, it **completely replaces** fetched rates — no merging, no fetching. The orchestrator skips `fetch-pricing.sh` entirely.

Intended for:
- Users with contract/negotiated rates
- Air-gapped environments with no internet access
- Testing specific rate assumptions

Most users should **not** have a `pricing` section in their config. The default path (live fetch → cache) handles everything automatically.

#### Cache file format

```json
{
  "source": "anthropic-pricing-page",
  "source_detail": "opus:4.6, sonnet:4.6, haiku:4.5",
  "fetched_at": "2026-03-15T05:25:48Z",
  "rates": {
    "opus": { "inputPerM": 5.00, "outputPerM": 25.00 },
    "sonnet": { "inputPerM": 3.00, "outputPerM": 15.00 },
    "haiku": { "inputPerM": 1.00, "outputPerM": 5.00 }
  }
}
```

### 3. tokenSplit: fixed constant in the script

The `tokenSplit` (75% input / 25% output assumption) is baked into `item-telemetry.sh` as a fixed constant, not user-configurable and not stored in any external file. Rationale:
- The Agent tool reports only total tokens, not the input/output split
- The 75/25 ratio is based on observed patterns across 12 test runs
- Cost estimates are already approximate (the disclaimer says so)
- Making this configurable adds surface area with negligible accuracy gain
- If a user truly cares about precision, they'd check their API dashboard

The constant lives in the cost computation function alongside the formula, not in the config or cache files. It is a property of *how we estimate*, not of *what the rates are*.

### 4. Logs move to `.agentic-workflow/logs/`

Currently in `.claude/logs/`. Moving them to `.agentic-workflow/logs/` consolidates all plugin runtime data in one place. This is consistent with the principle that `.claude/` is CC platform territory.

---

## Runtime file inventory (current → new)

All workflow runtime files are currently scattered across three locations. This design consolidates them into `.agentic-workflow/`.

| Current location | What | Written by | New location |
|-----------------|------|-----------|--------------|
| `.claude/state/<N>/orchestrator.json` | Per-run workflow state | Orchestrator | `.agentic-workflow/runs/<N>/orchestrator.json` |
| `.claude/logs/board-status.log` | Board status change log | `item-set-status.sh` | `.agentic-workflow/logs/board-status.log` |
| `.claude/logs/orchestrator.log` | Orchestrator activity log | CC hooks | `.agentic-workflow/logs/orchestrator.log` |
| `.claude/logs/board-drift.log` | Board drift detection log | `check-board-drift.sh` | `.agentic-workflow/logs/board-drift.log` |
| `.claude/worktrees/` | Worktree artifacts | CC Agent tool | `.agentic-workflow/worktrees/` |
| `.dispatch/story-<N>.md` | CLI dispatch prompt files | `dispatch-story.sh` | `.agentic-workflow/dispatch/story-<N>.md` |
| (didn't exist) | Cached pricing data | `fetch-pricing.sh` | `.agentic-workflow/pricing.json` |

## Other changes

| Current | New |
|---------|-----|
| `pricing` section required in config | `pricing` section optional (override only) |
| `fetch-pricing.sh` reads from config | `fetch-pricing.sh` scrapes web → writes cache |
| `item-telemetry.sh` reads config `_cfg_blended_rate()` | `item-telemetry.sh` reads cache file first, config override if present |
| `.claude/.gitignore` includes `state/`, `logs/`, `worktrees/` | Project `.gitignore` includes `.agentic-workflow/` |
| Hardcoded `$15/$75` Opus rates in config | Live rates from Anthropic ($5/$25 for Opus 4.6) |
| `tokenSplit` in config file | `tokenSplit` as constant in script |

## Scripts affected

| Script | Changes needed |
|--------|---------------|
| `fetch-pricing.sh` | Rewrite: 3-tier web fetch → cache write to `.agentic-workflow/pricing.json` |
| `item-telemetry.sh` | Update `_cfg_blended_rate()`: read cache file first, config override if present. Bake in `tokenSplit` as constant. |
| `item-set-status.sh` | Update `LOG_DIR` from `.claude/logs` to `.agentic-workflow/logs` |
| `check-board-drift.sh` | Update `LOG_DIR` from `.claude/logs` to `.agentic-workflow/logs` |
| `validate-logs.sh` | Update all log paths to `.agentic-workflow/logs/` |
| `dispatch-story.sh` | Update `DISPATCH_DIR` from `.dispatch` to `.agentic-workflow/dispatch` |
| `cleanup-post-merge.sh` | Update paths: `.agentic-workflow/runs/<N>/` instead of `.claude/state/<N>/` |
| Orchestrator agent (`orchestrator.md`) | Update all state file and log references |
| `CLAUDE.md` | Update state file, log, and pricing documentation |
| `.claude/.gitignore` | Remove `state/`, `logs/`, `worktrees/` (no longer used) |
| Project `.gitignore` | Add `.agentic-workflow/` |

## Out of scope (future)

- Moving `scripts/` into plugin root (separate design)
- Moving `agents/` from `.claude/agents/` to plugin structure (separate design)
- Plugin packaging (`plugin.json`, marketplace) (see existing design doc)
- The final plugin name (TBC — "agentic workflow" is a working name)
