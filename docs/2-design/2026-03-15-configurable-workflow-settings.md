---
date: 2026-03-15
author: carlosboeing
agent: designer
status: approved
scope: Centralize hardcoded workflow configuration into a single config file, as the foundation for future Claude Code plugin packaging
related: ../1-discovery/2026-03-15-plugin-packaging-research.md
---

# Design: Configurable Workflow Settings

> Historical record (March 2026). Measurements come from controlled synthetic workloads and early infrastructure runs; see [case studies](../case-studies.md) for scoped findings.

## Problem

The agentic workflow has **80+ hardcoded values** scattered across 8 shell scripts, 9 agent markdown files, and CLAUDE.md. These include GitHub project IDs, board status option IDs, model routing preferences, and pricing rates. The consequences:

1. **Changing the repo name** requires editing 10 files (8 scripts + 2 agent files).
2. **Changing model routing** (e.g., easy from haiku to sonnet) required editing 7 files (done manually in this session — CLAUDE.md, orchestrator.md x3, dispatch-workflow.sh, test file).
3. **Using this workflow on a different project** is impossible without a manual find-and-replace across the entire codebase.
4. **Board status option IDs** are duplicated in CLAUDE.md and `item-set-status.sh` with no cross-reference — a maintenance risk.

This design introduces a single configuration file that scripts and agents read at runtime, replacing hardcoded values with configurable settings.

## Goals

- **One file to configure** when adopting the workflow on a new project.
- **Sensible defaults** for everything except project-specific values (GitHub repo, project number).
- **No behavioral changes** — the workflow continues to work exactly as it does today.
- **Foundation for plugin packaging** — the config file becomes the consumer-project config when this is eventually packaged as a Claude Code plugin.

## Non-Goals (deferred)

- **Plugin packaging itself** — this design covers the config file only, not the plugin structure. See [Plugin Packaging Research](../1-discovery/2026-03-15-plugin-packaging-research.md) for the full plugin roadmap.
- **Interactive setup wizard** (`/sdlc-setup` command) — valuable for community onboarding, but the config file format must stabilize first.
- **Configurable branch patterns** — `backlog/<N>-<slug>`, `epic/eNN-slug`, etc. are structural conventions that would require agents to template-expand strings at runtime. High complexity, low near-term value. Deferred until someone actually needs different patterns.
- **Configurable label names** — `hierarchy/backlog`, `difficulty/easy`, etc. are referenced in too many places as literal strings. Making them configurable requires a label registry that agents query. Deferred.
- **Configurable doc paths** — `docs/2-design/`, `docs/3-plans/`, etc. Same structural coupling issue as branch patterns. Deferred.
- **Configurable issue naming** — `[#<backlog>/ENN-SNN]` format. Embedded in agent instructions as literal patterns. Deferred.
- **Repo renaming** — the config file makes this a one-line change, but propagating a rename across historical docs and the GitHub remote is out of scope for this design.

---

## Design Decision: Config File with Code-Level Defaults

### Approach chosen

A JSON config file at `.claude/agentic-sdlc-config.json` with code-level defaults. Users provide only what's required or what they want to override.

### Alternatives considered

| Approach | Rejected because |
|----------|-----------------|
| **Full config, no defaults** | Bad onboarding — users must fill in 20+ fields before anything works. Where does a new user get board status option IDs? |
| **Environment variables** | Doesn't scale for 20+ nested config values. Undiscoverable, hard to document, messy in CI. |
| **CLAUDE.md injection** (SessionStart hook transforms config into system prompt text) | Redundant — agents can read JSON directly. Adds a failure point with no benefit. |
| **Layered config** (plugin defaults + project config + local overrides, merged at runtime) | Unnecessary complexity now. Easy to add later if needed — just introduce `.claude/agentic-sdlc-config.local.json` and a merge step. |

### How config is consumed

| Consumer | Mechanism | Example |
|----------|-----------|---------|
| **Shell scripts** | `jq` with `//` fallback operator | `jq -r '.github.repo // ""' .claude/agentic-sdlc-config.json` |
| **Agent instructions** | Natural language instruction to read the file | "Read `.claude/agentic-sdlc-config.json` and use `modelRouting.<difficulty>` to select the builder variant." |
| **CLAUDE.md** | References the config file as source of truth; keeps current values as documentation/defaults | "Source of truth: `.claude/agentic-sdlc-config.json`. Defaults shown below." |

### Config file location

`.claude/agentic-sdlc-config.json` — inside the `.claude/` directory, which is already the home for project-level Claude Code configuration (settings, agents, hooks, state). The `agentic-sdlc-` prefix scopes it to this workflow and avoids collision with Claude Code's own `settings.json`.

The file should be **checked into source control** (not gitignored) so teams share the same configuration. Personal overrides can be added later via `.claude/agentic-sdlc-config.local.json` if needed.

---

## Configuration Schema

### Minimal config (new project onboarding)

A new user only needs to provide their GitHub project details. Everything else has sensible defaults:

```json
{
  "github": {
    "repo": "myorg/my-project",
    "projectNumber": 42,
    "owner": "myorg"
  }
}
```

### Full config (all settings with defaults shown)

```json
{
  "github": {
    "repo": "carlosboeing/agentic-sdlc-workflow",
    "projectNumber": 42,
    "owner": "carlosboeing",
    "projectId": "<project-id>",
    "statusFieldId": "<status-field-id>"
  },

  "boardStatus": {
    "backlog": "17425ce6",
    "planned": "cf183d2a",
    "todo": "f75ad846",
    "in-progress": "47fc9ee4",
    "in-review": "9bb97c15",
    "done": "98236657"
  },

  "modelRouting": {
    "easy": "sonnet",
    "medium": "sonnet",
    "hard": "opus"
  },

  "workflow": {
    "autoMergePlanPR": true,
    "autoMergeDesignPR": true,
    "skipRetro": false,
    "maxParallelBuilders": 3
  },

  "pricing": {
    "tokenSplit": { "input": 0.75, "output": 0.25 },
    "opus":   { "inputPerM": 15.00, "outputPerM": 75.00 },
    "sonnet": { "inputPerM": 3.00, "outputPerM": 15.00 },
    "haiku":  { "inputPerM": 1.00, "outputPerM": 5.00 }
  }
}
```

---

## Configuration Reference

### `github` — GitHub Repository and Project Board

These settings identify the GitHub repository and the GitHub Projects board used to track work items. Every script that interacts with the GitHub API uses these values.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `repo` | string | Recommended | Auto-detected via `gh repo view` | The full `owner/name` identifier of the GitHub repository (e.g., `"carlosboeing/agentic-sdlc-workflow"`). Used by scripts that call `gh api repos/<repo>/...` directly. If omitted, scripts fall back to auto-detection from the current git remote, but explicit is safer — auto-detection can fail in worktrees or CI environments where the remote isn't obvious. |
| `projectNumber` | integer | **Yes** | None | The GitHub Projects board number visible in the project URL (e.g., a URL ending in `/projects/42` → `42`). Used by `item-create.sh` to add issues to the board and by `item-set-status.sh` to look up board item IDs. There is no sensible default — every GitHub project has a unique number. |
| `owner` | string | **Yes** | None | The GitHub username or organization that owns the project board (e.g., `"carlosboeing"`). This is the project board owner, which may differ from the repo owner in organization setups. Used in `gh project item-add`, `gh project item-list`, and GraphQL queries. |
| `projectId` | string | Optional | Looked up at runtime | The internal GraphQL node ID of the project (e.g., `"<project-id>"`). Used in `gh project item-edit` mutations. If omitted, `item-set-status.sh` looks it up via `gh project item-list`, which works but costs an extra API call per status change. Providing it avoids that overhead. To find it: `gh project list --owner <owner> --format json \| jq '.projects[] \| select(.number == <N>) \| .id'`. |
| `statusFieldId` | string | Optional | Looked up at runtime | The internal GraphQL ID of the "Status" field on the project board (e.g., `"<status-field-id>"`). Used in `gh project item-edit` to set an issue's board status. Same trade-off as `projectId` — providing it avoids a runtime lookup. To find it: `gh project field-list <N> --owner <owner> --format json \| jq '.fields[] \| select(.name == "Status") \| .id'`. |

**How to find these values:**

1. Go to your GitHub Projects board URL — the number in the URL is `projectNumber`.
2. The account/org in the URL is `owner`.
3. For `projectId` and `statusFieldId`, use the `gh` CLI commands shown above, or run `./scripts/setup-labels.sh` which prints them during setup.

---

### `boardStatus` — Project Board Status Option IDs

Each status column on a GitHub Projects board has an internal option ID. These IDs are unique per project — they're generated when the board is created and change if the status field is recreated.

The workflow uses six statuses to track work items through the lifecycle:

| Field | Default | Description |
|-------|---------|-------------|
| `backlog` | `"17425ce6"` | **Backlog** — Unplanned work items. New backlog issues start here. Set by `item-create.sh`. |
| `planned` | `"cf183d2a"` | **Planned** — A plan exists but hasn't been approved yet (plan PR not merged). Set by the planner agent after creating issues. |
| `todo` | `"f75ad846"` | **Todo** — Plan approved, ready for builder dispatch. Set by the orchestrator after the plan PR merges (autonomous mode) or by the human (interactive mode). |
| `in-progress` | `"47fc9ee4"` | **In Progress** — Currently being worked on by a builder agent. Set by the orchestrator before dispatching a builder. Also set by `item-start.sh` as defense-in-depth. |
| `in-review` | `"9bb97c15"` | **In Review** — Implementation complete, awaiting review and backlog PR merge. Set by the orchestrator after a builder completes. Also set by `item-review.sh` as defense-in-depth. |
| `done` | `"98236657"` | **Done** — Completed and merged to `main`. Set by `item-close.sh` when an issue is closed. |

**How to find these values for your project:**

```bash
gh project field-list <projectNumber> --owner <owner> --format json \
  | jq '.fields[] | select(.name == "Status") | .options[] | {name, id}'
```

This prints each status name and its corresponding option ID. Copy the IDs into your config.

**Why these exist:** GitHub Projects uses opaque IDs for status options, not human-readable names. The `gh project item-edit` command requires the option ID, not the status name. There's no API to set status by name — you must provide the exact ID.

---

### `modelRouting` — Difficulty-to-Model Mapping

Controls which AI model builds stories at each difficulty level. The planner assigns a difficulty label (`difficulty/easy`, `difficulty/medium`, `difficulty/hard`) to each story issue. The orchestrator reads this label and dispatches the corresponding builder variant.

| Field | Default | Description |
|-------|---------|-------------|
| `easy` | `"sonnet"` | Model for `difficulty/easy` stories. These are typically single-file changes, config updates, documentation, or simple tests. Dispatches `builder-sonnet` (or `builder-haiku` if set to `"haiku"`). |
| `medium` | `"sonnet"` | Model for `difficulty/medium` stories. Multi-file changes, standard patterns, EF Core migrations, integration tests. Dispatches `builder-sonnet`. |
| `hard` | `"opus"` | Model for `difficulty/hard` stories. Cross-project changes, new abstractions, security-sensitive code, complex architectural work. Dispatches `builder-opus`. |

**Valid values:** `"haiku"`, `"sonnet"`, `"opus"`. These map to builder variant agent files (`builder-haiku.md`, `builder-sonnet.md`, `builder-opus.md`).

**Why not haiku for easy?** Telemetry across 11 test runs showed that Haiku uses 3-4x more tokens than Sonnet for comparable tasks (100-120K vs 28-38K tokens per story) due to more conversational turns and less precise tool use. Despite Haiku's lower per-token cost, the total cost per story is roughly the same (~$0.20-0.25). Sonnet produces cleaner output with fewer tokens, making it the better default. See [Telemetry Analysis](../1-discovery/2026-03-14-telemetry-metrics-analysis.md) for detailed per-model comparisons.

---

### `workflow` — Behavioral Toggles

Controls orchestrator behavior for optional workflow phases.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `autoMergePlanPR` | boolean | `true` | When `true` (autonomous mode), the orchestrator auto-merges the plan PR via `gh pr merge --merge` after the planner completes. When `false` (interactive mode), the orchestrator waits for a human to merge the PR before proceeding to the build phase. Only applies when the orchestrator runs in autonomous mode. |
| `autoMergeDesignPR` | boolean | `true` | Same as `autoMergePlanPR` but for the design doc PR. When `true`, the orchestrator auto-merges after the designer completes. |
| `skipRetro` | boolean | `false` | When `true`, the orchestrator skips the retro phase entirely (no retro agent dispatch, no retro issue, no convention change proposals). Useful for test runs or content-only workloads where the learning loop adds cost (~$0.77/run) without value. The retro phase is critical for code workloads where convention refinement drives quality improvements. |
| `maxParallelBuilders` | integer | `3` | Maximum number of builder agents dispatched concurrently in a single wave. Each parallel builder runs in its own git worktree. Higher values increase throughput but consume more API quota and may hit rate limits. The GitHub Projects API does not handle concurrent `item-edit` calls reliably, so board updates are always serialized regardless of this setting. |

---

### `pricing` — Cost Estimation Parameters

Controls how `item-telemetry.sh` estimates API costs from token counts. These are **fallback values** — the orchestrator normally fetches live pricing from Anthropic's pricing page at session start via `scripts/fetch-pricing.sh` and passes it to telemetry via the `--rate` flag. The config values are only used when both the live fetch fails AND the `--rate` flag isn't provided.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `tokenSplit.input` | number | `0.75` | Assumed fraction of total tokens that are input (prompt) tokens. The Anthropic API charges different rates for input vs output tokens, but the Agent tool only reports total token count, not the split. This ratio is used to estimate cost: `cost = tokens * (inputRate * input + outputRate * output)`. The 75/25 default is based on observed patterns across 11 test runs where prompts (CLAUDE.md, agent instructions, file contents) dominate the token budget. |
| `tokenSplit.output` | number | `0.25` | Assumed fraction of total tokens that are output (completion) tokens. Must equal `1 - tokenSplit.input`. |
| `opus.inputPerM` | number | `15.00` | Opus input token price in USD per million tokens. As of March 2026, Anthropic charges $15/M input for Claude Opus 4. |
| `opus.outputPerM` | number | `75.00` | Opus output token price in USD per million tokens. As of March 2026: $75/M output for Claude Opus 4. |
| `sonnet.inputPerM` | number | `3.00` | Sonnet input token price in USD per million tokens. As of March 2026: $3/M input for Claude Sonnet 4. |
| `sonnet.outputPerM` | number | `15.00` | Sonnet output token price in USD per million tokens. As of March 2026: $15/M output for Claude Sonnet 4. |
| `haiku.inputPerM` | number | `1.00` | Haiku input token price in USD per million tokens. As of March 2026: $1/M input for Claude Haiku 4.5. |
| `haiku.outputPerM` | number | `5.00` | Haiku output token price in USD per million tokens. As of March 2026: $5/M output for Claude Haiku 4.5. |

**Why this exists:** Accurate cost estimation requires knowing the per-token price for each model. The workflow tracks cost per story, per epic, and per backlog item to help teams understand the economics of agentic development. When subscription pricing is used (Pro, Max, Team plans), these cost estimates represent equivalent API value, not actual charges.

**How the blended rate is computed:**

```
blended_rate = (inputPerM * tokenSplit.input) + (outputPerM * tokenSplit.output)
```

For Opus: ($15 * 0.75) + ($75 * 0.25) = $11.25 + $18.75 = **$30/M tokens blended**.

---

## What Changes in Existing Files

### Scripts

Each script that currently hardcodes values will gain a config-reading preamble:

```bash
# Read config (with fallbacks for missing file or fields)
CONFIG_FILE="${SCRIPT_DIR}/../.claude/agentic-sdlc-config.json"
if [ -f "$CONFIG_FILE" ]; then
  REPO=$(jq -r '.github.repo // ""' "$CONFIG_FILE")
  # ... other fields
fi

# Fallback to auto-detection if config is missing
if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
fi
```

| Script | Fields read from config |
|--------|------------------------|
| `item-set-status.sh` | `github.projectId`, `github.statusFieldId`, `github.owner`, `github.repo`, all `boardStatus.*` |
| `item-telemetry.sh` | `github.repo`, all `pricing.*` |
| `item-create.sh` | `github.repo`, `github.projectNumber`, `github.owner` |
| `item-start.sh` | `github.repo` |
| `item-review.sh` | `github.repo` |
| `item-close.sh` | `github.repo` |
| `setup-labels.sh` | `github.repo` |
| `dispatch-story.sh` | `github.repo` |
| `dispatch-workflow.sh` | `github.repo`, `modelRouting.*` |
| `fetch-pricing.sh` | `pricing.*` (as fallback defaults) |
| `check-board-drift.sh` | `github.owner`, `github.repo` |

### Agent files

Agent files don't execute shell commands directly — they contain instructions that Claude follows. The changes are instructional, not mechanical:

| Agent file | Change |
|------------|--------|
| `orchestrator.md` | Add Phase 0 instruction: "Read `.claude/agentic-sdlc-config.json` at session start. Use `modelRouting` for builder dispatch, `github` for API calls. If the file is missing, use defaults." Replace hardcoded project IDs and routing tables with "see config file" references. |
| `designer.md` | Replace hardcoded `--owner carlosboeing` and project number with "read from config file". |
| `planner.md` | Same — replace hardcoded project details with config file reference. |
| `retro.md` | Replace hardcoded `carlosboeing/agentic-sdlc-workflow` in API calls with config reference. |
| `builder*.md` | No changes needed — builders don't reference project-specific values. |
| `reviewer.md` | No changes needed. |

### CLAUDE.md

The board status option IDs table, model routing table, and GitHub project references stay as documentation (they're useful for humans reading the file) but gain a note:

```markdown
> **Source of truth:** `.claude/agentic-sdlc-config.json`. The values below are defaults
> for this project. Scripts and agents read from the config file at runtime.
```

---

## What Does NOT Change

- **Historical docs** — design docs, plans, retros, lessons, telemetry analysis, changelog. These are records of past runs and retain their hardcoded values as historical context.
- **Branch naming patterns** — `backlog/<N>-<slug>`, `epic/eNN-slug`, `eNN-sNN/slug`. These remain conventions in agent instructions. Making them configurable requires template expansion logic in agents — deferred.
- **Label names** — `hierarchy/backlog`, `difficulty/easy`, etc. remain as literal strings in agent instructions. Making them configurable requires a label registry — deferred.
- **Doc directory paths** — `docs/2-design/`, `docs/3-plans/`, etc. remain as conventions.
- **Issue naming format** — `[#<backlog>/ENN-SNN]` remains as a convention.
- **State file paths** — `.agentic-workflow/runs/<backlog>/orchestrator.json` (moved from `.claude/state/` in Run 12).
- **host-specific config** (`Host` section key) — this is the consumer app's configuration, not the workflow's configuration. It stays in CLAUDE.md as project documentation.
- **Test file** — `tests/scripts/test-dispatch-workflow.sh` routing assertion was already updated in this session.

---

## Hardcoding Inventory

The full audit identified ~80 hardcoded values across the codebase, categorized into three tiers:

### Tier 1: Project-specific (addressed by this design)

Values that **break when the repo changes** — must be configurable.

| Category | Example value | Files affected | Config field |
|----------|--------------|----------------|-------------|
| Repo name | `carlosboeing/agentic-sdlc-workflow` | 8 scripts, orchestrator.md, retro.md | `github.repo` |
| Project number | (hardcoded number) | CLAUDE.md, designer.md, planner.md, item-create.sh | `github.projectNumber` |
| Project owner | `carlosboeing` | CLAUDE.md, designer.md, planner.md, item-set-status.sh, item-create.sh, check-board-drift.sh | `github.owner` |
| Project ID | `<project-id>` | CLAUDE.md, item-set-status.sh | `github.projectId` |
| Status field ID | `<status-field-id>` | CLAUDE.md, item-set-status.sh | `github.statusFieldId` |
| Board status IDs | 6 hex values | CLAUDE.md, item-set-status.sh | `boardStatus.*` |

### Tier 2: Workflow preferences (addressed by this design)

Values with **reasonable defaults** but that users may want to customize.

| Category | Example value | Files affected | Config field |
|----------|--------------|----------------|-------------|
| Model routing | easy→sonnet, medium→sonnet, hard→opus | CLAUDE.md, orchestrator.md, dispatch-workflow.sh | `modelRouting.*` |
| Pricing rates | opus $15/$75 per M tokens | fetch-pricing.sh, item-telemetry.sh | `pricing.*` |
| Token split | 75% input / 25% output | item-telemetry.sh, fetch-pricing.sh | `pricing.tokenSplit.*` |

### Tier 3: Structural conventions (deferred)

Values that are **deeply embedded** in agent instructions as patterns, not simple values. Making them configurable requires agents to template-expand strings at runtime — a significant complexity jump for little near-term value.

| Category | Example | Why deferred |
|----------|---------|-------------|
| Branch patterns | `backlog/<N>-<slug>`, `epic/eNN-slug` | Agents would need to construct branch names from templates. Currently they follow documented patterns. |
| Label names | `hierarchy/backlog`, `difficulty/easy` | Referenced as literal strings in 5+ agent files. Would need a label registry or name-mapping config. |
| Doc paths | `docs/2-design/`, `docs/3-plans/` | Structural convention used in grep patterns for plan/design detection. |
| Issue naming | `[#<backlog>/ENN-SNN]` | Formatting pattern embedded in planner instructions. |
| Label colors | `#5319E7`, `#6E40C9` | Only used by `setup-labels.sh`. Low impact. |
| State paths | `.agentic-workflow/runs/<backlog>/` | Moved to `.agentic-workflow/` in Run 12. |
| Gantt colors | `#059669`, `#8b5cf6` | Only the telemetry template uses this. Cosmetic. |

---

## Bug Fixes Included in This Session

Two bugs identified by the [Workflow Analysis](../1-discovery/2026-03-14-workflow-analysis.md) were fixed before this design work:

1. **Phase 3 plan detection** (`orchestrator.md:224`): Changed `grep -rl "<backlog-issue-number>"` to `grep -rl "^backlog: <backlog-issue-number>$"` — matches the fix already applied to design doc detection, prevents false matches on short numbers.

2. **Opus pricing fallback** (`item-telemetry.sh:116-128`): Comment said `$5 in / $25 out → ~$10/M`, rate was `1000` cents/M. Corrected to `$15 in / $75 out → ~$30/M`, rate `3000` cents/M. Now consistent with `fetch-pricing.sh` fallback rates.

3. **Model routing** (7 files): Changed `difficulty/easy → builder-haiku` to `difficulty/easy → builder-sonnet` across CLAUDE.md, orchestrator.md, dispatch-workflow.sh, and the test file. Based on telemetry evidence that Sonnet uses 3x fewer tokens at comparable cost.

---

## Path to Plugin Packaging

This config file is Step 1 of a larger path toward packaging the workflow as a Claude Code plugin. The full roadmap (from [Plugin Packaging Research](../1-discovery/2026-03-15-plugin-packaging-research.md)):

| Step | What | Status |
|------|------|--------|
| **1** | Config file (this design) | Designed |
| **2** | Move scripts alongside agents | Future |
| **3** | Add slash commands (`/dispatch`, `/board-status`, etc.) | Future |
| **4** | Create SKILL.md for the methodology | Future |
| **5** | Package as plugin with `plugin.json` | Future |
| **6** | Add `/sdlc-setup` onboarding command | Future |

### Plugin naming

The workflow is domain-agnostic — it handles creative content (markdown, reports) as well as software development (C# with TDD). Names under consideration: `forge`, `rally`, `dispatch`, `conveyor`, `workbench`. No final decision — see the research doc for competitive landscape analysis. For now, the config file uses the `agentic-sdlc-` prefix.

---

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Scripts fail if config file is missing | Every script falls back to hardcoded defaults or auto-detection. The config file is optional — its absence doesn't break anything. |
| Agent reads config file incorrectly | Config is simple flat JSON, well within Claude's parsing ability. Agent instructions include explicit field names and defaults. |
| Config file diverges from script defaults | Scripts use the `jq` `//` (alternative) operator, so the config value takes precedence when present. Defaults in scripts match the config schema documentation. |
| Breaking change to config schema | Use additive changes only. New fields get defaults. Never rename or remove fields without a migration period. |
