---
date: 2026-03-10
author: builder
story: "E03-S01 (#142) — SdlcWorkflowTool"
tags: [builder, testing, di, scoped, nsubstitute, sqlite]
severity: high
---

# AddTransient Causes Scope to Dispose Shared NNDbContext in Tests

## What happened

Tests for `SdlcWorkflowTool` registered the shared in-memory `NNDbContext` as
`AddTransient<NNDbContext>(_ => _db)` in the test service collection. The tool
uses `IServiceScopeFactory` and `await using var scope = scopeFactory.CreateAsyncScope()`.
When the `using` block exits, the scope disposes all disposable services it
created — including the transient `NNDbContext` it resolved. This disposed the
shared `_db` instance, causing `ObjectDisposedException` when the test then
accessed `_db.SdlcWorkflows` to verify results.

## Root cause

`AddTransient` with a factory that returns the same instance still registers the
instance as owned by the scope for disposal purposes. When the scope disposes,
it calls `Dispose()` on that instance.

`AddSingleton` tells the DI container the instance is externally owned (root
container lifetime) and the scope does NOT dispose it when released.

## Prevention

In tests that use `IServiceScopeFactory` and then verify DB state after a scope
exits, **always register the shared `NNDbContext` as `AddSingleton`**:

```csharp
// CORRECT — scope release does not dispose _db
services.AddSingleton(_db);

// WRONG — scope release calls _db.Dispose()
services.AddTransient<NNDbContext>(_ => _db);
```

This pattern is consistent with `SelfReviewServiceTests` (correct usage) but
the lesson wasn't captured explicitly. Now documented here for future test
authors using `IServiceScopeFactory` with a shared in-memory context.
