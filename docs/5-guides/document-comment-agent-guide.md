---
title: Document Comment Agent Guide
date: 2026-03-22
author: carlosboeing
agent: builder
status: approved
backlog: 116
---

# Document Comment Agent Guide

This guide shows how agents interact with document comments through the MCP tools and HTTP API exposed by the Workflow Runtime Service.

## Overview

The document comment system allows agents to annotate design docs, plans, and other markdown files in the repository. Comments are stored in the server's SQLite database and associated with specific documents via their path and optionally anchored to a heading or paragraph within that document.

## MCP Tools

Agents connected via MCP can use two tools for document comments:

### `add_doc_comment`

Add a comment to a document, optionally anchored to a specific heading or paragraph.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `path` | string | yes | Document path relative to the docs/ directory (e.g., `2-design/overview.md`) |
| `body` | string | yes | Comment text |
| `anchor` | string | no | Heading slug or paragraph index to anchor the comment (e.g., `introduction` or `p-0`) |

**Example — general comment:**

```json
{
  "tool": "add_doc_comment",
  "arguments": {
    "path": "2-design/workflow-runtime-service-design.md",
    "body": "Section 3 is missing the error handling strategy for failed migrations."
  }
}
```

**Example — anchored comment on a heading section:**

```json
{
  "tool": "add_doc_comment",
  "arguments": {
    "path": "2-design/workflow-runtime-service-design.md",
    "body": "The sequence diagram here is missing the fallback path.",
    "anchor": "sync-engine"
  }
}
```

**Example — anchored comment on a paragraph:**

```json
{
  "tool": "add_doc_comment",
  "arguments": {
    "path": "3-plans/implementation-plan.md",
    "body": "This assumption about WAL mode needs a citation.",
    "anchor": "p-3"
  }
}
```

The tool returns the created comment object:

```json
{
  "id": 42,
  "documentPath": "2-design/workflow-runtime-service-design.md",
  "body": "Section 3 is missing the error handling strategy for failed migrations.",
  "author": "mcp",
  "anchor": null,
  "threadId": null,
  "createdAt": "2026-03-22T10:15:00.000Z",
  "updatedAt": "2026-03-22T10:15:00.000Z"
}
```

### `list_doc_comments`

List all comments on a document.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `path` | string | yes | Document path (same format as `add_doc_comment`) |

**Example:**

```json
{
  "tool": "list_doc_comments",
  "arguments": {
    "path": "2-design/workflow-runtime-service-design.md"
  }
}
```

The tool returns an array of comment objects. An empty array means no comments exist for that path.

## Anchor Format

Anchors connect a comment to a specific location within a document:

- **Heading anchors** — slugified heading text. The slug is the heading text lowercased with spaces replaced by hyphens and special characters removed. For example, `## Design Decisions` has anchor `design-decisions`, and `### Performance Notes` has anchor `performance-notes`.
- **Paragraph anchors** — sequential zero-based indices prefixed with `p-`. The first paragraph in the document is `p-0`, the second is `p-1`, and so on. These indices count paragraphs across the entire document, regardless of section.

The document viewer renders comments alongside their anchor location. If a document is edited and a heading is renamed, its comments become "stale" — the anchor no longer matches any element in the document. The viewer marks stale comments visually so humans can resolve them.

## Agent Review Workflow

A typical review cycle works as follows:

1. The reviewer agent reads the document via `GET /api/documents/:path` (HTTP) or by reading the file directly from disk.
2. The reviewer identifies issues and posts comments using `add_doc_comment`, anchoring each comment to the relevant section.
3. The builder agent reads the comments using `list_doc_comments`, iterates on the document, and makes corrections.
4. The builder posts a reply comment to acknowledge or dispute each reviewer comment (via the HTTP API `POST /api/documents/:path/comments` with `thread_id`).

## HTTP API (Shell Adapter)

Shell scripts can also create document comments using the server adapter's `pm_add_doc_comment` function. This is useful for orchestrators running in bash or for agents using the shell adapter as a fallback.

**Usage:**

```bash
# Add a general comment
pm_add_doc_comment "2-design/overview.md" "This section needs clarification."

# Add an anchored comment
pm_add_doc_comment "2-design/overview.md" "The diagram is missing the DB layer." "architecture-overview"
```

The shell adapter calls `POST /api/documents/{path}/comments` with:

```json
{
  "body": "<body>",
  "author": "shell-adapter",
  "anchor": "<anchor>"   // omitted if no anchor provided
}
```

For thread replies, use the HTTP API directly:

```bash
curl -s -X POST \
  "${WORKFLOW_SERVER_URL}/api/documents/2-design/overview.md/comments" \
  -H "Content-Type: application/json" \
  -d '{"body": "Fixed in commit abc123", "author": "builder", "thread_id": "42"}'
```

## Error Cases

- **Empty path** — returns a 400 error from the HTTP API; the MCP tool propagates this as an error result.
- **Non-existent document** — `list_doc_comments` returns an empty array (comments are stored by path only; the document does not need to exist). `add_doc_comment` succeeds even for non-existent documents — comments are not validated against document existence.
- **Missing required fields** — both `path` and `body` are required for `add_doc_comment`. Omitting either returns a validation error.
- **Path traversal** — paths containing `..` or starting with `/` are rejected with a 400 error.
