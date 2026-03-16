# Roadmap

> **Last updated:** 2026-03-17
> **Work tracking:** [Project Board](https://github.com/users/carlosboeing/projects/7)
> **Analysis & research:** [docs/1-discovery/2026-03-15-roadmap.md](1-discovery/2026-03-15-roadmap.md)

## Dependency Graph

```mermaid
graph TD
    105["#105 Orchestrator<br/>Improvements ✅"]
    106["#106 Telemetry<br/>Accuracy ✅"]
    107["#107 Retro Agent<br/>Rework (M)"]
    108["#108 Run on Real<br/>Software (L)"]
    109["#109 PM Abstraction<br/>Layer (L)"]
    110["#110 Configurable<br/>Taxonomy (L)"]
    111["#111 Local-First<br/>PM (XL)"]
    112["#112 Plugin<br/>Packaging (XL)"]
    113["#113 Multi-PM<br/>Adapters (XL)"]
    114["#114 Domain<br/>Profiles (L)"]
    115["#115 Specialist<br/>Agents (L)"]
    116["#116 Dashboard (XL)"]
    117["#117 Multi-Repo (XL)"]
    118["#118 Learning Across<br/>Projects (L)"]
    148["#148 Adversarial<br/>Deliberation (M)"]
    149["#149 Universal Worktree<br/>Isolation (M)"]
    150["#150 Split<br/>orchestrator.md (S)"]

    105 --> 108
    106 --> 108
    107 --> 108
    109 --> 111
    109 --> 110
    109 --> 112
    109 --> 113
    109 --> 117
    110 --> 112
    111 --> 112
    111 --> 116
    107 --> 118
    112 --> 113
    112 --> 117
    112 --> 118

    style 105 fill:#9ca3af,color:#fff
    style 106 fill:#9ca3af,color:#fff
    style 107 fill:#059669,color:#fff
    style 108 fill:#059669,color:#fff
    style 109 fill:#8b5cf6,color:#fff
    style 110 fill:#8b5cf6,color:#fff
    style 111 fill:#8b5cf6,color:#fff
    style 112 fill:#8b5cf6,color:#fff
    style 113 fill:#374151,color:#fff
    style 114 fill:#374151,color:#fff
    style 115 fill:#374151,color:#fff
    style 116 fill:#374151,color:#fff
    style 117 fill:#374151,color:#fff
    style 118 fill:#374151,color:#fff
    style 148 fill:#059669,color:#fff
    style 149 fill:#059669,color:#fff
    style 150 fill:#059669,color:#fff
```

✅ Done · 🟢 Active (ready now) · 🟣 Plugin track · ⚫ Future ideas

## Priority Order

| Priority | Issue | Title | Size | Dependencies | Track |
|----------|-------|-------|------|-------------|-------|
| ✅ | [#105](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/105) | ~~Orchestrator Improvements~~ | M | — | Done |
| ✅ | [#106](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/106) | ~~Telemetry Accuracy & Automation~~ | M | — | Done |
| 1 | [#107](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/107) | Retro Agent Rework | M | — | Active |
| 2 | [#150](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/150) | Split orchestrator.md | S | — | Active |
| 3 | [#149](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/149) | Universal Worktree Isolation | M | — | Active |
| 4 | [#148](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/148) | Adversarial Deliberation Agent | M | — | Active |
| 5 | [#108](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/108) | Run on Real Software | L | ~~105~~, ~~106~~, 107 | Active |
| 6 | [#109](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/109) | PM Abstraction Layer | L | — | Plugin |
| 7 | [#110](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/110) | Configurable Taxonomy | L | 109 | Plugin |
| 8 | [#111](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/111) | Local-First PM System | XL | 109 | Plugin |
| 9 | [#112](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/112) | Plugin Packaging | XL | 109, 110, 111 | Plugin |
| 10 | [#113](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/113) | Multi-PM Adapters | XL | 109, 112 | Future |
| 11 | [#114](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/114) | Domain Profiles | L | — | Future |
| 12 | [#115](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/115) | New Specialist Agents | L | — | Future |
| 13 | [#116](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/116) | Dashboard | XL | 111 | Future |
| 14 | [#117](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/117) | Multi-Repo Orchestration | XL | 109, 112 | Future |
| 15 | [#118](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/118) | Learning Across Projects | L | 107, 112 | Future |

## Backlog Summaries

### Completed

**[#105 Orchestrator Improvements](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/105)** — `size/M` ✅
Bundle of orchestrator enhancements: Sonnet reviews for easy stories, early story branch creation, streaming reviews (review as each builder finishes), batched board updates, batch issue creation in planner, format templates for parallel content, orchestrator override pattern documentation, and orchestrator overhead metrics.

**[#106 Telemetry Accuracy & Automation](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/106)** — `size/M` ✅
Fix hand-crafted Gantt charts by generating them from state data with precise timestamps. Extract the 602-line `issue-telemetry.sh` dispatch computation into a separate Python module. Add tracking for fix cycle overhead and run duration baselines.

### Active Track

**[#107 Retro Agent Rework](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/107)** — `size/M`
Redesign the retro agent to stop self-modifying workflow files. Separate project-specific lessons (`docs/4-reviews/`) from workflow feedback (`.workflow/feedback/`). Enables parallel retro + PR review. Add opt-in feedback reporting for plugin maintainers.

**[#150 Split orchestrator.md](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/150)** — `size/S`
Split the 1270-line `orchestrator.md` into a lean core instruction file (~400 lines) and reference documents consulted only when needed. Extracts state schema, board management patterns, and telemetry computation into `docs/5-guides/` — reducing context loaded on every agent dispatch.

**[#149 Universal Worktree Isolation](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/149)** — `size/M`
Ensure every agent — including the orchestrator itself — operates in an isolated git worktree in autonomous mode. Eliminates checkout collisions, stale artifact leakage, and commits landing on wrong branches when multiple backlog items have active branches.

**[#148 Adversarial Deliberation Agent](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/148)** — `size/M`
Add a configurable deliberation capability where a second agent challenges the first agent's output at key decision points. Triages reviewer findings (filtering false positives before fix cycles), challenges design/plan assumptions, and improves merge/no-merge decisions.

**[#108 Run on Real Software](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/108)** — `size/L`
First real-software test — use the workflow to build one of its own improvements. 14 runs validated creative content; zero runs on actual code. Validates genericized agents work for real development. Blocked by #107 (last remaining dependency — #105 and #106 are complete).

### Plugin Track

**[#109 PM Abstraction Layer](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/109)** — `size/L`
Extract GitHub-specific operations into `scripts/lib/pm.sh` adapter interface. Config-driven adapter selection. Enables async external PM sync (local files are instant, external tools sync in background). Includes cost budgets feature.

**[#110 Configurable Taxonomy](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/110)** — `size/L`
Implement the configurable 3-level hierarchy with PM tool presets (Jira, Azure DevOps, GitHub, Linear, Asana, Shortcut, SAFe, Universal). Default: Epic → Story → Task. Labels migrate dynamically based on config.

**[#111 Local-First PM System](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/111)** — `size/XL`
File-based PM adapter — zero dependencies, offline capable, git-native. Work items as markdown with YAML frontmatter in `.workflow/`. The killer differentiator: no competitor offers zero-config PM.

**[#112 Plugin Packaging](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/112)** — `size/XL`
Package as a Claude Code plugin: `plugin.json`, SKILL.md, `/sdlc-setup` onboarding, `sdlc` CLI wrapper. Consumer projects only need `agentic-sdlc-config.json`.

### Future Ideas

**[#113 Multi-PM Adapters](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/113)** — `size/XL`
Jira, Linear, Azure DevOps, ClickUp adapters. One at a time, each implementing the PM interface. Possibly MCP servers for maximum interoperability.

**[#114 Domain Profiles](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/114)** — `size/L`
Config-driven builder/reviewer profiles for content, research, data, marketing, legal/compliance domains. Only builder and reviewer need profiles.

**[#115 New Specialist Agents](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/115)** — `size/L`
Estimator (most concrete — uses telemetry history), triage, documenter, QA, release, compliance, onboarding agents.

**[#116 Dashboard](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/116)** — `size/XL`
Ephemeral local web UI: Kanban board, telemetry charts, Gantt timeline. Reads from `.workflow/` files. CLI fallback for terminal environments.

**[#117 Multi-Repo Orchestration](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/117)** — `size/XL`
Backlog items spanning multiple repos with cross-repo branch coordination and merge strategy.

**[#118 Learning Across Projects](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/118)** — `size/L`
Global lessons database fed by workflow feedback from multiple projects. Institutional memory beyond per-project retros.
