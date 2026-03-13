# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
dotnet build NeuralNorris.slnx                    # Build all projects
dotnet test NeuralNorris.slnx                      # Run all tests
dotnet test tests/NN.Agent.Tests                   # Run a single test project
dotnet test --filter "FullyQualifiedName~ToolRegistryTests"  # Run a single test class
cd src/NN.Gateway && dotnet run                    # Run locally → http://localhost:5050
```

EF Core migrations (from repo root):
```bash
dotnet ef migrations add <Name> --project src/NN.Persistence --startup-project src/NN.Gateway
```

Docker deployment:
```bash
docker compose up -d          # ARM64 (Raspberry Pi) or x64
```

## Architecture

**NeuralNorris** is a self-hosted home AI assistant powered by Claude. It runs on a Raspberry Pi, persists memory across conversations, invokes tools, orchestrates multi-step tasks, and schedules background work.

**Stack:** C# / .NET 10 · Blazor Server · Anthropic SDK · Semantic Kernel (plugin registry only) · EF Core + SQLite · Docker

### Project Dependency Graph

```
NN.Gateway (ASP.NET host + Blazor UI)
  ├── NN.Agent (agentic loop, orchestration, scheduling)
  │     └── NN.Core (domain models, abstractions, config)
  ├── NN.Persistence (EF Core + SQLite, migrations)
  │     └── NN.Core
  ├── NN.Memory (per-member long-term memory store)
  │     └── NN.Core
  ├── NN.Tools (web search, web fetch, memory, system status)
  │     └── NN.Core
  ├── NN.Tools.Finance (PocketSmith integration)
  ├── NN.Tools.Twilio (SMS)
  └── NN.Tools.DevOps (self-modification: code read/write, git, Docker canary/promote)
```

### Key Architectural Patterns

**Agentic loop** (`AgentSession`): Drives multi-turn Claude conversations with streaming, tool invocation, iteration caps, and persistence. Uses `Anthropic.SDK` directly (not SK's model connector) for reliable streaming tool use. Semantic Kernel is only used as a plugin/function registry.

**Orchestration pipeline** (Plan-Execute Hybrid): Complex queries are decomposed into a DAG of parallel sub-agent tasks:
`ComplexityRouter` (Haiku classification) → `Planner` (DAG generation) → `Executor` (parallel via `Task.WhenAll` + `SemaphoreSlim`) → `Synthesiser` (streamed response).

**Tool system**: Tools implement both `ITool` (metadata) and `IKernelTool` (marker for SK registration). Registered via DI as `ITool`, then `ToolRegistry.BuildPlugins()` filters by allowlist and registers as SK plugins. Tool names are snake_case.

**Context management**: `SessionContext` loads turn history with pruning at token thresholds. `ContextCompactor` summarises older turns using Haiku when compaction triggers. All thresholds are configurable in `NNConfig.Tokens`.

**Auth**: Pluggable via `IAuthProvider` — PIN auth (default, zero-config) or ASP.NET Identity with optional TOTP 2FA. Provider selected by `NN:Auth:Provider` config.

**Configuration**: All config lives under the `NN` section key, bound to `NNConfig` (see `src/NN.Core/Configuration/NNConfig.cs`). API keys can come from `appsettings.Development.json` (gitignored) or env vars (`ANTHROPIC_API_KEY`, `TAVILY_API_KEY`, etc.).

**Personality**: `SOUL.md` is a template with `{{agentName}}` and `{{personality}}` placeholders, loaded at runtime by `SoulService`. Hot-swappable without rebuild.

**Self-modification (DevOps tools)**: Norris can read/write code, run shell commands (allowlisted), manage git worktrees, and deploy via Docker canary/promote. The `nn-promoter` sidecar watches for signal files — Norris never has direct Docker socket access.

**Sentinel**: GitHub Actions workflow (`sentinel.yml`) runs an AI-powered security review on all PRs to `main` before merge.

### Persistence

`NNDbContext` extends `IdentityDbContext`. All `DateTimeOffset` properties are stored as Unix milliseconds (SQLite compatibility). Auto-migrates on startup via `app.Services.MigrateAsync()`.

## Testing Conventions

- **Framework**: xUnit + NSubstitute for mocking
- **Pattern**: Arrange/Act/Assert with descriptive method names (`BuildPlugins_NullAllowlist_ReturnsDefaultEnabledOnly`)
- Tests use in-memory SQLite (`Microsoft.Data.Sqlite`) for database tests
- A pre-commit hook runs `dotnet test` before every commit (configured in `.claude/settings.json`)

## CI

GitHub Actions (`.github/workflows/ci.yml`): restore → build → test on push/PR to main. .NET 10.

## Project Documentation

- `docs/5-guides/PROJECT.md` — full architecture and technical overview
- `docs/1-discovery/VISION.md` — long-term vision and aspirations
- `docs/CHANGELOG.md` — build history
- `docs/2-design/` — feature design documents
- `docs/3-plans/` — implementation plans
- `docs/4-reviews/` — code reviews and retros
- `docs/6-adrs/` — architecture decision records

## Development Workflow

### Agents

Six specialized agents in `.claude/agents/`:

| Agent | Role | Writes to |
|-------|------|-----------|
| `designer` | Brainstorm features, write design docs | `docs/2-design/` |
| `planner` | Create plans, GitHub Issues with difficulty labels | `docs/3-plans/`, `docs/6-adrs/` |
| `builder` | TDD implementation of stories | Code only |
| `reviewer` | Code quality and convention review | Review comments |
| `orchestrator` | Workflow orchestration — dispatches agents, manages board | GitHub state only |
| `retro` | Epic retrospectives, convention change proposals | `docs/4-reviews/`, PR |

### For All Agents

- Always check GitHub Issues first (`gh issue list`) to understand project state
- Never start work without a corresponding GitHub Issue
- Use conventional commits: `<type>(<scope>): <description>`
- **Never use `#N` in commit messages** unless intentionally referencing a GitHub issue. GitHub auto-links any `#N` pattern to issue N, so reviewer warning numbers, list indices, or other numbered references must use a format without `#` (e.g., `warning 4`, `W4`, `item 4`). The `Fixes #N` / `Closes #N` footer is the correct place for issue references.
- Reference `docs/5-guides/PROJECT.md` for architecture context
- Write lesson files when encountering bugs, unexpected behavior, or missing conventions (see Lesson Conventions below)

### Branch Conventions

```
main
└── backlog/<N>-<slug>          ← integration branch (ONE PR to main per backlog item)
    ├── (design doc committed)  ← designer commits here (or merges docs/<slug> PR into it)
    ├── (plan committed)        ← planner commits here (or merges docs/<slug> PR into it)
    ├── epic/eNN-slug           ← epic branch (off integration branch)
    │   └── eNN-sNN/slug        ← story branch (off epic branch)
    └── (retro, changelog, lessons committed after stories complete)
```

- **Integration branch** (`backlog/<N>-<slug>`) is the single branch for all work under a backlog item. Created from `main` in Phase 0. ONE PR from this branch to `main` at the end.
- **Design/plan docs** are committed or merged into the integration branch (not `main`). Designer and planner create `docs/<slug>` branches off the integration branch and open PRs targeting the integration branch, or commit directly in autonomous mode.
- **Epic branches** are created from the integration branch (not `main`): `git checkout backlog/<N>-<slug> && git checkout -b epic/eNN-slug`.
- Stories merge into their epic branch, epic branches merge into the integration branch. **Delete branches after merging** — story branches after merging into epic, epic branches after merging into integration. The integration branch is deleted by `--delete-branch` when the backlog PR merges. **Safety:** Always verify the merge succeeded before deleting — use `git branch --merged HEAD | grep -q <branch>` before remote delete. `git branch -d` (lowercase) is safe (refuses unmerged), but `git push origin --delete` has no merge check. Never use `git branch -D` (force delete) in the workflow.
- **Retro, changelog, and lessons** are committed on the integration branch after all stories complete.
- **Nothing merges to `main`** until the human reviews the final PR. The backlog PR always stays open for human review.
- Never commit directly to `main`

### GitHub Conventions

**Labels:**

| Category | Labels | Purpose |
|----------|--------|---------|
| Hierarchy | `hierarchy/backlog`, `hierarchy/epic`, `hierarchy/story` | Identifies issue level for board filtering |
| Backlog | `backlog/<issue>-<slug>` | Groups **all** issues under a backlog item -- including design doc and plan issues, not just epics/stories (color: `#5319E7`) |
| Type | `type/feature`, `type/bug`, `type/refactor`, `type/test`, `type/docs` | Categorises work |
| Difficulty | `difficulty/easy`, `difficulty/medium`, `difficulty/hard` | Routes to model |

### Work Item Hierarchy

All work is tracked as **work items** organised into exactly three levels. This is a hard constraint — no additional levels may be created.

| Level | Name | What it represents | Real-world analogy | Label |
|-------|------|-------------------|-------------------|-------|
| **1** | **Backlog Item** | A user-facing capability or feature. The highest-level unit of work that delivers business value. | Jira Initiative · Azure DevOps Epic · Product roadmap line item | `hierarchy/backlog` |
| **2** | **Epic** | A technical workstream within a backlog item. Groups related stories that together deliver one slice of the capability. | Jira Epic · Azure DevOps Feature · Sprint goal | `hierarchy/epic` |
| **3** | **Story** | The smallest plannable unit of work. One builder agent, one branch, one PR. Should be completable in a single session. | Jira Story/Task · Azure DevOps PBI · Sprint backlog item | `hierarchy/story` |

**Why exactly three levels:**
- **Fewer than three** — forces stories to be too large (unplannable) or removes the grouping that makes epics useful for parallel dispatch and progress tracking.
- **More than three** — adds compounding complexity to labels, branches, dispatch logic, telemetry aggregation, and board management. Every additional level multiplies the orchestrator's state tracking. When a feature feels too large for three levels, the correct response is to split it into multiple independent backlog items, not to add hierarchy depth.

**Mapping the lifecycle:**

```
Designer brainstorms → one Backlog Item
Planner decomposes → Epics and Stories within that Backlog Item
Builder implements   → one Story at a time
Orchestrator manages → one Backlog Item per workflow run
```

**The planner MUST NOT create child backlog items.** If a feature feels too large for epics, use more epics with fewer stories each. An epic with 1-2 stories is perfectly valid. If the feature truly spans multiple independent domains (e.g., "build an e-commerce platform"), the designer should split it into separate backlog items upfront — each with its own lifecycle.

**Issue naming:** `[#<backlog>/ENN] Epic title` for epics, `[#<backlog>/ENN-SNN] Story title` for stories. The backlog issue number prefix disambiguates epics/stories across features (e.g., `[#43/E01-S01]` vs `[#5/E01-S01]`).

**Issue hierarchy (sub-issues):** All work is tracked via three-level GitHub sub-issue nesting:

```
Backlog item (#5)
├── Design doc issue (#24)              ← designer creates, links to backlog
├── Plan issue (#25)                    ← planner creates, links to backlog
├── [#5/E01] Epic issue (#38)           ← planner creates, links to backlog
│   ├── [#5/E01-S01] Story (#26)       ← planner creates, links to epic
│   ├── [#5/E01-S02] Story (#27)       ← planner creates, links to epic
│   └── ...
└── [#5/E02] Epic issue (#39)
    └── ...
```

Link sub-issues using `addSubIssue`:

```bash
PARENT_ID=$(gh issue view <parent-number> --json id -q .id)
CHILD_ID=$(gh issue view <child-number> --json id -q .id)
gh api graphql -f query="mutation { addSubIssue(input: { issueId: \"$PARENT_ID\", subIssueId: \"$CHILD_ID\" }) { subIssue { id } } }"
```

**Dependency diagrams on issues:** After the planner creates all issues, they MUST append the Mermaid dependency graph from the plan to the **issue description** (body) of the **backlog issue** (full cross-epic graph + dispatch plan table) and each **epic issue** (subset for that epic's stories). Use `gh issue edit --body` to append below the existing body with a `---` separator. This keeps dependency structure and wave assignments visible at the top of the issue page. See `planner.md` for the exact format.

**GitHub Project board:** All issues live on the [Agentic SDLC Workflow Project](https://github.com/users/carlosboeing/projects/7) (project number 7, owner `carlosboeing`).

Status field values and their meanings:

| Status          | Meaning                                           | Set by                                             |
|-----------------|---------------------------------------------------|----------------------------------------------------|
| **Backlog**     | Unplanned work items                              | Default for new backlog items                      |
| **Planned**     | Plan exists but not yet approved (PR not merged)  | Planner (on issue creation)                      |
| **Todo**        | Plan approved, ready for builder dispatch         | Human (on plan PR merge) / Orchestrator (autonomous mode) |
| **In Progress** | Currently being worked on                         | Orchestrator (sequentially, before dispatch)       |
| **In Review**   | Implementation complete, awaiting backlog PR merge | Orchestrator (sequentially, after builder completes) |
| **Done**        | Completed and merged to `main`                    | On issue close (`issue-close.sh`)                  |

**Epic status sync:** An epic's status must always reflect the aggregate of its stories:

- If at least one story is **In Progress** → epic is **In Progress**
- If all stories are **In Review** (none In Progress/Todo) → epic is **In Review**
- If all stories are **Done** → epic is **Done**
- The orchestrator must update the epic's board status whenever a story transitions.

**Board transitions in autonomous mode:** The orchestrator owns all board transitions that would normally be human-triggered. Specifically:

1. **After plan PR merge:** Set all story issues to **Todo** (sequentially, one at a time)
2. **Before dispatching a builder:** Set the story to **In Progress** (sequentially, before dispatch -- not delegated to builder scripts)
3. **After builder completes:** Set the story to **In Review** (sequentially, after completion -- not delegated to builder scripts)
4. **After parallel wave completes:** Verify board status for all stories in the wave and fix any that didn't transition correctly

Builder scripts (`issue-start.sh`, `issue-review.sh`) also update the board as defense-in-depth (they call `issue-set-status.sh` internally), but the orchestrator is the source of truth. All board updates must be serialized -- the GitHub Projects API does not handle concurrent `item-edit` calls reliably.

Adding an issue to the project and setting its status:

```bash
# Add issue to project
gh project item-add 7 --owner carlosboeing --url <issue-url> --format json

# Set status — prefer the helper script (handles control chars, validation, retry):
./scripts/issue-set-status.sh <issue-number> in-progress

# Or manually (use the option ID from the project field):
# NOTE: gh project item-list output contains control characters that break jq -- always pipe through tr -d
ITEM_ID=$(gh project item-list 7 --owner carlosboeing --format json --limit 100 | tr -d '\x00-\x1f' | jq -r '.items[] | select(.content.number == <issue-number>) | .id')
gh project item-edit --project-id "PVT_kwHOADPMJc4BRg45" --id "$ITEM_ID" \
  --field-id "PVTSSF_lAHOADPMJc4BRg45zg_UfJc" \
  --single-select-option-id "<option-id>"
```

Status option IDs:

| Status      | Option ID  |
|-------------|------------|
| Backlog     | `17425ce6` |
| Planned     | `cf183d2a` |
| Todo        | `f75ad846` |
| In Progress | `47fc9ee4` |
| In Review   | `9bb97c15` |
| Done        | `98236657` |

**DANGER: Never use `updateProjectV2Field` to add/modify status options.** That mutation replaces the entire option set, generating new IDs and wiping all existing item statuses. To add a new status option, use the GitHub web UI (Project → Settings → Status field) and then update the option IDs in this file.

**GitHub GraphQL API rate limit awareness:** The GraphQL API has a 5000 points/hour budget. Heavy commands like `gh project item-list` (fetches all items with all fields) consume many points per call — the planner's issue creation + board setup can use 50-60 calls, and `issue-set-status.sh` calls `item-list` twice per invocation (lookup + verification). When possible, prefer lightweight per-issue queries to look up board item IDs:

```graphql
query {
  repository(owner: "carlosboeing", name: "agentic-sdlc-workflow") {
    issue(number: $N) {
      projectItems(first: 1) {
        nodes { id }
      }
    }
  }
}
```

This costs ~1 point vs potentially 200+ for `item-list`. If rate limits are exhausted, use `gh api` with REST endpoints as a fallback. Evidence: Run 10 lesson `e00-setup/2026-03-13-s00-rate-limit-item-list.md`.

**Helper scripts:**

| Script | Usage |
|--------|-------|
| `scripts/issue-set-status.sh <n> <status>` | Set project board status (backlog/planned/todo/in-progress/in-review/done) |
| `scripts/issue-start.sh <n> --model <m> --agent <a>` | Post "Work Started" comment + set board to In Progress |
| `scripts/issue-review.sh <n> <commit>` | Post "Ready for Review" comment + set board to In Review |
| `scripts/issue-telemetry.sh <n> --model <m> --duration <ms> --commit <hash> [--tokens <n>] [--tool-uses <n>] [--rate <cents>] [--cost <dollars>] [--wall-clock <ms>] [--breakdown <md>] [--gantt <md>] [--summary <md>] [--footer <md>] [--pr <n>]` | Post telemetry (story, epic, or backlog) |
| `scripts/issue-close.sh <n>` | Close issue + set board to Done |
| `scripts/setup-labels.sh` | Create all labels (idempotent) |
| `scripts/fetch-pricing.sh` | Fetch current Anthropic API token pricing (JSON to stdout) |
| `scripts/dispatch-story.sh <n> --model <m> --agent <a>` | Dispatch CC CLI worker for a story |
| `scripts/dispatch-workflow.sh <n> [--skip-design] [--skip-plan] [--autonomous]` | Full lifecycle orchestration |

### Dispatch Protocol

#### Model routing

Map difficulty label to builder variant:

- `difficulty/easy` → `builder-haiku`
- `difficulty/medium` → `builder-sonnet`
- `difficulty/hard` → `builder-opus`

#### In-session dispatch (primary)

Use the Agent tool with `subagent_type: "builder-<model>"`:

1. Read difficulty label from GitHub Issue
2. Dispatch with `subagent_type: "builder-sonnet"` (or haiku/opus)
3. Builder runs `issue-start.sh` (posts comment + sets board to **In Progress**) → implements via TDD → runs `issue-review.sh` (posts comment + sets board to **In Review**)
4. Post telemetry (orchestrator — see below)
5. Update epic board status (see **Epic status sync** above)
6. **Dispatch reviewer** on the story branch (mandatory, before merging): `subagent_type: "reviewer"`
7. If reviewer finds issues: re-dispatch builder to fix, then re-review (max 2 cycles)
8. Merge story branch into epic branch (only after review passes)
9. After all stories complete: merge epic branches into integration branch, open backlog PR, post telemetry
10. **Dispatch reviewer** on the backlog PR (mandatory): `subagent_type: "reviewer"`
11. If reviewer finds issues: dispatch builder to fix on integration branch, then re-review (max 2 cycles)
12. Backlog PR is left open for human review (orchestrator NEVER auto-merges it)
13. Dispatch retro on the integration branch: `subagent_type: "retro"`

#### CLI dispatch (standalone terminal only)

For humans running builds from a terminal or CI — **not usable by agents**. `claude -p` refuses to start inside another Claude Code session (nested session detection), so the orchestrator and all agents must use the Agent tool for dispatch.

```bash
./scripts/dispatch-story.sh <issue-number> --model sonnet --agent builder --epic-branch epic/eNN-slug
```

#### Builder variants

Three model-specific variants exist alongside `builder.md`:

- `.claude/agents/builder-haiku.md` — for `difficulty/easy` stories
- `.claude/agents/builder-sonnet.md` — for `difficulty/medium` stories
- `.claude/agents/builder-opus.md` — for `difficulty/hard` stories

All variants share identical body content with `builder.md` (only the `model` frontmatter differs). **When updating `builder.md`, propagate changes to all three variants.**

**Telemetry is mandatory:** The orchestrator MUST post telemetry after each builder completes, before moving to the next story. The Agent tool result includes `duration_ms`, `total_tokens`, and `tool_uses` — pass all of them. **Capture telemetry even from failed or usage-limited dispatches** — they still consume tokens and time, and zeroing them out underreports actual costs. **When resuming an interrupted agent**, capture metrics from each invocation (interrupted + resumed) and sum them — it is unknown whether the resumed result reports cumulative or delta-only metrics:

```bash
./scripts/issue-telemetry.sh <issue-number> \
  --model <haiku|sonnet|opus> \
  --duration <duration_ms> \
  --commit <commit hash> \
  --tokens <total_tokens> \
  --tool-uses <tool_uses>
```

The script computes speed (tokens/s) and estimated cost automatically from the model and token count. The commit hash can be obtained from the builder's `issue-review.sh` comment or by checking the story branch head.

Add `--pr <pr-number>` to also post telemetry as a comment on the story PR. Every completed story must have all three comments on its issue: "Work Started" (`issue-start.sh`, by builder), "Ready for Review" (`issue-review.sh`, by builder), and "Telemetry" (`issue-telemetry.sh`, by orchestrator).

**Parallel dispatch:** When multiple stories share no dependencies (check the plan's dependency graph), dispatch their builder agents **in parallel** using concurrent Agent tool calls. Each parallel builder works on its own story branch. After all complete, review and merge sequentially. **CRITICAL: Use `isolation: "worktree"` in the Agent tool when dispatching parallel builders.** Without worktree isolation, parallel builders share the same working directory and can commit files from other stories onto the wrong branch. After parallel dispatch completes, verify each story branch contains only its expected files before merging.

**Story branch creation for parallel waves (REQUIRED):** Before dispatching parallel builders, the orchestrator MUST create all story branches from the same epic branch commit. Record this base commit hash. Do not push any story work to the epic branch until the entire wave completes. If a story branch is found to have diverged from the expected base (e.g., it includes commits from a sibling story), cherry-pick only the story's own commits onto a fresh branch from the recorded base before merging. This prevents the cross-contamination observed in Run 9 (E01-S03, issue #20) where a builder started from a sibling story's HEAD instead of the epic base.

**Post-worktree cleanup (REQUIRED):** After all worktree-dispatched builders complete, the orchestrator MUST:
1. Check for untracked files left in the main working tree: `git status --short`
2. Clean up any stale artifacts before proceeding to merges: `git clean -fd` (after verifying no wanted files are affected)
3. Verify each story branch was pushed to remote: `git ls-remote --heads origin <branch>` — worktree-isolated builders may not push automatically. If a branch is missing from remote, push it manually before merging.

**Parallel dispatch git safety (defense-in-depth):** With worktree isolation enabled, these rules serve as a secondary safety net. They remain mandatory for any non-worktree parallel dispatch:
- **Chain all git operations in a single Bash call:** `git checkout <branch> && git add <files> && git commit -m "msg"` — never split checkout and commit across separate Bash calls.
- **Verify branch before every commit:** Include `git branch --show-current` in the same `&&` chain, not in a separate call.
- **Use explicit file paths with `git add`** — never `git add .` which may stage files from other agents' work.

**Epic branches must be created from the integration branch:** Always `git checkout backlog/<N>-<slug> && git pull` before `git checkout -b epic/eNN-slug`.

**Integration and epic branches must be pushed to remote:** After creating the integration branch and epic branches, immediately push them with `git push -u origin <branch>`. After merging each story into its epic branch (and each epic into the integration branch), push again to keep the remote in sync. This prevents data loss if the local machine fails.

#### Full lifecycle orchestration

The orchestrator can handle the entire lifecycle from design to retro:

```bash
# Autonomous (recommended) — full live UI with real-time progress
claude --agent orchestrator --dangerously-skip-permissions \
  "Execute backlog item #42."

# Skip phases when design/plan already exist
claude --agent orchestrator --dangerously-skip-permissions \
  "Execute backlog item #42. Skip design and plan."

# Interactive — designer/planner ask questions, wait for PR approval
claude --agent orchestrator

# CLI dispatch with autonomous flag (always shows progress)
./scripts/dispatch-workflow.sh 42 --autonomous
./scripts/dispatch-workflow.sh 42 --skip-design --skip-plan
```

**Headless mode (`-p`):** For CI/CD or headless compute, add `-p` to run without the interactive UI. Options: `-p --verbose` for turn-by-turn text logging, `-p --output-format stream-json` for machine-readable streaming events (pipe to `tee` for log files), or `-p` alone for silent execution. All are fully autonomous with `--dangerously-skip-permissions`.

**Phase detection:** The orchestrator checks for existing design docs (`docs/2-design/`) and plans (`docs/3-plans/`) by matching the YAML frontmatter `backlog:` field (e.g., `grep -rl "^backlog: <N>$" docs/2-design/`). Raw content grep on the backlog number is unreliable for short numbers. If artifacts exist, those phases are skipped automatically.

**Autonomous mode:** When the prompt includes "autonomous" or the orchestrator is run non-interactively, the designer and planner agents skip interactive questions (brainstorming skill, `AskUserQuestion`) and instead derive all requirements from the backlog issue. Design/plan PRs are auto-merged via `gh pr merge`. The structured design process is preserved — agents still explore approaches, document trade-offs, and flag assumptions.

**Interactive mode:** When the orchestrator is run interactively without "autonomous", the designer and planner ask clarifying questions as normal, and the orchestrator waits for the human to merge PRs before proceeding.

### Backlog PR Strategy

**One PR per backlog item.** All work for a backlog item — design docs, plans, stories across all epics, retro, changelog, and lessons — ships in a single PR from `backlog/<N>-<slug>` to `main`. This PR stays open for human review and is never auto-merged by the orchestrator.

**Squash merge the backlog PR:** When the human merges the PR, always use squash merge to keep `main` history clean:

```bash
gh pr merge <N> --squash --delete-branch
```

**Link all issues to the PR:** The backlog PR body MUST include `Closes #NN` for the backlog issue, every epic issue, AND every story issue so merging the PR auto-closes them all (e.g., `Closes #57, closes #58, closes #59, closes #60, closes #61, ...`). Design doc and plan issues should also be included. Omitting issues from the `Closes` list causes them to remain open after merge.

**Update changelog:** The integration branch MUST include a `docs/CHANGELOG.md` entry before the PR is opened. Add the entry under the current date, following the existing format (feature summary + bullet points).

**Internal merges (epic → integration branch):** Epic branches merge into the integration branch using `--no-ff` merge (not squash). This is an internal merge — only the final PR to `main` uses squash. Design/plan PRs targeting the integration branch also use regular merge (`--merge`).

**Per-epic telemetry:** When all stories in an epic are complete, the orchestrator MUST post telemetry on **the epic issue** (via `issue-telemetry.sh`). Pass `--duration` (sequential sum of story durations in that epic) and `--wall-clock` (actual elapsed time for that epic's waves). Include a `--breakdown` with only that epic's stories. Use the integration branch head for `--commit`.

**Mixed-model epics:** When stories use different models, pass `--model 'mixed (model1, model2)'` and `--cost <dollars>` with the pre-computed aggregate cost (sum of per-story costs from the breakdown). For example: `--model 'mixed (haiku, sonnet)' --cost 0.67`. The `--cost` flag overrides the rate-based calculation, so the summary table shows the correct total instead of `—`.

**Backlog-level telemetry:** After all stories are built, reviewed, and merged into the integration branch — and the retro is complete — the orchestrator MUST post a **full lifecycle telemetry summary** using `issue-telemetry.sh` with `--summary`:

```bash
./scripts/issue-telemetry.sh <backlog-number> \
  --model opus --duration <total_ms> --wall-clock <wall_clock_ms> \
  --commit <hash> --tokens <total_tokens> --cost <total_dollars> \
  --summary "<phase-summary-rows>" \
  --breakdown "<per-dispatch-rows>" \
  --gantt "<mermaid-gantt-body>" \
  --footer "<trailing-notes>" \
  --pr <pr-number>
```

The script renders from `scripts/templates/telemetry.md` (single source of truth for all telemetry formatting). When `--summary` is provided, the script:
- Renders the backlog-level format: Summary → Breakdown → Duration → Timeline → Footer → Disclaimer
- Posts the telemetry as a comment on the backlog issue
- When `--pr` is also provided, appends the telemetry to the PR description (not as a comment)

The orchestrator must capture `duration_ms`, `total_tokens`, and `tool_uses` from every Agent tool dispatch (designers, planners, builders, reviewers, retro) and aggregate them into the summary and breakdown rows. See `.claude/agents/orchestrator.md` § "Backlog-Level Telemetry" for parameter details.

**Value column convention:** Value cells in all telemetry tables contain only numbers and units (e.g., `~33m`, `770K`, `~$4.79`). Never add descriptive text or parenthetical notes to value cells. Annotations belong in the Metric/Label column (e.g., `**Actual Duration** _(with parallelism)_` in Metric, `~33m` in Value). This matches the rule in `scripts/templates/telemetry.md`.

**Capturing orchestrator overhead:** The orchestrator's own tokens run in the parent session and aren't returned by the Agent tool. To capture them:
1. At the **start** of the orchestrator session, note the session's running token count (visible via `/cost` in the Claude Code UI)
2. At the **end**, note the final count. The difference minus all subagent tokens is the orchestrator's overhead.
3. Include as a separate "Orchestrator" row in the backlog telemetry, or note the session total with subagent total for easy subtraction.

**Orchestrator state persistence:** The orchestrator persists its full workflow state to `.claude/state/<backlog>/orchestrator.json` (gitignored). The state file is structured as versioned JSON (schema v1) with sections for session metadata, pricing, phase progress, epic/story status, and an append-only dispatch log. Key fields:

- **`session.orchestrator_model`** — the model the orchestrator is running, so inherited agents' models are known for accurate cost estimates.
- **`pricing`** — token rates fetched from Anthropic's pricing page at session start via `scripts/fetch-pricing.sh`. Falls back to hardcoded defaults on fetch failure. Used by `issue-telemetry.sh` via the `--rate` flag.
- **`dispatches[]`** — append-only log of every agent dispatch with model, duration, tokens, tool uses, and result.

The state file is updated after each agent dispatch and cleaned up after the backlog PR merges. On resume, the orchestrator reads this file for instant recovery without re-querying GitHub. If the file is missing (different machine, manual deletion), it falls back to querying GitHub for issue comments and branch state. The directory structure (`.claude/state/<backlog>/`) supports future per-agent state files as siblings (e.g., `builder-112.json`).

See `.claude/agents/orchestrator.md` § "Orchestrator State File" for the full schema and lifecycle.

**Epic-scoped telemetry:** When posting epic-level telemetry on epic issues, include only stories that belong to that specific epic (check the epic's sub-issues). The backlog PR and backlog issue are the only places where cross-epic aggregate and full lifecycle telemetry belongs. Do not post the full breakdown on individual epic issues.

**PR telemetry placement:** Full lifecycle telemetry goes in the **backlog PR description** (appended by `issue-telemetry.sh --pr`), not as a PR comment. The PR body is the single source of truth for the run.

**Cost disclaimer:** All telemetry posts must end with a cost disclaimer note. The `issue-telemetry.sh` script appends this automatically via the template. No manual disclaimer needed.

### Documentation Conventions

- Brainstorms → `docs/1-discovery/`
- Design docs → `docs/2-design/` (date-prefixed)
- Plans → `docs/3-plans/` (date-prefixed)
- Reviews → `docs/4-reviews/`
- Guides → `docs/5-guides/`
- ADRs → `docs/6-adrs/` (numbered: `NNNN-title.md`)
- Diagrams → use Mermaid (`\`\`\`mermaid` code blocks) for all architecture, flow, and sequence diagrams in docs

**Doc approval workflow:** Design docs and plans are written on `docs/<slug>` branches off the integration branch (`backlog/<N>-<slug>`) with a corresponding GitHub Issue (`type/docs`). A PR is opened targeting the integration branch (not `main`). **Merging the PR = approval.** In autonomous mode, the orchestrator auto-merges. In interactive mode, the human merges. The next phase (planner after design, builder after plan) cannot start until the PR is merged.

### Lesson Conventions

Agents write lessons as they discover issues — one file per lesson, organized by epic, tagged for cross-cutting discovery. This avoids merge conflicts when parallel agents write simultaneously and keeps lessons browsable by epic.

#### Folder convention

```text
docs/4-reviews/lessons/
  <backlog-issue>-<feature-slug>/
    e00-setup/                    ← lessons from design/plan/orchestrator-setup phases (pre-epic)
      YYYY-MM-DD-s00-<slug>.md
    eNN-<epic-slug>/
      YYYY-MM-DD-sNN-<slug>.md
```

Example: `docs/4-reviews/lessons/5-calendar-tool/e01-calendar-core/2026-03-09-s01-di-registration-blind-spot.md`

The backlog issue number is the top-level grouping (globally unique), with epic subfolders beneath. File names tie each lesson to the specific story where it was discovered. Use the `e00-setup/` subfolder for lessons discovered during design, plan, or orchestrator-setup phases before any epic begins.

#### File format

```markdown
---
date: 2026-03-09
author: reviewer
story: "E03-S01 (#34) — CalendarToolPlugin with list and get functions"
tags: [builder, di, testing, runtime-failure, review]
severity: critical
---

# DI Registration Blind Spot

## What happened
Builder created service classes but didn't register them in
ServiceCollectionExtensions. 3 critical runtime failures found by reviewer.

## Root cause
Unit tests mock the DI layer, so missing registrations pass all tests.

## Prevention
- Builder MUST verify every new service is registered in the
  corresponding ServiceCollectionExtensions file.
- Reviewer MUST check DI wiring for any new service class.
```

**YAML frontmatter fields:** `date` (ISO), `author` (agent role), `story` (issue ref + title), `tags[]` (freeform — common values: `builder`, `reviewer`, `orchestrator`, `design`, `architecture`, `testing`, `di`, `telemetry`, `github-api`), `severity` (`critical`, `high`, `medium`, `low`).

#### Tag discovery

Find lessons relevant to a specific role:

```bash
grep -rl "tags:.*builder" docs/4-reviews/lessons/       # builder lessons across all features
grep -rl "tags:.*review" docs/4-reviews/lessons/         # reviewer lessons
grep -rl "tags:.*orchestrator" docs/4-reviews/lessons/   # orchestrator lessons
grep -rl "tags:.*design" docs/4-reviews/lessons/         # designer lessons
grep -rl "tags:.*architecture" docs/4-reviews/lessons/   # planner lessons
# Scope to current feature for faster grep:
grep -rl "tags:.*builder" docs/4-reviews/lessons/43-sdlc-v2/
```

#### Who reads and writes lessons

| Agent | Reads | Writes | When it writes |
|-------|-------|--------|----------------|
| Builder | Yes (before starting) | Yes | When it encounters a bug, unexpected behavior, or missing convention during implementation |
| Reviewer | Yes (during review) | Yes | When it finds issues that represent a systemic pattern worth capturing |
| Orchestrator | Yes | Yes | When dispatch or board operations fail unexpectedly |
| Retro | Yes (all) | Yes (supplements) | When it identifies cross-story patterns that individual agents missed |
| Designer | Yes | Yes | When it discovers constraints or trade-offs worth capturing for future designs |
| Planner | Yes | Yes | When plan assumptions prove wrong or dependency graphs need revision |

#### Three-tier retention

| Tier | When | Lesson files | Primary source for agents |
|------|------|--------------|--------------------------|
| **Active** | During the current epic | Live — agents grep freely | Individual lesson files |
| **Compiled** | After retro runs | On disk but deprioritized | Retro doc (`docs/4-reviews/`) |
| **Archived** | After 3-5 epics | Moved to `lessons/archive/` or deleted | Retro doc only |

**Active (current epic):** Builders and reviewers write lessons as they discover issues; agents working on later stories in the same epic grep them immediately. No gating, no compilation step.

**Compiled (retro complete):** After the retro agent synthesizes lessons into the retro doc, the retro doc becomes the primary reference. Prefer `docs/4-reviews/lessons/<backlog-issue>-<slug>/YYYY-MM-DD-eNN-*-retro.md` over grepping individual lesson files for completed epics.

**Archived (3-5 epics later):** Convention changes have been merged into CLAUDE.md; raw lesson files add no further discovery value. Move to `lessons/archive/` or delete. The retro doc is the permanent record.

**Scoping grep for speed:** Scope to the current feature's lesson folder first (`docs/4-reviews/lessons/<issue>-<slug>/`), then fall back to retro docs for older features.

### Known Claude Code Platform Limitations (tested 2026-03-08)

These are limitations of Claude Code itself (not NeuralNorris) that affect how agents are dispatched:

- **Agent tool `model` parameter:** Not in the Agent tool schema (`additionalProperties: false`). You cannot pass a model override when dispatching a subagent — hence the need for builder variant files.
- **Dynamic agent files at runtime:** Agent `.md` files created mid-session are NOT discovered. Agents are loaded at session start only. All agent files must exist before the session begins.
- **PreToolUse hook `updatedInput` on Agent tool:** Crashes with `undefined is not an object (evaluating 'K.length')`. `updatedInput` works for other tools but NOT the Agent tool. Do not attempt to intercept/modify Agent tool inputs via hooks.
- **Nested session detection (tested 2026-03-09):** `claude -p` cannot be invoked inside another Claude Code session — it detects the `CLAUDECODE` environment variable and refuses to start. This is why agents must use the Agent tool for dispatch, not CLI scripts. The dispatch scripts (`dispatch-story.sh`, `dispatch-workflow.sh`) are for standalone terminal use only.

### Convention Change Propagation

When making **any** change in this project, proactively find and update all files that reference the changed concept in the same pass. Don't wait to be asked — propagate changes immediately as part of the same work.

**The rule:** No change is complete until a grep verification confirms all references are consistent. This applies universally — code, scripts, conventions, config, templates, agent files, and documentation.

**How to verify:**

```bash
# Always grep for the concept you changed and review every hit
grep -rn "<changed-concept>" --include="*.md" .
grep -rn "<changed-concept>" --include="*.sh" scripts/

# Examples:
grep -rn "issue-telemetry" --include="*.md" .       # Changed a script flag
grep -rn "308bbc1e" --include="*.md" .               # Changed a board status ID
grep -rn "backlog/" --include="*.md" .claude/agents/  # Changed branch convention
grep -rn "ITool" --include="*.md" .                   # Changed a C# interface
```

**Workflow-specific files to check:**

Changes to the SDLC workflow (scripts, board management, dispatch, telemetry, agent behavior) touch many interconnected files. These are the files that most commonly need updating together:

| File | Contains |
|------|----------|
| `CLAUDE.md` | Helper script signatures, board IDs, workflow conventions, dispatch protocol |
| `.claude/agents/orchestrator.md` | Workflow phases, dispatch commands, board transitions, telemetry posting |
| `.claude/agents/planner.md` | Issue creation, board setup, plan structure, difficulty labels |
| `.claude/agents/designer.md` | Design phase workflow, board transitions |
| `.claude/agents/builder.md` + variants | Build workflow, script usage, TDD protocol |
| `.claude/agents/reviewer.md` | Review criteria, verdict format |
| `.claude/agents/retro.md` | Retro workflow, lesson conventions |
| `scripts/templates/telemetry.md` | Template conditions, variable names, rendering logic |
| `docs/2-design/` | Design docs may describe the workflow being changed |

**Common propagation failures:**
- Changed a script flag but didn't update CLAUDE.md's helper scripts table
- Fixed a template rendering bug but didn't update the template's documentation comment
- Added a board transition step to the orchestrator but didn't update CLAUDE.md's board transitions section
- Changed "post as comment" to "append to issue body" but only updated one of two agent files

### Agent File Maintenance

When project conventions change, update the corresponding agent `.md` files in `.claude/agents/`. Changes that require agent updates include:

- Testing framework or mocking library changes (e.g., NSubstitute → Moq)
- Test naming convention changes
- Build or test command changes
- New project additions to the dependency graph
- Configuration structure changes (NNConfig sections)
- Branch strategy or naming convention changes
- Tool system contract changes (ITool, IKernelTool)
- Documentation structure changes

When making such changes, search agent files for affected references:
```bash
grep -r "<old-pattern>" .claude/agents/
```

**Agent tool list auditing:** When an agent's instructions reference CLI commands (`gh`, `git`, `dotnet`, shell commands), verify that its YAML frontmatter `tools` field includes `Bash`. An agent without `Bash` in its tool list cannot execute any shell commands, even if its instructions describe them in detail. Audit tool lists when adding new CLI-dependent instructions to any agent file.

**Builder variant sync (CRITICAL):** `builder.md` has three model-routed variants (`builder-haiku.md`, `builder-sonnet.md`, `builder-opus.md`). These files share identical body content — only the `name` and `model` fields in the YAML front matter differ. **Any change to `builder.md` body content must be propagated to all three variants.** Use this to sync:

```bash
for variant in haiku sonnet opus; do
  sed "s/^name: builder$/name: builder-$variant/;s/^model: inherit$/model: $variant/" .claude/agents/builder.md > .claude/agents/builder-$variant.md
done
```
