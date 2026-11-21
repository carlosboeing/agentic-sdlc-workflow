# GitHub Native Implementation — Project Management

## Overview

In the GitHub-native implementation, GitHub Issues serve as the task tracking backend and GitHub Projects provide board-based visualization. The pipeline's epics, user stories, and implementation tasks each map to a GitHub Issue with specific templates, labels, and project board integration. This approach keeps all project management within the same platform as code and documentation, eliminating context switching between tools.

## Issue Templates

Issue templates enforce consistent structure for the three work item types in the pipeline: epics, stories, and tasks. Place these files in the `.github/ISSUE_TEMPLATE/` directory of the repository.

### Epic Template

**`.github/ISSUE_TEMPLATE/epic.yml`**

```yaml
name: Epic
description: A high-level feature or initiative spanning multiple stories and tasks.
title: "[Epic] "
labels: ["type:epic"]
body:
  - type: markdown
    attributes:
      value: |
        ## Epic Definition
        An epic represents a significant feature or initiative. It is produced by the Visionary
        and Architect stages and decomposed into stories and tasks by the Planner stage.

  - type: textarea
    id: description
    attributes:
      label: Description
      description: High-level description of the feature or initiative.
      placeholder: Describe the feature, its scope, and its purpose.
    validations:
      required: true

  - type: textarea
    id: business-value
    attributes:
      label: Business Value
      description: Why this feature matters. Reference the PRFAQ or PRD if available.
      placeholder: |
        - User impact: ...
        - Business impact: ...
        - Source: docs/product/PRD-<feature>.md
    validations:
      required: true

  - type: textarea
    id: success-metrics
    attributes:
      label: Success Metrics
      description: Measurable criteria for determining whether this epic achieved its goals.
      placeholder: |
        - [ ] Metric 1: ...
        - [ ] Metric 2: ...
    validations:
      required: true

  - type: textarea
    id: acceptance-criteria
    attributes:
      label: Acceptance Criteria
      description: Conditions that must be true for this epic to be considered complete.
      placeholder: |
        - [ ] All stories completed and merged
        - [ ] Integration tests passing
        - [ ] Documentation updated
    validations:
      required: true

  - type: textarea
    id: design-docs
    attributes:
      label: Design Documents
      description: Links to associated PRFAQ, PRD, HLD, LLD, and ADRs.
      placeholder: |
        - PRFAQ: docs/product/PRFAQ-<feature>.md
        - PRD: docs/product/PRD-<feature>.md
        - HLD: docs/design/HLD-<feature>.md
        - LLD: docs/design/LLD-<feature>.md
        - ADRs: docs/decisions/ADR-NNN-<title>.md
    validations:
      required: false
```

### Story Template

**`.github/ISSUE_TEMPLATE/story.yml`**

```yaml
name: User Story
description: A user-facing capability that delivers value. Follows the "As a... I want... So that..." format.
title: "As a [persona], I want [action], so that [benefit]"
labels: ["type:story"]
body:
  - type: markdown
    attributes:
      value: |
        ## User Story
        Stories are decomposed from epics by the Planner agent. Each story represents a
        discrete unit of user-facing value with testable acceptance criteria.

  - type: textarea
    id: description
    attributes:
      label: Description
      description: Detailed description of the user story, including context and scope.
      placeholder: Describe the user need, the expected behavior, and any relevant context.
    validations:
      required: true

  - type: textarea
    id: acceptance-criteria
    attributes:
      label: Acceptance Criteria
      description: Specific, testable conditions that must be satisfied for this story to be complete.
      placeholder: |
        - [ ] Given [context], when [action], then [expected result]
        - [ ] Given [context], when [action], then [expected result]
        - [ ] Error case: when [invalid input], then [error handling]
    validations:
      required: true

  - type: input
    id: parent-epic
    attributes:
      label: Parent Epic
      description: "Reference to the parent epic issue (e.g., #42)."
      placeholder: "#"
    validations:
      required: true

  - type: textarea
    id: design-refs
    attributes:
      label: Design References
      description: Specific sections of design documents that inform this story.
      placeholder: |
        - PRD Section 3.2: Subscription Creation
        - HLD Component: Billing Service
        - LLD API: POST /api/billing/create-subscription
    validations:
      required: false

  - type: dropdown
    id: priority
    attributes:
      label: Priority
      options:
        - critical
        - high
        - medium
        - low
    validations:
      required: true
```

### Task Template

**`.github/ISSUE_TEMPLATE/task.yml`**

```yaml
name: Implementation Task
description: A concrete, implementable unit of work derived from a user story. Max 2-hour scope.
title: "[Task] "
labels: ["type:task"]
body:
  - type: markdown
    attributes:
      value: |
        ## Implementation Task
        Tasks are the atomic units of work assigned to Builder agents. Each task should be
        completable within approximately 2 hours and produce a single, reviewable branch.

  - type: textarea
    id: objective
    attributes:
      label: Objective
      description: Clear, concise statement of what this task must accomplish.
      placeholder: Create POST /api/billing/create-subscription endpoint.
    validations:
      required: true

  - type: textarea
    id: source-documents
    attributes:
      label: Source Documents
      description: References to PRD, HLD, LLD, and ADR sections that define the requirements and design for this task.
      placeholder: |
        - PRD: docs/product/PRD-<feature>.md (Section 3.2: Subscription Creation)
        - HLD: docs/design/HLD-<feature>.md (Component: Billing Service)
        - LLD: docs/design/LLD-<feature>.md (API: POST /api/billing/create-subscription)
        - ADR: docs/decisions/ADR-001-<title>.md
    validations:
      required: true

  - type: textarea
    id: files
    attributes:
      label: Files to Create/Modify
      description: List of files the Builder agent should create or modify. This informs context loading.
      placeholder: |
        - Create: `src/api/billing/create-subscription.ts`
        - Modify: `prisma/schema.prisma` (add Subscription model)
        - Modify: `src/lib/stripe.ts` (add createSubscription method)
    validations:
      required: true

  - type: textarea
    id: acceptance-criteria
    attributes:
      label: Acceptance Criteria
      description: Specific, testable conditions for task completion.
      placeholder: |
        - [ ] Endpoint accepts { priceId, customerId } body
        - [ ] Input validated with Zod schema
        - [ ] Returns { subscriptionId, clientSecret } on success
        - [ ] Returns 400 on invalid input, 500 on Stripe error
        - [ ] Unit tests for happy path and error cases
        - [ ] CHANGELOG.md updated
    validations:
      required: true

  - type: textarea
    id: dependencies
    attributes:
      label: Dependencies
      description: "Other tasks that must complete before this task can begin (e.g., #43, #44)."
      placeholder: |
        - #43 (Billing API base setup)
        - None (Wave 1 — parallelizable)
    validations:
      required: false

  - type: textarea
    id: test-strategy
    attributes:
      label: Test Strategy
      description: How this task should be tested. Informs the Tester agent.
      placeholder: |
        - Unit tests: mock Stripe client, test request validation, test error handling
        - Integration tests: use Stripe test mode, verify subscription creation
    validations:
      required: true

  - type: input
    id: parent-story
    attributes:
      label: Parent Story
      description: "Reference to the parent story issue (e.g., #45)."
      placeholder: "#"
    validations:
      required: true

  - type: dropdown
    id: priority
    attributes:
      label: Priority
      options:
        - critical
        - high
        - medium
        - low
    validations:
      required: true
```

## Label Taxonomy

Labels encode pipeline stage, work item type, source, and priority. Run the following commands to create the full taxonomy:

```bash
# Pipeline stage labels
gh label create "pipeline:visionary" --color "7057ff" --description "Visionary stage"
gh label create "pipeline:architect" --color "0075ca" --description "Architect stage"
gh label create "pipeline:planner" --color "008672" --description "Planner stage"
gh label create "pipeline:builder" --color "e4e669" --description "Builder stage"
gh label create "pipeline:tester" --color "d876e3" --description "Tester stage"
gh label create "pipeline:reviewer" --color "b60205" --description "Reviewer stage"

# Type labels
gh label create "type:epic" --color "3E4B9E" --description "Epic-level issue"
gh label create "type:story" --color "5319E7" --description "User story"
gh label create "type:task" --color "1D76DB" --description "Implementation task"

# Source labels
gh label create "agent-generated" --color "FBCA04" --description "Created by pipeline agent"

# Priority labels
gh label create "priority:critical" --color "B60205" --description "Critical priority"
gh label create "priority:high" --color "D93F0B" --description "High priority"
gh label create "priority:medium" --color "FBCA04" --description "Medium priority"
gh label create "priority:low" --color "0E8A16" --description "Low priority"

# Document review labels
gh label create "doc-review" --color "BFD4F2" --description "Document review requested"

# Workflow trigger labels
gh label create "ai-design" --color "C5DEF5" --description "Trigger AI design workflow"
gh label create "ai-plan" --color "C5DEF5" --description "Trigger AI planning workflow"
gh label create "ai-implement" --color "C5DEF5" --description "Trigger AI implementation workflow"
```

### Label Usage by Pipeline Stage

| Pipeline Stage | Applied Labels | Purpose |
|---|---|---|
| Visionary | `pipeline:visionary`, `type:epic` | Marks the epic as being in product definition |
| Architect | `pipeline:architect` | Marks the epic as being in technical design |
| Planner | `pipeline:planner`, `type:story`, `type:task` | Stories and tasks created with type labels |
| Builder | `pipeline:builder` | Tasks move to builder stage when implementation begins |
| Tester | `pipeline:tester` | Tasks move to tester stage during test authoring |
| Reviewer | `pipeline:reviewer` | Tasks move to reviewer stage during code review |

## GitHub Projects Board

### Board Configuration

Create a GitHub Projects (v2) board to visualize pipeline progress:

```bash
# Create the project board
gh project create --owner <OWNER> --title "SDLC Pipeline" --format board

# Note the project number from the output (e.g., 1)
PROJECT_NUM=1
```

### Column (Status Field) Configuration

Configure the board's status field with columns that map to pipeline stages:

| Column | Description | Entry Criteria |
|---|---|---|
| **Backlog** | Unstarted work items | Default for new issues |
| **Product Design** | Visionary stage active | `pipeline:visionary` label applied |
| **Tech Design** | Architect stage active | `pipeline:architect` label applied |
| **Planning** | Planner stage active | `pipeline:planner` label applied |
| **In Progress** | Builder stage active | `pipeline:builder` label applied |
| **Testing** | Tester stage active | `pipeline:tester` label applied |
| **Review** | Reviewer stage active | `pipeline:reviewer` label applied |
| **Done** | Merged and complete | Issue closed |

To configure columns, use the GitHub Projects web UI (Settings > Status field > add/rename options) or the GraphQL API:

```bash
# List project fields to find the Status field ID
gh project field-list $PROJECT_NUM --owner <OWNER> --format json

# Add status options via the web UI:
# Project Settings > Status > Add: "Product Design", "Tech Design", "Planning", "In Progress", "Testing", "Review"
```

### Automation Rules

GitHub Projects supports built-in automation for moving items between columns. Configure the following rules via the project's Workflows settings (Project Settings > Workflows):

| Trigger | Action |
|---|---|
| Item added to project | Set status to **Backlog** |
| Issue closed | Set status to **Done** |
| Pull request merged | Set status to **Done** |

For label-based automation (moving issues between columns when pipeline stage labels change), use a GitHub Actions workflow:

```yaml
# .github/workflows/project-automation.yml
name: Project Board Automation
on:
  issues:
    types: [labeled]

jobs:
  move-card:
    runs-on: ubuntu-latest
    steps:
      - name: Move issue on project board
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const label = context.payload.label.name;
            const statusMap = {
              'pipeline:visionary': 'Product Design',
              'pipeline:architect': 'Tech Design',
              'pipeline:planner': 'Planning',
              'pipeline:builder': 'In Progress',
              'pipeline:tester': 'Testing',
              'pipeline:reviewer': 'Review'
            };

            const status = statusMap[label];
            if (!status) return;

            // Use GitHub Projects GraphQL API to update the item status
            // Replace PROJECT_ID and FIELD_ID with actual values
            console.log(`Would move issue #${context.payload.issue.number} to ${status}`);
```

## Milestones

Use GitHub Milestones to group all work items belonging to a single feature or epic. Each epic maps to one milestone.

```bash
# Create a milestone for a feature
gh api repos/{owner}/{repo}/milestones \
  --method POST \
  --field title="Stripe Billing Integration" \
  --field description="All stories and tasks for the Stripe billing feature. Epic: #42" \
  --field due_on="2026-04-15T00:00:00Z"
```

When the Planner agent creates stories and tasks, it assigns them to the corresponding milestone:

```bash
gh issue create \
  --title "[Task] Create billing API endpoint" \
  --body "..." \
  --label "type:task,pipeline:planner" \
  --milestone "Stripe Billing Integration"
```

Milestones provide a progress percentage (open vs. closed issues) that serves as a lightweight progress tracker for the epic.

## MCP Tool Mapping

The core design documents define abstract project management tool interfaces. In the GitHub-native implementation, these map to the GitHub MCP server and the `gh` CLI.

| Abstract Tool | GitHub MCP Tool | `gh` CLI Equivalent |
|---|---|---|
| `mcp__pm__create_issue` | `mcp__github__create_issue` | `gh issue create` |
| `mcp__pm__update_issue` | `mcp__github__update_issue` | `gh issue edit` |
| `mcp__pm__list_tasks` | `mcp__github__list_issues` (with label filter) | `gh issue list --label` |
| `mcp__pm__add_comment` | `mcp__github__add_issue_comment` | `gh issue comment` |
| `mcp__pm__search_issues` | `mcp__github__search_issues` | `gh issue list --search` |

### Usage in Agent Prompts

Agents reference the GitHub MCP tools directly. For example, the Planner agent's `allowedTools` include:

```
mcp__github__create_issue
mcp__github__update_issue
mcp__github__list_issues
mcp__github__add_issue_comment
mcp__github__search_issues
```

The Builder agent's `allowedTools` include only status-update tools:

```
mcp__github__update_issue
mcp__github__add_issue_comment
```

## Issue Hierarchy and Cross-Referencing

GitHub Issues does not have native parent-child relationships. The pipeline uses conventions to establish hierarchy:

### Epic to Story

- Each story's body includes a "Parent Epic" field referencing the epic issue number (e.g., `Parent Epic: #42`).
- The epic's body includes a task list linking to all child stories:
  ```markdown
  ## Stories
  - [ ] #43 As a user, I can subscribe to a plan
  - [ ] #44 As a user, I can cancel my subscription
  - [ ] #45 As an admin, I can view subscription analytics
  ```

### Story to Task

- Each task's body includes a "Parent Story" field referencing the story issue number (e.g., `Parent Story: #45`).
- The story's body includes a task list linking to all child tasks:
  ```markdown
  ## Tasks
  - [ ] #46 [Task] Create billing API endpoint
  - [ ] #47 [Task] Add Stripe webhook handler
  - [ ] #48 [Task] Build subscription UI component
  ```

### Cross-Reference Conventions

- Reference design documents by relative path: `docs/design/HLD-stripe-billing.md`
- Reference other issues by number: `#42`, `#43`
- Reference PRs by number: `PR #55`
- Reference task specs by path: `.claude/context/tasks/001-billing-api.md`

These conventions are enforced by the issue templates and the Planner agent's prompt, not by GitHub's type system. Human reviewers should verify cross-references during the planning checkpoint.
