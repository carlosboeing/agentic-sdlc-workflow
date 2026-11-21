# GitHub Native Implementation

This implementation uses GitHub as both the documentation backend and the project management backend, with GitHub Actions for CI/CD automation. It is the zero-external-dependency option: everything lives within a single GitHub repository.

## Components

| Component | GitHub Service | Description |
|-----------|---------------|-------------|
| Doc storage | Repository `docs/` directory | Markdown files versioned with git, reviewed via PRs |
| PM tool | GitHub Issues + Projects | Issue templates for epics/stories/tasks, project board for visualization |
| CI/CD | GitHub Actions | Label-triggered agent workflows, environment-based approval gates |
| MCP | `@modelcontextprotocol/server-github` | Official GitHub MCP server for Issues, PRs, and Projects |

## Reading Order

| # | Document | Description |
|---|----------|-------------|
| 01 | [Setup](01-setup.md) | Prerequisites, MCP server installation, configuration, verification |
| 02 | [Doc Storage](02-doc-storage.md) | Directory structure, naming conventions, review workflow |
| 03 | [Project Management](03-project-management.md) | Issue templates, label taxonomy, project board, milestones |
| 04 | [CI/CD](04-ci-cd.md) | GitHub Actions workflows, approval gates, PR automation |

Start with [01-setup.md](01-setup.md). Each document references the next in its closing section.

## Prerequisites

- GitHub account with repo creation permissions
- GitHub Personal Access Token (`repo`, `project`, `read:org` scopes)
- Claude Code CLI
- `gh` CLI 2.40+
- Node.js 18+

See [01-setup.md](01-setup.md) for detailed setup instructions.
