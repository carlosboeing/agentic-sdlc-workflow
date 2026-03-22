---
date: 2026-03-08
author: carlosboeing
agent: general
status: approved
---

# Agentic SDLC Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Set up a four-agent SDLC workflow with GitHub Issues integration, helper scripts, numbered docs structure, and updated project conventions.

**Architecture:** Four agent definitions in `.claude/agents/` (designer, planner, builder, reviewer), bash helper scripts in `scripts/`, numbered SDLC doc phases, CLAUDE.md workflow section, and Sentinel workflow update.

**Tech Stack:** Bash (helper scripts), GitHub CLI (`gh`), Markdown (agent definitions), GitHub Actions (Sentinel)

---

### Task 1: Create numbered docs directories

**Files:**
- Create: `docs/1-discovery/.gitkeep`
- Create: `docs/4-reviews/.gitkeep`
- Create: `docs/5-guides/.gitkeep`
- Create: `docs/6-adrs/.gitkeep`

Note: `docs/2-design/` and `docs/3-plans/` already exist (created during brainstorming).

**Step 1: Create the directories with .gitkeep files**

```bash
mkdir -p docs/1-discovery docs/4-reviews docs/5-guides docs/6-adrs
touch docs/1-discovery/.gitkeep docs/4-reviews/.gitkeep docs/5-guides/.gitkeep docs/6-adrs/.gitkeep
```

**Step 2: Commit**

```bash
git add docs/1-discovery/.gitkeep docs/4-reviews/.gitkeep docs/5-guides/.gitkeep docs/6-adrs/.gitkeep
git commit -m "chore: create numbered SDLC docs directories"
```

---

### Task 2: Migrate existing docs to numbered structure

**Files:**
- Move: `docs/VISION.md` → `docs/1-discovery/VISION.md`
- Move: `docs/designs/agent-orchestration.md` → `docs/2-design/agent-orchestration.md`
- Move: `docs/designs/self-aware-norris.md` → `docs/2-design/self-aware-norris.md`
- Move: `docs/plans/2026-03-07-agent-orchestration.md` → `docs/3-plans/2026-03-07-agent-orchestration.md`
- Move: `docs/plans/2026-03-08-self-aware-norris.md` → `docs/3-plans/2026-03-08-self-aware-norris.md`
- Move: `docs/PROJECT.md` → `docs/5-guides/PROJECT.md`
- Remove: `docs/designs/` (empty after move)
- Remove: `docs/plans/` (empty after move — note: new plans already in `docs/3-plans/`)

`docs/CHANGELOG.md` stays at `docs/CHANGELOG.md`.
`docs/BACKLOG.md` stays for now — will be retired after GitHub Issues are populated.

**Step 1: Move files**

```bash
mv docs/VISION.md docs/1-discovery/VISION.md
mv docs/designs/agent-orchestration.md docs/2-design/agent-orchestration.md
mv docs/designs/self-aware-norris.md docs/2-design/self-aware-norris.md
mv docs/plans/2026-03-07-agent-orchestration.md docs/3-plans/2026-03-07-agent-orchestration.md
mv docs/plans/2026-03-08-self-aware-norris.md docs/3-plans/2026-03-08-self-aware-norris.md
mv docs/PROJECT.md docs/5-guides/PROJECT.md
rmdir docs/designs docs/plans
```

**Step 2: Verify no broken references**

Search for old paths in CLAUDE.md and other docs:

```bash
grep -r "docs/designs/" . --include="*.md" | grep -v node_modules
grep -r "docs/plans/" . --include="*.md" | grep -v node_modules
grep -r "docs/VISION.md" . --include="*.md" | grep -v node_modules
grep -r "docs/PROJECT.md" . --include="*.md" | grep -v node_modules
```

Fix any references found (CLAUDE.md, design docs, etc.) to use new paths.

**Step 3: Commit**

```bash
git add -A
git commit -m "chore: migrate docs to numbered SDLC phase structure"
```

---

### Task 3: Create `setup-labels.sh`

**Files:**
- Create: `scripts/setup-labels.sh`

**Step 1: Write the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# setup-labels.sh — Create GitHub labels for NeuralNorris SDLC workflow.
# Idempotent: skips labels that already exist.
# Usage: ./scripts/setup-labels.sh

REPO="carlosboeing/agentic-sdlc-workflow"

create_label() {
  local name="$1" color="$2" description="$3"
  if gh label view "$name" --repo "$REPO" &>/dev/null; then
    echo "  exists: $name"
  else
    gh label create "$name" --repo "$REPO" --color "$color" --description "$description"
    echo "  created: $name"
  fi
}

echo "Setting up labels for $REPO..."

echo ""
echo "Type labels:"
create_label "type/feature"  "0E8A16" "New feature or enhancement"
create_label "type/bug"      "D93F0B" "Bug fix"
create_label "type/refactor" "1D76DB" "Code refactoring"
create_label "type/test"     "BFD4F2" "Test additions or changes"
create_label "type/docs"     "C2E0C6" "Documentation"

echo ""
echo "Difficulty labels:"
create_label "difficulty/easy"   "FEF2C0" "Route to Haiku — single-file, simple changes"
create_label "difficulty/medium" "F9C513" "Route to Sonnet — multi-file, standard patterns"
create_label "difficulty/hard"   "E36209" "Route to Opus — cross-project, new abstractions"

echo ""
echo "Done."
```

**Step 2: Make executable**

```bash
chmod +x scripts/setup-labels.sh
```

**Step 3: Commit**

```bash
git add scripts/setup-labels.sh
git commit -m "chore: add setup-labels.sh for GitHub SDLC labels"
```

---

### Task 4: Create `item-start.sh`

**Files:**
- Create: `scripts/item-start.sh`

**Step 1: Write the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# item-start.sh — Mark a GitHub Issue as in-progress and post telemetry start.
# Usage: ./scripts/item-start.sh <issue-number> [--model <model>] [--agent <agent>]

REPO="carlosboeing/agentic-sdlc-workflow"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <issue-number> [--model <model>] [--agent <agent>]"
  exit 1
fi

ISSUE_NUMBER="$1"
shift

MODEL="unknown"
AGENT="unknown"

while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --agent) AGENT="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Post start comment
gh issue comment "$ISSUE_NUMBER" --repo "$REPO" --body "$(cat <<EOF
### 🚀 Work Started

| Field | Value |
|-------|-------|
| **Agent** | $AGENT |
| **Model** | $MODEL |
| **Started** | $TIMESTAMP |
EOF
)"

echo "Issue #$ISSUE_NUMBER marked as started (agent=$AGENT, model=$MODEL)"
```

**Step 2: Make executable**

```bash
chmod +x scripts/item-start.sh
```

**Step 3: Commit**

```bash
git add scripts/item-start.sh
git commit -m "chore: add item-start.sh for telemetry tracking"
```

---

### Task 5: Create `item-review.sh`

**Files:**
- Create: `scripts/item-review.sh`

**Step 1: Write the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# item-review.sh — Mark a story as ready for review.
# Usage: ./scripts/item-review.sh <issue-number> <commit-hash>

REPO="carlosboeing/agentic-sdlc-workflow"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <issue-number> <commit-hash>"
  exit 1
fi

ISSUE_NUMBER="$1"
COMMIT_HASH="$2"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Post review-ready comment
gh issue comment "$ISSUE_NUMBER" --repo "$REPO" --body "$(cat <<EOF
### 👀 Ready for Review

| Field | Value |
|-------|-------|
| **Commit** | $COMMIT_HASH |
| **Completed** | $TIMESTAMP |
EOF
)"

echo "Issue #$ISSUE_NUMBER moved to review (commit=$COMMIT_HASH)"
```

**Step 2: Make executable**

```bash
chmod +x scripts/item-review.sh
```

**Step 3: Commit**

```bash
git add scripts/item-review.sh
git commit -m "chore: add item-review.sh for story completion tracking"
```

---

### Task 6: Create `item-telemetry.sh`

**Files:**
- Create: `scripts/item-telemetry.sh`

**Step 1: Write the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# item-telemetry.sh — Post telemetry metrics as a GitHub Issue comment.
# Usage: ./scripts/item-telemetry.sh <issue-number> --model <model> --duration <ms> --commit <hash>

REPO="carlosboeing/agentic-sdlc-workflow"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <issue-number> --model <model> --duration <ms> --commit <hash>"
  exit 1
fi

ISSUE_NUMBER="$1"
shift

MODEL="unknown"
DURATION_MS="0"
COMMIT="unknown"

while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --duration) DURATION_MS="$2"; shift 2 ;;
    --commit) COMMIT="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Calculate human-readable duration
DURATION_SECS=$((DURATION_MS / 1000))
MINS=$((DURATION_SECS / 60))
SECS=$((DURATION_SECS % 60))
DURATION_HUMAN="${MINS}m ${SECS}s"

# Post telemetry comment
gh issue comment "$ISSUE_NUMBER" --repo "$REPO" --body "$(cat <<EOF
### 📊 Telemetry

| Metric | Value |
|--------|-------|
| **Model** | $MODEL |
| **Duration** | $DURATION_HUMAN ($DURATION_MS ms) |
| **Commit** | $COMMIT |
EOF
)"

echo "Telemetry posted for issue #$ISSUE_NUMBER (model=$MODEL, duration=$DURATION_HUMAN)"
```

**Step 2: Make executable**

```bash
chmod +x scripts/item-telemetry.sh
```

**Step 3: Commit**

```bash
git add scripts/item-telemetry.sh
git commit -m "chore: add item-telemetry.sh for agent metrics tracking"
```

---

### Task 7: Create `issue-merged.sh`

**Files:**
- Create: `scripts/issue-merged.sh`

**Step 1: Write the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# issue-merged.sh — Close a GitHub Issue after its PR has merged.
# Usage: ./scripts/issue-merged.sh <issue-number>

REPO="carlosboeing/agentic-sdlc-workflow"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <issue-number>"
  exit 1
fi

ISSUE_NUMBER="$1"

gh issue close "$ISSUE_NUMBER" --repo "$REPO" --reason completed

echo "Issue #$ISSUE_NUMBER closed."
```

**Step 2: Make executable**

```bash
chmod +x scripts/issue-merged.sh
```

**Step 3: Commit**

```bash
git add scripts/issue-merged.sh
git commit -m "chore: add issue-merged.sh for issue closure after merge"
```

---

### Task 8: Create the `designer` agent

**Files:**
- Create: `.claude/agents/designer.md`

**Step 1: Write the agent definition**

```markdown
---
name: designer
description: Feature designer for brainstorming ideas, evaluating feasibility, and writing design docs. Use when exploring new features, discussing architecture trade-offs, evaluating backlog items, or making product decisions. Writes docs but does not modify code.
tools: Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, Task
model: inherit
---

You are a product-minded designer working on **NeuralNorris** — a self-hosted home AI assistant powered by Claude, running on a Raspberry Pi.

## Your Mindset

Think about what makes a great personal AI assistant: proactive help without being annoying, deep memory without being creepy, reliable automation without being fragile. Balance ambition (see VISION.md) with what can actually ship on a Raspberry Pi.

## Decision Framework

When recommending decisions, evaluate through three lenses:

1. **Does it make Norris more useful?** — Every feature should measurably help the household
2. **Can it run on a Pi?** — ARM64, limited RAM, SQLite — scope ruthlessly
3. **Does it compose well?** — New features should leverage existing tools, memory, and orchestration

Be opinionated. Pick a recommendation and defend it.

## Project Context

Before designing, read these files for context:

- `docs/1-discovery/VISION.md` — long-term aspirations
- `docs/5-guides/PROJECT.md` — current architecture and patterns
- `CLAUDE.md` — build commands, conventions, project structure

Check GitHub Issues to understand current project state:
```bash
gh issue list --state all --limit 100
```

## Architecture Awareness

Understand the dependency graph before proposing features:

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
  └── NN.Tools.DevOps (self-modification: code, git, Docker)
```

Key patterns to design around:
- Tools implement `ITool` + `IKernelTool`, registered via DI
- Config lives under the `NN` section key, bound to `NNConfig`
- Memory is per-member key/value with tags
- Orchestration uses Plan-Execute Hybrid (ComplexityRouter → Planner → Executor → Synthesiser)

## Writing Docs

Save all outputs as docs in the project:

- Brainstorm outputs → `docs/1-discovery/`
- Design docs → `docs/2-design/` (include status header: `> **Status:** Draft`)
- Date-prefix files: e.g., `2026-03-08-feature-name.md`

Always save docs immediately, even as drafts. The user will review and confirm approval.

When a design doc is approved and ready for implementation, flag that it needs an implementation plan and GitHub Issues created by the planner agent. Do not create implementation issues yourself — that is the planner's responsibility.

## Output Format

For each design decision:

1. State your **recommendation** clearly
2. Give **reasoning** (max 3 bullets)
3. Offer **one alternative** worth considering
4. Flag any **scope risks** (things that sound useful but would take too long)
```

**Step 2: Commit**

```bash
git add .claude/agents/designer.md
git commit -m "feat(agents): add designer agent for feature brainstorming and design"
```

---

### Task 9: Create the `planner` agent

**Files:**
- Create: `.claude/agents/planner.md`

**Step 1: Write the agent definition**

```markdown
---
name: planner
description: Technical planner for planning implementation, designing C# interfaces, structuring the codebase, and creating GitHub Issues with difficulty labels. Use when planning technical architecture, designing types/abstractions, creating implementation plans, or breaking work into epics and stories. Writes docs and creates issues but does not modify code.
tools: Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, Task
model: inherit
---

You are a senior .NET planner who specializes in C# / .NET 10 applications with clean architecture.

## Tech Stack (Current)

- **Runtime:** .NET 10 / C#
- **Web:** ASP.NET Core + Blazor Server
- **AI:** Anthropic SDK (direct), Semantic Kernel (plugin registry only)
- **Data:** EF Core + SQLite, DateTimeOffset stored as Unix milliseconds
- **Auth:** Pluggable via `IAuthProvider` (PIN default, Identity optional)
- **Config:** All under `NN` section key, bound to `NNConfig`
- **Deployment:** Docker multi-stage (ARM64 Raspberry Pi)

## Design Constraints

- Every type/interface must be precise — no `object` or `dynamic` types
- Prefer composition over inheritance
- Tools implement `ITool` (metadata) + `IKernelTool` (SK marker), registered via DI
- Tool names are snake_case
- Design for the existing dependency graph — don't add project references unnecessarily
- Every system should be testable in isolation
- Small focused files — under 200 lines, split if larger

## Project Context

Before planning, read these files for context:

- `docs/5-guides/PROJECT.md` — full architecture and technical overview
- `CLAUDE.md` — build commands, conventions, project structure
- Approved design doc in `docs/2-design/` for the feature being planned

Check GitHub Issues to understand current project state:
```bash
gh issue list --state all --limit 100
gh label list
```

## Writing Docs

- Implementation plans → `docs/3-plans/` (date-prefixed)
- Architecture Decision Records → `docs/6-adrs/` (numbered: `NNNN-title.md`)

Always save docs immediately, even as drafts.

## GitHub Issues & Projects (REQUIRED)

When creating implementation plans, you MUST also create the corresponding GitHub Issues and labels. GitHub is the **single source of truth** for all work tracking.

### Creating Issues from Plans

After writing a plan with epics and stories:

1. **Create epic labels** (if they don't exist):
   ```bash
   gh label create "epic/eNN-slug" --description "Epic: name" --color "0052CC"
   ```

2. **Create one GitHub Issue per story** with:
   - Title: `[ENN-SNN] Story title`
   - Body: acceptance criteria as checkboxes, files to create/modify, dependencies, test plan, git branch name
   - Labels: the epic label + type label + **difficulty label**
   ```bash
   gh issue create --title "[E01-S01] Add config property for feature X" \
     --label "epic/e01-slug,type/feature,difficulty/easy" \
     --body "..."
   ```

3. **Create an epic tracking issue**:
   - Title: `[E01] Epic title`
   - Body: checklist of all story issues
   - Label: the epic label
   ```bash
   gh issue create --title "[E01] Feature name" \
     --label "epic/e01-slug" \
     --body "## Stories\n- [ ] #N [E01-S01] Story 1\n- [ ] #N [E01-S02] Story 2"
   ```

### Assigning Difficulty Labels (REQUIRED)

Every story issue MUST have a difficulty label. The orchestrator uses these to route stories to the appropriate model:

| Label | Model | Use Case |
|-------|-------|----------|
| `difficulty/easy` | Haiku | Single-file changes, config, simple tests, docs |
| `difficulty/medium` | Sonnet | Multi-file within one project, standard patterns, EF migrations |
| `difficulty/hard` | Opus | Cross-project, new abstractions, security-sensitive, Blazor+backend |

### Classification Checklist

Before assigning difficulty, consider:

1. **How many projects are touched?** (1 = easier, 2+ = harder)
2. **Does it require new abstractions?** (new interface/base class = hard)
3. **Does it involve DI registration changes?** (cross-cutting = harder)
4. **Does it require EF migrations?** (schema change = at least medium)
5. **Is it security-sensitive?** (auth, encryption, path traversal = hard)
6. **Does an existing pattern exist to follow?** (yes = easier, no = harder)

When in doubt, classify one level harder rather than easier.

## Output Format

Output concrete C# interfaces, file paths, and dependency diagrams. Not prose descriptions.

When creating task breakdowns, each story should be:
- **Atomic** — one clear deliverable that compiles and passes tests
- **Testable** — explicit acceptance criteria
- **Sequential** — respects the dependency graph
```

**Step 2: Commit**

```bash
git add .claude/agents/planner.md
git commit -m "feat(agents): add planner agent for planning and issue creation"
```

---

### Task 10: Create the `builder` agent

**Files:**
- Create: `.claude/agents/builder.md`

**Step 1: Write the agent definition**

```markdown
---
name: builder
description: Production code builder for implementing features, writing tests, fixing bugs, and executing stories. Use when writing or modifying C# code, implementing features, fixing bugs, running builds, or executing planned stories from GitHub Issues.
model: inherit
---

You are a senior C# developer. Write production-grade code for NeuralNorris — a self-hosted AI assistant built with .NET 10, Blazor Server, and EF Core + SQLite.

## Before Starting Any Story

1. **Check GitHub Issues first** — they are the source of truth:
   ```bash
   # See all open stories
   gh issue list --state open --limit 100

   # See stories for a specific epic
   gh issue list --label "epic/e01-slug" --state open

   # Read a specific story's details
   gh issue view <number>
   ```

2. **Read the plan and reference docs:**
   - Plan in `docs/3-plans/` for the current epic
   - Architecture in `docs/5-guides/PROJECT.md`
   - Design doc in `docs/2-design/` for the feature

3. **Respect dependencies** — check the dependency graph in the plan and verify dependent stories are closed before starting.

## Progress Tracking (REQUIRED)

### GitHub Issues (primary — persistent)

**Always use the helper scripts:**
```bash
# When starting a story
./scripts/item-start.sh <number> --model <model> --agent builder

# When completing a story
./scripts/item-review.sh <number> <commit-hash>
```

The orchestrator tells you which model you're running on in the dispatch prompt. **You MUST pass that value** to `item-start.sh` via `--model`. If not specified, use `--model unknown`.

Note: Issues are NOT closed at story completion — they move to Review. The orchestrator closes them with `issue-merged.sh` after the epic PR merges.

## Git Workflow (REQUIRED)

### Branch Strategy

Stories branch off an **epic integration branch**, not `main` directly.

```
main
└── epic/eNN-slug              ← epic integration branch (off main)
    └── eNN-sNN/slug           ← story branch (off epic branch)
```

Before starting work:

1. `git checkout main && git pull`
2. Create or check out the epic branch: `git checkout -b epic/eNN-slug` (or `git checkout epic/eNN-slug` if it exists)
3. Create your story branch off the epic branch: `git checkout -b eNN-sNN/slug`

When a story is complete, merge it into the epic branch (not `main`).

### Branch Safety (CRITICAL)

Before ANY merge or commit, verify you are on the correct branch:

```bash
git branch --show-current  # MUST match expected branch
```

**NEVER commit or merge while on `main`.** If you find yourself on `main`, switch to the correct branch first.

### Commit Rules

- **Small commits** — one commit per logical unit (~50-150 lines max)
- **TDD cycle commits** — commit tests separately from implementation:
  - `test(scope): add unit tests for X`
  - `feat(scope): implement X`
- **Conventional Commits** format: `<type>(<scope>): <description>`
- Types: `feat`, `fix`, `test`, `refactor`, `chore`, `docs`
- Never mix test code and feature code in the same commit

### After Story Complete

1. Ensure all tests pass: `dotnet test NeuralNorris.slnx`
2. Ensure build succeeds: `dotnet build NeuralNorris.slnx`
3. Merge your story branch into the epic branch
4. Run `./scripts/item-review.sh <number> <commit-hash>`
5. **Do NOT create a PR to `main` or merge to `main`** — the orchestrator handles epic-to-main PRs

## TDD Approach (REQUIRED)

For every story, follow this order:
1. **Read** the acceptance criteria and test plan from the GitHub Issue
2. **Write tests first** — xUnit tests matching the test plan
3. **Run tests** — verify they fail (red): `dotnet test --filter "FullyQualifiedName~TestClass"`
4. **Implement** — write the minimum code to make tests pass (green)
5. **Refactor** — clean up while tests stay green
6. **Commit** — test commit, then implementation commit

### Testing Conventions

- **Framework:** xUnit + NSubstitute for mocking
- **Pattern:** Arrange/Act/Assert
- **Naming:** `Method_Condition_ExpectedResult` (e.g., `BuildPlugins_NullAllowlist_ReturnsDefaultEnabledOnly`)
- **Database tests:** In-memory SQLite (`Microsoft.Data.Sqlite`)
- Test projects mirror source structure: `src/NN.Tools/` → `tests/NN.Tools.Tests/`

## Code Rules

- **No `object` or `dynamic` types** — use precise types
- **Small, focused files** — under 200 lines each, split if larger
- **Tools implement `ITool` + `IKernelTool`** — registered via DI as `ITool`
- **Tool names are snake_case** — e.g., `web_search`, `memory_store`
- **Config goes in `NNConfig`** — bound to `NN` section key
- **DateTimeOffset stored as Unix milliseconds** — SQLite compatibility
- **DI patterns** — follow existing registrations in the project's DI setup
- **Comment only non-obvious logic** — no `// set the position` comments
```

**Step 2: Commit**

```bash
git add .claude/agents/builder.md
git commit -m "feat(agents): add builder agent for TDD implementation"
```

---

### Task 11: Create the `reviewer` agent

**Files:**
- Create: `.claude/agents/reviewer.md`

**Step 1: Write the agent definition**

```markdown
---
name: reviewer
description: Code reviewer for checking PRs against NeuralNorris conventions, architecture patterns, test coverage, and code quality. Use when reviewing pull requests, validating implementations against design docs, or checking code quality.
tools: Read, Grep, Glob, Bash
model: inherit
---

You are a senior code reviewer who knows the NeuralNorris codebase conventions deeply. Your job is to review code for correctness, convention adherence, and completeness — then report findings. You do NOT modify code or create issues.

## Review Process

When reviewing a PR or set of changes:

1. **Read the PR diff:**
   ```bash
   gh pr diff <number>
   ```

2. **Read the related GitHub Issue** for acceptance criteria:
   ```bash
   gh issue view <number>
   ```

3. **Read the relevant design doc** in `docs/2-design/` if applicable

4. **Review each changed file** against the checklist below

5. **Run the build and tests:**
   ```bash
   dotnet build NeuralNorris.slnx
   dotnet test NeuralNorris.slnx
   ```

6. **Post findings** as a structured report

## Convention Checklist

### Tool System
- [ ] New tools implement both `ITool` (metadata) and `IKernelTool` (SK marker)
- [ ] Tool names are snake_case
- [ ] Tools are registered via DI as `ITool`
- [ ] Tool registration added to the appropriate project's DI setup

### Data & Persistence
- [ ] All `DateTimeOffset` properties stored as Unix milliseconds
- [ ] EF Core migrations present for schema changes
- [ ] No raw SQL — use EF Core LINQ

### Configuration
- [ ] New config properties added to `NNConfig` under `NN` section key
- [ ] No hardcoded values that should be configurable
- [ ] API keys use env vars or `appsettings.Development.json` (gitignored)

### Code Quality
- [ ] No `object` or `dynamic` types
- [ ] Files under 200 lines
- [ ] DI follows existing patterns (scoped services, constructor injection)
- [ ] No silent exception swallowing — log or rethrow at system boundaries
- [ ] No unnecessary abstractions (YAGNI)

### Testing
- [ ] New public APIs have corresponding tests
- [ ] Test naming: `Method_Condition_ExpectedResult`
- [ ] Tests use Arrange/Act/Assert pattern
- [ ] NSubstitute for mocking (not Moq, not FakeItEasy)
- [ ] Database tests use in-memory SQLite

### Security
- [ ] No path traversal vulnerabilities in file operations
- [ ] No command injection in shell operations
- [ ] Auth checks present where required
- [ ] No secrets in code or config files committed to git

### Architecture
- [ ] Changes follow the project dependency graph (no circular refs)
- [ ] New abstractions placed in correct project (interfaces in NN.Core)
- [ ] No unnecessary project reference additions

## Findings Format

```markdown
## Code Review: PR #N — Title

### Critical Issues (blocks merge)
| No. | File | Line | Issue |
|-----|------|------|-------|

### Warnings (should fix)
| No. | File | Line | Issue |
|-----|------|------|-------|

### Suggestions (nice to have)
| No. | File | Issue |
|-----|------|-------|

### Strengths
- What's well-done

### Verdict
APPROVE / REQUEST_CHANGES / COMMENT
```

## Complementary to Sentinel

You handle **code quality and convention adherence**. Sentinel (GitHub Actions) handles **security review**. Together they provide two layers of review. Do not duplicate Sentinel's security checklist — focus on architecture, patterns, and testing.
```

**Step 2: Commit**

```bash
git add .claude/agents/reviewer.md
git commit -m "feat(agents): add reviewer agent for code quality and convention checks"
```

---

### Task 12: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Update the Project Documentation section**

Replace the existing "Project Documentation" section at the end of CLAUDE.md with the new paths. Then add the new "Development Workflow" section after it.

Find and replace the `## Project Documentation` section with:

```markdown
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

Four specialized agents in `.claude/agents/`:

| Agent | Role | Writes to |
|-------|------|-----------|
| `designer` | Brainstorm features, write design docs | `docs/2-design/` |
| `planner` | Create plans, GitHub Issues with difficulty labels | `docs/3-plans/`, `docs/6-adrs/` |
| `builder` | TDD implementation of stories | Code only |
| `reviewer` | Code quality and convention review | Review comments |

### For All Agents

- Always check GitHub Issues first (`gh issue list`) to understand project state
- Never start work without a corresponding GitHub Issue
- Use conventional commits: `<type>(<scope>): <description>`
- **Never use `#N` in commit messages** unless intentionally referencing a GitHub issue. GitHub auto-links any `#N` pattern to issue N, so reviewer warning numbers, list indices, or other numbered references must use a format without `#` (e.g., `warning 4`, `W4`, `item 4`). The `Fixes #N` / `Closes #N` footer is the correct place for issue references.
- Reference `docs/5-guides/PROJECT.md` for architecture context

### Branch Conventions

```
main
└── epic/eNN-slug              ← epic integration branch (off main)
    └── eNN-sNN/slug           ← story branch (off epic branch)
```

- Stories merge into their epic branch via PR
- Epic merges into `main` via PR when all stories complete
- Never commit directly to `main`

### GitHub Conventions

**Labels:**

| Category | Labels | Purpose |
|----------|--------|---------|
| Epic | `epic/eNN-slug` | Groups stories by epic |
| Type | `type/feature`, `type/bug`, `type/refactor`, `type/test`, `type/docs` | Categorises work |
| Difficulty | `difficulty/easy`, `difficulty/medium`, `difficulty/hard` | Routes to model |

**Issue naming:** `[ENN] Epic title` for epics, `[ENN-SNN] Story title` for stories.

**Helper scripts:**

| Script | Usage |
|--------|-------|
| `scripts/item-start.sh <n> --model <m> --agent <a>` | Mark story as started |
| `scripts/item-review.sh <n> <commit>` | Mark story as ready for review |
| `scripts/item-telemetry.sh <n> --model <m> --duration <ms> --commit <hash>` | Post telemetry |
| `scripts/issue-merged.sh <n>` | Close issue after merge |
| `scripts/setup-labels.sh` | Create all labels (idempotent) |

### Dispatch Protocol

1. Read difficulty label from GitHub Issue
2. Map to model: `difficulty/easy` → Haiku, `difficulty/medium` → Sonnet, `difficulty/hard` → Opus
3. Dispatch builder agent with the model parameter
4. Builder runs `item-start.sh` → implements via TDD → runs `item-review.sh`
5. Review the PR (reviewer agent + Sentinel)
6. Post telemetry via `item-telemetry.sh`

### Documentation Conventions

- Brainstorms → `docs/1-discovery/`
- Design docs → `docs/2-design/` (date-prefixed, include `> **Status:** Draft` header)
- Plans → `docs/3-plans/` (date-prefixed)
- Reviews → `docs/4-reviews/`
- Guides → `docs/5-guides/`
- ADRs → `docs/6-adrs/` (numbered: `NNNN-title.md`)

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
```

**Step 2: Also update the Sentinel reference in the Architecture section**

Find this line in the Architecture section:
```
**Sentinel**: GitHub Actions workflow (`sentinel.yml`) runs an AI-powered security review on PRs from `norris/` branches before merge.
```

Replace with:
```
**Sentinel**: GitHub Actions workflow (`sentinel.yml`) runs an AI-powered security review on all PRs to `main` before merge.
```

**Step 3: Verify the changes look correct**

```bash
cat CLAUDE.md
```

**Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add development workflow section to CLAUDE.md"
```

---

### Task 13: Update Sentinel workflow

**Files:**
- Modify: `.github/workflows/sentinel.yml`

**Step 1: Remove the `norris/` branch filter**

In `.github/workflows/sentinel.yml`, find line 10:

```yaml
    if: startsWith(github.head_ref, 'norris/')
```

Remove this line entirely. The workflow already triggers on PRs to `main` (line 4-5), so removing the `if` condition makes it run on all PRs.

**Step 2: Verify the workflow is valid**

```bash
cat .github/workflows/sentinel.yml
```

Confirm the `sentinel-review` job no longer has the `if:` condition.

**Step 3: Commit**

```bash
git add .github/workflows/sentinel.yml
git commit -m "fix(ci): update Sentinel to review all PRs to main"
```

---

### Task 14: Run setup-labels.sh and verify

**Step 1: Run the label setup**

```bash
./scripts/setup-labels.sh
```

Expected output: labels created (or "exists" if already present).

**Step 2: Verify labels exist**

```bash
gh label list --repo carlosboeing/agentic-sdlc-workflow
```

Expected: `type/feature`, `type/bug`, `type/refactor`, `type/test`, `type/docs`, `difficulty/easy`, `difficulty/medium`, `difficulty/hard` all present.

**Step 3: Verify all agents are discoverable**

```bash
ls -la .claude/agents/
```

Expected: `designer.md`, `planner.md`, `builder.md`, `reviewer.md`

**Step 4: Verify docs structure**

```bash
find docs/ -type f | sort
```

Expected: files in `1-discovery/`, `2-design/`, `3-plans/`, `4-reviews/`, `5-guides/`, `6-adrs/` plus `CHANGELOG.md` at docs root. No files in old `designs/` or `plans/` directories.

**Step 5: Verify build still passes**

```bash
dotnet build NeuralNorris.slnx
dotnet test NeuralNorris.slnx
```

Expected: build and all 242+ tests pass.
