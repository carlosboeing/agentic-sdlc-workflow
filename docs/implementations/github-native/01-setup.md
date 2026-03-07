# GitHub Native Implementation — Setup

## Overview

This guide configures the agentic SDLC blueprint to use GitHub as both the documentation backend (markdown files in the repository) and the project management backend (GitHub Issues + GitHub Projects). GitHub Actions provides CI/CD automation. This is the zero-external-dependency implementation: everything lives within a single GitHub repository.

## Prerequisites

Before proceeding, ensure the following are available:

| Requirement | Minimum Version | Purpose |
|---|---|---|
| GitHub account | — | Repository hosting, Issues, Projects |
| GitHub Personal Access Token | — | MCP server authentication |
| Claude Code CLI | Latest | Agent execution |
| `gh` CLI | 2.40+ | GitHub API operations from terminal |
| Node.js | 18+ | MCP server runtime |
| Git | 2.30+ | Version control, worktree support |

### GitHub Personal Access Token

Generate a fine-grained or classic PAT with the following scopes:

- `repo` — Full control of private repositories (read/write issues, PRs, contents)
- `project` — Read/write access to GitHub Projects
- `read:org` — Read organization membership (required for org-owned repos)

To create a classic token:

```bash
# Open the token creation page
open "https://github.com/settings/tokens/new?scopes=repo,project,read:org&description=agentic-sdlc-pipeline"
```

Store the token securely. It will be referenced as `GITHUB_PAT` throughout this guide.

## MCP Server Installation

The GitHub MCP server provides programmatic access to GitHub Issues, Pull Requests, and repository contents. Install it globally:

```bash
npm install -g @modelcontextprotocol/server-github
```

Alternatively, use `npx` for on-demand execution (no global install required). The `.mcp.json` configuration below uses the `npx` approach.

## Configuration

### `.mcp.json`

Create or update `.mcp.json` in the project root:

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PAT}"
      }
    }
  }
}
```

This configuration serves as both the documentation MCP and the project management MCP. In the GitHub-native implementation, document operations (create, read, update) use the filesystem directly (via Claude Code's built-in `Read`, `Write`, `Edit` tools), while project management operations (issue creation, label management, board updates) route through the GitHub MCP server.

### Environment Variables

Set the following in your shell profile (`~/.zshrc`, `~/.bashrc`, or equivalent):

```bash
export GITHUB_PAT="ghp_your_token_here"
```

For CI/CD environments, store the token as a repository secret named `GITHUB_PAT` (see [04-ci-cd.md](04-ci-cd.md) for GitHub Actions configuration).

## Project Setup Steps

### 1. Copy the Reference Implementation

From the blueprint repository, copy the `reference/` directory into your target project:

```bash
cp -r /path/to/agentic-sdlc-blueprint/reference/.claude .claude
cp /path/to/agentic-sdlc-blueprint/reference/.mcp.json .mcp.json
```

### 2. Customize `CLAUDE.md`

Edit `CLAUDE.md` in the project root to reflect the target project's stack, commands, architecture, and conventions. This file is the single most important context source for all pipeline agents. See [04-context-strategy.md](../../04-context-strategy.md) for guidance on what to include.

### 3. Customize `.mcp.json`

Update `.mcp.json` with the GitHub MCP configuration shown above. If the project already has other MCP servers (e.g., a database MCP), merge the `github` entry into the existing `mcpServers` object.

### 4. Create the Document Directory Structure

```bash
mkdir -p docs/product docs/design docs/decisions
```

See [02-doc-storage.md](02-doc-storage.md) for the full directory layout and naming conventions.

### 5. Create GitHub Project Board

Using the `gh` CLI:

```bash
# Create a project (replace OWNER with your GitHub username or org)
gh project create --owner OWNER --title "SDLC Pipeline" --format board
```

Note the project number returned. Configure columns and automation as described in [03-project-management.md](03-project-management.md).

### 6. Set Up Label Taxonomy

Run the label creation commands from [03-project-management.md](03-project-management.md). Summary:

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

# Workflow trigger labels
gh label create "ai-design" --color "C5DEF5" --description "Trigger AI design workflow"
gh label create "ai-plan" --color "C5DEF5" --description "Trigger AI planning workflow"
gh label create "ai-implement" --color "C5DEF5" --description "Trigger AI implementation workflow"
```

### 7. Configure Branch Protection

Protect the `main` branch:

```bash
# Via GitHub web UI: Settings > Branches > Add rule
# Branch name pattern: main
# Enable:
#   - Require a pull request before merging
#   - Require status checks to pass before merging
#   - Require approvals (1+)
#   - Do not allow bypassing the above settings
```

Or via the GitHub API:

```bash
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["ci"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1}' \
  --field restrictions=null
```

## Verification

After completing setup, run the following verification steps to confirm each component is operational.

### Test MCP Server Connectivity

```bash
claude -p "List open issues in this repo" --allowedTools "mcp__github__*"
```

Expected: Claude returns a list of issues (or confirms zero issues exist). If the MCP server fails to start, verify `GITHUB_PAT` is exported and has the required scopes.

### Test Document Storage

```bash
echo "# Test Document" > docs/product/test-verification.md
git add docs/product/test-verification.md
git status
```

Expected: The file appears as a new staged file. Remove it after verification:

```bash
git reset docs/product/test-verification.md
rm docs/product/test-verification.md
```

### Test Project Board

```bash
gh issue create --title "[Test] Verification Issue" --body "This issue verifies the SDLC pipeline setup." --label "type:task"
```

Expected: Issue is created and visible in the repository. Verify it appears on the project board if auto-add is configured. Delete the test issue after verification:

```bash
gh issue close <issue-number> --reason "not planned"
gh issue delete <issue-number> --yes
```

### Test Label Taxonomy

```bash
gh label list
```

Expected: All labels from Step 6 are present with correct colors and descriptions.

## Next Steps

With setup complete, proceed to:

1. [02-doc-storage.md](02-doc-storage.md) — Configure document directory structure and review workflow
2. [03-project-management.md](03-project-management.md) — Configure issue templates, labels, and project board
3. [04-ci-cd.md](04-ci-cd.md) — Configure GitHub Actions workflows for pipeline automation
