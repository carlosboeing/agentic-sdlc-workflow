---
date: 2026-03-11
author: Carlos
status: draft
decision: Goal → Epic → Task
---

# Design: Work Item Taxonomy for Agentic SDLC

## Overview

This document captures the research, analysis, and decision process for selecting a standardised work item taxonomy for an agentic SDLC workflow. The taxonomy must serve two audiences: AI agents that operate the pipeline and humans who need visibility and tracking through PM tools.

The final decision: **Goal → Epic → Task** — two universal terms bookending one well-known PM term.

## Problem Statement

An agentic SDLC workflow needs a work item hierarchy that:

1. Gives AI agents clear, unambiguous boundaries between planning and execution
2. Maps cleanly to the most popular PM tools (Jira, GitHub Issues, Azure, Linear, Asana, Shortcut, ClickUp, Monday, Trello)
3. Aligns with recognised PM methodologies (Scrum, Kanban, SAFe, Shape Up)
4. Works for any team — engineering, marketing, product, operations — not just software development
5. Is easy to understand without requiring PM or agile training
6. Doesn't over-bureaucratise — agents iterate rapidly and the hierarchy should not slow them down

## Research: Industry Landscape

### Market Size

The global project management software market was valued at approximately USD 7–9 billion in 2024–2025, with projections reaching USD 20–40 billion by 2032–2035. Cloud deployment accounts for ~74% of revenue. North America holds ~36–38% market share, with Asia-Pacific growing fastest.

### Tool Positioning


| Tool          | Company       | Primary Audience                    | Scale                | Market Position                                  |
| ------------- | ------------- | ----------------------------------- | -------------------- | ------------------------------------------------ |
| Jira          | Atlassian     | Enterprise dev/eng teams            | ~118,000+ customers  | Dominant in software dev; 75% of Fortune 500     |
| Azure  | Microsoft     | Enterprise, MS stack                | Part of Azure DevOps | Strong in enterprise; part of broader suite      |
| GitHub Issues | Microsoft     | Developers, OSS teams               | 100M+ developers     | Largest dev platform; rapidly adding PM features |
| Asana         | Asana Inc.    | Cross-functional, mktg, ops         | ~170,000+ customers  | Leader in Gartner MQ 2025                        |
| Linear        | Linear Inc.   | Modern software teams               | Growing fast         | Rising star; 5–200 engineer sweet spot           |
| Monday.com    | Monday.com    | Cross-functional, SMB to enterprise | ~225,000+ customers  | Visual database approach; highly flexible        |
| Trello        | Atlassian     | Small teams, personal               | Millions of users    | Simplest tool; Kanban-first                      |
| ClickUp       | ClickUp Inc.  | All-in-one teams                    | ~800,000+ customers  | Feature-dense; deepest hierarchy model           |
| Shortcut      | Shortcut Inc. | Product/eng teams                   | Growing              | Developer-focused; clean hierarchy               |


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


| Level           | Jira           | Azure       | GitHub            | Linear     | Asana     | ClickUp     | Shortcut         | Monday   | Trello    |
| --------------- | -------------- | ------------------ | ----------------- | ---------- | --------- | ----------- | ---------------- | -------- | --------- |
| L5: Strategy    | Initiative*    | —                  | —                 | Initiative | Goal      | Workspace   | Objective        | —        | —         |
| L4: Programme   | —              | —                  | —                 | Project    | Portfolio | Space       | Milestone        | —        | —         |
| L3: Group       | Epic           | Epic               | Issue (Epic type) | —          | Project   | Folder/List | Epic             | Board    | Board     |
| L2: Deliverable | Story/Task/Bug | Feature/User Story | Issue (Task/Bug)  | Issue      | Task      | Task        | Story            | Group    | List      |
| L1: Granular    | Sub-task       | Task               | Sub-issue         | Sub-issue  | Subtask   | Subtask     | Task (checklist) | Item     | Card      |


*Requires Jira Premium/Enterprise with Plans.

### Methodology Mapping


| Term            | Scrum            | Kanban          | SAFe              | Shape Up      |
| --------------- | ---------------- | --------------- | ----------------- | ------------- |
| Initiative/Goal | (not native)     | (not native)    | Portfolio Epic    | Strategic Bet |
| Epic            | Epic             | Large work item | Epic / Capability | Project       |
| Feature         | (some teams use) | Feature card    | Feature           | Pitch / Bet   |
| Story           | User Story       | Card / Item     | Story             | Scope item    |
| Task            | Sprint Task      | Card / Item     | Task              | To-do         |
| Bug             | Bug / Defect     | Defect card     | Bug (Enabler)     | Bug           |


### Key Industry Insight: "Epic" Has No Consistent Meaning

The term "Epic" is used at fundamentally different hierarchy levels across the industry:


| Context                    | What "Epic" means                | Position                  |
| -------------------------- | -------------------------------- | ------------------------- |
| Original Agile (Mike Cohn) | A story too big for one sprint   | Top level — above stories |
| SAFe                       | Strategic portfolio investment   | Very top — above features |
| Jira Default               | Largest standard grouping        | Top of default hierarchy  |
| Jira with Plans            | Mid-level grouping               | Below Initiative          |
| Azure DevOps               | Major initiative / goal          | Very top — above Feature  |
| GitHub Issues              | "This is big" (flexible)         | No fixed position         |
| Linear                     | Doesn't use the term             | N/A                       |
| Shortcut                   | Collection of stories for a goal | Middle — below Objective  |


Two camps exist: **Camp 1** (Jira default, original agile, startups) places Epic at the top. **Camp 2** (SAFe, Azure DevOps, Jira Premium) places Epic in the middle with something above it.

## Requirements Analysis: What Do Agents Need?

The agentic SDLC pipeline has four distinct roles for work items:


| Role         | Created by                    | Consumed by                         | What it carries                                                    |
| ------------ | ----------------------------- | ----------------------------------- | ------------------------------------------------------------------ |
| **Intent**   | Product Manager (Human/AI)    | Design and planning phases          | The brief — what we're building, why, requirements, context        |
| **Grouping** | Planning phase                | Orchestration layer, humans (board) | Organisational scope — branch boundary, dispatch wave, review unit |
| **Spec**     | Planning phase                | Execution agents                    | Self-contained micro-spec — everything needed to execute           |
| **Step**     | Execution agent (during work) | Execution agent itself              | Execution checklist — AC checkboxes, implementation notes          |


The bottom level (Step) is informal — checkboxes in the Spec body, not tracked issues. AI agents don't need sub-items on a board.

**Conclusion: Agents need three tracked levels (Intent, Grouping, Spec).** Collapsing Intent + Grouping loses the "one brief spawns multiple work groups" relationship. Collapsing Grouping + Spec loses the organisational structure the orchestration layer depends on (branches, dispatch waves, reviews).

## Alternatives Considered

Eight options were evaluated through multiple rounds of analysis:

### Option A: Epic → Story → Task

- **Mapping:** Best — Jira Default 1:1 with zero configuration
- **Semantics:** Worst — "Story" as organisational glue and "Task" as the richest artifact both violate industry expectations
- **Cross-domain:** Poor — "Story: Design Facebook ad creative" reads awkwardly for non-engineering teams

### Option B: Initiative → Epic → Story

- **Mapping:** Good — Jira Default requires compressing Initiative into Epic; perfect for Jira Premium, Azure, Linear
- **Semantics:** Excellent — every term means what the industry expects
- **Cross-domain:** Moderate — "Initiative" carries enterprise/SAFe connotations; "Story" feels forced for non-engineering work

### Option C: Epic → Feature → Story

- **Mapping:** Decent — Azure native; Jira needs custom type for Feature
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

- **Mapping:** Azure has a semantic inversion (your Feature maps to their Epic, your Epic maps to their Feature)
- **Semantics:** Reads naturally for product work, but "Feature: Migrate to Postgres" and "Feature: Reduce Tech Debt" feel forced
- **Cross-domain:** Poor for technical and non-product work

### Option H: Goal → Epic → Task (selected)

- **Mapping:** Strong — maps to every tool; near-identical to Asana's native Goal → Project → Task
- **Semantics:** Excellent — Goal = intent (universal), Epic = body of work (well-known), Task = actionable unit (universal)
- **Cross-domain:** Best of all options — works for engineering, marketing, product, operations, infrastructure

## Decision Process

### Round 1: Three Levels Confirmed

Analysis showed that collapsing to two levels breaks the dispatch model (branches, waves, reviews depend on the middle layer). Four levels adds bureaucracy without operational benefit for AI agents. Three tracked levels match the sweet spot across the industry (Jira, GitHub, Shortcut all default to three).

### Round 2: Bottom Level — Story vs Task

Story and Task were stress-tested across domains:


| Test                                             | Task wins | Story wins |
| ------------------------------------------------ | --------- | ---------- |
| Cross-domain readability (marketing, ops, infra) | ✓         |            |
| Agent neutrality (no format bias)                | ✓         |            |
| Human communication in engineering teams         |           | ✓          |
| Template weight matching (rich micro-specs)      |           | ✓          |
| Tool mapping breadth (Asana, Monday, Trello)     | ✓         |            |
| Mixed team onboarding                            | ✓         |            |


**Task: 4. Story: 2.** Task won on breadth and universality. Story won on engineering culture fit.

Key insight: the *weight* of a Task is defined by the template, not the name. A marketing team's Task template is simple. An engineering team's Task template is a full micro-spec with design sections and acceptance criteria. Same taxonomy, different templates.

### Round 3: Top Level — Goal vs Initiative vs Feature vs Epic


| Candidate  | Product work      | Technical work | Marketing  | Research   |
| ---------- | ----------------- | -------------- | ---------- | ---------- |
| Goal       | ✓ Natural         | ✓ Natural      | ✓ Natural  | ✓ Natural  |
| Initiative | ✓ Slightly formal | ✓ Natural      | ✓ Formal   | ✓ Natural  |
| Feature    | ✓ Perfect         | ✗ Forced       | ✗ Forced   | ✗ Forced   |
| Epic       | ✓ Natural         | ✓ Natural      | ~ Jargon-y | ~ Jargon-y |


**Goal** was selected because it's the most universally understood term, works across all domains, and is the most natural word for a human starting the pipeline ("my goal is to..."). It avoids the enterprise connotations of "Initiative" and the product-only limitation of "Feature."

### Round 4: Middle Level — Epic Retained

Epic was evaluated against Milestone (time-based, wrong for containers), Workstream (corporate, no tool uses it), Phase (implies sequential), Project (massively overloaded), Module (too technical), Theme (too vague), and Track (no tool support).

**Epic was retained** because it's the one term that signals "structured body of work" while being widely known across PM tools. A marketing person learns one new word. An engineer already knows it.

## Final Decision

### Taxonomy: Goal → Epic → Task


| Level  | Term     | Role                                                               | Created by                 | Consumed by                         |
| ------ | -------- | ------------------------------------------------------------------ | -------------------------- | ----------------------------------- |
| Top    | **Goal** | Product intent — what we're building and why                       | Product Manager (Human/AI) | Design and planning phases          |
| Middle | **Epic** | Work grouping — scope boundary, branch, dispatch wave, review unit | Planning phase             | Orchestration layer, humans (board) |
| Bottom | **Task** | Self-contained micro-spec — everything needed to execute           | Planning phase             | Execution agents                    |


### Definitions

- **Goal:** A concrete deliverable objective. What we're building and why. Contains the brief, requirements, and context. Owned by the Product Manager (Human/AI). Entry point for the agent pipeline. A Goal is *not* an abstract OKR metric — it describes a tangible outcome ("Build Social Login," "Migrate to Postgres," "Q3 Lead Gen Campaign").
- **Epic:** A coherent grouping of related Tasks within a Goal. Defines a scope boundary for branching, dispatch, and review. May represent a sub-feature, a technical domain, or a work phase. Created during the planning phase. Consumed by the orchestration layer and humans for board tracking. An Epic is organisational glue — no execution agent consumes it directly for build instructions.
- **Task:** A self-contained, buildable unit of work. The execution agent's single source of truth. Contains everything needed to execute: context, design guidance, acceptance criteria, branch metadata. One Task = one agent dispatch = one deliverable. The richness of a Task is defined by its template, which varies by team and domain.

### Type Field on Task

Instead of separate hierarchy levels for different work types, a `type` field on Task provides classification:


| Type       | Description                                                                     |
| ---------- | ------------------------------------------------------------------------------- |
| `feature`  | New functionality to implement                                                  |
| `bug`      | Defect or unintended behaviour to fix                                           |
| `refactor` | Code/process improvement, no behaviour change                                   |
| `spike`    | Research or exploration, time-boxed                                             |
| `chore`    | Maintenance work (dependencies, config, CI/CD)                                  |
| `story`    | Optional — for engineering teams that want agile vocabulary on user-facing work |


### PM Tool Mapping


| Your term | Jira Default | Jira Premium | Azure    | GitHub Issues   | Linear     | Asana   | Shortcut  | Trello | Monday |
| --------- | ------------ | ------------ | --------------- | --------------- | ---------- | ------- | --------- | ------ | ------ |
| Goal      | Epic         | Initiative   | Epic            | Issue (Epic)    | Initiative | Goal    | Objective | Board  | Board  |
| Epic      | Story        | Epic         | Feature         | Issue (Feature) | Project    | Project | Epic      | List   | Group  |
| Task      | Sub-task     | Story        | User Story/Task | Issue (Task)    | Issue      | Task    | Story     | Card   | Item   |


### Mapping Strategy

- Map by **semantic role**, not by name matching
- If a tool doesn't support a level (e.g., Trello has no Epic concept), flatten the hierarchy — an Epic becomes a List or labelled Card
- Preserve tool-specific metadata (Jira Story Points, Linear Cycles, Azure Value Area) as extension fields
- Bug placement is configurable per tool — some tools treat Bugs at the Task level, others at the Epic level
- The mapping layer translates transparently — team members see their tool's native terminology

### Minimum Viable Hierarchy

For maximum cross-tool compatibility, the three-level core maps to every tool researched without requiring custom configuration. For tools with only two native levels, compress Goal + Epic into one level. For tools with four+ levels, the extra levels remain unused or map to labels/milestones.

## Stress Test Results

The taxonomy was tested against eight scenarios:


| Scenario                                 | Result          | Convention                                         |
| ---------------------------------------- | --------------- | -------------------------------------------------- |
| Tiny feature (one Task)                  | Holds           | Single-Task Epics are acceptable                   |
| Sprawling migration (40+ Tasks)          | Cracks slightly | Use labels/milestones to link related Goals        |
| Bug promotion (Bug outgrows Task)        | Holds           | Close Task, promote to new Epic or Goal            |
| Cross-cutting concerns (Sentry, logging) | Holds           | Tasks can decompose by domain, not just feature    |
| Task too big mid-work                    | Holds           | Tasks use checklists internally; promote if needed |
| Spike/research                           | Holds           | Spike is a Task with `type: spike`                 |
| Non-engineering work (marketing, ops)    | Holds           | All three terms are domain-neutral                 |
| Multi-tool integration                   | Holds           | Mapping config per tool handles translation        |


## How It Reads in Practice


| Domain         | Goal                         | Epic                     | Task                                    |
| -------------- | ---------------------------- | ------------------------ | --------------------------------------- |
| Product        | Goal: Build Social Login     | Epic: Auth Backend       | Task: Implement Google OAuth callback   |
| Infrastructure | Goal: Set Up CI/CD Pipeline  | Epic: GitHub Actions     | Task: Configure deployment workflow     |
| Bug bash       | Goal: Fix Critical Auth Bugs | Epic: Token Handling     | Task: Fix refresh token race condition  |
| Marketing      | Goal: Q3 Lead Gen Campaign   | Epic: Social Media       | Task: Design Facebook ad creative       |
| Product mgmt   | Goal: Create Q3 Roadmap      | Epic: Customer Research  | Task: Analyse NPS survey results        |
| Tech debt      | Goal: Reduce Auth Tech Debt  | Epic: Session Management | Task: Migrate from JWT to opaque tokens |


## What This Replaces

If migrating from the earlier `Backlog Item → Epic → Story` naming:


| Previous term  | New term | What changed                                                                      |
| -------------- | -------- | --------------------------------------------------------------------------------- |
| Backlog Item   | Goal     | "Backlog" is a container, not an item type. "Goal" describes the role accurately. |
| Epic           | Epic     | No change — same role, same name.                                                 |
| Story          | Task     | "Task" is domain-neutral and universally understood. Template defines richness.   |


The templates, information flow, and agent pipeline remain structurally identical. This is a naming change, not a redesign.