---
date: 2026-03-19
author: orchestrator
story: "E00-Setup — Backlog #243 Phase Restructuring"
tags: [orchestrator, design, process, planner-deviation]
severity: high
---

# Never Skip Design Phase for Complex/Ambiguous Work

## What happened

Backlog #243 had a detailed issue body with problem analysis, five evaluated approaches, a chosen approach (Approach E: prompt augmentation), and acceptance criteria. The orchestrator skipped the design phase reasoning that the issue body was sufficient. The planner was dispatched directly.

The planner deviated from the agreed approach — implementing Approach D (parallel reviews after all builds) instead of Approach E (lifecycle coupling via prompt augmentation). The planner's rationale was technically valid from its perspective: it concluded that the Agent tool constraint makes lifecycle coupling impractical, and parallel reviews achieve the same wall-clock for evenly-balanced stories.

The planner missed the key insight (established through conversation with the user): that reviews are ALREADY parallel (Gantt chart evidence), and the real bottleneck is the wait gate — which only lifecycle coupling solves.

## Root cause

The design reasoning existed only in an ephemeral conversation, not in a durable design doc. The planner couldn't access the Gantt chart analysis, the wait gate discovery, or the rationale for why Approach D is insufficient. Without this context, the planner made a reasonable but incorrect architectural choice.

The issue body described WHAT to build (Approach E) but not the full WHY chain that led there. The designer's role is to produce that WHY chain as a durable artifact.

## Prevention

- **Always run the design phase for complex or ambiguous work**, even when the backlog issue is detailed. Complexity indicators:
  - Multiple viable implementation approaches
  - Architectural decisions with trade-offs
  - Changes to core infrastructure (orchestrator, dispatch model, agent interactions)
  - Non-obvious technical constraints (like the Agent tool wait gate)
- **The designer's value is the reasoning process**, not just the output doc. Designers explore the codebase, challenge assumptions, analyze evidence, and document the full decision chain. This is exactly what happened in the orchestrator-user conversation — it should have been the designer's job.
- **A detailed backlog issue is NOT a substitute for a design doc.** The issue describes requirements and the chosen approach. The design doc explains the technical analysis, evidence, constraints, alternatives evaluated in depth, and the reasoning chain that makes the chosen approach unambiguous to downstream agents.
- **Convention proposal:** The orchestrator should default to running the design phase for any backlog item with `difficulty/hard` stories or multiple viable approaches in the issue body. "Skip design" should require explicit user instruction, not be inferred from issue detail level.
