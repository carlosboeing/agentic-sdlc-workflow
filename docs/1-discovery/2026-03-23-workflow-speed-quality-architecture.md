---
title: "Workflow Speed, Quality & Instruction Architecture — Discovery"
type: research
authors: ["Carlos Boeing"]
date: 2026-03-23
agent: general
scope: Post BL#116 deep dive — workflow speed optimization, quality improvement, instruction architecture (3-layer model), mock contract parallelism, review strategy, observability gaps
sources:
  - BL#116 orchestrator state file (.agentic-workflow/runs/116/orchestrator.json)
  - BL#116 retro (docs/4-reviews/lessons/116-workflow-runtime-service/2026-03-22-workflow-runtime-service-retro.md)
  - Prior optimization analysis (docs/1-discovery/2026-03-19-workflow-optimization-analysis.md)
  - Retro recommendations tracker (docs/4-reviews/retro-recommendations.md)
  - Human-orchestrator discussion session (2026-03-23)
related:
  - 2026-03-19-workflow-optimization-analysis.md
  - 2026-03-22-workflow-runtime-service.md
---

# Workflow Speed, Quality & Instruction Architecture — Discovery

> Historical record (March 2026). Measurements come from controlled synthetic workloads and early infrastructure runs; see [case studies](../case-studies.md) for scoped findings.

> **Context:** This document captures findings and ideas from a deep-dive analysis of BL#116 (Workflow Runtime Service) — the largest backlog item executed through the workflow (19 stories, 6 epics, 69 dispatches, ~$50, ~6.5h wall clock). The discussion expanded from "why was this run slow?" into broader architectural questions about instruction layering, parallelism strategies, review models, and the workflow's path toward domain-agnostic plugin packaging.

## 1. BL#116 Run Data

### Time Breakdown

| Category | Agent time | Wall clock impact | % of total |
|----------|-----------|-------------------|------------|
| Initial builds (18 stories) | 257m | ~180m (parallelism) | 56% |
| Initial reviews (18 stories) | 91m | ~65m (parallelism) | 20% |
| Fix cycle builds (12 stories) | 55m | ~45m | 12% |
| Fix cycle re-reviews | 38m | ~30m | 8% |
| Design + plan | 28m | 28m (sequential) | 6% |
| Retro + PR review | 48m | 43m (parallel) | — |
| Orchestrator overhead | — | 46m | — |
| Usage limit interruption | — | ~50m (dead time) | — |
| **Total** | **457m agent** | **~393m wall clock** | |

### Fix Cycle Analysis

- 12 of 18 stories (67%) needed fix cycles — far above the ~11% historical average
- 6 stories passed review first time: E01-S01 (schema), E03-S01 (MCP tools), E03-S02 (MCP reg), E05-S02 (Kanban), E05-S03 (item detail), E06-S03 (integration)
- Fix cycle overhead: 93m agent time (~20% of total), ~75m wall clock
- E05-S04 hit the 3-cycle cap without approval

### Bug Categories (from reviewer findings)

| Category | Stories affected | BL#116 specific? |
|----------|-----------------|------------------|
| DI wiring blindspots | ~6 | Yes — DI-heavy server architecture |
| Dead code / orphan files | ~3 | No — universal |
| Cross-layer violations | ~2 | Partially — frontend/backend separation |
| Missing functionality | ~3 | No — universal |
| Security (injection) | ~1 | No — universal |

### Long Pole Tasks

| Story | Time | Why |
|-------|------|-----|
| E02-S03 Shell Adapter (#339) | 54m (44m build + 10m fix) | Bridges bash and TypeScript — two worlds in one story |
| E03-S02 MCP Registration (#341) | 40m (35m build + 4m review) | Anomalously long for medium; likely usage limit interruption |
| Retro (#352) | 43m | Synthesizing 66 dispatches across 6 epics |

### Key Observation

The stories that passed clean were either pure data definitions (schema), thin wrappers over established service layers (MCP tools, Kanban), or lightweight glue (integration test). What failed: anything that **wires new infrastructure into existing infrastructure** — startup paths, adapters, cross-layer integrations. This is project-type specific — a content creation project would have entirely different failure patterns.

---

## 2. Instruction Architecture — Three-Layer Model

### Problem

Today, workflow knowledge and user preferences are tangled in the same files:
- Agent `.md` files contain both generic workflow principles AND project-specific conventions
- `CLAUDE.md` contains both user preferences AND workflow-specific knowledge (800+ lines, most of which is workflow knowledge)
- The retro agent writes convention changes to `CLAUDE.md` and `builder.md` — both wrong targets when the workflow ships as a plugin on someone else's project
- Builder instructions include code examples specific to this project's tech stack (`startServer({db}) -> createApp({db})`)

### Proposed Three-Layer Architecture

```
Layer 1: Agent .md files          (plugin-owned, immutable per version)
Layer 2: Project workflow file    (plugin-owned, project-specific, mutable)
Layer 3: User's CLAUDE.md         (user-owned, we never write to it)
```

**Layer 1 — Agent Files (ships with plugin, never modified at runtime):**
- Generic principles: engineering heuristics (KISS, DRY, YAGNI, SoC, SOLID), systemic thinking framework, TDD discipline
- Workflow mechanics: branch strategy, commit conventions, progress tracking
- "Read the project workflow file for project-specific conventions"
- Updated only when the plugin itself is updated (new version release)

**Layer 2 — Project Workflow File (plugin-owned, project-specific, self-improving):**
- Created during setup/init or automatically on first run
- Contains: tech stack, framework-specific gotchas, testing conventions, build commands, architecture patterns, common bug patterns learned from previous runs
- The workflow reads it; the retro writes to it (if self-improvement is enabled)
- This is the workflow's "project memory" — the knowledge base that improves over runs
- Each project has its own instance (a .NET project's file looks different from a Next.js project's file)
- Examples of project-specific content:
  - .NET project: "verify DI registration in `Startup.cs`", "check EF migrations"
  - Next.js project: "verify page is exported from `app/` directory", "check middleware"
  - Data project: "verify grants on new tables", "check transform idempotency"
  - This workflow's own project: "verify DI wiring with startup integration tests", "shell adapter stories should be split by function group"

**Layer 3 — User's CLAUDE.md (user-owned, we only read, never write):**
- User's own instructions, coding preferences, commit style preferences
- We read it (agents respect user preferences) but never write to it
- Users may be particular about their CLAUDE.md — we must not assume we can modify it

### Layer Priority / Conflict Resolution

When instructions conflict between layers:
1. **User's CLAUDE.md takes precedence** (it's their project, their rules)
2. Project workflow file second (project-specific knowledge)
3. Agent files last (generic defaults)

When a conflict is detected (e.g., agent file says "conventional commits" but CLAUDE.md says "angular commits"), the workflow should **warn the user** rather than silently pick one. The project workflow file should document the resolution.

### Self-Improvement Toggle

```json
{
  "selfImprovement": {
    "enabled": true,
    "target": "project-workflow-file"
  }
}
```

When enabled: retro agent writes lessons and convention changes to the project workflow file. Over runs, the file accumulates project-specific knowledge ("builders on this project should always verify X because we've seen it fail N times").

When disabled: retro agent writes to retro docs only (read-only knowledge, not fed back into the builder's instruction loop).

### Special Case: This Repository

This repository IS the plugin. So Layer 1 (agent files) and Layer 2 (project knowledge) overlap — changes to agent files ARE changes to the plugin. The retro agent writing to `builder.md` is correct here because `builder.md` is a deliverable, not just an instruction. When the workflow runs on a different project, the retro should only write to Layer 2.

### File Location and Storage

- Layer 1: Ships with the plugin (in user's `~/.claude/` for user-level plugins, or in-project `.claude/` for project-level)
- Layer 2: Stored in the project repository, **committed** (shared across team members)
  - Candidate paths: `.agentic-workflow/project.md`, `.claude/workflow-project.md`, `WORKFLOW.md`
  - Must be in the project repo, not the plugin install location
  - Committed = shared knowledge, not local-only learning
- Layer 3: Already exists at standard CLAUDE.md locations

### Naming (to be decided)

Options for the project workflow file:
- `.agentic-workflow/project.md` — keeps workflow files together, but `.agentic-workflow/` is currently gitignored
- `.claude/workflow-project.md` — lives alongside agent files and config
- `WORKFLOW.md` — visible at repo root, clear purpose
- Name TBD — should be decided when implementing

---

## 3. Parallelism Optimization

### Current State

BL#116 had 11 dispatch waves. Parallelism saved 109m (24%) vs fully sequential execution. The bottleneck was the dependency graph, not `maxParallelBuilders` — most waves couldn't run more than 2-3 stories because remaining stories depended on current wave outputs.

### What the Planner Missed

1. **E01 didn't need to be fully sequential.** E01-S01 (schema) and E01-S03 (lifecycle) share no code. They could have been Wave 1 in parallel, saving ~5m.

2. **E02-S03 (shell adapter) should have been 2-3 stories.** 44m for a single story is too long. Split by function group (item CRUD, board/lifecycle, comments/labels). First two could run in parallel.

3. **E05-S04 (WebSocket) was too coupled.** Modified 9 files across services, API, and frontend. Should have been split into server-side EventService + WebSocket hub (no frontend deps, could run earlier) and frontend hooks + components.

### Mock Contract Parallelism (New Strategy)

**Concept:** In real teams, work that has dependencies is often parallelized by defining interface contracts upfront. The upstream layer works against the contract (with mocks) while the downstream layer implements it. Both run simultaneously.

**How it would work in the workflow:**

1. Planner defines contracts in the plan document — TypeScript interfaces, API schemas, function signatures at each epic boundary
2. A small "contract" story at the start of each epic (difficulty/easy, 5-10 min) creates the interface files and mock implementations
3. Downstream stories import from interfaces, not concrete implementations
4. When the real implementation merges, it replaces the mock

**Applied to BL#116:**

The E01→E02→E03 dependency chain (schema → services → routes → MCP) took 4 sequential waves before any parallelism. With contracts:

```
Wave 1: E01-S01 (schema) + E01-S03 (lifecycle) + contract stories
Wave 2: E01-S02 (services) + E02-S01 (routes, against contract) + E05-S01 (SPA, against contract)
Wave 3: E02-S02 + E02-S03a (shell CRUD) + E03-S01 (MCP, against contract) + E05-S02
Wave 4: E02-S03b + E03-S02 + E05-S03 + E04-S01
Wave 5: E04-S02 + E04-S03 + E05-S04 + E06-S01 + E06-S02
Wave 6: E06-S03 (integration)
```

6 waves instead of 11, with 3-5 stories per wave. **Estimated critical path: ~100m vs actual ~348m (3x improvement).**

**Risks:**
- If the contract is wrong, everything built against it needs rework
- Merge conflicts when the real implementation differs from the mock
- In human teams, people communicate to resolve contract mismatches; in this workflow, the contract is defined once by the planner and never revised
- Additional complexity in the planner's decomposition

**Mitigation:** The contract stories should be deliberately thin — just TypeScript interfaces and type definitions, not full mock implementations. The less mock code, the less can be wrong.

**Verdict:** High potential payoff (2-3x parallelism) but requires planner-level changes and a new "contract story" pattern. Worth prototyping on a smaller backlog item first.

---

## 4. Review Strategy

### Current Model

Every story gets: build → review → (fix cycle if needed) → merge. The orchestrator waits for all builders in a wave, then dispatches all reviewers in a wave. Per-story review is always-on (configurable to skip for easy stories, but disabled by default).

### BL#116 Review Costs

| Category | Dispatches | Agent time | Wall clock |
|----------|-----------|-----------|------------|
| Initial reviews | 18 | 91m | ~65m |
| Fix cycle re-reviews | 15 | 38m | ~30m |
| PR-level review | 1 | 5m | 5m |
| **Total review** | **34** | **134m** | **~100m** |

Reviews consumed 29% of total agent time. Fix cycle overhead (builds + re-reviews) was 93m / 20%.

### Options Analyzed

**Option A: Keep per-story review (current)**
- Pro: Catches bugs early, before they propagate
- Pro: Fix cycles are scoped to one story (small context, fast fix)
- Con: 29% of agent time on reviews; 20% on fix cycle overhead
- Con: Orchestrator must wait for all builders before dispatching reviewers (wave boundary)
- Evidence from BL#116: The camelCase/snake_case bug (C1) introduced in E05-S01 propagated through 6 stories because per-story review didn't catch the contract — it caught individual symptoms

**Option B: Review per epic only**
- Pro: Reduces review dispatches from 18+15=33 to ~6 (one per epic)
- Pro: Reviewer sees the full epic context (better cross-story integration review)
- Con: Bugs accumulate across 3-4 stories before being caught
- Con: Fix cycles are larger (builder must context-switch across multiple stories)
- Untested — no data on whether this increases or decreases total cost

**Option C: PR-level review only (skip all per-story/per-epic reviews)**
- Pro: Maximum speed — no review overhead during build phase
- Pro: Reviewer sees the entire backlog item in context
- Con: All bugs caught at the end, all fix cycles are against the full codebase
- Con: The PR review for BL#116 found 4 critical issues across the entire codebase — fix cycle was 8m. But this was AFTER per-story reviews had already caught most bugs. Without per-story reviews, the PR review would face 30+ issues.
- Risk: High — the PR review becomes the only quality gate

**Option D: Builder self-verification + PR review (no separate reviewer agent)**
- Concept: The builder runs a structured verification checklist after completing the story, before pushing. Not a "review" (which would be biased) but mechanical checks: import chain tracing, endpoint verification, dependency audit.
- Pro: Eliminates the wave boundary problem — no need to wait for all builders before dispatching reviewers. Each builder is self-contained.
- Pro: Catches wiring bugs (60%+ of fix cycles) at build time
- Pro: PR review remains as the quality gate for cross-story integration issues
- Con: Builder bias — the builder sees what it intended, not what it wrote. Mechanical checks help but don't catch all issues.
- Con: Unknown effectiveness — no data on whether self-verification catches the same bugs as an independent reviewer
- Relates to: The "streaming review" problem from BL#105 (orchestrator can't dispatch reviewer until builder finishes, creating wave boundaries)

**Option E: Hybrid — conditional review based on story characteristics**
- Easy stories: builder self-verification only
- Medium stories: builder self-verification + reviewer if story touches > N files or modifies existing infrastructure
- Hard stories: always full review
- All stories: PR-level review as final gate
- Pro: Applies review effort where it has highest ROI
- Con: Complexity in determining which stories get reviewed

### Recommendation

No definitive recommendation yet — this needs experimentation. The most promising direction is **Option D (self-verification + PR review)** because it eliminates the wave boundary problem and could be combined with mock contract parallelism for maximum throughput. But it's untested and the bias concern is real.

A pragmatic first step: run the next backlog item with the builder self-verification checklist (already added) AND per-story review enabled. Measure whether the checklist reduces the fix cycle rate. If it drops to <20%, that's evidence that self-verification is effective and the per-story reviewer could be made conditional.

---

## 5. Observability Gaps

### What We Can't See Today

1. **Usage limit interruptions within a dispatch.** When E03-S02 takes 35m for a medium story, we can't distinguish between genuine complexity and a usage limit pause. The Agent tool returns total `duration_ms` including any pauses.

2. **Token rate breakdown.** We have total tokens and total duration, but not the distribution over time. A dispatch could be fast-fast-pause-fast and we'd never know.

3. **Builder progress milestones.** We don't know when the builder finished writing tests vs when it started implementing. If tests took 2m and implementation took 30m, that's useful signal.

### What We Could Do

**Token rate as a proxy (low cost):**
- Already partially implemented: telemetry script flags `[stalled]` for dispatches below 50 tok/s
- Could be enhanced: if `tokens/duration` is below model's typical throughput by >3x, flag as "likely interrupted"
- Limitation: only works after the dispatch completes, not in real-time

**Builder milestone logging (medium cost):**
- Builder logs timestamps at key phases (test writing, implementation, integration check) as issue comments
- Gaps between milestones reveal interruptions or struggles
- Adds ~3 issue comments per story (API cost, noise)

**Orchestrator-level timing (low cost):**
- Record wall clock before and after Agent tool dispatch
- Compare orchestrator's wall clock with the Agent tool's reported `duration_ms`
- Significant discrepancy = overhead or interruption

**Platform feature request (no cost to us):**
- Claude Code exposing interruption/resume events in Agent tool results
- Would give us exact data instead of heuristics

### Priority

Observability is foundational — without it, we're optimizing based on incomplete data. The token rate proxy and orchestrator-level timing are cheap wins. Builder milestone logging is higher cost but gives the richest signal. Platform feature request is the ideal solution but not in our control.

---

## 6. Builder Quality — Beyond Wiring Bugs

### The Over-Fitting Problem

The current builder improvements (systemic thinking checklist, startup wiring tests) are tuned to BL#116's failure pattern. But the workflow aims to be domain-agnostic. Different project types have different failure patterns:

| Project type | Common builder failures | Not "wiring bugs" |
|-------------|------------------------|-------------------|
| Server (DI-heavy) | DI wiring, startup path gaps | ✓ (this run) |
| Frontend (Next.js, React) | Hydration mismatches, missing routes, stale cache | Different class |
| Data pipeline (Snowflake, dbt) | Schema drift, missing grants, untested transforms | Different class |
| Mobile (React Native, Flutter) | Platform-specific APIs, missing permissions | Different class |
| Shell/CLI tools | Operator precedence, quoting, portability | Different class (BL#109 data) |
| Content creation | Word count violations, cross-references, formatting | No code bugs at all |

### The Right Abstraction

The builder instructions should teach **transferable thinking patterns**, not project-specific checklists:

**Generic (belongs in agent files — Layer 1):**
- Integration thinking: "How does this reach the user? What else needs to know?"
- Engineering principles as heuristics: KISS, DRY, YAGNI, SoC, SOLID — with "when to bend it" guidance
- The meta-principle: "every principle is a heuristic for reducing future cost"
- Reachability check: "Is every file I created reachable from a production entry point?"
- Duplication check: "Am I duplicating logic that exists elsewhere?"

**Project-specific (belongs in project workflow file — Layer 2):**
- "For this project, verify DI wiring with startup integration tests"
- "For this project, shell adapter stories should be split by function group"
- "For this project, `bun test` needs explicit react in devDependencies for TSX"
- These accumulate from retro findings and lessons, specific to this codebase

### Action: Current Builder Instructions Need Refactoring

The current `builder.md` has project-specific content that should move to Layer 2 when the three-layer architecture is implemented:
- The `startServer({db}) -> createApp({db}) -> route handler` example
- The DI wiring test convention (generic principle stays, specific example moves)
- Any reference to this project's specific file paths or patterns

---

## 7. Initialization and Zero-Config

### Philosophy

The workflow should be zero-config by default with progressive disclosure of options:
1. **First run with no setup:** Workflow infers what it can from the codebase (tech stack, testing framework, build commands, directory structure) and generates the project workflow file automatically
2. **Optional setup wizard:** Users who want to customize can run an init command, but it should ask as few questions as possible — anything inferable should be inferred
3. **Fault tolerant:** If the user doesn't initialize and doesn't answer questions, the workflow still works — it just starts with less project-specific knowledge and learns over runs
4. **Self-improving:** Each run makes the project workflow file slightly smarter (if self-improvement is enabled)

### What Can Be Inferred

| Signal | Inference |
|--------|-----------|
| `package.json` exists | Node/Bun project → TypeScript conventions, npm/bun test runner |
| `*.csproj` exists | .NET project → C# conventions, dotnet test runner |
| `pyproject.toml` / `setup.py` | Python project → pytest conventions |
| `tsconfig.json` settings | Strict mode, module system, target |
| Existing test files | Test framework (Jest, Vitest, bun:test, pytest, xUnit) |
| `CLAUDE.md` content | User preferences, commit conventions, project description |
| Git history | Commit style (conventional? angular? freeform?) |
| Directory structure | Architecture patterns (monorepo, monolith, microservices) |
| CI config | Build commands, test commands, linting |

### What Requires User Input (can't be inferred)

- Business domain and context (what the project does)
- Team conventions that aren't codified anywhere
- Preferences for review strategy, parallelism, model routing
- External service integrations (PM tool, VCS hosting)

---

## 8. Tester Agent (Visual / E2E Testing)

### The Gap

The current workflow has builders (write code + unit tests) and reviewers (read code, find bugs). Neither actually **runs the application and verifies it works visually**. The reviewer reads the build script and sees `Bun.build()` processing CSS — it looks correct. But the CSS has no utility classes because `Bun.build()` doesn't run Tailwind's content scanning. This class of bug is invisible to code review.

**Evidence:** BL#116's dashboard shipped with zero Tailwind styling. All 500+ tests passed. The reviewer approved. The bug was only discovered when a human opened the browser and saw unstyled HTML. The fix was a one-line change in the build script.

### What a Tester Agent Would Do

A new agent type — `tester` — that runs after the builder and before (or alongside) the reviewer:

1. **Build the project** — run the build command, verify it succeeds
2. **Start the application** — launch the server/app locally
3. **Run visual checks** — navigate to key pages, verify elements render, check for console errors
4. **Run E2E scenarios** — click through critical paths (create item, navigate, submit form)
5. **Take screenshots** — capture visual state for human review or diffing
6. **Report findings** — post results as an issue comment (like the reviewer does)

### Tool Agnostic

The tester agent should work with whatever browser automation tool is available — Playwright, Puppeteer, Cypress, Selenium, or any MCP-accessible browser tool. The agent instructions should describe **what to verify** (pages load, elements render, no console errors) rather than **which tool to use**. The tool choice is a project-level configuration.

**Artifact management:** When taking screenshots or saving test artifacts, always save to a dedicated output directory (e.g., `.test-artifacts/`) — never to the project root. This directory should be gitignored.

### Open Questions

- Should the tester agent run per-story (after each builder) or per-epic (after merge)?
- How does it know what to test? From acceptance criteria? From a test plan in the story issue?
- Should it generate Playwright test files that persist, or run ad-hoc checks and discard?
- How to handle projects without a UI (APIs, CLIs, libraries)? The tester agent may not always apply.

---

## 9. A/B Testing Strategy

### The Attribution Problem

Every workflow run is different — different backlog scope, different technology, different story complexity. If we make 5 optimizations and the next run is 30% faster, we can't tell which optimization mattered. We might even be slower on a harder backlog and think our changes failed when they actually helped.

Architectural changes (three-layer model, self-improvement, observability) should be implemented regardless — they're structurally correct independent of speed. But speed/cost/quality optimizations need controlled comparison.

### Approach: Paired Benchmark Runs

Design a **benchmark backlog item** — a sample application built as a "test run" (like the creative content test runs, but code-focused). Run it twice with identical backlog item content: once as a baseline (control), once with optimizations (variant).

#### Benchmark App Requirements

1. **Layered CRUD application** — exercises the exact patterns where builders fail:
   - Database layer (schema, migrations, seed data)
   - Service layer (business logic, DI wiring)
   - API layer (REST endpoints, validation)
   - Presentation layer (frontend UI, client-server integration)
2. **Self-contained and runnable** — must be locally runnable for manual verification (human or Playwright). Output lives in `test-output/` within this repo, isolated from the workflow's own code.
3. **6-8 stories, 2-3 epics, mix of easy/medium/hard** — enough to exercise parallelism and generate fix cycle data, small enough to complete in ~2h target.
4. **Boring domain** — task tracker, bookmark manager, recipe app, etc. The builder's effort should go to architecture, not domain research. We're testing the workflow, not creativity.
5. **Diverse story types** — at least one DI-wired service, one frontend component, one cross-layer integration, one CLI/adapter story. This avoids over-fitting the benchmark to one bug category.

#### Sample App Ideas (to be decided)

- **Task/Todo app** — classic layered CRUD. SQLite + API + React. Risk: too simple, may not trigger enough failure patterns.
- **Bookmark manager with tags** — CRUD + many-to-many relationships + search. More interesting DI patterns.
- **Mini expense tracker** — CRUD + aggregation queries + charts. Exercises frontend data visualization.
- **Link shortener** — CRUD + redirect logic + analytics. Exercises middleware, caching patterns.

#### Full Workflow Execution

Both control and variant runs execute the **full workflow** — design, plan, implementation, review, retro. No phases are skipped, because:
- Optimizations may affect any phase (e.g., "better story splitting" affects the planner)
- Skipping phases would invalidate the comparison — the planner might decompose differently
- The designer is non-deterministic; each run's design choices are part of the measurement
- We want to measure total end-to-end, not just the build phase

#### Isolation Strategy

**Two separate repository clones**, each running in its own terminal:

```
<repo-root>-control/    ← Clone A (baseline)
<repo-root>-variant/    ← Clone B (with optimizations)
```

- **Separate backlog items on GitHub** — create two identical issues with the same body/scope but different issue numbers. Each run creates its own epics, stories, branches, and PM state with no cross-contamination.
- **Both clones start from the same commit** on `main` — identical codebase, identical agent files (except for the specific optimization being tested in the variant).
- **Separate integration branches** — `backlog/<A>-benchmark-control` and `backlog/<B>-benchmark-variant`. Neither knows the other exists.
- **GitHub API budget** — two simultaneous runs create ~20 issues + ~40 status updates + ~30 comments each = ~180 API calls total. Well within the 5000 points/hour budget.
- **Neither run is merged** — both PRs stay open for analysis. No artifacts from A leak into B or vice versa.

#### What to Measure

| Metric | How to compare | What it tells us |
|--------|---------------|-----------------|
| Fix cycle rate | % stories needing fixes (control vs variant) | Builder quality improvement |
| Fix cycle overhead | Minutes spent on fix builds + re-reviews | Direct time savings from fewer fix cycles |
| Wall clock | Total start-to-finish | Net speed improvement (including any overhead from new process) |
| Critical path | Sum of max-per-wave durations | Parallelism effectiveness |
| Cost (tokens) | Total tokens consumed | Whether we're trading tokens for speed or genuinely reducing both |
| Reviewer findings | Count and categories of bugs found | Whether self-verification catches what the reviewer would have caught |
| Code quality | Manual inspection + Playwright test of running app | Whether optimizations trade quality for speed |
| Planner decomposition | Number of waves, parallelism opportunities | Whether planner instruction changes improve the dependency graph |
| Design quality | Approaches considered, feasibility verification | Whether design phase changes affect downstream quality |

Capture everything — even metrics that seem redundant. Analysis happens after both runs complete, not during.

#### Test Matrix

Run the benchmark backlog item multiple times, changing one variable per pair:

| Pair | Control | Variant | What it tests |
|------|---------|---------|--------------|
| A | Current workflow (no self-verification) | With builder self-verification checklist | Does the checklist reduce fix cycles? |
| B | Per-story review (current) | PR-review only (skip per-story) | Does skipping reviews save time without hurting quality? |
| C | Current sequential dependencies | Mock contract parallelism | Does contract-first parallelism reduce wall clock? |
| D | Current workflow | Self-verification + PR-review only (no per-story) | Combined effect of builder quality + review reduction |

Pair A should run first — it's the cheapest test (just instruction changes) and validates the foundational assumption that self-verification works before we build on it.

#### Practical Considerations

- **Same model routing** — both runs use identical model configuration to isolate the variable being tested.
- **Variance tolerance** — with n=1 per pair, we can't prove statistical significance. But we can detect large effects (>20% improvement). If the effect is <10%, it's probably noise. From historical data, run-to-run variance on similar workloads is ±15-20%.
- **Simultaneous execution** — running both in parallel halves calendar time but means both compete for your machine's resources (memory, CPU for local operations). This is unlikely to be a bottleneck since most time is spent in Claude's API, not locally.
- **Post-run analysis** — after both runs complete, compare state files side-by-side. The dispatch logs, fix cycle counts, and timing data are all in `.agentic-workflow/runs/<N>/orchestrator.json`. A comparison script could diff the two state files and produce a report.

#### What NOT to A/B Test

- Three-layer instruction architecture — structurally correct, implement regardless
- Observability improvements — foundational infrastructure, no downside
- Zero-config init — UX improvement, no speed trade-off
- Story splitting conventions — apply as planner instruction update, measure over time across multiple runs

---

## 10. Summary of Potential Backlog Items

These emerged from the discussion. Not prioritized — to be evaluated and added to the roadmap separately.

| Idea | Category | Estimated Impact | Complexity |
|------|----------|-----------------|------------|
| Three-layer instruction architecture | Architecture | High (enables plugin packaging, clean self-improvement) | L — touches all agent files, config, retro |
| Project workflow file (Layer 2) | Architecture | High (project-specific knowledge, self-improvement) | M — new file, init logic, retro target |
| Mock contract parallelism | Speed | High (2-3x parallelism potential) | L — planner changes, new story pattern |
| Builder self-verification checklist | Quality + Speed | Medium (reduces fix cycles, eliminates wave boundary) | S — builder instruction changes |
| Conditional review strategy | Speed + Cost | Medium (skip reviews where they have low ROI) | M — orchestrator logic, config |
| Observability / interruption tracking | Diagnostics | Medium (enables data-driven optimization) | S — logging changes |
| Better story splitting conventions | Speed | Medium (prevents long-pole stories) | S — planner instruction changes |
| Codebase inference for zero-config init | UX | High (zero barrier to entry for new projects) | M — analysis script, template generation |
| Conflict detection between instruction layers | Quality | Low-Medium (prevents silent rule conflicts) | S — startup check |
| Refactor builder.md: separate generic vs specific | Architecture | Medium (prerequisite for plugin packaging) | S — move content between files |
| A/B testing benchmark | Diagnostics | High (validates all other optimizations with data) | M — design benchmark item, run paired comparisons |
| Tester agent (visual/E2E) | Quality | High (catches bugs invisible to code review) | L — new agent, browser automation integration, test infrastructure |

---

## 11. Open Questions

1. **Mock contract accuracy:** How often would the planner's upfront contracts be wrong, requiring rework? Is the rework cost less than the parallelism benefit? Needs experimentation.

2. **Self-verification effectiveness:** Does the builder integration checklist actually reduce fix cycles? Need one run with the checklist enabled + per-story reviews to measure. If fix rate drops from 67% to <20%, that's strong evidence.

3. **Review bias:** Can a single agent effectively "wear multiple hats" (build then review its own work)? Or is the fresh-eyes effect of a separate reviewer fundamentally necessary? Research question — possibly testable with a controlled experiment.

4. **Optimal review granularity:** Per-story, per-epic, or per-PR? The answer likely depends on project size and story interdependence. XL backlogs with tightly coupled stories might benefit from per-epic review; small backlogs might only need PR review.

5. **Layer 2 file format:** Markdown (natural for agents to read/write) vs JSON/YAML (structured, easier to parse programmatically) vs hybrid (markdown with YAML frontmatter)? The retro agent writes prose (markdown-friendly) but the init wizard writes structured data (JSON-friendly).

6. **Self-improvement scope:** Should the retro only add to the project workflow file, or can it also propose changes to Layer 1 agent files? In this repo (where Layer 1 is a deliverable), the answer is yes. For other projects, the answer is no. How to make this configurable?

7. **Cross-project learning:** When the workflow runs on 10 different projects, each with its own Layer 2 file, the lessons are siloed. Is there a Layer 0 (global workflow knowledge) that aggregates patterns across projects? E.g., "DI wiring is a common failure pattern in server projects" — learned from BL#116 but applicable to any future server project.

8. **A/B test design:** What's the right benchmark backlog item? Should it be a real roadmap item (useful output) or a synthetic benchmark (more controlled)? Real items have natural variance; synthetic items may not exercise realistic patterns. How do we account for model performance variance between runs?

---

## Appendix A: Builder Instruction Changes (for A/B Test Variant)

The following content was drafted during the BL#116 post-run discussion and then reverted from `builder.md` to preserve a clean baseline for A/B testing. This is a **starting example, not a final specification** — the implementer should evaluate, adapt, and improve it based on their own design phase findings.

**Insert after the existing "Code Rules" section (after the "Comment only non-obvious logic" bullet), before "Capturing Lessons":**

```markdown
### Think Systemically, Not Just Locally

Before writing code, ask yourself these questions. Most fix cycles come from builders thinking locally (does my function work?) instead of systemically (does my function work inside the running system?).

**Integration checklist (ask before marking a story complete):**

1. **How does this reach the user?** Trace the path from entry point to your code. If you wrote a service, is it wired into the startup path? If you wrote a route, is it registered in the router? If you wrote a component, is it imported by a page? Every new module must be reachable from the system's entry point — not just callable from a test.

2. **What else needs to know this exists?** When you add a feature, other parts of the system may need to react. If you add a new event type, does the WebSocket hub broadcast it? If you add a new API endpoint, does the client wrapper have a method for it? If you add a dependency, is it in the correct section of package.json?

3. **Is every file I created imported by production code?** Trace each new file's import chain back to an entry point (server startup, route registration, component tree, etc.). If a file isn't reachable from any entry point, it's dead code — either wire it in or delete it. Don't confuse test coverage with reachability: a file can have passing tests but still be dead code if nothing in production imports it.

4. **Am I duplicating logic that exists elsewhere?** Search the codebase before writing a utility function. If similar logic exists, import it or extract a shared module. If you must duplicate (e.g., frontend can't import from backend), document the duplication with a comment linking to the canonical source.

**Engineering principles as heuristics (not dogma):**

Apply these principles with judgment. Each has a context where violating it is the right call.

| Principle | What it prevents | When to bend it |
|-----------|-----------------|-----------------|
| **KISS** — prefer simple, obvious solutions | Over-engineered abstractions that nobody can debug | When the "simple" solution creates a maintenance trap (e.g., copy-pasting 200 lines vs. extracting a function) |
| **DRY** — share logic, don't copy it | Bugs fixed in one place but not the other | When sharing creates a coupling that's worse than the duplication (e.g., forcing frontend to import from backend source tree) |
| **YAGNI** — don't build what isn't needed yet | Dead code, speculative abstractions, unused parameters | When a small structural investment now (folder layout, interface design) prevents a painful migration later |
| **Separation of Concerns** — each module owns one responsibility | Cross-layer violations, circular dependencies, God objects | When strict separation creates a class explosion that's harder to reason about than the "messy" original |
| **SOLID** — especially Single Responsibility and Dependency Inversion | Rigid code that can't be tested or extended | When applying all five principles to a simple function creates 5 files where 1 was clear enough |

**The meta-principle:** Every principle is a heuristic for reducing future cost. Apply the one that reduces cost the most in your specific context. When two principles conflict (DRY says share it, SoC says keep layers separate), use judgment — which violation will be more expensive to fix later?
```

**Note:** This version includes the fixed item 3 (reachability check instead of the flawed "can I delete this file" heuristic). The original version was corrected during review before being reverted for A/B testing purposes.
