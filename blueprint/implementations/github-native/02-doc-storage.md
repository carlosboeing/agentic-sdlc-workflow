# GitHub Native Implementation — Document Storage

## Overview

In the GitHub-native implementation, the repository's `docs/` directory serves as the documentation backend. All pipeline documents — PRFAQ, PRD, Product Vision, HLD, LLD, and ADRs — are stored as markdown files, versioned through git, and reviewed through pull requests. This approach eliminates external dependencies for document management and provides the same branching, diffing, and review workflow used for code.

The tradeoff is explicit: no WYSIWYG editor, no real-time collaboration, and no embedded rich media without file management overhead. In exchange, the team gets full version control, PR-based review with inline comments, free hosting, offline access, and a single source of truth colocated with the codebase.

## Directory Structure

```
docs/
├── product/
│   ├── PRFAQ-<feature-name>.md
│   ├── PRD-<feature-name>.md
│   └── vision-<feature-name>.md
├── design/
│   ├── HLD-<feature-name>.md
│   └── LLD-<feature-name>.md
└── decisions/
    ├── ADR-001-<title>.md
    ├── ADR-002-<title>.md
    └── ...
```

### Subdirectory Responsibilities

| Directory | Contents | Produced By | Consumed By |
|---|---|---|---|
| `docs/product/` | PRFAQ, PRD, Product Vision | Visionary agent | Architect agent |
| `docs/design/` | HLD, LLD | Architect agent | Planner, Builder, Reviewer agents |
| `docs/decisions/` | ADRs | Architect agent | Planner, Builder, Reviewer agents |

## Naming Conventions

All document files follow the pattern:

```
<TYPE>-<feature-name>.md
```

- **TYPE**: Uppercase document type identifier (`PRFAQ`, `PRD`, `HLD`, `LLD`, `ADR-NNN`). The `vision` type uses lowercase for readability.
- **feature-name**: Kebab-case feature identifier (e.g., `stripe-billing`, `user-onboarding`, `dark-mode-toggle`).
- **ADR numbering**: ADRs use zero-padded sequential numbering: `ADR-001`, `ADR-002`, etc. The number is global to the project, not scoped to a feature. This ensures unique, chronologically ordered decision records.

### Examples

```
docs/product/PRFAQ-stripe-billing.md
docs/product/PRD-stripe-billing.md
docs/product/vision-stripe-billing.md
docs/design/HLD-stripe-billing.md
docs/design/LLD-stripe-billing.md
docs/decisions/ADR-001-stripe-over-paddle.md
docs/decisions/ADR-002-webhook-idempotency-strategy.md
docs/decisions/ADR-003-subscription-state-machine.md
```

## MCP Tool Mapping

The core design documents define abstract tool interfaces for document operations. In the GitHub-native implementation, these map to Claude Code's built-in tools rather than an external MCP server, because documents are local files in the repository.

| Abstract Tool | GitHub Implementation | Claude Code Tool | Notes |
|---|---|---|---|
| `mcp__docs__create_page` | Create markdown file, stage, commit | `Write` + `Bash` | Agent writes file, then runs `git add` + `git commit` |
| `mcp__docs__update_page` | Edit markdown file, commit | `Edit` + `Bash` | Agent edits in place, then commits |
| `mcp__docs__get_page` | Read markdown file | `Read` | Direct file read by path |
| `mcp__docs__search` | Search across `docs/` directory | `Grep` | Text search with regex support; use `rg` for performance |

### Agent Prompt Adaptation

Because the GitHub-native implementation uses local files instead of an external doc MCP server, the agent prompts reference file paths instead of document IDs. The Visionary agent writes to `docs/product/PRFAQ-<feature>.md` instead of calling `mcp__docs__create_page`. The Architect agent reads from `docs/product/PRD-<feature>.md` instead of calling `mcp__docs__get_page` with a Notion page ID.

This mapping is configured in `CLAUDE.md`:

```markdown
## Docs
- Product documents: `docs/product/` (PRFAQ, PRD, Vision)
- Technical design: `docs/design/` (HLD, LLD)
- Architecture decisions: `docs/decisions/` (ADR-NNN-title.md)
- Templates: `.claude/templates/`
```

## Review Workflow

Document changes follow the same pull request workflow as code changes. This is a distinct advantage of the GitHub-native approach: design documents are reviewed with the same rigor and tooling as implementation.

### Process

1. **Branch creation**: The agent creates a branch for document work:
   ```
   docs/<feature-name>
   ```

2. **Document authoring**: The agent writes or updates markdown files in `docs/` on the branch.

3. **Commit**: Changes are committed with conventional commit messages:
   ```
   docs(product): add PRFAQ for stripe-billing
   docs(design): add HLD and LLD for stripe-billing
   docs(decisions): add ADR-001 stripe-over-paddle
   ```

4. **Pull request**: A PR is opened with the `doc-review` label:
   ```bash
   gh pr create \
     --title "docs: add product and design docs for stripe-billing" \
     --body "PRFAQ, PRD, Vision, HLD, LLD, and 3 ADRs for the Stripe billing feature." \
     --label "doc-review,agent-generated"
   ```

5. **Human review**: The reviewer reads the markdown diffs, leaves inline comments, requests changes or approves.

6. **Merge**: Upon approval, the PR is merged to `main`. The documents are now the canonical versions referenced by downstream pipeline stages.

### Review Conventions

- **One PR per pipeline checkpoint**: The Visionary agent produces one PR containing PRFAQ, PRD, and Vision. The Architect agent produces a separate PR containing HLD, LLD, and ADRs. This aligns with the pipeline's checkpoint model.
- **Inline comments**: Reviewers use GitHub's line-level commenting on markdown diffs to provide targeted feedback.
- **Re-run after edits**: If the reviewer edits the documents directly (via the GitHub web editor or locally), the pipeline can be resumed from the current stage with the updated documents as input.

## Template Usage

Document templates in `.claude/templates/` define the expected structure for each document type. Agents load these templates and populate them with feature-specific content. The templates are checked into the repository and versioned alongside the agent definitions.

```
.claude/templates/
├── prfaq-template.md
├── prd-template.md
├── hld-template.md
├── lld-template.md
└── adr-template.md
```

When the Visionary agent creates a PRFAQ, it reads `.claude/templates/prfaq-template.md`, fills in the sections, and writes the result to `docs/product/PRFAQ-<feature>.md`. The template structure ensures consistency across features, which is critical for downstream agents that parse specific sections (e.g., the Planner reads the "Requirements" section of the PRD, and the Reviewer checks the "Security Considerations" section of the HLD).

## Advantages

- **Full git history**: Every document change is tracked with author, timestamp, and diff. Blame, log, and bisect work on documents the same as code.
- **PR-based review**: Design documents receive the same review workflow as code — assignees, reviewers, inline comments, approval gates, and merge protection.
- **Diff visibility**: Markdown diffs render cleanly in GitHub's PR view, making it straightforward to review changes to requirements or architecture.
- **Zero external dependencies**: No SaaS subscriptions, API keys, or MCP servers required for document storage. Git is the only dependency.
- **Offline access**: All documents are available locally. Agents can read and write documents without network connectivity.
- **Free**: No per-user or per-workspace cost for document storage.
- **Colocated with code**: Documents live in the same repository as the code they describe. No context switching between tools.
- **CI/CD integration**: Document changes can trigger workflows (e.g., validate markdown structure, check for broken internal links, generate a documentation site).

## Limitations

- **No rich editing UI**: Authors must write raw markdown. No WYSIWYG, no drag-and-drop, no block-based editing. This is acceptable for agent-authored content but may friction human collaborators who prefer visual editors.
- **No real-time collaboration**: Git does not support simultaneous editing. Concurrent document work requires branching and merging, which can produce merge conflicts in prose.
- **No embedded media**: Images, diagrams, and other media require file management (e.g., storing images in `docs/assets/` with relative path references). Mermaid diagrams render natively in GitHub but other diagram formats do not.
- **Text-based search only**: Search is limited to text/regex matching via `grep` or `ripgrep`. No semantic search, no full-text indexing with relevance ranking. For large document corpora (50+ features), consider adding a vector RAG MCP server as described in [04-context-strategy.md](../../04-context-strategy.md).
- **No granular permissions**: GitHub repository permissions apply to the entire repository. There is no way to restrict write access to `docs/` independently of `src/`. Branch protection rules provide some mitigation.

## Migration from External Backends

### From Notion

1. **Export**: Use Notion's "Export" feature (Settings > Workspace > Export all workspace content) to download pages as markdown.
2. **Clean**: Notion's markdown export includes non-standard formatting. Clean up:
   - Remove Notion-specific block IDs and metadata
   - Convert Notion callout blocks to standard markdown blockquotes
   - Fix image paths (Notion exports images as separate files with UUIDs)
3. **Organize**: Move files into the `docs/` directory structure defined above, renaming to match the naming conventions.
4. **Commit**: Stage and commit all documents as a single migration commit.

### From Confluence

1. **Export**: Use Confluence's space export (Space Settings > Content Tools > Export) to download as HTML or use the REST API.
2. **Convert**: Use a tool such as `pandoc` to convert HTML to markdown:
   ```bash
   pandoc -f html -t gfm -o output.md input.html
   ```
3. **Clean**: Fix tables, image paths, and Confluence-specific macros that do not convert cleanly.
4. **Organize and commit**: Follow the same organize and commit steps as the Notion migration.

### Post-Migration Verification

After migration, verify:

- All documents render correctly in GitHub's markdown viewer
- Internal cross-references between documents use correct relative paths
- Mermaid diagrams (if any) render in GitHub
- The document directory structure matches the layout defined in this guide
