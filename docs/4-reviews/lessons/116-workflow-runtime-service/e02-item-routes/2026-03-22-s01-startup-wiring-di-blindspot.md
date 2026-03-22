---
date: 2026-03-22
author: carlosboeing
agent: builder
story: "E02-S01 (#337) — Item CRUD and Query Routes"
tags: [builder, di, testing, runtime-failure, wiring]
severity: critical
---

# Startup Wiring DI Blind Spot

## What happened

`createApp({ db })` correctly registers item routes when `db` is passed.
Unit tests use `createApp` directly with a test DB injected, so they all
pass. However, the daemon startup path — `commandStartForeground()` →
`startServer()` → `createApp()` — never initialized a database and never
passed one to `createApp`. Result: the server started with only the health
endpoint available. All item routes were silently absent at runtime.

The `ServerOptions` interface lacked a `db` field, so even if a caller
tried to pass `db` to `startServer()`, TypeScript would silently accept it
as an excess property (structural typing) without the value being used.

## Root cause

Tests inject `db` directly into `createApp`, bypassing `startServer()`
entirely. This is the classic DI blind spot: the component under test
(`createApp`) is correctly wired, but the production entry point
(`startServer`) sits between the test and the real startup sequence.
Without a test that calls `startServer({ db })` and hits a live HTTP
endpoint, the missing link is invisible.

The existing `server.ts` already had a conditional `if (options.db)`
guard in `createApp` — so the feature was designed to be db-optional.
But `startServer()` never passed `db` through to `createApp`, making
it impossible for the guard to do its job in production.

## Prevention

1. **Always write a wiring test that exercises `startServer()` directly**,
   not just `createApp()`. Specifically: start a server on port 0, hit an
   endpoint that requires DB, assert 200. This catches any gap between the
   factory function (testable in isolation) and the entry point (the actual
   production path).

2. **`ServerOptions` must include all parameters that `createApp()` needs.**
   If `AppOptions` has a field (`db`), `ServerOptions` must also have it
   (or a superset). A structural diff between these two interfaces is a
   wiring gap.

3. **Initialize the database before starting the server.** In
   `commandStartForeground()` and `commandMcp()`: call `createDatabase()`
   and `migrate()` before `startServer()`. This also enables graceful
   shutdown via `closeDatabase(sqlite)` which runs a WAL checkpoint before
   closing.
