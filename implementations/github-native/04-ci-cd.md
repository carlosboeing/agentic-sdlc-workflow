# GitHub Native Implementation — CI/CD

## Overview

This document defines the GitHub Actions configuration for automating pipeline stages using `anthropics/claude-code-action@v1`. The CI/CD layer provides three capabilities: label-triggered workflows that invoke pipeline agents on demand, environment-based approval gates that enforce human review between stages, and PR automation that labels, assigns, and validates agent-generated pull requests.

## Branch Strategy

All agent work occurs on branches. No agent has write access to `main`.

| Branch Pattern | Purpose | Created By | Merges Into |
|---|---|---|---|
| `main` | Protected trunk. Requires PR + CI green + human approval. | — | — |
| `docs/<feature-name>` | Document branches for PRFAQ, PRD, HLD, LLD, ADRs. | Visionary, Architect agents | `main` via PR |
| `feat/<task-id>-<description>` | Implementation branches. One per task. | Builder agent | `main` via PR |
| `test/<task-id>-<description>` | Test branches (if tests are authored on separate branches). | Tester agent | Corresponding `feat/` branch |
| `integration/<feature>` | Temporary branch for cross-task integration testing. | Reviewer agent | Deleted after verification |

### Branch Protection Rules

Configure `main` with the following protections:

- Require pull request before merging (no direct pushes)
- Require at least 1 approving review
- Require status checks to pass (CI workflow)
- Require branches to be up to date before merging
- Do not allow bypassing the above settings

## Secrets Configuration

Store the following secrets in the repository (Settings > Secrets and variables > Actions):

| Secret | Purpose |
|---|---|
| `ANTHROPIC_API_KEY` | Claude API authentication for `claude-code-action` |
| `GITHUB_PAT` | GitHub API access for MCP server (if default `GITHUB_TOKEN` lacks sufficient scope) |

The default `GITHUB_TOKEN` provided by GitHub Actions has sufficient permissions for most operations (issues, PRs, labels). A PAT is required only if the workflow needs to access GitHub Projects or cross-repository resources.

## Label-Triggered Workflows

Each pipeline stage is triggered by applying a specific label to a GitHub Issue. This design allows humans to control when each stage runs by simply adding a label, and the issue body provides the context (feature description, document references) that the agent needs.

### Design Workflow

**`.github/workflows/ai-design.yml`**

Triggered by the `ai-design` label on an issue. Invokes the Architect agent to produce HLD, LLD, and ADRs based on the issue body and any referenced product documents.

```yaml
name: AI Design
on:
  issues:
    types: [labeled]

jobs:
  design:
    if: github.event.label.name == 'ai-design'
    runs-on: ubuntu-latest
    environment: design-review
    timeout-minutes: 30

    permissions:
      contents: write
      issues: write
      pull-requests: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run Architect agent
        uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          allowed_tools: "Read,Write,Edit,Bash,Grep,Glob"
          max_turns: 30
          prompt: |
            You are the Architect agent. Read the issue below and produce technical design documents.

            Issue #${{ github.event.issue.number }}: ${{ github.event.issue.title }}
            Body: ${{ github.event.issue.body }}

            Instructions:
            1. Read all product documents referenced in the issue body (docs/product/).
            2. Search existing ADRs in docs/decisions/ for relevant prior decisions.
            3. Explore the codebase to understand current architecture and constraints.
            4. Load templates from .claude/templates/ and produce:
               - HLD: docs/design/HLD-<feature>.md
               - LLD: docs/design/LLD-<feature>.md
               - ADRs: docs/decisions/ADR-NNN-<title>.md (one per significant decision)
            5. Create a branch named docs/<feature-name>.
            6. Commit all documents with conventional commit messages.
            7. Open a PR with label "doc-review" and reference issue #${{ github.event.issue.number }}.
            8. Comment on issue #${{ github.event.issue.number }} with links to the created documents.

      - name: Remove trigger label
        if: always()
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.removeLabel({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: ${{ github.event.issue.number }},
              name: 'ai-design'
            });
```

### Planning Workflow

**`.github/workflows/ai-plan.yml`**

Triggered by the `ai-plan` label on an issue. Invokes the Planner agent to create the task breakdown — epics, stories, tasks, and dependency DAG.

```yaml
name: AI Plan
on:
  issues:
    types: [labeled]

jobs:
  plan:
    if: github.event.label.name == 'ai-plan'
    runs-on: ubuntu-latest
    environment: plan-review
    timeout-minutes: 30

    permissions:
      contents: write
      issues: write
      pull-requests: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run Planner agent
        uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          allowed_tools: "Read,Write,Edit,Bash,Grep,Glob"
          max_turns: 30
          prompt: |
            You are the Planner agent. Read the issue below and create an engineering plan.

            Issue #${{ github.event.issue.number }}: ${{ github.event.issue.title }}
            Body: ${{ github.event.issue.body }}

            Instructions:
            1. Read all design documents referenced in the issue body:
               - HLD, LLD from docs/design/
               - ADRs from docs/decisions/
               - PRD requirements section from docs/product/
            2. Explore the codebase to validate the design against current code structure.
            3. Create user stories as GitHub Issues using the story template.
               - Each story references the parent epic (issue #${{ github.event.issue.number }}).
               - Apply labels: type:story, pipeline:planner, agent-generated.
            4. For each story, create implementation tasks as GitHub Issues using the task template.
               - Apply labels: type:task, pipeline:planner, agent-generated.
               - Include: objective, source document references, files to create/modify,
                 acceptance criteria, dependencies (other task issue numbers), test strategy.
            5. Write task spec files to .claude/context/tasks/<NNN>-<short-name>.md.
            6. Build a dependency DAG and write it to .claude/context/task-manifest.json.
            7. Update the epic issue body with links to all created stories and tasks.
            8. Comment on issue #${{ github.event.issue.number }} with a summary of the plan.

      - name: Remove trigger label
        if: always()
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.removeLabel({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: ${{ github.event.issue.number }},
              name: 'ai-plan'
            });
```

### Implementation Workflow

**`.github/workflows/ai-implement.yml`**

Triggered by the `ai-implement` label on a task issue. Invokes the Builder agent to implement the task described in the issue body and referenced task spec file.

```yaml
name: AI Implement
on:
  issues:
    types: [labeled]

jobs:
  implement:
    if: github.event.label.name == 'ai-implement'
    runs-on: ubuntu-latest
    environment: implementation-review
    timeout-minutes: 45

    permissions:
      contents: write
      issues: write
      pull-requests: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run Builder agent
        uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          allowed_tools: "Read,Write,Edit,Bash,Grep,Glob"
          max_turns: 30
          prompt: |
            You are the Builder agent. Implement the task described in the issue below.

            Issue #${{ github.event.issue.number }}: ${{ github.event.issue.title }}
            Body: ${{ github.event.issue.body }}

            Instructions:
            1. Read your task spec from the path referenced in the issue body
               (e.g., .claude/context/tasks/NNN-<name>.md).
            2. If the task spec references HLD/LLD sections, read those sections and follow
               the design decisions exactly.
            3. Create a feature branch: feat/${{ github.event.issue.number }}-<short-description>.
            4. Implement the task incrementally, committing after each logical unit.
            5. Run lint and tests after each change. Fix issues before proceeding.
            6. After implementation, update:
               - CHANGELOG.md (add entry under [Unreleased])
               - Any relevant documentation
            7. Open a PR that references issue #${{ github.event.issue.number }}.
               Apply labels: agent-generated, pipeline:builder.
            8. Comment on the issue with the PR link and a summary of changes.

            Rules:
            - Never modify files outside the scope defined in the task spec.
            - Use Conventional Commits referencing the task issue number.
            - Do not merge the PR — it requires human review.

      - name: Remove trigger label
        if: always()
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.removeLabel({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: ${{ github.event.issue.number }},
              name: 'ai-implement'
            });
```

## Environment-Based Approval Gates

GitHub Environments provide human approval gates between pipeline stages. Each environment requires designated reviewers to approve before the associated workflow job executes.

### Environment Configuration

Create three environments in the repository (Settings > Environments):

| Environment | Required Reviewers | Purpose |
|---|---|---|
| `design-review` | 1+ team member | Approve before Architect agent runs |
| `plan-review` | 1+ team member | Approve before Planner agent runs |
| `implementation-review` | 1+ team member | Approve before Builder agent runs |

When a workflow job references an `environment:`, GitHub pauses execution and notifies the required reviewers. The job proceeds only after explicit approval.

### Reviewer Assignment

Assign reviewers based on role:

- **`design-review`**: Tech leads, staff engineers, or architects who can evaluate design documents.
- **`plan-review`**: Tech leads or engineering managers who can evaluate task breakdowns and scope estimates.
- **`implementation-review`**: Any engineer who can validate that the task spec is well-defined before agent execution.

## PR Automation

### Auto-Labeling Agent PRs

Apply the `agent-generated` label to all PRs created from agent branches:

**`.github/workflows/pr-labeler.yml`**

```yaml
name: PR Labeler
on:
  pull_request:
    types: [opened]

jobs:
  label:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
    steps:
      - name: Label agent-generated PRs
        uses: actions/github-script@v7
        with:
          script: |
            const branch = context.payload.pull_request.head.ref;
            const labels = [];

            // Label PRs from agent branches
            if (branch.startsWith('feat/') || branch.startsWith('docs/')) {
              // Check if PR body contains agent indicators
              const body = context.payload.pull_request.body || '';
              if (body.includes('agent-generated') || body.includes('Claude') || body.includes('pipeline')) {
                labels.push('agent-generated');
              }
            }

            // Label by branch type
            if (branch.startsWith('docs/')) {
              labels.push('doc-review');
            }

            if (labels.length > 0) {
              await github.rest.issues.addLabels({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.payload.pull_request.number,
                labels: labels
              });
            }
```

### Auto-Assigning Reviewers

Assign reviewers to PRs based on changed file paths using a `CODEOWNERS` file:

**`CODEOWNERS`**

```
# Design documents require tech lead review
docs/design/          @your-org/tech-leads
docs/decisions/       @your-org/tech-leads

# Product documents require product owner review
docs/product/         @your-org/product-owners

# Source code requires engineering review
src/                  @your-org/engineers
lib/                  @your-org/engineers

# Infrastructure and CI changes require devops review
.github/              @your-org/devops
```

### Required Status Checks

Configure the following status checks as required for PR merges (Settings > Branches > Branch protection rules > Require status checks):

- **CI** — Lint, type check, unit tests, integration tests
- **Security** — SAST scan (e.g., CodeQL, Semgrep)
- **Docs** — Markdown lint, broken link check (for doc PRs)

## Full Pipeline Workflow

For teams that want to run the entire pipeline as a single, gated workflow rather than individual label-triggered workflows, the following chained workflow provides all six stages with manual approval between each.

**`.github/workflows/ai-full-pipeline.yml`**

```yaml
name: AI Full Pipeline
on:
  workflow_dispatch:
    inputs:
      feature_description:
        description: "High-level feature description"
        required: true
        type: string
      feature_slug:
        description: "Kebab-case feature identifier (e.g., stripe-billing)"
        required: true
        type: string
      entry_point:
        description: "Pipeline entry point"
        required: true
        type: choice
        options:
          - full
          - design
          - plan
          - build
      epic_issue:
        description: "Existing epic issue number (required for design/plan/build entry)"
        required: false
        type: string

jobs:
  # ── Stage 1: Visionary ──────────────────────────────────────────────
  visionary:
    if: inputs.entry_point == 'full'
    runs-on: ubuntu-latest
    timeout-minutes: 30
    permissions:
      contents: write
      issues: write
    outputs:
      epic_issue: ${{ steps.visionary.outputs.epic_issue }}
    steps:
      - uses: actions/checkout@v4
      - name: Run Visionary agent
        id: visionary
        uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          allowed_tools: "Read,Write,Edit,Bash,Grep,Glob"
          max_turns: 25
          prompt: |
            You are the Visionary agent. Feature: "${{ inputs.feature_description }}"
            Slug: ${{ inputs.feature_slug }}

            1. Research the feature — understand the problem space and user needs.
            2. Load templates from .claude/templates/ and produce:
               - docs/product/PRFAQ-${{ inputs.feature_slug }}.md
               - docs/product/PRD-${{ inputs.feature_slug }}.md
               - docs/product/vision-${{ inputs.feature_slug }}.md
            3. Create a GitHub Issue as the epic for this feature.
               Title: "[Epic] ${{ inputs.feature_description }}"
               Labels: type:epic, pipeline:visionary, agent-generated
            4. Create branch docs/${{ inputs.feature_slug }}, commit documents, open PR.
            5. Output the epic issue number.

  # ── Gate: Approve product docs ──────────────────────────────────────
  approve-product-docs:
    if: inputs.entry_point == 'full'
    needs: visionary
    runs-on: ubuntu-latest
    environment: design-review
    steps:
      - run: echo "Product documents approved. Proceeding to Architect stage."

  # ── Stage 2: Architect ──────────────────────────────────────────────
  architect:
    if: inputs.entry_point == 'full' || inputs.entry_point == 'design'
    needs: [approve-product-docs]
    runs-on: ubuntu-latest
    timeout-minutes: 30
    permissions:
      contents: write
      issues: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
        with:
          ref: main
      - name: Run Architect agent
        uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          allowed_tools: "Read,Write,Edit,Bash,Grep,Glob"
          max_turns: 40
          prompt: |
            You are the Architect agent.
            Feature: "${{ inputs.feature_description }}"
            Slug: ${{ inputs.feature_slug }}
            Epic Issue: #${{ needs.visionary.outputs.epic_issue || inputs.epic_issue }}

            1. Read product docs: docs/product/PRFAQ-${{ inputs.feature_slug }}.md,
               docs/product/PRD-${{ inputs.feature_slug }}.md,
               docs/product/vision-${{ inputs.feature_slug }}.md
            2. Search existing ADRs in docs/decisions/.
            3. Explore codebase for architecture and constraints.
            4. Load templates and produce HLD, LLD, and ADRs.
            5. Create branch docs/${{ inputs.feature_slug }}-design, commit, open PR.
            6. Comment on the epic issue with design document links.

  # ── Gate: Approve design docs ───────────────────────────────────────
  approve-design-docs:
    if: inputs.entry_point == 'full' || inputs.entry_point == 'design'
    needs: architect
    runs-on: ubuntu-latest
    environment: plan-review
    steps:
      - run: echo "Design documents approved. Proceeding to Planner stage."

  # ── Stage 3: Planner ───────────────────────────────────────────────
  planner:
    if: inputs.entry_point != 'build'
    needs: [approve-design-docs]
    runs-on: ubuntu-latest
    timeout-minutes: 30
    permissions:
      contents: write
      issues: write
    steps:
      - uses: actions/checkout@v4
        with:
          ref: main
      - name: Run Planner agent
        uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          allowed_tools: "Read,Write,Edit,Bash,Grep,Glob"
          max_turns: 40
          prompt: |
            You are the Planner agent.
            Feature: "${{ inputs.feature_description }}"
            Slug: ${{ inputs.feature_slug }}
            Epic Issue: #${{ needs.visionary.outputs.epic_issue || inputs.epic_issue }}

            1. Read design docs: HLD, LLD, ADRs from docs/design/ and docs/decisions/.
            2. Read PRD requirements from docs/product/PRD-${{ inputs.feature_slug }}.md.
            3. Create stories and tasks as GitHub Issues with proper templates and labels.
            4. Write task specs to .claude/context/tasks/.
            5. Build dependency DAG in .claude/context/task-manifest.json.
            6. Commit task specs and manifest, open PR.
            7. Comment on epic issue with the full plan summary.

  # ── Gate: Approve plan ──────────────────────────────────────────────
  approve-plan:
    if: inputs.entry_point != 'build'
    needs: planner
    runs-on: ubuntu-latest
    environment: implementation-review
    steps:
      - run: echo "Plan approved. Proceeding to Builder stage."

  # ── Stage 4: Builder (per-task, sequential for simplicity) ─────────
  builder:
    needs: [approve-plan]
    runs-on: ubuntu-latest
    timeout-minutes: 45
    permissions:
      contents: write
      issues: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
        with:
          ref: main
      - name: Run Builder agent
        uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          allowed_tools: "Read,Write,Edit,Bash,Grep,Glob"
          max_turns: 30
          prompt: |
            You are the Builder agent.
            Feature: "${{ inputs.feature_description }}"

            1. Read .claude/context/task-manifest.json for the task DAG.
            2. For each task in dependency order:
               a. Read the task spec from .claude/context/tasks/.
               b. Create branch feat/<task-number>-<short-name>.
               c. Implement the task following the spec exactly.
               d. Run lint and tests. Fix any issues.
               e. Commit with conventional commits.
               f. Open a PR referencing the task issue.
            3. After all tasks, comment on the epic issue with PR links.

  # ── Stage 5: Tester ────────────────────────────────────────────────
  tester:
    needs: builder
    runs-on: ubuntu-latest
    timeout-minutes: 30
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
        with:
          ref: main
      - name: Run Tester agent
        uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          allowed_tools: "Read,Write,Edit,Bash,Grep,Glob"
          max_turns: 30
          prompt: |
            You are the Tester agent.

            1. Read .claude/context/task-manifest.json for the list of tasks.
            2. For each task's feature branch:
               a. Checkout the branch.
               b. Read the task spec for acceptance criteria and test strategy.
               c. Write comprehensive unit and integration tests.
               d. Run the full test suite. Iterate until all tests pass.
               e. Commit tests to the feature branch.
            3. Comment on each task's PR with test results.

  # ── Stage 6: Reviewer ──────────────────────────────────────────────
  reviewer:
    needs: tester
    runs-on: ubuntu-latest
    timeout-minutes: 30
    permissions:
      contents: read
      issues: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
        with:
          ref: main
      - name: Run Reviewer agent
        uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          allowed_tools: "Read,Bash,Grep,Glob"
          max_turns: 20
          prompt: |
            You are the Reviewer agent.

            1. Read HLD, LLD, and ADRs from docs/design/ and docs/decisions/.
            2. For each open PR with the agent-generated label:
               a. Review the diff for architecture alignment with design docs.
               b. Check code quality, security (OWASP Top 10), conventions.
               c. Check that tests cover acceptance criteria.
               d. Post review comments on the PR.
            3. Create a temporary integration branch, merge all feature branches,
               run the full test suite. Report cross-branch conflicts or failures.
            4. Comment on the epic issue with the review summary and integration results.
            5. For each PR, submit a review: APPROVE or REQUEST_CHANGES.
```

## Workflow Execution

### Label-Triggered (Recommended for Most Teams)

1. Create an epic issue describing the feature.
2. Apply `ai-design` label to trigger the Architect workflow.
3. Review and merge the design document PR.
4. Apply `ai-plan` label to trigger the Planner workflow.
5. Review the created stories and tasks.
6. Apply `ai-implement` label to individual task issues to trigger implementation.
7. Review and merge implementation PRs.

### Full Pipeline (Manual Dispatch)

1. Navigate to Actions > AI Full Pipeline > Run workflow.
2. Enter the feature description, slug, and entry point.
3. Approve each gate as the pipeline progresses through environments.
4. Review and merge the final PRs.

## Cost Considerations

Each workflow job that invokes `claude-code-action` consumes Claude API tokens. Monitor costs via:

- Anthropic Usage Dashboard for API token consumption
- GitHub Actions usage for runner minutes
- Pipeline run manifests in `.claude/context/runs/` for per-stage cost tracking

Set `max_turns` conservatively (25-40) to bound per-job costs. The full pipeline workflow running all six stages typically consumes 200K-400K tokens total, depending on codebase size and feature complexity.
