---
title: "ADR-0006: Server PM Adapter Pattern"
date: 2026-03-22
author: carlosboeing
agent: planner
status: approved
backlog: 116
---

# ADR-0006: Server PM Adapter Pattern

## Status

Approved

## Context

The existing PM system uses `pm.sh` to route between adapters based on the `pm.adapter` config value:
- `"github"` -- dual-write: local file I/O (primary) + GitHub API (fire-and-forget sync)
- `"local"` -- local file I/O only

The Workflow Runtime Service introduces a SQLite-backed server that handles both local persistence and external sync internally. The shell scripts need to call this server instead of performing file I/O directly.

## Decision

Add `"server"` as a new PM adapter value. When configured, `pm.sh` routes all `pm_*` calls to the server adapter (`scripts/lib/adapters/pm/server/`), which calls the HTTP API via `curl`. The server handles external sync internally through its durable sync queue.

**Adapter routing:**

```
pm.adapter = "server"
  -> pm.sh sources scripts/lib/adapters/pm/server/*.sh
  -> pm_* functions call HTTP API via curl
  -> Server writes to SQLite + enqueues external sync

pm.adapter = "github" (legacy, unchanged)
  -> pm.sh sources local + github adapters with dual-write wrappers
  -> pm_* functions write to .workflow/items/ + fire-and-forget gh CLI

pm.adapter = "local" (unchanged)
  -> pm.sh sources local adapter only
  -> pm_* functions write to .workflow/items/
```

**Graceful fallback:** When `pm.adapter` is `"server"` but the server is not running (health check fails), `pm.sh` automatically falls back to the `"local"` adapter with a stderr warning. This preserves workflow functionality during server downtime, developer setup, or CI environments where the server is not needed.

## Consequences

### Positive
- Shell scripts continue to work unchanged (the `pm_*` function interface is preserved)
- The server becomes the single PM backend when running (no more dual-write at the shell layer)
- External sync moves from `pm.sh` background subshells to the server's durable sync queue (more reliable, with retry and dead-letter handling)
- Graceful degradation ensures the workflow never breaks due to server absence

### Negative
- Adds a network hop (localhost HTTP) to every PM operation when the server is running
- `curl` must be available on the system (universally present on macOS/Linux)
- Server startup latency (~100ms) is added to the first PM operation if the server auto-starts

### Mitigations
- **Latency:** localhost HTTP round-trip is ~1ms. The previous file I/O path was ~5-10ms (YAML parse + write + fsync). The server path is comparable or faster.
- **curl dependency:** curl is part of macOS and every major Linux distribution. Not a practical concern.
- **Auto-start:** The orchestrator starts the server in Phase 0. Individual PM calls do not trigger server start -- they fall back to the local adapter.

## Alternatives Considered

1. **Replace the local adapter entirely:** Remove file-based storage and require the server for all PM operations. Rejected because it removes the fallback path and makes CI setup harder.
2. **Use Unix sockets instead of HTTP:** Lower overhead than TCP, but less portable (Windows), harder to debug (no curl), and the latency difference is negligible for this workload.
3. **Embed SQLite directly in shell scripts:** Use `sqlite3` CLI instead of a server. Rejected because it does not provide WebSocket events for the dashboard, MCP tools for agents, or the sync queue for reliable external sync.
