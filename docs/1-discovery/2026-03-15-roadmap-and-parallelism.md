---
date: 2026-03-15
author: analysis
scope: Product roadmap for plugin packaging, PM tool agnosticism, domain expansion, and workflow parallelism optimizations
---

# Agentic SDLC — Roadmap & Parallelism Optimizations

## Part I: Product Roadmap

### 1. PM Tool Abstraction Layer

The workflow is currently coupled to GitHub in 15+ files. The path to tool agnosticism requires an adapter pattern.

#### PM Adapter Interface (~10 operations)

| Operation | What it does | Current implementation |
|-----------|-------------|----------------------|
| `create_item(level, title, body, labels)` | Create a work item | `gh issue create` |
| `update_item(id, fields)` | Edit title/body/labels | `gh issue edit` |
| `close_item(id)` | Close/resolve | `gh issue close` |
| `get_item(id)` | Read item details | `gh issue view` |
| `list_items(filters)` | Query items | `gh issue list` |
| `add_comment(id, body)` | Post a comment | `gh issue comment` |
| `link_parent(parent, child)` | Create hierarchy | `addSubIssue` GraphQL |
| `set_status(id, status)` | Board transition | `issue-set-status.sh` |
| `create_pr(base, head, title, body)` | Open a PR/MR | `gh pr create` |
| `get_board(project)` | Read board state | `gh project item-list` |

#### Target Adapters

| Adapter | API | Hierarchy mapping |
|---------|-----|-------------------|
| **GitHub** (current) | REST + GraphQL | Issue + sub-issues + labels |
| **Local** (new default) | Filesystem (`.sdlc/`) | Markdown files + YAML board |
| **Jira** | REST v3 | Epic > Story > Sub-task |
| **Linear** | GraphQL | Initiative > Project > Issue |
| **Azure DevOps** | REST | Epic > Feature > User Story |
| **ClickUp** | REST v2 | Space > List > Task |

#### Design Question: MCP Servers as Adapters?

Each adapter could be an MCP server, making them usable by any MCP-capable client — not just this workflow's agents. The orchestrator would call generic MCP tools (`pm_create_item`, `pm_set_status`) and the active MCP server would translate to the target platform.

Pros: Maximum interoperability, community can build adapters independently.
Cons: MCP adds latency per call, more complex than direct shell functions for the common case.

Hybrid approach: Shell functions for the fast path (local, GitHub), MCP for external tools (Jira, Linear) where the latency is already network-bound.

---

### 2. Local-First PM Layer

**Killer differentiator** — no competitor offers this. Everyone requires GitHub/Jira/etc.

#### Value proposition

- **Zero setup** — `sdlc init` and you're running
- **Offline capable** — works without internet
- **Git-native** — items are files, history is commits, diffs are meaningful
- **Syncs UP to cloud tools** — local is source of truth, push to Jira/GitHub on demand

#### Proposed structure

```
.sdlc/
├── config.yaml              ← project config
├── counter.txt              ← next item ID (simple sequential)
├── items/
│   ├── 001-auth-system.md   ← backlog item (YAML frontmatter + body)
│   ├── 002-e01-login.md     ← epic
│   ├── 003-e01-s01-form.md  ← story
│   └── ...
├── board.yaml               ← current status of all items
├── comments/
│   ├── 003-001.md           ← comment 1 on item 3
│   └── 003-002.md           ← comment 2 on item 3
└── telemetry/
    └── 003.json             ← telemetry for item 3
```

Items are markdown with YAML frontmatter — human readable, git-diffable, greppable. The board is a single YAML file tracking status for all items.

#### Sync to cloud tools

`sdlc sync --to jira` would push local items to Jira, establish ID mappings, and keep them in sync bidirectionally. Local remains source of truth for the workflow; cloud tool becomes the human-facing view.

---

### 3. Domain Expansion

The test runs prove the pipeline is domain-agnostic — it handles creative content as well as software. But agent instructions are software-flavored (TDD, DI, unit tests). Domain-specific profiles would adapt the builder and reviewer to different work types.

#### Domain profiles (config-driven)

```json
{
  "domain": "software"
}
```

| Domain | Builder focus | Reviewer focus | Example work |
|--------|-------------|---------------|--------------|
| **Software** (current) | TDD, code, tests, DI | Code quality, security, architecture | Features, bug fixes, refactors |
| **Content** | Writing, formatting, tone, structure | Accuracy, consistency, style guide adherence | Blog posts, documentation, copy |
| **Research** | Literature review, analysis, methodology | Citations, rigor, reproducibility | Research reports, whitepapers |
| **Data** | Pipelines, transformations, SQL, notebooks | Data quality, performance, schema design | ETL, dashboards, data models |
| **Design** | Wireframes, specs, component design | UX heuristics, accessibility, design system | UI/UX specifications |
| **Marketing** | Campaign copy, landing pages, messaging | Brand voice, conversion, audience fit | Campaigns, launch plans |
| **Legal/Compliance** | Policy drafts, contract templates | Regulatory accuracy, completeness | SOC2 prep, privacy policies |

The orchestrator, designer, planner, and retro agents are already domain-agnostic — only the **builder** and **reviewer** need domain profiles. The profiles could be separate instruction files loaded based on config.

---

### 4. New Specialist Agents

Beyond the current 6 agents, new roles that add value at specific lifecycle points:

| Agent | Role | When it runs | Value |
|-------|------|-------------|-------|
| **Estimator** | Predicts story duration/cost from telemetry history + story description | After planner, before dispatch | Better wave scheduling, cost forecasting |
| **Triage** | Reads incoming bug reports/feature requests, creates structured backlog items | On-demand (intake) | Consistent backlog quality without human formatting |
| **Documenter** | Generates user-facing docs (README, API docs, guides) from completed stories | After build phase | Always-current documentation |
| **QA Agent** | Runs integration/E2E tests across stories (not just per-story unit tests) | After all stories merge into epic | Cross-story regression detection |
| **Release Agent** | Handles versioning, release notes, tagging, deployment | After PR merge | Automated release pipeline |
| **Compliance Agent** | Checks work against regulatory/policy requirements | Parallel with reviewer | Regulatory safety net |
| **Onboarding Agent** | Analyzes a codebase and generates project-specific `SKILL.md` + config | On `sdlc init` | Zero-effort project onboarding |

---

### 5. Plugin Packaging

Target: Claude Code plugin distributable via the plugin marketplace.

#### Plugin structure

```
agentic-sdlc-plugin/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── orchestrator.md
│   ├── designer.md
│   ├── planner.md
│   ├── builder.md
│   ├── builder-sonnet.md
│   ├── builder-opus.md
│   ├── reviewer.md
│   └── retro.md
├── skills/
│   └── sdlc-workflow/
│       └── SKILL.md           ← teaches the methodology
├── commands/
│   ├── dispatch.md            ← /dispatch <issue>
│   ├── board-status.md        ← /board-status
│   ├── new-backlog.md         ← /new-backlog
│   └── telemetry.md           ← /telemetry <issue>
├── hooks/
│   └── hooks.json
├── scripts/
│   ├── lib/
│   │   ├── pm.sh              ← PM adapter functions
│   │   └── config.sh          ← config reader
│   ├── issue-set-status.sh
│   ├── issue-telemetry.sh
│   └── ...
├── templates/
│   └── telemetry.md
└── README.md
```

Consumer project only needs: `.claude/agentic-sdlc-config.json`

---

### 6. Additional Feature Ideas

| Feature | Description | Value |
|---------|-------------|-------|
| **Cost budgets** | `"maxCostPerRun": 10.00` in config — orchestrator halts at budget | Cost control for teams |
| **Multi-repo orchestration** | Backlog item spanning multiple repos (API + frontend + docs) | Monorepo-like coordination for polyrepo |
| **Team mode** | Multiple humans + AI agents on the same backlog, with assignment | Scale beyond single-developer |
| **Dashboard** | Ephemeral local web UI — Kanban board, telemetry charts, Gantt | Visual progress without cloud tool |
| **Learning across projects** | Global lessons database that feeds into new projects | Institutional memory |
| **Template library** | Pre-built story/epic templates per domain (auth, CRUD, API, etc.) | Faster planning |
| **Dry-run mode** | Simulate the full workflow without creating issues or branches | Workflow validation |

---

## Part II: Parallelism Optimizations

### Current Execution Model

The workflow executes as a strict sequence of phases with batch parallelism within build waves:

```
Design ──► Plan ──► [Wave 1 Build ──► Wave 1 Review] ──► [Wave 2 Build ──► Wave 2 Review] ──► ... ──► Merge ──► Retro ──► PR ──► PR Review
```

Each wave is a barrier: all builds must complete before any reviews start, all reviews must complete before the next wave starts. This leaves significant idle time.

### Run 13 Timeline (actual)

```
00:00  ├─ Design (4m) ──────────────────────┤
04:00  ├─ Plan (5m) ────────────────────────────────┤
09:00  ├─ W1 Build: S01(2m25s) S02(1m47s) S05(1m58s) ┤  ← 3 parallel
11:26  ├─                                              idle 39s (waiting for slowest builder)
11:26  ├─ W1 Review: R01(52s) R02(47s) R05(57s)       ┤  ← 3 parallel
12:23  ├─ W1 Merge + W2 branch setup                   ┤
12:53  ├─ W2 Build: S03(2m11s) S04(3m19s)              ┤  ← 2 parallel
16:12  ├─                                              idle 1m08s (waiting for S04)
16:12  ├─ W2 Review: R03(55s) R04(56s)                 ┤  ← 2 parallel
17:08  ├─ W2 Merge + W3 branch setup                   ┤
17:38  ├─ W3 Build: S06(2m29s)                         ┤  ← sequential
20:07  ├─ W3 Review: R06(1m37s)                        ┤
21:44  ├─ Merge all + Changelog                        ┤
22:14  ├─ Retro (3m38s) ───────────────────────────────┤
25:52  ├─ PR Review (3m) ──────────────────────────────┤
28:52  Done
```

Total idle time waiting for slowest-in-wave: ~2 min. Total barrier overhead (merge + branch setup between waves): ~2 min.

### Optimization 1: Streaming Reviews (within a wave)

**Current:** Wait for all builders in a wave → dispatch all reviewers.
**Proposed:** Review each story as soon as its builder finishes, even while other builders are still running.

```
CURRENT:                           PROPOSED:
S01 Build ████                     S01 Build ████
S02 Build ██████                   S02 Build ██████
S03 Build ████████                 S03 Build ████████
         [wait]                    S01 Review ██        ← starts immediately
S01 Review ██                      S02 Review ██        ← starts when S02 done
S02 Review ██                      S03 Review ██        ← starts when S03 done
S03 Review ██
```

**Savings:** Eliminates the gap between builders finishing and reviews starting. For a 3-story wave where builders take 1m47s–2m25s, the review of the fastest builder starts ~38s earlier. Compound savings: ~1-2 min per wave.

**Implementation:** The orchestrator dispatches reviews as background agents while waiting for remaining builders. Requires tracking which stories are "built but not reviewed" as a separate state.

### Optimization 2: Pipelined Waves

**Current:** Wave 1 build → Wave 1 review → Wave 1 merge → Wave 2 build.
**Proposed:** If Wave 2 stories don't depend on Wave 1 stories (only on Wave 1 being *merged* into the epic branch), start Wave 2 builds while Wave 1 reviews are running.

```
CURRENT:                                   PROPOSED:
W1 Build ████████                          W1 Build ████████
W1 Review    ████                          W1 Review    ████
W1 Merge         █                         W2 Build     ████████    ← overlaps with W1 review
W2 Build          ████████                 W1 Merge          █
W2 Review              ████               W2 Review          ████   ← after W2 build + W1 merge
```

**Savings:** One full wave-build duration saved (~2-3 min per pipelined wave).

**Constraint:** Wave 2 builders work on worktree-isolated branches from the same epic base as Wave 1. They don't need Wave 1's content on the epic branch to *build* — they only need it to *merge*. If Wave 2 stories have content dependencies on Wave 1 (e.g., cross-references), this optimization doesn't apply.

**Implementation:** Use `isolation: "worktree"` for Wave 2 builders started from the pre-Wave-1 epic base. After Wave 1 reviews pass, merge Wave 1, then merge Wave 2 (rebasing if needed). The orchestrator tracks "building-ahead" vs "ready-to-merge" states.

### Optimization 3: Parallel Retro + PR Review

**Current:** Build all → Merge → Retro → Open PR → PR Review.
**Proposed:** Build all → Merge → Open PR → [Retro + PR Review in parallel].

```
CURRENT:                           PROPOSED:
Merge ██                           Merge ██
Retro    ████                      PR Open █
PR Open      █                     Retro   ████        ← parallel
PR Review     ████                 PR Review ████      ← parallel
                                   Edit PR body  █     ← add retro to Closes
```

**Savings:** ~3 min (retro and PR review overlap entirely).

**Constraint:** The retro commits to the integration branch, so the PR diff changes while the reviewer is reading it. In practice this is fine — the retro adds docs, not code.

**Implementation:** Open PR before dispatching retro. Dispatch retro and PR reviewer as concurrent agents. After retro completes, edit PR body to add retro issue to `Closes` list.

### Optimization 4: Early Story Branch Creation

**Current:** Create story branches one wave at a time, right before dispatch.
**Proposed:** Create ALL story branches upfront in Phase 4 (reading the plan). Record base commits per wave.

**Savings:** ~30s per wave transition (eliminates branch creation between waves).

**Implementation:** Already partially done — the orchestrator creates branches from the epic base. The change is creating them all at once rather than per-wave.

### Optimization 5: Batched Board Updates

**Current:** Each `issue-set-status.sh` call does a GraphQL query + mutation + verification (3 API calls).
**Proposed:** Accumulate board transitions and apply them in a batch at wave boundaries.

```
CURRENT: Set S01 In Progress → Set S02 In Progress → Set S03 In Progress → dispatch
PROPOSED: dispatch → Set S01,S02,S03 In Progress (single script call with retry)
```

**Savings:** ~1-2 min per run total. Also reduces rate limit pressure.

**Trade-off:** Board state is momentarily stale during dispatch. Acceptable since the board is for human visibility, not workflow correctness.

### Optimization 6: Reviewer Dispatch by Difficulty

**Current:** All reviews use Opus regardless of story difficulty.
**Proposed:** Use Sonnet for reviewing easy stories, Opus for medium/hard.

**Savings:** ~15-20% of review cost per run. Slightly faster (Sonnet reviews may be quicker).

**Risk:** Lower quality catch rate for easy stories. Mitigate by testing in one run and comparing.

### Combined Impact Estimate

For a Run 13-sized workload (6 stories, 3 waves):

| Optimization | Wall-clock savings | Cost savings |
|---|---|---|
| Streaming reviews | ~1-2 min | — |
| Pipelined waves | ~2-3 min | — |
| Parallel retro + PR review | ~3 min | — |
| Early branch creation | ~30s | — |
| Batched board updates | ~1-2 min | — |
| Sonnet reviews for easy | — | ~15-20% review cost |
| **Combined** | **~8-10 min** (~30% of wall-clock) | **~10-15%** |

For a Run 14-sized workload (12 stories, more waves), the savings would be proportionally larger — potentially **10-15 min** off a ~45 min run.

### Implementation Priority

| Priority | Optimization | Effort | Impact |
|----------|-------------|--------|--------|
| 1 | Parallel retro + PR review | Low (reorder 2 dispatches) | High (3 min) |
| 2 | Streaming reviews | Medium (background agent tracking) | High (1-2 min/wave) |
| 3 | Early branch creation | Low (move branch creation to Phase 4) | Low (30s) |
| 4 | Batched board updates | Medium (new batch script) | Medium (1-2 min) |
| 5 | Pipelined waves | High (complex state management) | High (2-3 min/wave) |
| 6 | Sonnet reviews for easy | Low (config change) | Medium (cost only) |

---

## Part III: Incremental Roadmap

Sequenced so each step leaves the system fully functional:

### Phase 1: Foundation (Runs 14-15)
1. Implement workflow quick wins A-H from the analysis
2. Parallel retro + PR review (Optimization 3)
3. Streaming reviews within waves (Optimization 1)
4. Formalize easy → sonnet routing (already done in practice)

### Phase 2: PM Abstraction (Runs 16-17)
5. Extract PM operations into `scripts/lib/pm.sh` — all scripts call these instead of `gh` directly
6. Make agent instructions use intent language — "create a work item" not `gh issue create`
7. Build the local adapter (`.sdlc/` folder)
8. Config-driven adapter selection: `"pm": "local"` or `"pm": "github"`

### Phase 3: Plugin Packaging (Run 18)
9. Package as Claude Code plugin — agents, skills, scripts, hooks
10. Onboarding command — `/sdlc-setup`
11. SKILL.md — teaches the methodology
12. `sdlc` CLI wrapper

### Phase 4: Multi-PM Support (per adapter, 1 run each)
13. Jira adapter
14. Linear adapter
15. Azure DevOps adapter
16. ClickUp adapter

### Phase 5: Domain Expansion (Runs 22+)
17. Builder/reviewer domain profiles (config-driven)
18. New specialist agents (estimator, triage, documenter)
19. Custom agent injection (user-defined agents)
20. Template library per domain

### Phase 6: Advanced Features
21. Dashboard (local web UI)
22. Cost budgets
23. Multi-repo orchestration
24. Pipelined waves (Optimization 5)
25. Learning across projects
