---
date: 2026-03-23
author: carlosboeing
agent: builder
story: "E02-S03 (#373) — End-to-End Integration Tests"
tags: [builder, testing, architecture, async]
severity: medium
---

# Async/Sync Interface Mismatch Between DatabaseUpserter and PullSyncService

## What happened

E01-S01 defined a `DatabaseUpserter` interface in `pull-sync.ts` with synchronous
return types (`upsertPage(): UpsertPageResult`, `linkHierarchy(): number`). The
unit tests used synchronous mocks. This worked because mock values are sync.

E01-S02 implemented `DatabaseUpserter` class with `async` methods returning
`Promise<UpsertPageResult>` and `Promise<number>`. No tests caught this because
unit tests for `PullSyncService` never used the real `DatabaseUpserter`.

When E02-S03 integration tests wired the real `DatabaseUpserter` into
`PullSyncService`, the calls without `await` returned `Promise` objects. Code like
`result.itemsCreated += upsertResult.created` would silently produce `NaN` because
`Promise.created` is `undefined`.

Also: `upsertComments` was defined in the `PullSyncService.DatabaseUpserter`
interface but never implemented in the real `DatabaseUpserter` class.

## Root cause

Unit tests for `PullSyncService` (E01-S01) mocked all dependencies, so the
async/sync mismatch and missing `upsertComments` were invisible. Integration tests
expose these gaps because they wire real implementations together.

## Prevention

1. **Define interfaces to match implementation signatures.** If the implementation
   is async (`Promise<T>`), the interface must declare `Promise<T>` (or use
   `| Promise<T>` union for backward compatibility with sync mocks).

2. **Include all interface methods in the implementation.** When a story defines
   an interface with a method, the story that implements the class must implement
   every method — including `upsertComments`. Reviewers should check this.

3. **Write integration tests to verify wiring** — they catch interface mismatches
   that unit tests cannot because unit tests mock dependencies.

## Fix applied

- Changed `PullSyncService.DatabaseUpserter` interface to accept
  `UpsertPageResult | Promise<UpsertPageResult>` (and same for other methods).
- Added `await` to `PullSyncService.pullSync()` calls for `upsertPage`,
  `upsertComments`, and `linkHierarchy`.
- Added `DatabaseUpserter.upsertComments()` implementation.
- Integration tests use `DatabaseUpserterAdapter` to bridge field name difference
  (`itemsCreated`/`itemsUpdated` in class vs `created`/`updated` in interface).
