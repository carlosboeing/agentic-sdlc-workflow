---
date: 2026-03-22
author: carlosboeing
agent: builder
story: "E05-S04 (#348) — WebSocket Integration and Activity Feed"
tags: [builder, testing, react, bun, jsx]
severity: medium
---

# React Missing from Server devDependencies Causes TSX Import Failures in Tests

## What happened

After merging the epic branch (E05-S01/S02/S03), running `bun test` showed 30 pre-existing failures in `tests/frontend/item-detail-components.test.ts`. All 30 failures were:

```
error: Cannot find module 'react/jsx-dev-runtime' from '...some-component.tsx'
```

The test file tries to `await import("../../frontend/src/components/StatusBadge")` (a `.tsx` file). Bun resolves the JSX transform by looking for `react/jsx-dev-runtime` in `node_modules`. But `react` and `react-dom` were only listed in the server's `package.json` under `devDependencies` — they were never installed.

## Root cause

The previous story builder added `react` and `react-dom` to `package.json`'s `devDependencies` but may not have run `bun install` at the server level, or the packages were installed only in a worktree that didn't persist. Either way, the production bun.lock for the server directory did not include react at the time the tests were written.

When `bun test` runs, it resolves imports relative to the server `node_modules/`, which did not have react. The frontend's own `node_modules/` (installed by the build script) would have it, but `bun test` does not look there for server-level test runs.

## Prevention

- When a test file imports a `.tsx` file, `react` must be installed in the test runner's `node_modules/` (server-level in this case, not just frontend-level).
- The fix: run `bun add react react-dom --dev` from `server/` to install react in `server/node_modules/`.
- The `bun.lock` file should capture this. After running this fix, all 30 tests pass.
- Future builders: if you see `Cannot find module 'react/jsx-dev-runtime'` in bun test output, it means react is missing from the server-level node_modules. Run `bun add react react-dom --dev` from `server/`.
