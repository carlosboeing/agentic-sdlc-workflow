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

Approved — **Updated 2026-03-23:** The server adapter is now the default local PM. `pm.adapter` names the remote sync target (e.g., `"github"`), not the local storage backend.

## Context

The existing PM system uses `pm.sh` to route between adapters based on the `pm.adapter` config value:
- `"github"` -- dual-write: local file I/O (primary) + GitHub API (fire-and-forget sync)
- `"local"` -- local file I/O only

The Workflow Runtime Service introduces a SQLite-backed server that handles both local persistence and external sync internally. The shell scripts need to call this server instead of performing file I/O directly.

## Decision

The workflow server (SQLite via HTTP API) is the local PM adapter. The `pm.adapter` config field names the remote sync target for dual-write (e.g., `"github"`). The old file-based adapter (`adapters/pm/local/`) is retained for tests only.

**Adapter routing:**

```
pm.sh always sources scripts/lib/adapters/pm/server/*.sh as the local adapter
  -> pm_* functions call HTTP API via curl
  -> Server writes to SQLite

pm.adapter = "github" (optional sync target)
  -> pm.sh additionally sources adapters/pm/github/*.sh as external
  -> Dual-write wrappers: local (sync) + external (fire-and-forget)

pm.adapter = "" (no sync target)
  -> Local only, no external sync
```

The old three-way routing (`"server"` / `"github"` / `"local"`) was simplified in BL#364 to remove the implementation detail from the config. The server IS the local adapter — there's no choice to make.

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
- **Auto-start:** The orchestrator starts the server in Phase 0. Individual PM calls do not trigger server start.

## Alternatives Considered

1. **Keep file-based adapter as default with server opt-in:** The original BL#116 approach. Rejected because it required users to explicitly configure `pm.adapter: "server"` — the server should just be the default local PM.
2. **Use Unix sockets instead of HTTP:** Lower overhead than TCP, but less portable (Windows), harder to debug (no curl), and the latency difference is negligible for this workload.
3. **Embed SQLite directly in shell scripts:** Use `sqlite3` CLI instead of a server. Rejected because it does not provide WebSocket events for the dashboard, MCP tools for agents, or the sync queue for reliable external sync.
