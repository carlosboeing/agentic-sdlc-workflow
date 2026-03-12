---
date: 2026-03-10
author: builder
story: "E03-S01 (#142) — SdlcWorkflowTool"
tags: [builder, testing, di, nsubstitute, interface-extraction]
severity: medium
---

# Sealed Class Mockability — Extract Interface Before Injecting

## What happened

`SdlcWorkflowTool` needed to call `ClaudeDispatchTool.DispatchAsync`. The initial
test setup tried `Substitute.For<ClaudeDispatchTool>()`, which fails at runtime
because `ClaudeDispatchTool` is `sealed partial`. NSubstitute cannot create proxies
for sealed types.

## Root cause

`ClaudeDispatchTool` was sealed (correctly, for production safety) but had no
interface abstraction. Any higher-level tool that depended on it would be
untestable unless an interface was extracted first.

## Prevention

- **Whenever a concrete tool needs to call another tool's methods**, extract an
  interface before wiring the dependency. Pattern:
  1. Create `IClaudeDispatch` with the needed method signature.
  2. Implement it on `ClaudeDispatchTool` (add to the base list: `: IKernelTool, IClaudeDispatch`).
  3. Register in DI: `services.AddScoped<IClaudeDispatch>(sp => sp.GetRequiredService<ClaudeDispatchTool>())`.
  4. Depend on `IClaudeDispatch` in the consumer — never on the concrete class.

- **Architect should note** this in story acceptance criteria when a new tool
  wraps an existing tool: "Extract interface X from Tool Y to enable testability."

## Scope of fix

Added `/src/NN.Tools.DevOps/Dispatch/IClaudeDispatch.cs` with `DispatchAsync`
and updated `ClaudeDispatchTool` to implement it. DI registration updated in
`ServiceCollectionExtensions.cs`.
