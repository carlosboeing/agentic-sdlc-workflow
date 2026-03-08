# Implementation Guides

## Overview

The core design documents in this repository (01 through 08) define the agentic SDLC architecture in a backend-agnostic manner. They specify agent contracts, orchestration algorithms, context strategies, security models, and state management without prescribing any particular toolstack. Implementation guides bridge that abstraction to reality: each guide provides concrete setup instructions, configuration files, CLI commands, and workflow definitions for a specific combination of documentation backend, project management backend, and CI/CD platform.

An implementation guide does not redefine the architecture. It maps the abstract interfaces — `mcp__docs__create_page`, `mcp__pm__create_issue`, checkpoint gates, branch strategies — onto the concrete APIs and tools of a given platform. Teams should read the core design docs first for architectural understanding, then follow the implementation guide that matches their existing toolstack.

## Available Implementations

| Implementation | Doc Backend | PM Backend | CI/CD | Status |
|---|---|---|---|---|
| [GitHub Native](github-native/) | Repository MD files | GitHub Issues + Projects | GitHub Actions | Available |
| Notion + Linear | Notion pages | Linear issues | — | Planned |
| Confluence + Jira | Confluence pages | Jira issues | — | Planned |
| Google Docs + Asana | Google Docs | Asana tasks | — | Planned |

## Standard Structure

Every implementation guide follows a four-document structure. This consistency allows teams to evaluate and compare implementations systematically.

| Document | Purpose |
|---|---|
| `01-setup.md` | Prerequisites, MCP server installation, configuration, environment variables, verification steps |
| `02-doc-storage.md` | How pipeline documents (PRFAQ, PRD, HLD, LLD, ADRs) are stored, versioned, and reviewed |
| `03-project-management.md` | How epics, stories, and tasks are tracked; issue templates, label taxonomy, board configuration |
| `04-ci-cd.md` | How pipeline stages are automated; workflow definitions, approval gates, PR automation |

## Comparison Matrix

The following matrix compares documentation and project management backends across dimensions relevant to implementation selection. CI/CD is excluded because it is typically determined by the PM backend (GitHub Issues implies GitHub Actions; Jira implies Jenkins or Bitbucket Pipelines).

### Documentation Backends

| Dimension | GitHub MD Files | Notion | Confluence | Google Docs |
|---|---|---|---|---|
| **Cost** | Free (included with repo) | Free tier available; Team $10/user/mo | $5.75/user/mo (Standard) | Free with Google Workspace |
| **Setup Complexity** | Minimal — git is the only dependency | Low — API key + MCP server | Medium — Atlassian auth + MCP server | Medium — OAuth + MCP server |
| **Rich Editing** | None — plain markdown only | Excellent — blocks, databases, embeds | Good — WYSIWYG, macros | Excellent — native word processor |
| **Version History** | Full git history with diffs | Page history (no branching) | Page versions (no branching) | Revision history (no branching) |
| **PR-based Review** | Native — markdown diffs in PRs | Not supported | Not supported | Suggesting mode (no PR equivalent) |
| **Search Quality** | Text-based (grep/ripgrep) | Good — full-text with filters | Good — CQL queries | Good — Google search integration |
| **Team Size Sweet Spot** | 1-5 engineers | 3-20 cross-functional | 10-100+ enterprise | 3-15 cross-functional |

### Project Management Backends

| Dimension | GitHub Issues + Projects | Linear | Jira | Asana |
|---|---|---|---|---|
| **Cost** | Free (public repos); included with GitHub Teams | $8/user/mo | Free tier; Standard $8.15/user/mo | Free tier; Premium $10.99/user/mo |
| **Setup Complexity** | Minimal — same platform as code | Low — API key + MCP server | Medium — Atlassian auth + MCP server | Medium — OAuth + MCP server |
| **Issue Templates** | YAML-based templates in repo | Markdown templates | Screen-based schemes | Form-based templates |
| **Automation** | GitHub Actions + Projects workflows | Built-in automation | Jira Automation rules | Asana Rules |
| **API Quality** | Excellent — GraphQL + REST | Excellent — GraphQL | Extensive but complex — REST | Good — REST |
| **Developer Experience** | Native to git workflow | Purpose-built for engineers | Enterprise-oriented | General-purpose |
| **Team Size Sweet Spot** | 1-10 engineers | 5-50 engineers | 10-500+ enterprise | 5-50 cross-functional |

## Contributing a New Implementation

To add support for a new backend combination:

1. Fork this repository.
2. Create a new directory under `implementations/` named after the implementation (e.g., `notion-linear/`, `confluence-jira/`).
3. Follow the standard four-document structure: `01-setup.md`, `02-doc-storage.md`, `03-project-management.md`, `04-ci-cd.md`.
4. Add a `README.md` to the new directory with an overview, reading order, and links to all four docs.
5. Map every abstract interface from the core design docs to a concrete tool, API call, or CLI command in the new backend.
6. Include verification steps so adopters can confirm their setup is working before running the pipeline.
7. Submit a pull request with a description of the backend combination, any limitations relative to the reference GitHub-native implementation, and any additional prerequisites.

Refer to the [GitHub Native](github-native/) implementation as the reference for expected scope and depth.
