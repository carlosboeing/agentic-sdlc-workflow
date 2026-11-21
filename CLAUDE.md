# CLAUDE.md

> This file is the operating brief that the workflow's agents load at the start of every session: conventions, branch rules, dispatch and telemetry protocols. It was written for agents, not as an introduction. Readers should start with [README.md](README.md), then [docs/architecture.md](docs/architecture.md).

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains an **agentic SDLC workflow** — a set of specialized AI agents, scripts, and conventions that orchestrate the full software development lifecycle: design → plan → build → review → retro. The workflow is domain-agnostic and is being developed toward packaging as a Claude Code plugin.

## Design Philosophy: Determinism First

This workflow turns something inherently non-deterministic (AI/LLM output) into something deterministic and reliable (defined input → structured workflow → predictable output). Every design decision should reinforce this principle.

**The rule:** When a value can be computed deterministically from existing data, compute it. Never rely on an agent to remember, estimate, or manually track what a script can derive from the state file, config, or Git history.

| Prefer | Over | Why |
|--------|------|-----|
| Compute from state file | Track with `$SECONDS` or mental arithmetic | State file is durable; memory and timers are fragile |
| Read from config/pricing file | Memorize or hardcode rates | Config is the single source of truth; memory drifts |
| Derive from Git history | Ask the agent "what did you do?" | Git is immutable; agent recall is approximate |
| Script with validation | Agent judgment call | Scripts are repeatable; judgment varies by context window |
| Convention with enforcement | Convention with trust | Enforcement catches violations; trust assumes compliance |

**Where AI/LLM intelligence belongs:** The non-deterministic strengths of AI — creativity, judgment, adaptation, self-healing — are valuable for:
- **Design and planning:** Brainstorming approaches, evaluating trade-offs, decomposing requirements
- **Content creation:** Writing code, docs, and creative content that meets acceptance criteria
- **Failure recovery:** Diagnosing unexpected errors, working around infrastructure issues, adapting to novel situations
- **Code review:** Applying judgment about quality, security, and convention adherence

**Where determinism must prevail:** The workflow infrastructure — dispatch sequencing, board management, telemetry computation, branch operations, state tracking, cost estimation — must be deterministic. These are the rails that make the AI's output reliable at scale. When an agent makes a mistake in infrastructure (wrong branch, incorrect cost, missed status update), the workflow's credibility degrades even if the content is perfect.

**Evidence:** Run 14 posted wall-clock = sequential duration (102m 43s instead of 74m 4s) because the orchestrator relied on `$SECONDS` tracking instead of computing the critical path from the state file's dispatch log. The state file already contained all the data — `started_at` timestamps naturally encode parallelism. The fix was to compute deterministically from what was already recorded, not to "try harder" to track `$SECONDS`. See `item-telemetry.sh` wall-clock auto-computation.

## Design Philosophy: Fault Tolerance

The workflow runs long autonomous sessions where interruptions are expected: usage limits, crashes, network failures, window closures. The system must recover gracefully without human intervention.

**The rule:** Every workflow checkpoint must be recoverable from durable state. If the orchestrator is interrupted at any point and restarted — potentially on a different machine, in a different session, with no memory of prior work — it must be able to reconstruct its position and resume without data loss.

**Where this applies:**
- **State persistence:** The orchestrator state file captures every dispatch, phase transition, and telemetry data point. If the session is interrupted, the state file enables instant recovery.
- **State reconstruction:** If the state file itself is lost, `state.sh reconstruct` rebuilds it from durable external sources (GitHub issue comments, branch state, board status). The telemetry comments posted on each issue are the write-ahead log that makes this possible.
- **Idempotent operations:** Every phase can be re-entered safely. Branch creation checks for existing branches. Story dispatch checks for "Ready for Review" comments. Board updates are idempotent by design.
- **No silent data loss:** Failed dispatches still record telemetry. Interrupted agents accumulate metrics defensively. The system never drops information that was paid for in tokens and time.

**Where AI judgment belongs in recovery:** The orchestrator uses judgment to decide what to do after recovery (which phase to resume, whether to re-dispatch a failed builder, how to handle partial work). But determining *where we are* — reading the state file, checking GitHub, verifying branch state — must be deterministic and scripted.

## Design Philosophy: Fix What You Find

When you encounter a small, pre-existing bug while working on something else — fix it. Don't defer it, don't file it, don't say "not my problem." If the fix is trivially small (a few lines, obvious correctness, no architectural risk), it costs less to fix now than to context-switch back to it later. The "not my problem" attitude causes small issues to fall through the cracks and accumulate into systemic debt.

**The rule:** If you can fix it in under 5 minutes and the fix is obviously correct, fix it in the same change. If it's larger, file an issue — but bias toward fixing.

**Where this applies:**
- Pre-existing test failures you notice while running tests for your change
- Missing `local` declarations, unguarded exit codes, stale comments
- Off-by-one thresholds, typos in error messages, dead imports
- Any small defect where the cost of fixing now is lower than the cost of rediscovering later

**Where it does NOT apply:**
- Architectural disagreements or design changes (those need discussion)
- Large refactors that change behavior across many files
- Fixes that require understanding context you don't have

**Evidence:** Run 17 — three pre-existing test failures in `test-local-items-sh.sh` (129 tests, 3 failing) were caused by a classic bash trap: `[ -n "$updated_by" ] && ...` as the last statement returns exit 1 when the variable is empty. Two-character fix (`|| true`). Had been failing silently across multiple runs because each agent said "pre-existing, not my problem."

## Design Philosophy: Think Long Term, Execute Short Term

Every design decision should consider the end-state architecture, but every implementation should deliver only what is needed now. Apply pragmatism — build for today's requirements while ensuring today's choices don't block tomorrow's goals.

**The rule:** When making an architectural choice, evaluate it against the long-term vision. If the pragmatic short-term option creates a painful migration later, invest a small amount now to avoid it. If the long-term option adds significant complexity for no immediate value, defer it — but document the future direction so it isn't lost.

| Prefer | Over | Why |
|--------|------|-----|
| Namespace folders for future layers | Flat structure that needs renaming later | One extra directory level now saves a migration later |
| Design the interface, build one adapter | Build all adapters speculatively | Interface is the hard part; adapters are mechanical |
| Document deferred decisions in the design doc | Trust future agents to rediscover the plan | Design docs are durable; agent recall is not |
| YAGNI on dead code | Building stubs "just in case" | Dead code rots; documented intent survives |
| Small structural investments (naming, folder layout) | Punting all future concerns | Structural changes are cheap now, expensive at scale |

**How this plays out in practice:**
- **Design phase:** Explore the full long-term architecture (all layers, all adapters, all edge cases). Use adversarial triangulation — multiple perspectives evaluating trade-offs independently.
- **Plan phase:** Scope the implementation to what delivers value now. Document what was deferred and why.
- **Build phase:** Execute only the scoped plan. Don't sneak in future work.
- **Review phase:** Check that short-term choices align with the documented long-term direction.

**Evidence:** Backlog #109 designed a three-layer abstraction landscape (PM, VCS, DOC) but scoped implementation to PM-only with ~13 functions. The folder structure was namespaced as `adapters/pm/github/` (not `adapters/github/`) — a trivial investment that ensures VCS and DOC layers slot in without migration. The VCS and DOC boundaries were documented with deferred function signatures, preserving the vision without building dead code.


## Project Documentation

- `README.md` — architecture overview, PM architecture diagram, project structure
- `docs/1-discovery/VISION.md` — long-term vision and aspirations
- `docs/CHANGELOG.md` — build history
- `docs/2-design/` — feature design documents
- `docs/3-plans/` — implementation plans
- `docs/4-reviews/` — code reviews and retros
- `docs/6-adrs/` — architecture decision records

## Configuration

Workflow configuration lives in `.claude/agentic-sdlc-config.json`. See `docs/2-design/2026-03-15-configurable-workflow-settings.md` for field documentation. All scripts read from this config file via the shared `scripts/lib/config.sh` library.

**`reviewStrategy` section** — controls per-story review skipping:

```json
"reviewStrategy": {
  "skipPerStoryReview": {
    "enabled": true,               // bool, default: false — master switch
    "conditions": {
      "maxDifficulty": "easy",     // string: "easy"|"medium"|"hard" — max difficulty to skip
      "requireLabel": "test-agentic-sdlc"  // string — backlog label required; "" means no label required
    }
  }
}
```

When `enabled` is `false` (the default), all stories receive per-story reviewer dispatch regardless of difficulty. When `enabled` is `true`, stories satisfying all conditions are assigned `review_tier = SKIP` and bypass per-story review. The PR-level review (Phase 5) always runs.

Config variables exposed by `scripts/lib/config.sh` (see **Review Tier Logic** in the Dispatch Protocol section):

| Variable | Config path | Default |
|----------|-------------|---------|
| `CFG_SKIP_REVIEW_ENABLED` | `.reviewStrategy.skipPerStoryReview.enabled` | `"false"` |
| `CFG_SKIP_REVIEW_MAX_DIFFICULTY` | `.reviewStrategy.skipPerStoryReview.conditions.maxDifficulty` | `"easy"` |
| `CFG_SKIP_REVIEW_REQUIRE_LABEL` | `.reviewStrategy.skipPerStoryReview.conditions.requireLabel` | `""` |

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

- Always check GitHub Issues first (`./scripts/item-list.sh`) to understand project state
- Never start work without a corresponding GitHub Issue
- Use conventional commits: `<type>(<scope>): <description>`
- **Never use `#N` in commit messages** unless intentionally referencing a GitHub issue. GitHub auto-links any `#N` pattern to issue N, so reviewer warning numbers, list indices, or other numbered references must use a format without `#` (e.g., `warning 4`, `W4`, `item 4`). The `Fixes #N` / `Closes #N` footer is the correct place for issue references.
- Reference `README.md` for architecture context (PM architecture diagram, project structure, workflow overview)
- Write lesson files when encountering bugs, unexpected behavior, or missing conventions (see Lesson Conventions below)
- **Browser automation / UI testing artifacts:** When taking screenshots or saving test artifacts using any browser automation tool (Playwright, Puppeteer, Cypress, Selenium, etc.), always save to a dedicated output directory (e.g., `.playwright-mcp/`, `.test-artifacts/`) — never to the project root or working directory. These artifacts should be gitignored. If the tool supports an `--output-dir` flag or equivalent configuration, use it.
- **Local PM data lives in SQLite** (`.agentic-workflow/workflow.db`) via the workflow server — no files to commit. The `pm.adapter` config field names the remote sync target (e.g., `"github"` for dual-write to the GitHub API). The old file-based adapter (`adapters/pm/local/`) is retained for tests only. See `server/` directory and `docs/2-design/2026-03-22-workflow-runtime-service-design.md` for the server architecture.

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
| Difficulty | `difficulty/easy`, `difficulty/medium`, `difficulty/hard` | Stories only — routes to builder model variant |
| Size | `size/S`, `size/M`, `size/L`, `size/XL` | Backlog items only — t-shirt sizing for prioritization |

**Difficulty and Size are separate concerns applied at different levels:**

- **Difficulty** (stories only): Assigned by the planner. Routes to the builder model variant (`easy`/`medium` → sonnet, `hard` → opus). This is an internal dispatch routing concern — it determines which model builds the story.
- **Size** (backlog items only): T-shirt sizing for effort estimation and roadmap prioritization. **When creating a backlog item, always assign a `size/*` label** — assess the scope from the description and apply `S`, `M`, `L`, or `XL`. This applies whether running as the orchestrator agent or in a standard CC session. Currently used for human visibility on the roadmap. May eventually be used by the orchestrator to adjust workflow behavior (e.g., extra verification steps for XL items).

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

**Issue naming:** `[#<backlog>/ENN] Epic title` for epics, `[#<backlog>/ENN-SNN] Story title` for stories

**Dependency declaration (REQUIRED on all work items):** Every issue at every level (backlog, epic, story) must include a `**Blocked by:**` line in the body. The orchestrator parses this line in Phase 0 to validate dependencies before starting work.

Format: `**Blocked by:** none` or `**Blocked by:** #109, #110, #111`

- Always present — use `none` explicitly, never omit the line
- Use issue numbers with `#` prefix — renders as clickable links on GitHub
- Optional parenthetical descriptions: `**Blocked by:** #109 (PM Abstraction Layer)`
- Machine-parsed by the orchestrator with portable tools (BSD and GNU): `sed -n 's/.*Blocked by:\*\* *//p' | grep -oE '#[0-9]+'`. Title prefixes follow the same scheme: `[#<backlog>/ENN] Epic title`, `[#<backlog>/ENN-SNN] Story title`, and `[#<backlog>] Write design doc for X` / `[#<backlog>] Write implementation plan for X` / `[#<backlog>] Write retrospective for X` for doc issues. The backlog issue itself is also prefixed with `[#<N>]` by the orchestrator in Phase 0 (the number is known once the issue exists). This prefix disambiguates issues across features and makes them scannable on the project board.

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

Link sub-issues using `item-link-child.sh`:

```bash
./scripts/item-link-child.sh <parent-number> <child-number>
```

**Dependency diagrams on issues:** After the planner creates all issues, they MUST append the Mermaid dependency graph from the plan to the **issue description** (body) of the **backlog issue** (full cross-epic graph + dispatch plan table) and each **epic issue** (subset for that epic's stories). Use `./scripts/item-append-body.sh <N> "<content>"` to append below the existing body. This keeps dependency structure and wave assignments visible at the top of the issue page. See `planner.md` for the exact format.

**GitHub Project board:** All issues live on the configured project board (optional).

Status field values and their meanings:

| Status          | Meaning                                           | Set by                                             |
|-----------------|---------------------------------------------------|----------------------------------------------------|
| **Backlog**     | Unplanned work items                              | Default for new backlog items                      |
| **Ready**       | Has acceptance criteria, ready for dispatch       | Planner (on story creation)                        |
| **In Progress** | Currently being worked on                         | Orchestrator (at design phase start for backlog; before dispatch for stories) |
| **In Review**   | Implementation complete, awaiting backlog PR merge | Orchestrator (sequentially, after builder completes) |
| **Done**        | Completed and merged to `main`                    | On issue close (`item-close.sh`)                  |

**Epic status sync:** An epic's status must always reflect the aggregate of its stories:

- If at least one story is **In Progress** → epic is **In Progress**
- If all stories are **In Review** (none In Progress/Ready) → epic is **In Review**
- If all stories are **Done** → epic is **Done**
- The orchestrator must update the epic's board status whenever a story transitions.

**Board transitions in autonomous mode:** The orchestrator owns all board transitions that would normally be human-triggered. Specifically:

1. **After plan PR merge:** Set all story issues to **Ready** (sequentially, one at a time)
2. **Before dispatching a builder:** Set the story to **In Progress** (sequentially, before dispatch -- not delegated to builder scripts)
3. **After builder completes:** Set the story to **In Review** (sequentially, after completion -- not delegated to builder scripts). For SKIP-tier stories (no per-story reviewer), set to **In Review** immediately after the build; the status reflects that the story is complete and awaiting the backlog PR merge, not a per-story review.
4. **After parallel wave completes:** Verify board status for all stories in the wave and fix any that didn't transition correctly
5. **After parallel wave completes (comment verification):** Query each story in the wave for expected issue comments ("Work Started" from `item-start.sh`, "Ready for Review" from `item-review.sh`). Parallel builders may fail to post comments due to concurrent GitHub API contention. Post any missing comments retroactively. Evidence: Run 4 (issue #114 missing both comments), Run 11 (issues #47 and #48 missing comments in 3-way parallel wave).

Builder scripts (`item-start.sh`, `item-review.sh`) also update the board as defense-in-depth (they call `item-set-status.sh` internally), but the orchestrator is the source of truth. All board updates must be serialized -- the GitHub Projects API does not handle concurrent `item-edit` calls reliably.

Adding an issue to the project and setting its status: use `item-create.sh` (which calls `pm_add_to_board` internally). For pre-existing issues not yet on the board (**NOTE:** `gh project item-add` does NOT assign a default status -- the item appears with `status: null` and is invisible in status-filtered views. Always follow up with an explicit status set):

```bash
# Add a pre-existing issue to project (does NOT set status — item will have status: null)
gh project item-add <project-number> --owner <owner> --url <issue-url> --format json

# REQUIRED: Set status explicitly after adding
./scripts/item-set-status.sh <issue-number> in-progress

# Or manually (use the option ID from the project field):
# NOTE: gh project item-list output contains control characters that break jq -- always pipe through tr -d
ITEM_ID=$(gh project item-list <project-number> --owner <owner> --format json --limit 100 | tr -d '\x00-\x1f' | jq -r '.items[] | select(.content.number == <issue-number>) | .id')
gh project item-edit --project-id "<project-id>" --id "$ITEM_ID" \
  --field-id "<status-field-id>" \
  --single-select-option-id "<option-id>"
```

Status option IDs:

| Status      | Option ID  |
|-------------|------------|
| Backlog     | `<backlog-option-id>` |
| Ready       | `<ready-option-id>` |
| In Progress | `<in-progress-option-id>` |
| In Review   | `<in-review-option-id>` |
| Done        | `<done-option-id>` |

Read the option IDs for your board from its Status field (`gh project field-list <project-number> --owner <owner> --format json`) and record them in `.claude/agentic-sdlc-config.json`.

**DANGER: Never use `updateProjectV2Field` to add/modify status options.** That mutation replaces the entire option set, generating new IDs and wiping all existing item statuses. To add a new status option, use the GitHub web UI (Project → Settings → Status field) and then update the option IDs in this file.

**GitHub GraphQL API rate limit awareness:** The GraphQL API has a 5000 points/hour budget. Heavy commands like `gh project item-list` (fetches all items with all fields) consume many points per call — the planner's issue creation + board setup can use 50-60 calls, and `item-set-status.sh` calls `item-list` twice per invocation (lookup + verification). When possible, prefer lightweight per-issue queries to look up board item IDs:

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
| `scripts/item-get.sh <N> [--json <fields>]` | Read a work item (replaces `gh issue view`) |
| `scripts/item-list.sh [--label <l>] [--state <s>] [--limit <n>]` | List work items (replaces `gh issue list`) |
| `scripts/item-link-child.sh <parent> <child>` | Link a child sub-issue to a parent (replaces `gh api graphql ... addSubIssue`) |
| `scripts/item-comment.sh <N> <body>` | Post a comment on a work item (replaces `gh issue comment`) |
| `scripts/item-create.sh <level> --title <t> [--body <text>] [--label <l>] ... [--slug <s>]` | Create work item (backlog/epic/story/docs). For backlog with --slug: full Phase 0 setup (board + status + label) |
| `scripts/item-set-status.sh <n> <status>` | Set project board status (backlog/ready/in-progress/in-review/done) |
| `scripts/batch-set-status.sh <n>:<status> [<n>:<status> ...]` | Set board status for multiple issues: fetch-all, mutate-sequentially, verify-once |
| `scripts/item-start.sh <n> --model <m> --agent <a>` | Post "Work Started" comment + set board to In Progress |
| `scripts/item-review.sh <n> <commit>` | Post "Ready for Review" comment + set board to In Review |
| `scripts/item-telemetry.sh <n> --model <m> --duration <ms> --commit <hash> [--tokens <n>] [--tool-uses <n>] [--rate <cents>] [--cost <dollars>] [--wall-clock <ms>] [--breakdown <md>] [--gantt <md>] [--gantt-from-state <state-file>] [--gantt-mode <work\|wall-clock>] [--summary <md>] [--footer <md>] [--pr <n>] [--dispatches <json>] [--dispatches-from-state <state-file>]` | Post telemetry (story, epic, or backlog) |
| `scripts/lib/compute-dispatches.py --from-state <state-file> [--gantt] [--gantt-mode <work\|wall-clock>] [--pricing <file>] [--config <file>]` | Compute dispatch metrics (breakdown, summary, Gantt, fix cycles) from state or dispatch JSON. `--gantt-mode work` (default) collapses gaps; `wall-clock` uses absolute timestamps. |
| `scripts/state.sh <subcommand> [args]` | Orchestrator state CRUD: init, update, get, overhead, lifecycle-duration, reconstruct |
| `scripts/item-close.sh <n>` | Close item + set board to Done |
| `scripts/item-append-body.sh <n> <content>` | Append content to item body via PM dual-write |
| `scripts/cleanup-post-merge.sh [--dry-run] [<backlog-number>]` | Human post-merge step. Without a number: report only. With a number: removes that item's merged branches (local and `origin`), clean worktrees and run state; keeps unmerged branches, open-PR branches and dirty worktrees |
| `scripts/check-board-drift.sh <n> <status>` | Diagnostic: set board status, re-verify at +10s and +30s for drift |
| `scripts/reconcile-board.sh --from-state <state-file> [--epic-issues <json>] [--dry-run]` | Reconcile board statuses with state file (1 API query to read, 1 per fix) |
| `scripts/validate-logs.sh` | Report on board-status, orchestrator, and drift logs |
| `scripts/setup-labels.sh` | Create all labels (idempotent) |
| `scripts/fetch-pricing.sh` | Fetch live API pricing and cache locally (JSON to stdout) |
| `scripts/dispatch-story.sh <n> --model <m> --agent <a>` | Dispatch CC CLI worker for a story |
| `scripts/dispatch-workflow.sh <n> [--skip-design] [--skip-plan] [--autonomous]` | Full lifecycle orchestration |

### Dispatch Protocol

#### Model routing

Map difficulty label to builder variant:

- `difficulty/easy` → `builder-sonnet`
- `difficulty/medium` → `builder-sonnet`
- `difficulty/hard` → `builder-opus`

#### In-session dispatch (primary)

**Universal worktree isolation (autonomous mode):** In autonomous mode, **every** Agent tool dispatch MUST use `isolation: "worktree"` — not just parallel builders. This includes designers, planners, builders (parallel and sequential), reviewers, and retro agents. Without worktree isolation, agents share the main working directory and are affected by stale branches, leftover artifacts, and checkout collisions from other active backlog items. The only exception is interactive mode where a human is actively monitoring. Evidence: Run 15 (backlog #105) had repeated checkout collisions with `backlog/106-telemetry-accuracy` artifacts, including a commit landing on the wrong branch.

Use the Agent tool with `subagent_type: "builder-<model>"`:

1. Read difficulty label from GitHub Issue
2. Determine `review_tier` for each story (see **Review Tier Logic** below)
3. Dispatch with `subagent_type: "builder-sonnet"` (or haiku/opus) — all independent stories in parallel
4. Builder runs `item-start.sh` (posts comment + sets board to **In Progress**) → implements via TDD → runs `item-review.sh` (posts comment + sets board to **In Review**)
5. Post telemetry (orchestrator — see below)
6. Update epic board status (see **Epic status sync** above)
7. **Dispatch reviewers in parallel for REVIEW-tier stories; skip SKIP-tier stories**: `subagent_type: "reviewer"`, one per REVIEW-tier story, all in parallel
8. For `REQUEST_CHANGES` verdict: **dispatch fix builders in parallel** for all stories with changes requested, then **re-dispatch reviewers in parallel** for the fixed stories (max 2 fix cycles per story)
9. Merge story branches into epic branch (only after review passes for REVIEW-tier; immediately for SKIP-tier)
10. After all stories complete: merge epic branches into integration branch, open backlog PR, post telemetry
11. **Dispatch PR reviewer and retro in parallel** (both with `isolation: "worktree"`):
    - PR reviewer (`reviewer`): reviews frozen branch snapshot
    - Retro (`retro`): writes retro doc in worktree, does NOT push until PR review completes
    - This saves ~6 min/run. The retro does not modify files under review — it only adds docs.
    - **Note:** PR review (Phase 5) always runs regardless of story-level review tiers — SKIP only applies to per-story reviews.
12. If PR reviewer finds issues: dispatch builder to fix on integration branch, then re-review (max 2 cycles). Retro results remain valid.
13. After both complete: merge retro worktree commits into integration branch, push
14. Backlog PR is left open for human review (orchestrator NEVER auto-merges it)

#### Review Tier Logic

Before dispatching any wave, determine each story's `review_tier` using config variables from `scripts/lib/config.sh`:

```
CFG_SKIP_REVIEW_ENABLED          (default: "false")
CFG_SKIP_REVIEW_MAX_DIFFICULTY   (default: "easy")
CFG_SKIP_REVIEW_REQUIRE_LABEL    (default: "")
```

Assignment rules:

```
IF CFG_SKIP_REVIEW_ENABLED == "true"
   AND story difficulty <= CFG_SKIP_REVIEW_MAX_DIFFICULTY
   AND (CFG_SKIP_REVIEW_REQUIRE_LABEL == "" OR backlog item has label CFG_SKIP_REVIEW_REQUIRE_LABEL):
   review_tier = SKIP
ELSE:
   review_tier = REVIEW
```

**Difficulty ordering:** easy < medium < hard. "Less than or equal to easy" means only easy qualifies; "less than or equal to medium" means easy and medium qualify.

**SKIP tier applies only to per-story reviews.** The PR review in Phase 5 always runs regardless of review tier. SKIP stories skip only the per-story reviewer dispatch (step 7 above) — they still get built, merged, and covered by the cross-story PR review.

**Default behavior (feature disabled):** When `CFG_SKIP_REVIEW_ENABLED` is `"false"` (the default), all stories are assigned `review_tier = REVIEW`. No stories skip per-story review.

Record `review_tier` in the state file dispatch entry for each builder dispatch (alongside `agent`, `model`, `issue`, `duration_ms`, etc.).

#### CLI dispatch (standalone terminal only)

For humans running builds from a terminal or CI — **not usable by agents**. `claude -p` refuses to start inside another Claude Code session (nested session detection), so the orchestrator and all agents must use the Agent tool for dispatch.

```bash
./scripts/dispatch-story.sh <issue-number> --model sonnet --agent builder --epic-branch epic/eNN-slug
```

#### Builder variants

Three model-specific variants exist alongside `builder.md`:

- `.claude/agents/builder-haiku.md` — available but not used by default (Sonnet is preferred for easy stories)
- `.claude/agents/builder-sonnet.md` — for `difficulty/easy` and `difficulty/medium` stories
- `.claude/agents/builder-opus.md` — for `difficulty/hard` stories

All variants share identical body content with `builder.md` (only the `model` frontmatter differs). **When updating `builder.md`, propagate changes to all three variants.**

**Telemetry is mandatory:** The orchestrator MUST post telemetry after each builder completes, before moving to the next story. The Agent tool result includes `duration_ms`, `total_tokens`, and `tool_uses` — pass all of them. **Capture telemetry even from failed or usage-limited dispatches** — they still consume tokens and time, and zeroing them out underreports actual costs. **When resuming an interrupted agent**, capture metrics from each invocation (interrupted + resumed) and sum them — it is unknown whether the resumed result reports cumulative or delta-only metrics:

```bash
./scripts/item-telemetry.sh <issue-number> \
  --model <haiku|sonnet|opus> \
  --duration <duration_ms> \
  --commit <commit hash> \
  --tokens <total_tokens> \
  --tool-uses <tool_uses>
```

The script computes speed (tokens/s) and estimated cost automatically from the model and token count. The commit hash can be obtained from the builder's `item-review.sh` comment or by checking the story branch head.

Add `--pr <pr-number>` to also post telemetry as a comment on the story PR. Every completed story must have all three comments on its issue: "Work Started" (`item-start.sh`, by builder), "Ready for Review" (`item-review.sh`, by builder), and "Telemetry" (`item-telemetry.sh`, by orchestrator).

**Parallel dispatch:** When multiple stories share no dependencies (check the plan's dependency graph), dispatch their builder agents **in parallel** using concurrent Agent tool calls. Each parallel builder works on its own story branch. After all builders complete, dispatch reviewers **in parallel** for all REVIEW-tier stories in the wave (not sequentially). If any stories require fixes, dispatch fix builders **in parallel**, then re-reviewers **in parallel**. All dispatches already use `isolation: "worktree"` per the universal rule above. After parallel dispatch completes, verify each story branch contains only its expected files before merging.

**Story branch creation for parallel waves (REQUIRED):** All epic branches and story branches are created upfront in **Phase 2** (before any dispatch) — not lazily at dispatch time. See `orchestrator.md` Phase 2 for the authoritative procedure with code examples. Key invariants: all story branches for an epic are created from the same epic branch commit (the base SHA is recorded in `epics.*.base_sha` in the state file); no story work is pushed to the epic branch until the entire wave completes; if a story branch is found to have diverged from the expected base, cherry-pick only that story's own commits onto a fresh branch from the recorded base before merging. This eliminates the cross-contamination class of error observed in Run 9 (E01-S03, issue #20) where a builder started from a sibling story's HEAD instead of the epic base.

**Post-worktree cleanup (REQUIRED):** After all worktree-dispatched builders complete, the orchestrator MUST:
1. Check for untracked files left in the main working tree: `git status --short`
2. Clean up any stale artifacts before proceeding to merges: `git clean -fd` (after verifying no wanted files are affected)
3. Verify each story branch was pushed to remote: `git ls-remote --heads origin <branch>` — worktree-isolated builders may not push automatically. If a branch is missing from remote, push it manually before merging.

**This cleanup also applies before fix cycle dispatches.** When re-dispatching a builder for a fix cycle in worktree mode, run the same cleanup steps first. Stale artifacts from the original parallel wave may still be present and can leak into the fix cycle's commits. Evidence: Run 14 E01-S04 fix cycle 2 (commit `9aa16c7`) picked up E02-S01's `violation-quantum-bistro.md` from a stale worktree, requiring manual removal (commit `d537441`).

**Parallel dispatch git safety (defense-in-depth):** With worktree isolation enabled, these rules serve as a secondary safety net. They remain mandatory for any non-worktree parallel dispatch:
- **Chain all git operations in a single Bash call:** `git checkout <branch> && git add <files> && git commit -m "msg"` — never split checkout and commit across separate Bash calls.
- **Verify branch before every commit:** Include `git branch --show-current` in the same `&&` chain, not in a separate call.
- **Use explicit file paths with `git add`** — never `git add .` which may stage files from other agents' work.

**Epic branches must be created from the integration branch:** Always `git checkout backlog/<N>-<slug> && git pull` before `git checkout -b epic/eNN-slug`.

**Integration and epic branches must be pushed to remote:** After creating the integration branch and epic branches, immediately push them with `git push -u origin <branch>`. After merging each story into its epic branch (and each epic into the integration branch), push again to keep the remote in sync. This prevents data loss if the local machine fails.

#### Full lifecycle orchestration

The orchestrator can handle the entire lifecycle from design to retro:

```bash
# Autonomous — full live UI with real-time progress (see the README section on running safely)
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

**Link all issues to the PR:** The backlog PR body MUST include `Closes #NN` for every **open** issue that should auto-close on merge: the backlog issue, every epic issue, and every story issue (e.g., `Closes #57, closes #58, closes #59, ...`). **Already-closed issues** (design doc, plan, retro) must NOT use the `Closes` keyword — list them separately as `Related (already closed): #24, #25, #42`. The `Closes` keyword links the PR to the issue, which triggers GitHub's default "Pull request linked to issue" automation and reverts Done → In Progress. This was the root cause of board status drift observed across Runs 3-16 (observation iv). Using `Closes` on already-closed issues provides no functional benefit (auto-close is a no-op on closed issues) while triggering status reversions.

**Board reconciliation (defense-in-depth):** After opening the backlog PR (which links issues and may trigger external automations), wait 5 seconds, then run a full board reconciliation:

```bash
sleep 5  # allow automations to fire
./scripts/reconcile-board.sh --from-state .agentic-workflow/runs/<N>/orchestrator.json \
  --epic-issues '{"e01":<N>,"e02":<N>,...}'
```

The script reads the state file, computes expected statuses deterministically, batch-queries actual statuses (1 API point), and fixes discrepancies. Call at every phase boundary and as a final step before workflow completion.

**Update changelog:** The integration branch MUST include a `docs/CHANGELOG.md` entry. Added during Phase 5 documentation propagation (after all fix cycles and retro are complete, when the code is final). Add the entry under the current date, following the existing format (feature summary + bullet points). For test run entries, include the wall-clock duration in the heading: `**Run N -- <Topic>** (backlog #NNN, 25m wall-clock)`. Read `session.lifecycle_duration_ms` from the orchestrator state file to get the exact duration — do not estimate.

**Internal merges (epic → integration branch):** Epic branches merge into the integration branch using `--no-ff` merge (not squash). This is an internal merge — only the final PR to `main` uses squash. Design/plan PRs targeting the integration branch also use regular merge (`--merge`).

**Cost computation for manual breakdown strings (CRITICAL):** When the orchestrator writes `--breakdown`, `--summary`, or `--cost` strings, it must compute cost estimates using rates from `.agentic-workflow/pricing.json` (cached by `fetch-pricing.sh`) — never from memory or hardcoded values. The preferred method is `--dispatches-from-state` which computes everything automatically from the orchestrator state file, including wall-clock duration. See `.claude/agents/orchestrator.md` § "Cost Computation" for the rule.

**Wall-clock auto-computation:** When `--dispatches-from-state` or `--gantt-from-state` is used, `item-telemetry.sh` automatically computes wall-clock duration from the `started_at` timestamps in the dispatch log. Dispatches with the same `started_at` ran in parallel (take `max(duration_ms)`); different timestamps ran sequentially (sum). The orchestrator does NOT need to pass `--wall-clock` when using either flag — it is computed deterministically. If `--wall-clock` is passed but equals `--duration` (which is always wrong when parallel dispatches exist), the script overrides with the computed value and warns. Evidence: Run 14 posted wall-clock = sequential (102m 43s) when actual critical path was 74m 4s.

**Per-epic telemetry:** When all stories in an epic are complete, the orchestrator MUST post telemetry on **the epic issue** (via `item-telemetry.sh`). Pass `--duration` (sequential sum of story durations in that epic) and `--wall-clock` (actual elapsed time for that epic's waves). Include a `--breakdown` with only that epic's stories. Use the integration branch head for `--commit`.

**Mixed-model epics:** When stories use different models, pass `--model 'mixed (model1, model2)'` and `--cost <dollars>` with the pre-computed aggregate cost (sum of per-story costs from the breakdown). For example: `--model 'mixed (haiku, sonnet)' --cost 0.67`. The `--cost` flag overrides the rate-based calculation, so the summary table shows the correct total instead of `—`.

**Backlog-level telemetry:** After all stories are built, reviewed, and merged into the integration branch — and the retro is complete — the orchestrator MUST post a **full lifecycle telemetry summary** using `item-telemetry.sh` with `--summary`:

```bash
./scripts/item-telemetry.sh <backlog-number> \
  --model opus --duration <total_ms> \
  --commit <hash> --tokens <total_tokens> --cost <total_dollars> \
  --summary "<phase-summary-rows>" \
  --breakdown "<per-dispatch-rows>" \
  --gantt-from-state .agentic-workflow/runs/<backlog>/orchestrator.json \
  --footer "<trailing-notes>" \
  --pr <pr-number>
```

When `--gantt-from-state` is provided, the script calls `compute-dispatches.py` with `--from-state --gantt` to generate the Mermaid Gantt body automatically from dispatch data. Wall-clock duration is also computed automatically — `--wall-clock` does not need to be passed. Pass `--gantt "<mermaid-gantt-body>"` only as a fallback when the state file is unavailable.

The script renders from `scripts/templates/telemetry.md` (single source of truth for all telemetry formatting). When `--summary` is provided, the script:
- Renders the backlog-level format: Summary → Breakdown → Duration → Timeline → Footer → Disclaimer
- Posts the telemetry as a comment on the backlog issue
- When `--pr` is also provided, appends the telemetry to the PR description (not as a comment)

The orchestrator must capture `duration_ms`, `total_tokens`, and `tool_uses` from every Agent tool dispatch (designers, planners, builders, reviewers, retro) and aggregate them into the summary and breakdown rows. See `.claude/agents/orchestrator.md` § "Phase 6: Telemetry + Cleanup" for the full command.

**Value column convention:** Value cells in all telemetry tables contain only numbers and units (e.g., `30m 43s`, `770K`, `~$4.79`). Never add descriptive text or parenthetical notes to value cells. Annotations belong in the Metric/Label column (e.g., `**Actual Duration** _(with parallelism)_` in Metric, `25m 12s` in Value). This matches the rule in `scripts/templates/telemetry.md`.

**Duration precision:** Duration values (including totals) must use exact `Xm Ys` format, not rounded approximations like `~31m`. Durations are measured from `duration_ms`, not estimated. Costs may use `~` prefix (they are estimates based on blended rates).

**`--cost` flag for mixed-model epics:** When an epic's stories use different models (e.g., haiku + sonnet), the rate-based cost calculation doesn't work. Pass `--cost <dollars>` with the pre-computed sum of per-story costs from the breakdown. For single-model epics, omit `--cost` and let the script compute from the rate.

**Gantt color tagging:** Gantt task tags control bar colors — `:active` (violet) for design/plan/retro, no tag (emerald) for builds, `:done` (yellow) for reviews, `:crit` (red) for fix cycles. When using `--gantt-from-state`, `compute-dispatches.py` assigns these tags automatically based on agent type — the orchestrator does not need to set them manually. Do not use `:active` on build or review tasks when constructing Gantt strings manually.

**Fix cycle footer convention:** When fix cycles are detected, a fix cycle summary row and footer line are automatically included in the telemetry output. This happens whenever `--dispatches-from-state` or `--gantt-from-state` is used — no manual `--footer` flag is needed to capture fix cycle metrics. The footer line is formatted: `*Fix cycles: <count> / <total_stories> stories (<rate>% fix rate), adding <duration> and <cost> (<pct>% of total cost).*`

**Capturing orchestrator overhead:** The orchestrator's own tokens run in the parent session and aren't returned by the Agent tool. Use the wall-clock heuristic to estimate overhead duration:

- **Formula:** `overhead_duration = total_wall_clock_ms - sum(critical_path_subagent_ms)`
- **Where:** `total_wall_clock_ms` = time from `session.start_wall_clock` to Phase 6 completion; `critical_path_subagent_ms` = sum of `max(duration_ms)` per parallel wave from `dispatches[]`
- **State file fields:** `session.start_wall_clock` (ISO timestamp set in Phase 0), `overhead.duration_ms` (computed in Phase 6), `overhead.estimated_cost` (nullable — not measurable)
- **Token overhead is NOT directly measurable.** The parent session tokens are not returned by the Agent tool. Set `overhead.estimated_cost` to null unless `/cost` was captured manually at session start and end via the Claude Code UI.
- **Include an "Orchestrator" row** in the backlog telemetry summary table with the computed duration. Use `—` for tokens and cost columns since they cannot be measured from the Agent tool result.

**Orchestrator state persistence:** The orchestrator persists its full workflow state to `.agentic-workflow/runs/<backlog>/orchestrator.json` (gitignored). Schema defined in `scripts/schemas/orchestrator-state.v1.json`. Key fields:

- **`session.orchestrator_model`** — the model the orchestrator is running, so inherited agents' models are known for accurate cost estimates.
- **`pricing`** — token rates fetched live from Anthropic's pricing page at session start via `scripts/fetch-pricing.sh`. Cached in `.agentic-workflow/pricing.json`. Config `pricing` section is an optional override for custom/contract rates. Used by `item-telemetry.sh` via the `--rate` flag.
- **`dispatches[]`** — append-only log of every agent dispatch with model, duration, tokens, tool uses, result, and `review_tier`. The `review_tier` field (`"REVIEW"` or `"SKIP"`) is recorded for every builder dispatch entry and used by `compute-dispatches.py` to annotate the Gantt chart and telemetry breakdown. Example entry:
  ```json
  {"agent":"builder-sonnet","model":"sonnet","issue":112,"started_at":"...","duration_ms":109000,"tokens":103000,"tool_uses":18,"result":"success","review_tier":"REVIEW"}
  ```

**Initialize:** `./scripts/state.sh init <N> --mode autonomous --model <model>`

**Update** after phase changes, dispatches, story transitions:
```bash
./scripts/state.sh update --dispatch '<json>'
./scripts/state.sh update --story <N> --status <status>
./scripts/state.sh update --phase <name> --status <status>
./scripts/state.sh update --epic <slug> --base-sha <sha>
```

**Read:** `./scripts/state.sh get '<jq-path>'`

**Fallback (no state file):** Run `./scripts/state.sh reconstruct <backlog-number>` to rebuild from GitHub issue comments, branch state, and board status. **Note:** `reconstruct` is currently a stub (not yet implemented). Until then, use idempotent restart: check "Ready for Review" comments, merged branches, re-fetch pricing.

See `.claude/agents/orchestrator.md` § "Orchestrator State File" for the full lifecycle and state readers table.

**Epic-scoped telemetry:** When posting epic-level telemetry on epic issues, include only stories that belong to that specific epic (check the epic's sub-issues). The backlog PR and backlog issue are the only places where cross-epic aggregate and full lifecycle telemetry belongs. Do not post the full breakdown on individual epic issues.

**PR telemetry placement:** Full lifecycle telemetry goes in the **backlog PR description** (appended by `item-telemetry.sh --pr`), not as a PR comment. The PR body is the single source of truth for the run.

**Cost disclaimer:** All telemetry posts must end with a cost disclaimer note. The `item-telemetry.sh` script appends this automatically via the template. No manual disclaimer needed.

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
  YYYY-MM-DD-<feature-slug>/
    e00-setup/                    ← lessons from design/plan/orchestrator-setup phases (pre-epic)
      YYYY-MM-DD-s00-<slug>.md
    eNN-<epic-slug>/
      YYYY-MM-DD-sNN-<slug>.md
```

Example: `docs/4-reviews/lessons/synthetic-workloads/2026-03-13-run10-orchestrator-logging/e00-setup/2026-03-13-s00-rate-limit-item-list.md`

The date-prefixed directory groups lessons by feature, with epic subfolders beneath. The backlog issue number is stored in the retro doc's YAML frontmatter, not in the directory name. File names tie each lesson to the specific story where it was discovered. Use the `e00-setup/` subfolder for lessons discovered during design, plan, or orchestrator-setup phases before any epic begins.

#### File format

```markdown
---
date: 2026-03-09
author: carlosboeing
agent: reviewer
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

**YAML frontmatter fields:** `date` (ISO), `author` (GitHub username of the human collaborator), `agent` (agent role that produced the doc: `designer`, `planner`, `builder`, `reviewer`, `orchestrator`, `retro`, or `general`), `story` (issue ref + title), `tags[]` (freeform — common values: `builder`, `reviewer`, `orchestrator`, `design`, `architecture`, `testing`, `di`, `telemetry`, `github-api`), `severity` (`critical`, `high`, `medium`, `low`). Use lowercase for `status` values (`draft`, `approved`, `implemented`).

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

> These limitations were observed in March 2026, and several no longer hold. See `docs/architecture.md` for the current platform assumptions.

These are limitations of Claude Code itself that affect how agents are dispatched:

- **Agent tool `model` parameter:** Not in the Agent tool schema (`additionalProperties: false`). You cannot pass a model override when dispatching a subagent — hence the need for builder variant files.
- **Dynamic agent files at runtime:** Agent `.md` files created mid-session are NOT discovered. Agents are loaded at session start only. All agent files must exist before the session begins.
- **PreToolUse hook `updatedInput` on Agent tool:** Crashes with `undefined is not an object (evaluating 'K.length')`. `updatedInput` works for other tools but NOT the Agent tool. Do not attempt to intercept/modify Agent tool inputs via hooks.
- **Subagent nesting hard cap (confirmed 2026-03-19):** Subagents cannot spawn other subagents. The Agent/Task tool is explicitly excluded from subagent tool access — this is an intentional design constraint, not a bug. Maximum nesting depth is 1 level (orchestrator → subagent). Any approach requiring agent-dispatches-agent (e.g., builder dispatching reviewer) is infeasible within Claude Code. See [GitHub issue #4182](https://github.com/anthropics/claude-code/issues/4182). Workaround: use `claude -p` in separate processes (each is a top-level session, not a subagent) — but this conflicts with nested session detection (below).
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
grep -rn "<old-status-option-id>" --include="*.md" .  # Changed a board status ID
grep -rn "backlog/" --include="*.md" .claude/agents/  # Changed branch convention
grep -rn "modelRouting" --include="*.md" .              # Changed a config field
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
| `docs/ROADMAP.md` | Backlog item list, priority order, dependency graph, completion status |

**Common propagation failures:**
- Changed a script flag but didn't update CLAUDE.md's helper scripts table
- Fixed a template rendering bug but didn't update the template's documentation comment
- Added a board transition step to the orchestrator but didn't update CLAUDE.md's board transitions section
- Changed "post as comment" to "append to issue body" but only updated one of two agent files
- Created or closed a backlog item but didn't update `docs/ROADMAP.md`
- Shipped a feature that replaces a core system but didn't update README.md's architecture diagram or agent file references

**Orchestrator enforcement:** Individual agents should propagate changes as they work, but the orchestrator provides a safety net in **Phase 5 (after all fix cycles and retro are complete)**: update `docs/CHANGELOG.md`, `docs/ROADMAP.md`, `README.md`, `CLAUDE.md`, agent files, and historical design docs in a single pass when the code is final. This catches propagation failures that individual agents missed — especially cross-cutting changes like replacing a core subsystem. Documentation is not written earlier because PR review fix cycles and retro convention changes can invalidate it.

Evidence: BL#116 shipped a complete server replacing the file-based PM, but README.md, ROADMAP.md, CLAUDE.md, and 6 agent files still referenced the old system. All discovered post-merge by the human.

### Agent File Maintenance

When project conventions change, update the corresponding agent `.md` files in `.claude/agents/`. Changes that require agent updates include:

- Branch strategy or naming convention changes
- Script flag or signature changes
- Configuration changes (`.claude/agentic-sdlc-config.json` schema)
- Board management or status transition changes
- Documentation structure changes

When making such changes, search agent files for affected references:
```bash
grep -r "<old-pattern>" .claude/agents/
```

**Agent tool list auditing:** When an agent's instructions reference CLI commands (`gh`, `git`, shell commands), verify that its YAML frontmatter `tools` field includes `Bash`. An agent without `Bash` in its tool list cannot execute any shell commands, even if its instructions describe them in detail. Audit tool lists when adding new CLI-dependent instructions to any agent file.

**Builder variant sync (CRITICAL):** `builder.md` has three model-routed variants (`builder-haiku.md`, `builder-sonnet.md`, `builder-opus.md`). These files share identical body content — only the `name` and `model` fields in the YAML front matter differ. **Any change to `builder.md` body content must be propagated to all three variants.** Use this to sync:

```bash
for variant in haiku sonnet opus; do
  sed "s/^name: builder$/name: builder-$variant/;s/^model: inherit$/model: $variant/" .claude/agents/builder.md > .claude/agents/builder-$variant.md
done
```

## Testing the Workflow

This project validates the workflow pipeline using **test runs** — autonomous end-to-end executions with content-creation workloads. Test runs exercise the full lifecycle (design → plan → build → review → retro) without requiring a real software application.

### Test Run History

| Run | Backlog | Topic | What it tested |
|-----|---------|-------|---------------|
| 8 | #1 | Run 8 | Worktree isolation |
| 9 | #14 | Run 9 | Full autonomous lifecycle |
| 10 | #27 | Orchestrator Logging | Orchestrator logging |
| 11 | #41 | Board Drift Detection | Board drift detection |
| 12 | #56 | Run 12 | Configurable workflow settings (config.json, model routing, pricing) |
| 13 | #69 | Run 13 | Runtime data consolidation, live pricing, dispatches-from-state |
| 14 | #83 | Run 14 | Fix cycle validation, cross-epic merge |

Runs 1-7 were executed in the repository where the workflow was first developed (an earlier host project); their issues are not part of this repository.

### Creating a Test Run

When creating a new test run backlog item, include the following in the **issue body** so all downstream agents (designer, planner, builder) inherit the conventions:

1. **Title format:** `Test SDLC v2 Workflow (Run N) — <Topic>`
2. **Labels:** Apply `test-agentic-sdlc` to the backlog issue. Instruct the planner to apply `test-agentic-sdlc` to **all** child issues — epics, stories, **and** doc issues (design doc, plan, retro).
3. **Content guidelines:** Specify the creative theme, difficulty distribution (easy/medium/hard), word count ranges, and any cross-reference requirements.
4. **What to validate:** State what workflow capability this run is testing (e.g., "validate configurable model routing from `.claude/agentic-sdlc-config.json`").

The workflow agents are generic — they don't know they're running a test. They follow whatever the backlog item specifies.

### Test Run Asset Conventions

All test run assets are grouped under `test-agentic-sdlc/` subfolders within the standard docs directories. This keeps real feature docs uncluttered while test runs follow the exact same workflow path (designers write to `docs/2-design/`, planners write to `docs/3-plans/`, etc.). The `test-agentic-sdlc` prefix moves from the filename to the folder path.

| Asset | Convention | Example |
|-------|-----------|---------|
| **Design doc** | `docs/2-design/test-agentic-sdlc/YYYY-MM-DD-runNN-<slug>.md` | `docs/2-design/test-agentic-sdlc/2026-03-20-run15.md` |
| **Plan doc** | `docs/3-plans/test-agentic-sdlc/YYYY-MM-DD-runNN-<slug>-plan.md` | `docs/3-plans/test-agentic-sdlc/2026-03-20-run15-plan.md` |
| **Lesson folder** | `docs/4-reviews/lessons/synthetic-workloads/YYYY-MM-DD-runNN-<slug>/` | `docs/4-reviews/lessons/synthetic-workloads/2026-03-20-run15/` |
| **Labels** | `test-agentic-sdlc` on **all** issues (backlog, epics, stories, design, plan, retro) | — |

Content output of test runs is not retained in the published tree, and neither are the per-run design and plan documents. Only the lessons and retros under `docs/4-reviews/lessons/synthetic-workloads/` are kept as engineering evidence.

