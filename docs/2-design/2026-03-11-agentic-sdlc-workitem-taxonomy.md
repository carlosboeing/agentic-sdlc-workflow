---
date: 2026-03-11
status: draft — pending team review
recommendations:
  - Architecture: configurable 3-level hierarchy with role-based internal model
  - Default taxonomy: leaning toward Epic → Story → Task based on market familiarity; configurable via presets
  - Default statuses: Backlog → Ready → In Progress → In Review → Done
---

# Design: Work Item Taxonomy for Agentic SDLC

## Overview

This document captures the research, analysis, and reasoning behind a proposed work item taxonomy for an agentic SDLC workflow. The taxonomy must serve two audiences: AI agents that operate the pipeline and humans who need visibility and tracking through PM tools.

The core problem: every PM tool uses different terminology for the same concepts. Jira calls them Epics and Stories. Azure DevOps uses Features and User Stories. Linear has Projects and Issues. Asana uses Projects and Tasks. A team switching tools — or integrating with multiple tools — faces immediate confusion about what maps to what.

**The goal of this design is to eliminate that ambiguity.** The workflow uses a generic, role-based internal model (Level 1, Level 2, Level 3) with configurable naming that adapts to whatever PM tool and terminology the user's team already knows. New users should see familiar terms from their existing workflow, not be forced to learn a new vocabulary.

Key recommendations:
- **Architecture:** A configurable 3-level hierarchy where each level has a defined role (Intent, Grouping, Spec) but user-configurable naming
- **Presets:** Pre-built naming configurations for each major PM tool, selectable during first-run setup
- **Default taxonomy:** Leaning toward Epic → Story → Task based on market familiarity — the most widely encountered terms across the developer population. Configurable via presets for other PM tools.
- **Default statuses:** Backlog → Ready → In Progress → In Review → Done (5 statuses mapped to 3 universal categories)

## Problem Statement

An agentic SDLC workflow needs a work item hierarchy that:

1. Gives AI agents clear, unambiguous boundaries between planning and execution
2. Maps cleanly to the most popular PM tools (Jira, GitHub Issues, Azure Boards, Linear, Asana, Shortcut, ClickUp, Monday, Trello)
3. Aligns with recognised PM methodologies (Scrum, Kanban, SAFe, Shape Up)
4. Works for any team — engineering, marketing, product, operations — not just software development
5. Is easy to understand without requiring PM or agile training
6. Doesn't over-bureaucratise — agents iterate rapidly and the hierarchy should not slow them down
7. **Avoids ambiguity and confusion for new users** — teams already have established terminology from their PM tools; the workflow should speak their language, not impose a new one

It also needs to answer two structural questions: **how many hierarchy levels** are required for a proper agile workflow, and **how many workflow statuses** (board columns) are needed to track work from creation to completion.

The fundamental challenge: every PM tool calls the same concepts by different names. A "Story" in Jira is an "Issue" in Linear, a "Task" in Asana, and a "Card" in Trello. Picking any single set of terms alienates users from other tools. The solution is to make the terminology configurable while keeping the underlying structure consistent.

## Research: Industry Landscape

### Market Size

The global project management software market was valued at approximately USD 7–9 billion in 2024–2025, with projections reaching USD 20–40 billion by 2032–2035. Cloud deployment accounts for ~74% of revenue. North America holds ~36–38% market share, with Asia-Pacific growing fastest.

### Tool Positioning

| Tool | Company | Primary Audience | Scale | Market Position |
|------|---------|-----------------|-------|-----------------|
| Jira | Atlassian | Enterprise dev/eng teams | ~118,000+ customers | Dominant in software dev; 75% of Fortune 500 |
| Azure Boards | Microsoft | Enterprise, MS stack | Part of Azure DevOps | Strong in enterprise; part of broader suite |
| GitHub Issues | Microsoft | Developers, OSS teams | 100M+ developers | Largest dev platform; rapidly adding PM features |
| Asana | Asana Inc. | Cross-functional, mktg, ops | ~170,000+ customers | Leader in Gartner MQ 2025 |
| Linear | Linear Inc. | Modern software teams | Growing fast | Rising star; 5–200 engineer sweet spot |
| Monday.com | Monday.com | Cross-functional, SMB to enterprise | ~225,000+ customers | Visual database approach; highly flexible |
| Trello | Atlassian | Small teams, personal | Millions of users | Simplest tool; Kanban-first |
| ClickUp | ClickUp Inc. | All-in-one teams | ~800,000+ customers | Feature-dense; deepest hierarchy model |
| Shortcut | Shortcut Inc. | Product/eng teams | Growing | Developer-focused; clean hierarchy |

### Native Work Item Hierarchies by Tool

**Jira (Atlassian)**
- Default: `Epic → Story / Task / Bug → Sub-task`
- Premium (Plans): `Initiative → Epic → Story / Task / Bug → Sub-task`
- SAFe-configured: `Initiative → Epic (renamed Feature) → Story → Sub-task`
- Key: Stories, Tasks, Bugs all sit at the same level (Level 0). Custom levels can only be added above Epic, not between Epic and Story.

**Azure DevOps Boards (Microsoft)**
- Agile: `Epic → Feature → User Story → Task (+ Bug)`
- Scrum: `Epic → Feature → Product Backlog Item → Task (+ Bug)`
- CMMI: `Epic → Feature → Requirement → Task (+ Bug)`
- Basic: `Epic → Issue → Task`
- Key: Only major tool with a native "Feature" level between Epic and Story out of the box.

**GitHub Issues & Projects**
- Current (GA 2025): Issue Types (Epic, Feature, Task, Bug — org-configurable) + Sub-issues (up to 8 levels) + Projects (50,000 items)
- Key: Everything is an "Issue" decorated with a type. Hierarchy depth defined by nesting, not type constraints. Hierarchy view in public preview (Jan 2026).

**Linear**
- Organisational: `Initiative (5 levels on Enterprise) → Project (with Milestones) → Cycle`
- Work items: `Issue → Sub-issue`
- Key: No "Epic" or "Story" concepts. Issues classified by labels. Projects = time-bound deliverables. Initiatives = strategic goals.

**Asana**
- Hierarchy: `Goal → Portfolio → Project (with Sections, Milestones) → Task → Subtask (up to 5 levels)`
- Key: No distinct work item types. Everything is a "Task." Differentiation via custom fields, tags, and containers. Multi-homing (tasks in multiple projects).

**ClickUp**
- Hierarchy: `Workspace → Space → Folder → List → Task → Subtask → Checklist`
- Key: Deepest built-in hierarchy. Supports custom task types at each level.

**Shortcut (formerly Clubhouse)**
- Organisational: `Objective → Milestone`
- Work items: `Epic → Story (Feature/Bug/Chore types) → Task (checklist items)`
- Key: Stories are the fundamental work unit in three types. Tasks are simple checklists (under an hour).

**Monday.com**
- Hierarchy: `Workspace → Board → Group → Item → Sub-item`
- Key: No fixed work item types; teams define their own column schemas.

**Trello**
- Hierarchy: `Workspace → Board → List → Card → Checklist`
- Key: Simplest model. No sub-card capability, no native types.

### Cross-Tool Hierarchy Comparison (Normalised)

| Level | Jira | Azure Boards | GitHub | Linear | Asana | ClickUp | Shortcut |
|-------|------|-------------|--------|--------|-------|---------|----------|
| L5: Strategy | Initiative* | — | — | Initiative | Goal | Workspace | Objective |
| L4: Programme | — | — | — | Project | Portfolio | Space | Milestone |
| L3: Group | Epic | Epic | Issue (Epic type) | — | Project | Folder/List | Epic |
| L2: Deliverable | Story/Task/Bug | Feature/User Story | Issue (Task/Bug) | Issue | Task | Task | Story |
| L1: Granular | Sub-task | Task | Sub-issue | Sub-issue | Subtask | Subtask | Task (checklist) |

*Requires Jira Premium/Enterprise with Plans.

### Methodology Mapping

| Term | Scrum | Kanban | SAFe | Shape Up |
|------|-------|--------|------|----------|
| Initiative/Goal | (not native) | (not native) | Portfolio Epic | Strategic Bet |
| Epic | Epic | Large work item | Epic / Capability | Project |
| Feature | (some teams use) | Feature card | Feature | Pitch / Bet |
| Story | User Story | Card / Item | Story | Scope item |
| Task | Sprint Task | Card / Item | Task | To-do |
| Bug | Bug / Defect | Defect card | Bug (Enabler) | Bug |

### Key Industry Insight: "Epic" Has No Consistent Meaning

The term "Epic" is used at fundamentally different hierarchy levels across the industry:

| Context | What "Epic" means | Position |
|---------|-------------------|----------|
| Original Agile (Mike Cohn) | A story too big for one sprint | Top level — above stories |
| SAFe | Strategic portfolio investment | Very top — above features |
| Jira Default | Largest standard grouping | Top of default hierarchy |
| Jira with Plans | Mid-level grouping | Below Initiative |
| Azure DevOps | Major initiative / goal | Very top — above Feature |
| GitHub Issues | "This is big" (flexible) | No fixed position |
| Linear | Doesn't use the term | N/A |
| Shortcut | Collection of stories for a goal | Middle — below Objective |

Two camps exist: **Camp 1** (Jira default, original agile, startups) places Epic at the top. **Camp 2** (SAFe, Azure DevOps, Jira Premium) places Epic in the middle with something above it.

## Requirements Analysis: What Do Agents Need?

The agentic SDLC pipeline has four distinct roles for work items:

| Role | Created by | Consumed by | What it carries |
|------|-----------|-------------|-----------------|
| **Intent** | Product Manager (Human/AI) | Design and planning phases | The brief — what we're building, why, requirements, context |
| **Grouping** | Planning phase | Orchestration layer, humans (board) | Organisational scope — branch boundary, dispatch wave, review unit |
| **Spec** | Planning phase | Execution agents | Self-contained micro-spec — everything needed to execute |
| **Step** | Execution agent (during work) | Execution agent itself | Execution checklist — AC checkboxes, implementation notes |

The bottom level (Step) is informal — checkboxes in the Spec body, not tracked issues. AI agents don't need sub-items on a board.

**Conclusion: Agents need three tracked levels (Intent, Grouping, Spec).** Collapsing Intent + Grouping loses the "one brief spawns multiple work groups" relationship. Collapsing Grouping + Spec loses the organisational structure the orchestration layer depends on (branches, dispatch waves, reviews).

## Alternatives Considered

Seven naming options were evaluated through multiple rounds of analysis. This research informed both the preset configurations and the "Universal" default candidate. While the architecture is now configurable (users choose their own naming), this analysis remains relevant for understanding the trade-offs of each preset and for selecting a sensible fallback default.

### Option A: Epic → Story → Task

- **Mapping:** Best — Jira Default 1:1 with zero configuration
- **Semantics:** Worst — "Story" as organisational glue and "Task" as the richest artifact both violate industry expectations
- **Cross-domain:** Poor — "Story: Design Facebook ad creative" reads awkwardly for non-engineering teams

### Option B: Initiative → Epic → Story

- **Mapping:** Good — Jira Default requires compressing Initiative into Epic; perfect for Jira Premium, Azure, Linear
- **Semantics:** Excellent — every term means what the industry expects
- **Cross-domain:** Moderate — "Initiative" carries enterprise/SAFe connotations; "Story" feels forced for non-engineering work

### Option C: Epic → Feature → Story

- **Mapping:** Decent — Azure Boards native; Jira needs custom type for Feature
- **Semantics:** Mixed — "Feature" in the middle lies ~40% of the time when grouping technical work ("CI/CD Updates," "Tech Debt Batch")
- **Cross-domain:** Moderate

### Option D: Epic → Story → Sub-task

- **Mapping:** Honest about Jira mapping
- **Semantics:** Poor — "Sub-task" implies lightweight and dependent, opposite of the rich micro-specs in this system
- **Cross-domain:** Poor

### Option E: Goal → Epic → Story

- **Mapping:** Good — same structure as Option B
- **Semantics:** Good — "Goal" is universally understood; slightly vague about whether it's an outcome or a deliverable
- **Cross-domain:** Strong — everyone knows what a goal is, but "Story" still feels engineering-specific

### Option F: Goal → Story → Task

- **Eliminated** — loses the middle grouping level that the dispatch model, branch strategy, and dispatch waves depend on

### Option G: Feature → Epic → Story

- **Mapping:** Azure Boards has a semantic inversion (your Feature maps to their Epic, your Epic maps to their Feature)
- **Semantics:** Reads naturally for product work, but "Feature: Migrate to Postgres" and "Feature: Reduce Tech Debt" feel forced
- **Cross-domain:** Poor for technical and non-product work

### Option H: Goal → Epic → Task

- **Mapping:** Strong — maps to every tool; near-identical to Asana's native Goal → Project → Task
- **Semantics:** Excellent — Goal = intent (universal), Epic = body of work (well-known), Task = actionable unit (universal)
- **Cross-domain:** Best of all options — works for engineering, marketing, product, operations, infrastructure
- **Outcome:** Selected as the "Universal" preset. Not hardcoded as the system default — the architecture is configurable with presets per PM tool.

## Decision Process

### Round 1: Three Levels Confirmed

Analysis showed that collapsing to two levels breaks the dispatch model (branches, waves, reviews depend on the middle layer). Four levels adds bureaucracy without operational benefit for AI agents. Three tracked levels match the sweet spot across the industry (Jira, GitHub, Shortcut all default to three).

### Round 2: Bottom Level — Story vs Task

Story and Task were stress-tested across domains:

| Test | Task wins | Story wins |
|------|-----------|------------|
| Cross-domain readability (marketing, ops, infra) | ✓ | |
| Builder/agent neutrality (no format bias) | ✓ | |
| Human communication in engineering teams | | ✓ |
| Template weight matching (rich micro-specs) | | ✓ |
| Tool mapping breadth (Asana, Monday, Trello) | ✓ | |
| Mixed team onboarding | ✓ | |

**Task: 4. Story: 2.** Task won on breadth and universality. Story won on engineering culture fit.

Key insight: the *weight* of a Task is defined by the template, not the name. A marketing team's Task template is simple. An engineering team's Task template is a full micro-spec with design sections and acceptance criteria. Same taxonomy, different templates.

### Round 3: Top Level — Goal vs Initiative vs Feature vs Epic

| Candidate | Product work | Technical work | Marketing | Research |
|-----------|-------------|---------------|-----------|----------|
| Goal | ✓ Natural | ✓ Natural | ✓ Natural | ✓ Natural |
| Initiative | ✓ Slightly formal | ✓ Natural | ✓ Formal | ✓ Natural |
| Feature | ✓ Perfect | ✗ Forced | ✗ Forced | ✗ Forced |
| Epic | ✓ Natural | ✓ Natural | ~ Jargon-y | ~ Jargon-y |

**Goal** emerged as the strongest candidate because it's the most universally understood term, works across all domains, and is the most natural word for a human starting the pipeline ("my goal is to..."). It avoids the enterprise connotations of "Initiative" and the product-only limitation of "Feature."

### Round 4: Middle Level — Epic Retained

Epic was evaluated against Milestone (time-based, wrong for containers), Workstream (corporate, no tool uses it), Phase (implies sequential), Project (massively overloaded), Module (too technical), Theme (too vague), and Track (no tool support).

**Epic is the recommended choice** because it's the one term that signals "structured body of work" while being widely known across PM tools. A marketing person learns one new word. An engineer already knows it.

### Round 5: From Fixed Taxonomy to Configurable Architecture

Rounds 1–4 identified Goal → Epic → Task as the most semantically neutral naming. However, a key realisation emerged: **no single set of terms will feel familiar to all users.** A Jira team expects "Epic → Story → Sub-task." A Linear team expects "Initiative → Project → Issue." Picking any fixed vocabulary creates friction for users coming from a different tool.

The insight: the *structure* is universal (3 levels with defined roles) but the *names* are inherently tool-specific. Rather than imposing one vocabulary, the architecture should be generic — with role-based levels internally and configurable naming via presets that match each team's existing PM tool. The goal is to eliminate ambiguity for new users by speaking their language from day one.

### Round 6: Local-First PM and Low Barrier of Entry

Further analysis revealed that the workflow should not assume an external PM tool at all. Many users — especially solo developers and small teams — will use the workflow without connecting to Jira, GitHub Projects, or any other tool. The workflow should ship with a **local file-based PM system** (markdown files in the repo) that works immediately with zero configuration.

This has several implications:

**3 levels are operationally required, not optional.** The planning phase groups tasks into batches for parallel dispatch, branch isolation, and review boundaries. Without a middle level, the board becomes a flat list of tasks with no visual grouping, the dispatch plan loses its structure, and branch strategy collapses. Reducing to 2 levels was considered but eliminated because it breaks the core orchestration model.

**The default must work on first use without setup.** The best developer tools work immediately — git doesn't ask you to pick a branching strategy on `git init`. A mandatory "which PM tool?" step is a gate that signals complexity. Configuration should be discovered when needed, not imposed upfront.

**Terms should be self-explanatory in a filesystem context.** The local PM system stores work items as files in directories. The taxonomy appears as folder names (`epics/`, `stories/`, `tasks/`), file names, CLI commands, and board UI labels. The default terms need to read naturally across all of these contexts.

**The default audience is a developer who just installed the plugin**, not a PM professional configuring an enterprise tool. That developer has most likely encountered Jira at some point — Epic, Story, and Task are the terms they'll recognise without explanation.

Goal → Epic → Task remains available as the "Universal" preset for cross-domain use. But the out-of-box default leans toward **Epic → Story → Task** because it optimises for the largest group of users who will never change it. This trades semantic purity (Epic → Story → Task was rated lowest on semantics in our alternatives analysis) for familiarity — the right trade-off for a default that most users will never change. Users who care about terminology will configure it.

## Recommended Approach

### Architecture: Configurable 3-Level Hierarchy

The workflow uses a generic, role-based internal model. Work items are defined by their **role** in the pipeline, not by their name. The naming is a configuration layer on top.

#### Internal Model (Name-Agnostic)

| Internal role | Purpose | Created by | Consumed by |
|--------------|---------|-----------|-------------|
| **Level 1 (Intent)** | What we're building and why — the brief, requirements, context | Product Manager (Human/AI) | Design and planning phases |
| **Level 2 (Grouping)** | How the work is organised — scope boundary, dispatch wave, review unit | Planning phase | Orchestration layer, humans (board) |
| **Level 3 (Spec)** | What gets executed — self-contained, everything needed to build | Planning phase | Execution agents |

The internal model doesn't change regardless of what the levels are called. An agent dispatching a Level 3 item doesn't care if it's called a "Task," a "Story," or an "Issue" — it reads the template and executes. The naming exists purely for human comprehension and PM tool compatibility.

#### Why Configurable Naming Matters

The PM industry uses different terms for identical concepts. A team coming from Jira expects "Epic → Story → Sub-task." A team from Azure DevOps expects "Epic → Feature → User Story." A team from Linear expects "Initiative → Project → Issue." Forcing any single vocabulary on all users creates unnecessary friction and confusion.

By making the naming configurable, the workflow speaks the language each team already knows. New users see familiar terms from their existing PM tool and can start working immediately without learning a new taxonomy. This is the primary design goal: **eliminate ambiguity and confusion by meeting users where they are.**

#### Presets

The workflow ships with presets for each major PM tool. Users select their tool during first-run setup, and the system auto-applies the matching terminology.

| Preset | Level 1 (Intent) | Level 2 (Grouping) | Level 3 (Spec) | Based on |
|--------|------------------|--------------------|--------------------|----------|
| **Default** | **Epic** | **Story** | **Task** | **Jira-inspired (most widely recognised terms)** |
| Azure DevOps | Epic | Feature | User Story | Azure Boards Agile process |
| GitHub | Epic | Feature | Task | GitHub native issue types |
| Linear | Initiative | Project | Issue | Linear's model |
| Asana | Goal | Project | Task | Asana's native hierarchy |
| Shortcut | Epic | Story | Task | Shortcut's model (same as default) |
| SAFe | Epic | Feature | Story | Scaled Agile Framework |
| Universal | Goal | Epic | Task | Semantically neutral (research recommendation) |

Users can also define fully custom names if none of the presets match their workflow.

#### First-Run Experience

The workflow should work immediately on first use with no mandatory setup. Configuration is optional and can be done later.

```
Install → works immediately with Epic → Story → Task defaults
                ↓
       Use it, get value
                ↓
    Optionally configure naming (presets or custom)
                ↓
    Optionally connect a PM tool for sync
```

When a user does choose to configure, the preset selector is available:

```
"Which PM tool does your team use?" (optional)

  → Jira           → applies Epic / Story / Sub-task
  → Azure DevOps   → applies Epic / Feature / User Story
  → GitHub          → applies Epic / Feature / Task
  → Linear          → applies Initiative / Project / Issue
  → Asana           → applies Goal / Project / Task
  → Shortcut        → applies Epic / Story / Task
  → Custom          → user names each level manually
```

#### Local-First PM System

The workflow includes a built-in, file-based PM system that works without any external tool. Work items are stored as markdown files in the repo, tracked alongside code in version control.

```
.workflow/
  epics/
    e01-auth-backend.md
    e02-frontend-components.md
  stories/
    e01-s01-implement-oauth.md
    e01-s02-token-storage.md
    e02-s01-login-button.md
  tasks/
    (checklists within story files, not separate files)
```

Benefits:
- **Zero dependencies** — no accounts, APIs, or external tools required
- **Works offline** — agents read and write local files
- **Version controlled** — work item history lives in git alongside the code
- **Portable** — move the repo, the PM system moves with it
- **Agent-native** — reading a markdown spec from disk is simpler and faster than an API call

External PM tool sync (Jira, GitHub Projects, Linear, etc.) is an optional layer on top. When connected, the local files remain the source of truth for agents, and the sync engine pushes/pulls state to the external tool for human visibility.

#### Default Taxonomy

The out-of-box default — what new users see with no configuration — is:

**Epic → Story → Task** (leaning toward this based on analysis)

Reasoning:
- Jira dominates the PM market (~75% of Fortune 500). More developers have encountered these terms than any alternative.
- The default serves users who will never configure it. That audience most likely speaks Jira vocabulary.
- "Epic" and "Task" are widely understood. "Story" has Scrum origins but has crossed into general developer vocabulary.
- In a filesystem context, `epics/`, `stories/`, `tasks/` read naturally as folder names.
- On a board UI, the hierarchy renders clearly:

```
Epic: Social Login
├─ Story: Auth Backend          [3/5 tasks done]
├─ Story: Frontend Components   [0/4 tasks done]
└─ Story: CI/CD Updates         [1/2 tasks done]
```

Alternative considered: Goal → Epic → Task is semantically cleaner and more cross-domain, but optimises for universality over familiarity. It's available as the "Universal" preset for teams that prefer it.

This can be finalised based on team discussion, user testing, and onboarding feedback.

### Definitions (Role-Based, Name-Independent)

These definitions describe the role of each level, regardless of what it's called in a specific preset:

- **Level 1 (Intent):** A concrete deliverable objective. What we're building and why. Contains the brief, requirements, and context. Owned by the Product Manager (Human/AI). Entry point for the agent pipeline. This is *not* an abstract OKR metric — it describes a tangible outcome ("Build Social Login," "Migrate to Postgres," "Q3 Lead Gen Campaign").

- **Level 2 (Grouping):** A coherent grouping of related Level 3 items within a Level 1 item. Defines a scope boundary for branching, dispatch, and review. May represent a sub-feature, a technical domain, or a work phase. Created during the planning phase. Consumed by the orchestration layer and humans for board tracking. This level is organisational glue — no execution agent consumes it directly for build instructions.

- **Level 3 (Spec):** A self-contained, buildable unit of work. The execution agent's single source of truth. Contains everything needed to execute: context, design guidance, acceptance criteria, branch metadata. One item = one agent dispatch = one deliverable. The richness of a Level 3 item is defined by its template, which varies by team and domain.

### Type Field on Level 3

Instead of separate hierarchy levels for different work types, a `type` field on Level 3 items provides classification:

| Type | Description |
|------|-------------|
| `feature` | New functionality to implement |
| `bug` | Defect or unintended behaviour to fix |
| `refactor` | Code/process improvement, no behaviour change |
| `spike` | Research or exploration, time-boxed |
| `chore` | Maintenance work (dependencies, config, CI/CD) |

### PM Tool Mapping

The mapping layer translates between the internal model and each tool's native terminology. This table shows how the three levels map to each tool's native work item types:

| Internal role | Jira Default | Jira Premium | Azure Boards | GitHub Issues | Linear | Asana | Shortcut | Trello | Monday |
|--------------|-------------|-------------|-------------|--------------|--------|-------|----------|--------|--------|
| Level 1 (Intent) | Epic | Initiative | Epic | Issue (Epic) | Initiative | Goal | Objective | Board | Board |
| Level 2 (Grouping) | Story | Epic | Feature | Issue (Feature) | Project | Project | Epic | List | Group |
| Level 3 (Spec) | Sub-task | Story | User Story/Task | Issue (Task) | Issue | Task | Story | Card | Item |

### Mapping Strategy

- Map by **semantic role**, not by name matching — the mapping layer handles the translation transparently
- If a tool doesn't support a level (e.g., Trello has no native grouping concept), flatten the hierarchy — a Level 2 item becomes a List or labelled Card
- Preserve tool-specific metadata (Jira Story Points, Linear Cycles, Azure Value Area) as extension fields
- Bug placement is configurable per tool — some tools treat Bugs at the Level 3 level, others at Level 2
- Team members see their tool's native terminology — the internal model is invisible to end users

### Minimum Viable Hierarchy

For maximum cross-tool compatibility, the three-level core maps to every tool researched without requiring custom configuration. For tools with only two native levels, compress Level 1 + Level 2 into one level. For tools with four+ levels, the extra levels remain unused or map to labels/milestones.

## Stress Test Results

The 3-level taxonomy was tested against eight scenarios (using the "Universal" preset — Goal → Epic → Task — as the test case, but findings apply to all presets):

| Scenario | Result | Convention |
|----------|--------|------------|
| Tiny feature (one Level 3 item) | Holds | Single-item Level 2 groupings are acceptable |
| Sprawling migration (40+ Level 3 items) | Cracks slightly | Use labels/milestones to link related Level 1 items |
| Bug promotion (Bug outgrows Level 3) | Holds | Close item, promote to new Level 2 or Level 1 |
| Cross-cutting concerns (Sentry, logging) | Holds | Level 3 items can decompose by domain, not just feature |
| Item too big mid-work | Holds | Level 3 items use checklists internally; promote if needed |
| Spike/research | Holds | Spike is a Level 3 item with `type: spike` |
| Non-engineering work (marketing, ops) | Holds | All three levels are domain-neutral |
| Multi-tool integration | Holds | Mapping config per tool handles translation |

## How It Reads in Practice

### Universal Preset (Goal → Epic → Task)

| Domain | Level 1 | Level 2 | Level 3 |
|--------|---------|---------|---------|
| Product | Goal: Build Social Login | Epic: Auth Backend | Task: Implement Google OAuth callback |
| Infrastructure | Goal: Set Up CI/CD Pipeline | Epic: GitHub Actions | Task: Configure deployment workflow |
| Marketing | Goal: Q3 Lead Gen Campaign | Epic: Social Media | Task: Design Facebook ad creative |
| Tech debt | Goal: Reduce Auth Tech Debt | Epic: Session Management | Task: Migrate from JWT to opaque tokens |

### Jira Preset (Epic → Story → Sub-task)

| Domain | Level 1 | Level 2 | Level 3 |
|--------|---------|---------|---------|
| Product | Epic: Build Social Login | Story: Auth Backend | Sub-task: Implement Google OAuth callback |
| Infrastructure | Epic: Set Up CI/CD Pipeline | Story: GitHub Actions | Sub-task: Configure deployment workflow |

### Azure DevOps Preset (Epic → Feature → User Story)

| Domain | Level 1 | Level 2 | Level 3 |
|--------|---------|---------|---------|
| Product | Epic: Build Social Login | Feature: Auth Backend | User Story: Implement Google OAuth callback |
| Infrastructure | Epic: Set Up CI/CD Pipeline | Feature: GitHub Actions | User Story: Configure deployment workflow |

The same work, the same structure, the same agent pipeline — just different labels. The user sees the terminology they already know.

## Hierarchy Levels

### How Many Levels?

Three levels is the industry sweet spot. Every major tool defaults to three tracked levels of work items:

| Tool | Default levels | Notes |
|------|---------------|-------|
| Jira | 3 (Epic → Story → Sub-task) | 4th level (Initiative) requires Premium |
| Azure Boards | 4 (Epic → Feature → User Story → Task) | The outlier — only tool with 4 by default |
| GitHub Issues | Flexible (up to 8 via nesting) | Default issue types suggest 3 |
| Linear | 3 (Initiative → Project → Issue) | Sub-issues exist but are informal |
| Asana | 3 effective (Project → Task → Subtask) | Goal/Portfolio are containers, not work items |
| Shortcut | 3 (Epic → Story → Task as checklist) | Objective/Milestone are containers |
| ClickUp | 3 effective (List → Task → Subtask) | Space/Folder are containers |

Scrum and Kanban both operate with 2–3 levels. The official Scrum Guide doesn't even mention "Epic" — it defines only Product Backlog Items and Sprint Tasks. Kanban tracks cards through columns with no required hierarchy. SAFe is the only methodology that demands 4+ levels, but it's explicitly designed for large enterprises with multiple teams.

### Recommendation: 3 Levels (Configurable 2–4)

The default is 3 levels. This is not just a best-practice recommendation — it's an operational requirement for the agentic workflow. The planning phase groups work items into batches for parallel dispatch. Each group defines a branch boundary, a dispatch wave, and a review unit. Without the middle level, the dispatch plan becomes a flat list with no structure, branch isolation is lost, and the board UI shows a wall of cards in a single swimlane.

Teams that need less (simple projects) can use 2 levels, but this disables grouped dispatch and reduces board visibility. Teams on Azure Boards or in SAFe shops can extend to 4. The framework treats levels as configurable, with naming and depth set by the user. Naming defaults are applied via presets based on the user's PM tool selection, with Epic → Story → Task as the out-of-box default.

## Workflow Statuses

### Industry Research: Default Statuses by Tool

| Tool | Default statuses | Status categories |
|------|-----------------|-------------------|
| Jira (Scrum board) | To Do, In Progress, Done | 3 categories: To Do, In Progress, Done |
| Jira (Kanban board) | Backlog, Selected for Development, In Progress, Done | Same 3 categories |
| Jira (Agile dev typical) | Backlog, To Do, In Progress, In Review, Done | Same 3 categories |
| Linear | Backlog, Todo, In Progress, Done, Cancelled | Plus Triage as entry point |
| GitHub Issues | Open, Closed | Just 2 (projects add custom columns) |
| Azure Boards (Agile) | New, Active, Resolved, Closed, Removed | 3 categories: Proposed, InProgress, Complete |
| Asana | (custom per project) | Typically: To Do, In Progress, Complete |
| Shortcut | Unstarted, Started, Done | 3 categories |

The universal pattern across all tools and methodologies is **three status categories**: Not Started, In Progress, and Completed. Jira hardcodes exactly these three categories — you can't create a fourth. Every custom status must map to one of them.

The simplest Kanban board (To Do → Doing → Done) and the minimum Scrum board both use three columns. However, for a proper development workflow, the "In Progress" category needs sub-states to distinguish "building" from "validating."

### Alternatives Considered

**3 statuses (To Do → In Progress → Done):** The Kanban minimum. Too coarse for any workflow involving review or validation. No way to distinguish "being built" from "being reviewed."

**4 statuses (Backlog → In Progress → Review → Done):** Workable but conflates "exists but not prioritised" with "ready to be picked up." For an agentic workflow, the distinction between Backlog (not yet ready) and Ready (can be dispatched) is operationally critical.

**6 statuses (+ Rejected):** A "Rejected" status was considered for the execution → review re-dispatch loop. Rejected because this loop is internal agent orchestration — the user doesn't need to see how many review cycles happened. From the user's perspective, the item is "being worked on" until it's done. The re-dispatch signal lives in the orchestration layer (comments, internal state, agent-to-agent communication), not on the board.

**7 statuses (+ Cancelled):** A "Cancelled" terminal state was considered but deferred. Users who need it can add it. The defaults should be minimal.

### Recommendation: 5 Default Statuses

```
Backlog → Ready → In Progress → In Review → Done
```

| Status | Category | What it signals | Board position |
|--------|----------|----------------|----------------|
| **Backlog** | Not Started | Item exists but isn't prioritised or fully specified | Left |
| **Ready** | Not Started | Fully specified, dependencies met, can be picked up | Left |
| **In Progress** | In Progress | Actively being worked on by a human or agent | Middle |
| **In Review** | In Progress | Work complete, awaiting validation (review, testing, QA) | Middle |
| **Done** | Completed | Accepted and complete, no further action needed | Right |

### Status Categories (Universal Translation Layer)

Regardless of how many statuses a user configures, each must map to one of three categories. These categories are the universal translation layer for PM tool integration:

| Category | Default statuses | Jira category | GitHub mapping | Linear mapping |
|----------|-----------------|---------------|----------------|----------------|
| **Not Started** | Backlog, Ready | To Do | Open | Backlog, Todo |
| **In Progress** | In Progress, In Review | In Progress | Open | In Progress |
| **Completed** | Done | Done | Closed | Done |

When mapping to GitHub (which only has Open/Closed), everything in "Not Started" and "In Progress" maps to Open, and "Completed" maps to Closed. When mapping to Jira, each status maps to its native category. The category model ensures compatibility with every tool.

### Why Each Status Exists

**Backlog** — The item has been created but isn't ready for execution. It may be missing requirements, waiting on design, or simply not prioritised. This is where Level 1 and Level 2 items start before planning is complete. Maps to Jira's "To Do" category, Linear's "Backlog," GitHub's "Open."

**Ready** — The item is fully specified, dependencies are met, and it can be picked up by the next available agent or team member. This is Jira Kanban's "Selected for Development." For an agentic workflow, this status is the dispatch signal — the orchestration layer looks for items in "Ready" to dispatch to execution agents.

**In Progress** — Actively being worked on. An agent or human has picked it up and is executing. Maps to every tool's "In Progress."

**In Review** — Work is complete but awaiting validation. This is where code review, testing, and QA happen. For an agentic workflow, this is where review and testing agents operate. Internal review cycles (agent submits → reviewer requests changes → agent fixes → reviewer approves) happen while the item remains in this status. The user sees "In Review" throughout, not the internal back-and-forth.

**Done** — Accepted and complete. No further action. Universal across all tools.

### Configurability

Statuses are user-configurable. Teams can add (e.g., Cancelled, On Hold, Blocked, Deployed, QA), remove, or rename statuses. The 5 defaults cover the universal workflow. Each custom status must be assigned to one of the three categories (Not Started, In Progress, Completed) to maintain PM tool compatibility.

## What This Replaces

If migrating from the earlier `Backlog → Epic → Story` naming used in test runs:

| Previous term | New approach | What changed |
|---------------|-------------|--------------|
| Backlog (item) | Level 1 (Intent) — configurable name | "Backlog" is a container, not an item type. The role is "Intent" — the name depends on the user's PM tool preset. |
| Epic | Level 2 (Grouping) — configurable name | Same role. Name depends on preset (Epic, Feature, Story, Project, etc.). |
| Story | Level 3 (Spec) — configurable name | Same role. Name depends on preset (Task, Story, Sub-task, Issue, User Story, etc.). |

The templates, information flow, and agent pipeline remain structurally identical. The internal model is role-based and name-agnostic. The naming is a configuration layer that adapts to each team's existing vocabulary.