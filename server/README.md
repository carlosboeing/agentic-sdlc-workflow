# Workflow Runtime Service

Persistent local server that powers the workflow dashboard, PM backend, document viewer, and MCP tools.

## Prerequisites

- [Bun](https://bun.sh/) (v1.0+) — install with `curl -fsSL https://bun.sh/install | bash`

## Quick Start

```bash
# Install dependencies
cd server && bun install

# Run database migrations
bun run migrate

# Start the server (daemon mode — returns immediately)
bun run src/index.ts start

# Check status
bun run src/index.ts status

# Open the dashboard
open http://localhost:$(cat ../.agentic-workflow/server.port)
```

The server writes its port to `.agentic-workflow/server.port` for discovery. If the default port is taken, it automatically tries the next available port in the configured range.

## Commands

| Command | Description |
|---------|-------------|
| `bun run src/index.ts start` | Start as background daemon (returns immediately) |
| `bun run src/index.ts stop` | Stop the running daemon |
| `bun run src/index.ts status` | Print whether the server is running and on which port |
| `bun run src/index.ts mcp` | Start in MCP mode (used by Claude Code via `.mcp.json`) |

## Development

```bash
# Run with auto-reload on file changes
bun run dev

# Run all tests
bun test

# Build the frontend assets
bun run build:frontend
```

## Configuration

Server settings are configured in `.claude/agentic-sdlc-config.json` under the `server` section:

```json
{
  "server": {
    "port": 3117,
    "portRange": [3117, 3127],
    "idleTimeoutMinutes": 240,
    "logLevel": "info"
  }
}
```

| Setting | Default | Description |
|---------|---------|-------------|
| `port` | `3117` | Preferred port. The server tries this first. |
| `portRange` | `[3117, 3127]` | Fallback range. If the preferred port is taken, the server scans this range for an available port. |
| `idleTimeoutMinutes` | `240` | Auto-shutdown after this many minutes of no API calls. Set to `0` to disable. |
| `logLevel` | `"info"` | Log verbosity (`debug`, `info`, `warn`, `error`). Logs go to stderr and `.agentic-workflow/server.log`. |

## Architecture

```
server/
  src/
    index.ts              ← Entry point (daemon/MCP mode detection)
    server.ts             ← Bun.serve() with Hono router + WebSocket
    lifecycle.ts          ← PID/port file management, idle timeout
    db/                   ← SQLite schema (Drizzle ORM), migrations
    services/             ← PM service layer (items, board, comments, etc.)
    api/                  ← Hono HTTP routes (20+ endpoints)
    mcp/                  ← MCP server (13 tools via stdio)
    adapters/             ← External sync adapters (GitHub)
  frontend/              ← React SPA (Kanban board, item detail, doc viewer)
  tests/                 ← ~500 tests
```

## Runtime Files

When running, the server creates these files in `.agentic-workflow/`:

| File | Purpose |
|------|---------|
| `workflow.db` | SQLite database (persists across restarts) |
| `server.pid` | Process ID of the running daemon |
| `server.port` | Port number the server is listening on |
| `server.log` | Server log output |

These are gitignored. The database persists your workflow data across server restarts.

## Data Migration

On first startup, if the database is empty and `.workflow/items/` contains legacy item files, the server automatically imports them into SQLite. This is a one-time migration — subsequent starts skip it.

The server is now the default local PM adapter. All `pm_*` shell functions route through the server's HTTP API. The old file-based adapter (`scripts/lib/adapters/pm/local/`) is retained for tests only.

To manually trigger migration from legacy files:
```bash
bun run src/db/seed.ts
```
