---
date: 2026-03-10
author: carlosboeing
agent: orchestrator
story: "N/A — design, plan, and orchestrator-setup phases"
tags: [orchestrator, designer, planner, github-api, labels, board-management]
severity: high
---

# Board Management and Label Gaps for Design/Plan Phases

## What happened
Three related gaps were discovered during Run 5:

1. **Missing backlog labels:** Design doc issue (#147), plan issue (#149), and even the backlog item itself (#146) were missing the `backlog/146-doomco-handbook` label. Only epics and stories had it.

2. **Backlog item never added to board at workflow start:** The backlog issue (#146) was never added to the project board or given an initial status. It stayed in "No Status" for the entire workflow until post-merge cleanup. It should have been added with status **Backlog** at Phase 0, then progressed to **In Progress** when the first builder dispatched.

3. **Design/plan doc issues never moved on the board:** Issues #147 (design doc) and #149 (plan) were set to In Progress / In Review by the designer/planner, but never moved to **Done** when their PRs were auto-merged. The orchestrator auto-merged the PRs but didn't update the board status for these doc issues.

## Root cause
- The orchestrator's Phase 0 doesn't include adding the backlog item to the board or setting its initial status
- The orchestrator's Phase 1/2 (Design/Plan) auto-merge steps don't include board transitions for the design/plan doc issues
- Neither designer nor planner agents were instructed to add the `backlog/<N>-<slug>` label to their doc issues
- The backlog item's board status lifecycle was completely undefined

## Prevention
- **Orchestrator Phase 0:** Add backlog item to board with status **Backlog**. When first builder dispatches, set to **In Progress**. After all stories merge, set to **In Review**. After epic PR merges, set to **Done**.
- **Orchestrator Phase 1/2:** After auto-merging design/plan PRs, set the doc issue's board status to **Done** (and close the issue if not already closed)
- **Designer/Planner agents:** Must add `backlog/<N>-<slug>` label to ALL issues they create, including doc issues
- **CLAUDE.md:** Document the full board lifecycle for backlog items and doc issues, not just stories/epics
