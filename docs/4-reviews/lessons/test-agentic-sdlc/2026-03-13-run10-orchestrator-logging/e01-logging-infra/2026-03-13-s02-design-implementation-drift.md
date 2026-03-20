---
date: 2026-03-13
author: builder
story: "E01-S02 (#34) — Design Doc Reconciliation"
tags: [builder, design, implementation-drift, documentation]
severity: medium
---

# Design-Implementation Drift in Hook Registration Format

## What happened

During design doc reconciliation for the logging infrastructure, the actual implementation in `.claude/settings.json` differed from the design specification in two key ways:

1. **Hook registration format:** Design showed a nested `matcher` object with `toolName` property, but implementation uses a flat `matcher` string with nested `hooks` array containing `type` and `command` fields.
2. **Tool naming:** Design documentation referenced `Agent` tool name, but Claude Code API uses `Task` as the tool name in hook payloads.

These discrepancies were successfully reconciled in the design doc by updating the specification and adding documentation notes.

## Root cause

The design document was written before final implementation details were locked. Claude Code's hook registration API evolved between design time and implementation time, and the design wasn't updated as implementation progressed. This is a normal part of the design-to-implementation cycle for new platforms.

## Prevention

- **For designers:** When designing against new/evolving platform APIs (like Claude Code), include a "Platform API Discovery" phase before final design approval to lock in actual behavior.
- **For builders:** When implementing designs against new platforms, document actual API format in a parallel tracking doc during implementation, then feed back to the designer for reconciliation.
- **For reviewers:** Verify design docs are reconciled with implementation before accepting PRs that touch design artifacts.

## Future impact

The reconciled design doc now serves as the single source of truth for hook registration, with actual format examples that can be copy-pasted directly into code. This reduces future implementation confusion.
