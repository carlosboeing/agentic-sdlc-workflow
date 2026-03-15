---
date: 2026-03-14
author: orchestrator
story: "Run 11 backlog telemetry (#41)"
tags: [orchestrator, telemetry, gantt, convention-gap]
severity: medium
---

# Gantt Color Tags Applied Incorrectly

## What happened

The orchestrator tagged every task in the lifecycle Gantt chart with `:active`,
rendering the entire timeline in violet. Build tasks should have no tag (emerald)
and review tasks should use `:done` (yellow). The resulting chart lost its visual
differentiation between phases.

## Root cause

The color tagging rules were defined in `scripts/templates/telemetry.md` (the
rendering template), but the orchestrator composes the `--gantt` parameter inline
without reading that file. The orchestrator agent file (`orchestrator.md`) said
"color rules are defined in the template" — an indirection that doesn't work at
composition time. The example in `orchestrator.md` only showed `:active` tasks
(designer, planner), reinforcing the wrong pattern.

## Prevention

1. Inlined the color tagging table directly in `orchestrator.md` where the
   orchestrator reads it during Gantt composition.
2. Added a brief reference in `CLAUDE.md` for cross-agent awareness.
3. Expanded the example Gantt in `orchestrator.md` to show all three tag types
   (`:active` for design/plan/retro, no tag for builds, `:done` for reviews).
4. Added explicit warning: "Do not use `:active` on build or review tasks."
