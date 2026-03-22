---
title: "ADR-0005: Bun as Server Runtime"
date: 2026-03-22
author: carlosboeing
agent: planner
status: approved
backlog: 116
---

# ADR-0005: Bun as Server Runtime

## Status

Approved

## Context

The Workflow Runtime Service (BL#116) needs a TypeScript server runtime with:
- Built-in SQLite support (for the PM database)
- WebSocket support (for real-time dashboard updates)
- Static file serving (for the React SPA)
- Fast startup (daemon starts in Phase 0, must be under 2 seconds)
- Test runner (TDD is mandatory in this project)

The conventional choice is Node.js with `better-sqlite3` + `ws` + `express` + `vitest`. This requires 4+ dependencies for capabilities that Bun provides as built-in APIs.

## Decision

Use Bun as the runtime for the workflow server.

**Key built-in capabilities used:**
- `bun:sqlite` -- synchronous SQLite with WAL mode, transactions, and prepared statements
- `Bun.serve()` -- HTTP server with native WebSocket upgrade and pub/sub
- `bun:test` -- test runner with `describe`/`test`/`expect`
- `bun build` -- bundler for the React SPA
- Native TypeScript execution (no compilation step)

## Consequences

### Positive
- Significantly fewer dependencies (SQLite, WebSocket, test runner are all built-in)
- Fast startup time (~100ms vs ~500ms for Node.js + better-sqlite3)
- Single toolchain for server, tests, and frontend bundling
- `bun:sqlite` API is simpler than `better-sqlite3` (no native compilation)

### Negative
- Bun must be installed as a development dependency on all contributor machines
- Younger ecosystem than Node.js -- fewer production examples and community answers
- `bun:sqlite` is synchronous (blocks the event loop), which is acceptable for this workload (hundreds of items, sub-millisecond queries) but would need replacement for high-concurrency scenarios
- Some edge cases in Bun's Node.js compatibility layer may surface with the MCP SDK

### Mitigations
- **Portability:** The API contract (HTTP routes, JSON schemas, database schema) is language-agnostic. The server can be rewritten in Node.js, Python, or Go without changing agents, scripts, or frontend. This is explicitly not a one-way door.
- **Bun installation:** One command: `curl -fsSL https://bun.sh/install | bash`. The orchestrator checks for Bun in Phase 0 and prints instructions if missing.
- **MCP SDK compatibility:** Verified in the design doc (section 12.1) that `@modelcontextprotocol/sdk` uses standard APIs. Build-time verification is included in E03-S01.

## Alternatives Considered

1. **Node.js + better-sqlite3 + ws + express:** More battle-tested, but 4+ extra dependencies, native compilation for better-sqlite3, and slower startup.
2. **Deno:** Good built-in tooling but weaker SQLite support (no built-in), smaller package ecosystem.
3. **Python (FastAPI + sqlite3):** Different language from the rest of the project (TypeScript types, React frontend). Would fragment the codebase.
