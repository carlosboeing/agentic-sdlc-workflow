# Agentic SDLC Blueprint

## Project Overview
Documentation repository + starter kit for an end-to-end agentic software
development lifecycle using Claude Code. Contains 8 core design docs,
implementation guides, and working starter kit files.

## Repository Structure
- `blueprint/01-08-*.md` — Core design documents (HLD/LLD format)
- `implementations/` — Backend-specific implementation guides
- `implementations/github-native/` — GitHub Issues/Projects/Actions guide
- `starter-kit/.claude/agents/` — 6 agent definitions with YAML frontmatter
- `starter-kit/.claude/templates/` — 5 document templates (PRFAQ, PRD, HLD, LLD, ADR)
- `starter-kit/.claude/commands/` — 5 slash commands
- `starter-kit/scripts/` — Orchestration scripts (Bash)
- `starter-kit/CLAUDE.md` — Example project context (NOT this file)
- `internal/` — Working documents for iterating on the blueprint (see below)

## Writing Conventions

### Tone
- Formal tech design language — specification-grade, not conversational
- Never use: "start here", "the key insight:", "battle-tested", "the most overlooked"
- No emojis anywhere in docs
- Audience: engineers, tech leads, stakeholders, and public readers

### Document Format (core docs 01-08)
- Start with `# Title` followed by 1-2 sentence overview paragraph
- Sections numbered: `## 1. Section Name`, `### 1.1 Subsection`
- End every doc with `## Related Documents` section linking relevant sibling docs
- Cross-reference other docs: `[Agent Pipeline](02-agent-pipeline.md)`
- Use relative paths for all internal links
- Include Mermaid diagrams where they aid understanding
- Use tables for structured comparisons and specifications

### Implementation Guides (implementations/)
- Each backend has a folder with a README.md + 4 numbered docs
- Standard structure: `01-setup.md`, `02-doc-storage.md`, `03-project-management.md`, `04-ci-cd.md`
- Folder README.md: overview, components table, reading order table, prerequisites summary
- Title format: `# GitHub Native Implementation — Setup`
- Include exact CLI commands and config snippets
- Provide verification steps at the end
- Each doc's closing section links to the next doc in sequence

## Terminology (use consistently)
- Six agents: Visionary, Architect, Planner, Builder, Tester, Reviewer (always capitalized)
- MCP tool names: `mcp__docs__create_page`, `mcp__pm__create_issue` (abstract, never backend-specific in core docs)
- Models: Opus, Sonnet (capitalized, no version numbers)
- Orchestration tiers: Tier 1 (Bash), Tier 2 (Agent SDK), Tier 3 (GitHub Actions)
- Entry points: Full, Design, Plan, Build (capitalized)
- Context tiers: Tier 1 (Structured Loading), Tier 2 (Native Search), Tier 3 (Vector RAG)
- Security layers: Layer 1-5 (OS Sandbox, Tool Permissions, Hook Guards, Branch Protection, CI/CD Gates)
- Permission modes: plan, acceptEdits, full (lowercase)
- Cost modes: standard, economy (lowercase)

## Agent Definitions (starter-kit/.claude/agents/)
- YAML frontmatter: name, description, tools, model, permissionMode
- Tool names must be abstract MCP names, not backend-specific
- Rules section at bottom with bullet points

## Starter Kit
- `starter-kit/` is a copy-paste starter kit — files must be self-contained and runnable
- `starter-kit/CLAUDE.md` is an EXAMPLE template for user projects, not this repo's config
- Scripts use `set -euo pipefail` and have header comment blocks with usage/flags

## Internal Documentation (internal/)
Working documents for iterating on the blueprint. All files follow the
naming convention `YYYY-MM-DD-<topic>.md` with kebab-case topics.

- `designs/` — Design docs from brainstorming and ideation
- `plans/` — Implementation plans for approved designs
- `reviews/` — Code reviews, design reviews, post-implementation reviews
- `decisions/` — Decision records explaining why X was chosen over Y
- `audits/` — Periodic quality and completeness assessments
- `research/` — Technical investigations, paper analyses, external reference digests
- `notes/` — Session notes and daily logs of what was done and why

CC skill overrides:
- Brainstorming design docs → `internal/designs/YYYY-MM-DD-<topic>.md`
- Implementation plans → `internal/plans/YYYY-MM-DD-<topic>.md`

## Git Conventions
- Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`
- Co-author line: `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`
- Commit docs and starter kit files in logical groups, not one file per commit
