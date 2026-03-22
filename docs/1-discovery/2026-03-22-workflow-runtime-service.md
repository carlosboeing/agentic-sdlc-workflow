---
date: 2026-03-22
author: carlos
backlog: 116
scope: Brainstorming and research for BL#116 — expanding from a dashboard to a full workflow runtime service
---

# Workflow Runtime Service — Discovery & Research

> **Backlog:** [#116 Dashboard (Local Web UI)](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/116)
> **Status:** Brainstorming complete. Ready for design phase.

## Context

BL#116 was originally scoped as an ephemeral local web UI for visual progress tracking (Kanban board, telemetry charts, Gantt timeline, activity feed). During brainstorming, the scope expanded significantly based on three interconnected insights:

1. The dashboard needs data — and the current file-system PM adapter is fragile (worktree isolation issues, ID collisions, scaling concerns documented across Runs 15-17)
2. If we're running a server for the dashboard, it should also serve as the PM backend — replacing file I/O with a proper database
3. A document viewer/editor would close the gap in the human-in-the-loop workflow for design doc reviews

The result is a **workflow runtime service** — a persistent local server that powers the dashboard UI, the PM backend, document review, and agent tool access via MCP.

## Pillars

### 1. Dashboard UI

Visual progress tracking for humans monitoring workflow runs.

**Features:**
- Kanban board with drag-and-drop (status columns: Backlog, Ready, In Progress, In Review, Done)
- Work item detail view (description, acceptance criteria, activity history)
- Telemetry summary (cost, tokens, duration per item and per run)
- Gantt timeline (interactive, zoomable, with dependency arrows)
- Activity feed (real-time status changes, comments, telemetry events)
- Dependency graph (embedded Mermaid rendering)
- Auto-refresh via WebSocket push or SSE

### 2. Document Viewer/Editor

Closes the gap in design doc review workflow. Today, giving feedback on a design doc requires reading it in an IDE or GitHub, then switching to the CC CLI to discuss each comment — context is lost and it doesn't scale for large docs.

**V1 — Viewer + Comments:**
- Render markdown documents with rich preview
- Inline comment threads anchored to specific paragraphs/sections (Google Docs / Quip style)
- Overall document-level comments
- Comments stored in the database, associated with doc path + paragraph anchor
- Agents (designer) can read comments via API/MCP and iterate on the doc

**V2 — Editor (future):**
- WYSIWYG editing experience with option to toggle raw markdown view
- Edit in the browser, changes written back to the file system
- Track changes / suggestion mode

**Note:** V2 is tracked here for architectural consideration but is not in scope for the initial implementation. The design should not preclude it.

### 3. PM Backend (Database-Backed API)

Replaces the file-system local PM adapter with a SQLite database served via REST API.

**Motivation:**
- **Worktree PM isolation (Run 15, rec AM):** Worktree-isolated agents write `.workflow/items/` files in the ephemeral worktree — lost after PR merge
- **ID collisions (Run 17, rec AO):** External PM creation failures cause numbering desync between `.workflow/_next_id` and GitHub's auto-increment
- **Scaling concerns (BL#283):** As work items grow, scanning 50+ YAML frontmatter files becomes fragile (though currently fast enough)
- **Concurrent access:** A database with proper transactions is more reliable than file-level locking for parallel agents

**Architecture:**
- Same dual-write pattern from BL#227 — local DB is always-on, GitHub sync is fire-and-forget
- PM abstraction layer (#109) interface unchanged — new adapter implementation, not a new interface
- Sync engine lives inside the server (retries, queuing, conflict resolution centralized)

**Open question for the designer — Work Item ID Strategy:**
Today, the dual-write system has an ID problem: GitHub assigns its own sequential IDs, and the local PM has a separate `_next_id` counter. When the external creation fails, IDs diverge. The designer should evaluate options:
- Server-generated UUIDs as primary keys, with GitHub issue number as a secondary reference
- Server calls GitHub first to get the ID, then stores locally (current approach, but fragile)
- Decouple IDs entirely — local has its own namespace, mapping table links to external IDs
- Other approaches

### 4. MCP Server (Agent Tool Access)

Expose PM operations as native Claude Code tools via MCP protocol.

**Motivation:**
- Today: Agent → Bash tool → shell script → curl/file I/O → PM
- With MCP: Agent → MCP tool call → server → SQLite + GitHub sync
- Eliminates shell overhead, provides structured responses, enables richer tool schemas

**Strategy: Both interfaces from day one, agents choose.**
- MCP tools and HTTP API expose the same PM service layer — two interfaces, one system
- Shell scripts remain and call the HTTP API via `curl` (backward compatible, no agent instruction changes needed)
- Agents can use MCP tools when available — gradual adoption as agent instructions evolve
- No forced migration — both paths are first-class

**MCP tool examples:**
- `create_item` — create a work item (backlog/epic/story)
- `get_item` — read a work item by ID
- `list_items` — list/filter work items
- `set_status` — update board status
- `add_comment` — post a comment
- `link_child` — link sub-issue to parent
- `start_work` / `complete_work` — lifecycle transitions

### 5. Server Lifecycle

**Hybrid: persistent daemon with auto-start.**

The server starts as a background daemon on first need and persists until explicitly stopped or idle timeout. This is a prerequisite for the workflow to function — if the server IS the PM backend, it must be running before any agent work begins.

**Start triggers:**
- Orchestrator Phase 0 (auto-start — ensures server is running before dispatching agents)
- Manual command (e.g., `<cli> dashboard` — for humans browsing between runs)
- Claude Code `SessionStart` hook (automatic when orchestrator agent is invoked)

**Lifecycle:**
- Start-or-attach: if already running, reuse the existing instance
- Idle timeout: ~4 hours of no API calls → auto-shutdown
- Explicit stop: `<cli> server stop` or Ctrl+C
- SQLite file always persists on disk — data survives server restarts and crashes
- PID file (`.agentic-workflow/server.pid`) for process management

**Port management:**
- Port and port range must be configurable (developers run many things on localhost)
- Default port (e.g., 3117) with automatic fallback to next available port in range
- Port discovery: the workflow must be able to discover which port the server is running on (write port to a well-known file like `.agentic-workflow/server.port`)
- All consumers (scripts, agents, dashboard) read the port file to find the server

**Future consideration:** Cloud-hosted solution — the same server could be deployed to a cloud environment, enabling team collaboration and potentially a subscription model. The API contract should be designed with this in mind (auth headers, multi-tenancy isolation), even if not implemented initially.

### 6. CLI (Deferred)

A CLI tool for humans to interact with the workflow is a long-term goal but is **not in scope** for this backlog item. The CLI's purpose and command surface are not yet fully defined — it would likely focus on dispatching the workflow or specific agents, rather than being used internally by the workflow.

**Short-term impact on design:**
- The HTTP API should be clean and well-documented enough for a future CLI to consume
- The API contract is the durable asset — the CLI would be a thin HTTP client
- The command name is TBD (not "sdlc" — the workflow applies beyond software development)

## Technology Decisions

### Runtime: Bun

**Why Bun:**
- **Built-in SQLite** (`bun:sqlite`) — synchronous, fast, zero native compilation. No `node-gyp` or C++ toolchain needed on user machines
- **Native TypeScript** — run `.ts` files directly, no build step for the server
- **Built-in WebSocket** — `Bun.serve()` with upgrade + pub/sub, no `ws` dependency
- **Built-in bundler** — `Bun.build()` can bundle the React frontend
- **Built-in test runner** — `bun:test` with Jest-compatible API
- **Built-in package manager** — `bun install`, 10-100x faster than npm
- **Auto `.env` loading** — replaces `dotenv`
- **Single binary** (~50MB) — can be bundled with the plugin

**Why not Python:**
- Claude Code does NOT require or install Python (native installer is standalone)
- Python is pre-installed on macOS/Linux but not Windows
- Two-language stack (Python + TypeScript) increases maintenance burden
- The user's expertise is in TypeScript/React, not Python backend

**Why not Node.js:**
- Claude Code does NOT require Node.js (native installer is standalone since npm install is deprecated)
- `better-sqlite3` requires native compilation (node-gyp + C++ toolchain)
- TypeScript requires a transpiler step (ts-node, tsx, or tsc)
- Additional npm dependencies needed for what Bun provides built-in (dotenv, ws, test runner)

**Why not Next.js:**
- Couples the entire stack to the framework (API routes + frontend + server)
- Harder to swap server implementation later
- Bun + React SPA + Hono gives the same capabilities with more flexibility

**Risks and mitigations:**
- **Bun is young (3 years, VC-funded):** Design the API contract and DB schema as language-agnostic. The server can be rewritten in Node.js/Python/Go without changing agents, scripts, or frontend. This is NOT a one-way door.
- **Windows support less mature:** Core APIs (serve, sqlite, static files) work. Test in CI. If issues arise, the Bun runtime can be swapped for Node.js.
- **Plugin distribution:** Bun binary (~50MB) would need to be bundled or users install it. Evaluate distribution strategy during design phase.

### Frontend: React

**Why React:**
- User has deep Next.js/React expertise — fastest development velocity
- Complex features (inline doc commenting, Kanban DnD) benefit from React's component model
- Rich npm ecosystem (dnd-kit, react-markdown, mermaid, recharts)
- Builds to static files — served by any HTTP server, portable to VS Code webview in the future

### Database: SQLite

**Why SQLite:**
- Single-file database — simplest possible persistence
- `bun:sqlite` is built-in — zero dependencies
- Survives server restarts (data on disk)
- Every language has a mature SQLite driver — not locked to Bun
- More than sufficient for the data volumes (hundreds to low thousands of items)

### API Framework: Hono

**Why Hono:**
- Lightweight (~20KB), Bun-native API router
- Express-like middleware model (familiar patterns)
- Built-in CORS, validation helpers
- TypeScript-first with type-safe routes

### Minimal npm Dependencies

**Backend (mostly built-in to Bun):**
- `hono` — API routing/middleware
- `zod` — request validation
- `drizzle-orm` + `drizzle-kit` — ORM + DB migrations

**Frontend:**
- `react` + `react-dom`
- `marked` or `react-markdown` — markdown rendering
- `mermaid` — diagram rendering (client-side)
- `tailwindcss` — styling
- `dnd-kit` or `SortableJS` — Kanban drag-and-drop
- Gantt chart library (frappe-gantt or similar)

## Architecture Overview

```
                    ┌──────────────────────────────────────┐
                    │         Bun Server (daemon)           │
                    │                                      │
Claude Agent ──MCP──┤  MCP Handler ────┐                   │
                    │                  │                   │
Browser ─────HTTP───┤  HTTP API ───────┤── PM Service ─────┤── SQLite DB (always)
                    │  (Hono routes)   │      │            │
Future CLI ──HTTP───┤  Static Files ───┘  Sync Engine ─────┤──→ GitHub (fire-and-forget)
                    │  (React SPA)         │               │──→ Jira (future)
                    │                      │               │──→ Linear (future)
                    │                WebSocket Hub ────────┤──→ Dashboard (real-time push)
                    └──────────────────────────────────────┘
                                   │
                            .agentic-workflow/
                            ├── workflow.db      (SQLite database)
                            ├── server.pid       (process ID)
                            └── server.port      (discovered port)
```

**Key properties:**
- Agents never touch the dashboard — they call MCP tools or shell scripts, the server pushes updates to the dashboard via WebSocket
- The PM service layer is shared — MCP, HTTP, and sync engine all call the same functions
- External PM sync is centralized in the server — retries, queuing, and conflict resolution in one place
- The database is the single source of truth for local state

## CC Plugin Precedents

- **claude-mem** (39K stars) — ships Express + React viewer as a CC plugin. MCP server via stdio. Proves the "plugin with web server + dashboard" pattern
- **compound-engineering** (10.8K stars) — uses Bun as primary runtime in a CC plugin
- Both validate that this architecture is feasible within the CC plugin ecosystem

## Not a One-Way Door

The API contract (REST + JSON), MCP tool schemas, and database schema (SQLite) are the durable assets. Everything else can be swapped:

| Component | Can be swapped to | Impact |
|-----------|------------------|--------|
| Server runtime (Bun) | Node.js, Deno, Python, Go | Rewrite server handlers. API contract unchanged. |
| Frontend (React) | Vue, Svelte, vanilla JS | Rebuild SPA. API unchanged. |
| Database (SQLite) | PostgreSQL, libSQL, Turso | Schema migration. Server changes. API unchanged. |
| API framework (Hono) | Express, Fastify, Elysia | Rewrite routes. API contract unchanged. |
| MCP transport | stdio → http | Config change. Tool schemas unchanged. |

## Open Questions for Design Phase

1. **Work item ID strategy** — how to handle GitHub IDs vs local IDs in a dual-write system (see Pillar 3)
2. **Bun distribution** — bundle with plugin, require user install, or auto-install via hook?
3. **Port discovery protocol** — exact file format and fallback behavior when server is not running
4. **Database schema** — work items, comments, telemetry, document annotations (comment threads)
5. **MCP tool granularity** — one tool per operation vs. fewer tools with action parameters?
6. **Migration path** — how to migrate existing `.workflow/items/` data into the new SQLite database
7. **Auth model for future cloud hosting** — token-based? Multi-tenant isolation strategy?
8. **CLI command name** — TBD (not "sdlc" — the workflow is not limited to software development)
9. **Offline resilience** — behavior when the server is down (fallback to file-based adapter? Queue operations?)

## Related Issues and References

- [#111 Local-First PM System](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/111) — predecessor, introduced file-based PM. Now complete.
- [#227 Dual-Write PM Layer](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/227) — dual-write architecture this builds on. Complete.
- [#109 PM Abstraction Layer](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/109) — adapter interface this implements. Complete.
- [#283 Scale Local PM Storage](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/283) — this backlog item supersedes or absorbs BL#283
- [#289 CLI Scripts Redesign](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/289) — scripts evolving to call HTTP API; related but separate
- [#112 Plugin Packaging](https://github.com/carlosboeing/agentic-sdlc-workflow/issues/112) — the server would be packaged as part of the plugin
- `docs/2-design/2026-03-11-agentic-sdlc-extraction-design.md` — original dashboard design (§ "Decision: Dashboard")
- Run 15 retro rec AM — worktree PM sync (this server eliminates the problem)
- Run 17 retro rec AO — external PM creation failure / ID collision (centralized sync engine addresses this)
- Retro recommendations tracker — recs AM, AO, AN, AI all addressed by this architecture
