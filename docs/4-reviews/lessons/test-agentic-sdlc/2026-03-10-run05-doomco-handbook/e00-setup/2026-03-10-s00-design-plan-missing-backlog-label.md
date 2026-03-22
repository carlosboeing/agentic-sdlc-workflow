---
date: 2026-03-10
author: carlosboeing
agent: orchestrator
story: "N/A — design and plan phases"
tags: [orchestrator, designer, planner, github-api, labels]
severity: medium
---

# Design and Plan Issues Missing Backlog Label

## What happened
The designer created issue #147 (Write design doc) and the planner created issue #149 (Write implementation plan) without the `backlog/146-doomco-handbook` label. All epic and story issues had the label correctly, but the design/plan doc issues were missed. The orchestrator had to retroactively add the labels.

## Root cause
Neither the designer nor planner agent instructions explicitly require adding the `backlog/<N>-<slug>` label to design doc and plan issues. The CLAUDE.md convention section lists the label pattern but doesn't explicitly call out that design/plan doc issues must carry it. The agents only applied `type/docs`.

## Prevention
- Update designer and planner agent instructions to explicitly require the `backlog/<N>-<slug>` label on design doc and plan issues
- Update CLAUDE.md to clarify that ALL issues under a backlog item — including design docs and plans — must carry the backlog label
- Orchestrator should verify labels on all issues as a post-phase check
