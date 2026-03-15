---
date: 2026-03-15
author: orchestrator
story: "E00-Setup — Phase 0 backlog status transition"
tags: [orchestrator, board-management, status-transition]
severity: medium
---

# Backlog Item Should Be In Progress From Design Phase

## What happened

The orchestrator set the backlog issue (#56) to **In Progress** only at Phase 5 (before dispatching builders). During Phase 1 (Design) and Phase 2 (Plan), the backlog issue remained at **Backlog** status on the project board. This is incorrect — design and plan work are active work on the backlog item.

## Root cause

The orchestrator agent file (`orchestrator.md`) instructs setting the backlog to In Progress in Phase 5 ("Before the first wave dispatch, set the backlog issue board status to In Progress"). There is no instruction to set it earlier during design/plan phases.

## Prevention

- The orchestrator should set the backlog issue to **In Progress** at the beginning of Phase 1 (Design), not Phase 5 (Build). Design and plan phases are part of the backlog item's lifecycle and represent active work.
- Update `orchestrator.md` Phase 0 or Phase 1 to include: `./scripts/issue-set-status.sh <backlog-issue> in-progress`
- The convention in CLAUDE.md should clarify that "In Progress" for a backlog item starts when any phase of work begins (design, plan, or build), not just when builders are dispatched.
