---
date: 2026-03-10
author: carlosboeing
agent: general
status: approved
---

# GitHub Issue Categorization Improvements

## Problem

The NeuralNorris project board mixes backlog items, epics, and stories with no way to visually distinguish or filter by hierarchy level. The only clues are title prefixes (`[Backlog]`, `[#122/E01]`, `[#122/E01-S01]`) and per-instance grouping labels — but the board doesn't support filtering by hierarchy level.

## Solution

Add three static `hierarchy/*` labels for level identification. Keep `backlog/*` as the single workstream grouping label (retire per-epic `epic/*` labels). Delete unused GitHub default labels. Standardize label colors.

## Label Taxonomy (After Changes)

| Category | Labels | Purpose | Created by |
|----------|--------|---------|------------|
| **Hierarchy** (new) | `hierarchy/backlog`, `hierarchy/epic`, `hierarchy/story` | Level identification, board grouping/filtering | `setup-labels.sh` (static) |
| **Backlog** (keep) | `backlog/<issue>-<slug>` | Workstream grouping — single label across all epics and stories in a feature | Planner (per feature) |
| **Type** (keep) | `type/feature`, `type/bug`, `type/refactor`, `type/test`, `type/docs` | Work category | `setup-labels.sh` (static) |
| **Difficulty** (keep) | `difficulty/easy`, `difficulty/medium`, `difficulty/hard` | Model routing (easy→Haiku, medium→Sonnet, hard→Opus) | Planner (per story) |

### Labels Retired

| Category | Reason |
|----------|--------|
| `epic/*` (per-epic labels) | Replaced by `backlog/*` + `hierarchy/epic` + sub-issues. The `backlog/*` label groups all work in a feature; `hierarchy/epic` identifies the level; sub-issues provide parent-child linkage. |
| GitHub defaults (`bug`, `documentation`, `duplicate`, `enhancement`, `good first issue`, `help wanted`, `invalid`, `question`, `wontfix`) | Zero usage across all issues. Superseded by `type/*` labels. |

## Label Colors

| Label | Hex | Visual |
|-------|-----|--------|
| `hierarchy/backlog` | `#6E40C9` | Purple |
| `hierarchy/epic` | `#E36209` | Orange |
| `hierarchy/story` | `#FBCA04` | Yellow |
| All `backlog/*` | `#5319E7` | Deep purple (standardized) |

## Example: How Issues Look After Migration

**Story** (`#138 [#122/E02-S01] DispatchChannel`):
> `hierarchy/story` · `backlog/122-sdlc-self-orchestration` · `type/feature` · `difficulty/easy`

**Epic** (`#132 [#122/E01] Domain Model & Configuration`):
> `hierarchy/epic` · `backlog/122-sdlc-self-orchestration` · `type/feature`

**Backlog item** (`#122 SDLC Self-Orchestration`):
> `hierarchy/backlog` · `type/feature`

## Board Views Unlocked

| View | Filter |
|------|--------|
| Roadmap (backlog items only) | `hierarchy/backlog` |
| Epic overview | `hierarchy/epic` |
| Sprint board (stories only) | `hierarchy/story` |
| Single workstream | `backlog/122-sdlc-self-orchestration` |
| Stories in a workstream | `backlog/122-sdlc-self-orchestration` + `hierarchy/story` |
| Epics in a workstream | `backlog/122-sdlc-self-orchestration` + `hierarchy/epic` |

## Filtering Replacements for Retired `epic/*`

| Before | After |
|--------|-------|
| `gh issue list --label "epic/e01-sdlc-domain"` | Navigate to epic issue → view sub-issues |
| Board filter: `epic/e01-sdlc-domain` | `backlog/122-sdlc` + `hierarchy/story`, then identify parent via sub-issues |

## Migration Scope

1. **Create** 3 `hierarchy/*` labels via `setup-labels.sh`
2. **Apply** `hierarchy/backlog` to all backlog items, `hierarchy/epic` to all epics, `hierarchy/story` to all stories (existing + future)
3. **Standardize** all `backlog/*` label colors to `#5319E7`
4. **Delete** 9 GitHub default labels
5. **Remove** `epic/*` labels from all issues, then delete the labels
6. **Update** `setup-labels.sh` — add `hierarchy/*` labels, document standard `backlog/*` color
7. **Update** `CLAUDE.md` — label conventions, GitHub conventions section
8. **Update** agent `.md` files — planner (creates labels/issues), orchestrator (filters by labels), builder (reads labels)
9. **Update** lesson folder convention if affected by `epic/*` removal

## What's NOT Changing

- Issue title format (`[#122/E01-S01]`) — still useful for human readability
- Sub-issue hierarchy — still the source of truth for parent-child relationships
- `type/*` and `difficulty/*` labels — working well
- Branch naming conventions (`epic/eNN-slug`, story branches)
- `backlog/*` label naming convention (`backlog/<issue>-<slug>`)

## Work Item Hierarchy — Project Management Reference

> This section is tool-agnostic and reusable across projects. It defines the work item structure, how it maps to industry-standard PM practices, and the rules that govern decomposition.

### What Is a Work Item?

A **work item** is any tracked unit of work in the project. Work items are organised into a fixed hierarchy that mirrors how real-world software projects decompose scope: from a high-level capability down to an implementable task.

The term "work item" is used generically across PM tools — Azure DevOps calls them "work items" explicitly, Jira calls them "issues", GitHub calls them "issues", Trello calls them "cards". Regardless of the tool, the concept is the same: a discrete, trackable piece of work with a title, description, status, and owner.

### The Three-Level Hierarchy

All work is organised into exactly **three levels**. This is a hard constraint — no additional levels may be created.

```
Level 1: Backlog Item     ← WHAT to build (business value)
Level 2: Epic             ← HOW to organise the build (technical workstreams)
Level 3: Story            ← HOW to build it (implementable units)
```

#### Level 1 — Backlog Item

**Definition:** A user-facing capability or feature that delivers business value. This is the highest-level unit of work — the thing a stakeholder would recognise and care about.

**Characteristics:**
- Answers the question: "What are we building and why?"
- Has a clear value proposition ("users can manage their calendar from the chat")
- Too large to implement directly — must be decomposed into epics and stories
- Owned by a product owner, designer, or stakeholder
- Lives on the product roadmap
- One backlog item = one complete workflow run (design → plan → build → review → retro)

**Examples:**
- "Calendar integration with Google Calendar"
- "SMS notification system"
- "User authentication with 2FA"

**Heuristic:** If you can ship it to a user and they'd say "oh, that's a new feature" — it's a backlog item.

#### Level 2 — Epic

**Definition:** A technical workstream within a backlog item. Epics group related stories that together deliver one coherent slice of the capability. They represent architectural boundaries, not user-visible features.

**Characteristics:**
- Answers the question: "What are the major technical components?"
- Represents a natural architectural boundary (data layer, API layer, UI layer, integration layer)
- Contains 1-8 stories (fewer is fine — an epic with 1-2 stories is valid)
- Can be worked on in parallel with other epics (if stories have no cross-epic dependencies)
- Defined by an planner or tech lead during planning

**Examples (for a "Calendar integration" backlog item):**
- Epic 1: "Calendar Core Infrastructure" (domain models, config, DB migration)
- Epic 2: "Google Calendar Provider" (OAuth, API client, read/write operations)
- Epic 3: "Calendar Tool Plugin" (chat commands, availability lookup)

**Heuristic:** If it has a distinct technical identity and could be assigned to a different team or developer — it's an epic. If it's just a big story, it's not an epic — break it into smaller stories instead.

#### Level 3 — Story

**Definition:** The smallest plannable unit of work. One implementer, one branch, one PR. A story should be completable in a single working session (typically 1-4 hours of focused work).

**Characteristics:**
- Answers the question: "What specific thing am I building right now?"
- Has clear acceptance criteria (testable, verifiable)
- Results in code that compiles, passes tests, and can be reviewed independently
- Has a single owner (one developer or one AI agent)
- Belongs to exactly one epic

**Examples (for a "Calendar Core Infrastructure" epic):**
- Story 1: "Calendar domain models" (CalendarEvent, CalendarProvider entities)
- Story 2: "CalendarConfig and NNConfig extension"
- Story 3: "OAuthToken EF migration"

**Heuristic:** If you can write a PR title for it and a reviewer could understand the scope from that title — it's a well-sized story. If the PR would touch 15+ files across multiple domains, it's too big — split it.

### Decomposition Rules

1. **Every backlog item decomposes into 1-6 epics.** One epic is fine for simple features. More than 6 suggests the backlog item is too large — split it into multiple backlog items.

2. **Every epic decomposes into 1-8 stories.** One story is fine for simple workstreams. More than 8 suggests the epic is too broad — split it into multiple epics.

3. **Stories do not decompose further.** Implementation steps within a story (write test, implement, refactor) are tracked in the story's acceptance criteria, not as separate work items.

4. **Never create child backlog items.** If a feature feels too large, use more epics with fewer stories each. If it truly spans multiple independent domains, split it into separate backlog items at the design stage — each with its own lifecycle.

5. **Dependency ordering is within epics, not across them.** Stories within an epic have a natural sequence (domain models before API, API before UI). Epics themselves should be as independent as possible to enable parallel execution.

### How They Relate (Concrete Example)

```
Backlog Item: "Calendar Integration"
│
│   Owned by: Product owner / Designer
│   Scope: Users can view, create, and manage calendar events through chat
│   Lifecycle: Design → Plan → Build (3 epics) → Review → Retro
│
├── Epic E01: "Calendar Core Infrastructure"
│   │   Scope: Domain models, configuration, database schema
│   │   Dependencies: None (can start immediately)
│   │
│   ├── Story S01: "Domain models"
│   │   Acceptance: CalendarEvent, CalendarProvider entities with tests
│   │
│   ├── Story S02: "Configuration"
│   │   Acceptance: CalendarConfig section in NNConfig, validated at startup
│   │
│   └── Story S03: "EF migration"
│       Acceptance: Migration creates calendar tables, passes on SQLite
│
├── Epic E02: "Google Calendar Provider"
│   │   Scope: OAuth flow, Google API client, CRUD operations
│   │   Dependencies: E01 (needs domain models and config)
│   │
│   ├── Story S01: "OAuth service"
│   ├── Story S02: "Read operations"
│   └── Story S03: "Write operations"
│
└── Epic E03: "Calendar Tool Plugin"
    │   Scope: Chat tool integration, natural language commands
    │   Dependencies: E01 + E02 (needs provider and domain)
    │
    └── Story S01: "List and get functions"
```

### Lifecycle Mapping

Each level maps to a phase of the software development lifecycle:

| Phase | Who | Work item level | Output |
|-------|-----|-----------------|--------|
| **Discovery** | Stakeholder / Designer | Backlog Item | Problem statement, requirements |
| **Design** | Designer | Backlog Item | Design document, approach trade-offs |
| **Planning** | Planner | Epics + Stories | Implementation plan, dependency graph, difficulty ratings |
| **Implementation** | Builder | Story | Code, tests, PR |
| **Review** | Reviewer | Story / Epic | Review comments, approval |
| **Integration** | Orchestrator | Backlog Item | Merged epic PR(s), changelog |
| **Retrospective** | Retro | Backlog Item | Lessons learned, convention changes |

### Why Exactly Three Levels

**Fewer than three** forces stories to be too large (unplannable) or removes the grouping that makes epics useful for parallel work and progress tracking. Without epics, a 15-story backlog item is a flat list with no structure — you can't tell which stories can be parallelised, which share dependencies, or how far along the feature is.

**More than three** adds compounding complexity:

| Concern | 3 levels | 4+ levels |
|---------|----------|-----------|
| Labels | 3 static `hierarchy/*` labels | Ambiguity: "is this a sub-epic or a big story?" |
| Branches | `epic/eNN-slug` (one level deep) | Nested branch naming, unclear ownership |
| Dispatch | Orchestrator dispatches stories directly | Second level of dispatch management |
| Telemetry | Flat sum per epic | Tree traversal for aggregation |
| Board views | Filter by level + workstream | Combinatorial explosion of filter combinations |
| Agent rules | Unambiguous: 3 types, 3 rules | Gray areas cause wrong decompositions |

**The escape hatch for large scope:** When a feature genuinely spans multiple independent domains (e.g., "build an e-commerce platform" = auth + catalog + cart + payments), the correct response is to split it into multiple backlog items at the design stage. Each gets its own full lifecycle. This handles arbitrary scope without adding hierarchy depth.

### Work Item Status Flow

Work items move through a standard set of statuses during their lifecycle:

```
Backlog → Planned → Todo → In Progress → In Review → Done
```

| Status | Meaning | Applies to |
|--------|---------|------------|
| **Backlog** | Unplanned — idea exists but no design or plan | Backlog items |
| **Planned** | Plan exists but not yet approved | Epics, Stories |
| **Todo** | Plan approved, ready for implementation | Stories |
| **In Progress** | Currently being worked on | Stories, Epics (when any story is in progress) |
| **In Review** | Implementation complete, awaiting review/merge | Stories, Epics (when all stories are in review) |
| **Done** | Merged and closed | All levels |

**Epic status is derived from its stories:**
- Any story In Progress → Epic is In Progress
- All stories In Review → Epic is In Review
- All stories Done → Epic is Done

### Cross-Tool Terminology Mapping

Different PM tools use different names for the same concepts. This table provides the translation layer:

| This workflow | Jira | Azure DevOps | Trello | Linear | GitHub (native) | Shortcut |
|--------------|------|-------------|--------|--------|-----------------|----------|
| Backlog Item | Initiative | Epic | Board | Project | Issue (top-level) | Epic |
| Epic | Epic | Feature | List | — | Issue (mid-level) | — |
| Story | Story / Task | Product Backlog Item / Task | Card | Issue | Issue (leaf) | Story |
| `hierarchy/*` label | Issue Type | Work Item Type | — | — | Issue Type (org only) | Issue Type |
| `backlog/*` label | Initiative link | Area Path | Board membership | Project membership | — | Epic link |
| `type/*` label | Issue Type | Work Item Type | Label | Label | Label | Label |
| `difficulty/*` label | Story Points / T-shirt size | Effort | — | Estimate | — | Estimate |

**Notes on the mapping:**
- **Jira** uses "Initiative" for the top level (above Epic) in Advanced Roadmaps. Standard Jira has Epic as the highest level — treat the Jira Epic as our Backlog Item in that case.
- **Azure DevOps** has a 4th level (Epic → Feature → PBI → Task). Our Backlog Item maps to their Epic, our Epic maps to their Feature, our Story maps to their PBI. Their "Task" level (sub-tasks within a PBI) is not used — implementation steps live in the story's acceptance criteria.
- **Trello** has no hierarchy — boards, lists, and cards are flat. Map Backlog Items to boards, Epics to lists, Stories to cards.
- **Linear** has Projects (our Backlog Item) and Issues (our Story) but no middle tier. Group issues by label or cycle to approximate epics.
- **GitHub** has Issues and sub-issues (arbitrary depth) but no native hierarchy types on personal accounts. Our `hierarchy/*` labels fill this gap.

## Design Decisions

### Why not GitHub Issue Types?

GitHub Issue Types (Task, Bug, Feature) are organization-scoped only. NeuralNorris is on a personal account, so Issue Types are not available. Labels are the universal fallback that also provides cross-tool portability.

### Why keep `backlog/*` but retire `epic/*`?

A single grouping label per workstream is sufficient when combined with `hierarchy/*` for level identification and sub-issues for parent-child relationships. Two tiers of grouping labels (`backlog/*` + `epic/*`) were redundant. The `backlog/*` label was chosen over `epic/*` because it scopes to the entire feature workstream — filtering by workstream + hierarchy level replaces any query that previously used `epic/*`.

### Why not rename `backlog/*` to `sprint/*`?

"Sprint" implies a time-boxed iteration (Scrum), which conflicts with the feature-scoped nature of NeuralNorris workstreams. It would also collide with first-class "Sprint" concepts in Jira, Azure DevOps, and other tools the workflow may integrate with in the future.

### Why exactly three hierarchy levels?

A 4th level (e.g., "tasks" below stories, or "initiatives" above backlog items) was considered and rejected. The planner agent in a prior workflow run created child backlog items under a parent backlog item — effectively introducing a 4th level — which broke dispatch, telemetry, and board tracking.

**The problem with 4 levels:**
- Every additional level multiplies state management: labels, branches, dispatch logic, telemetry aggregation, board status sync
- The boundary between levels becomes ambiguous ("is this a big story or a small epic?")
- Agents need clear, unambiguous rules. Three levels are easy to reason about; four create gray areas.

**The fix for "too big for 3 levels":** Split the feature into multiple independent backlog items at the designer stage. Each backlog item gets its own full lifecycle (design → plan → build → retro). This handles arbitrary scope without adding hierarchy depth.

### Cross-tool portability

Labels are the lowest-common-denominator across GitHub, Jira, Azure DevOps, and Trello. The `hierarchy/*` and `backlog/*` label conventions can be mapped to equivalent constructs in any tool without semantic conflict.
