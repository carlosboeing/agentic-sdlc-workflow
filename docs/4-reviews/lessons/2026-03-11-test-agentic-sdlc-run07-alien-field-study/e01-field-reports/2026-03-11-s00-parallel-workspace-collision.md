---
date: 2026-03-11
author: retro
story: "E01-S01/S02/S03 (#209, #210, #211) -- Wave 1 parallel dispatch"
tags: [orchestrator, parallel-dispatch, worktree, git, workspace-collision]
severity: critical
---

# Parallel Builders Caused Workspace Collision (Commute Report on Brunch Branch)

## What happened

Wave 1 dispatched 3 builders in parallel (E01-S01 haiku, E01-S02 haiku, E01-S03 sonnet) without git worktree isolation. All three shared the same working directory. The commute report file (`report-the-commute.md`) from E01-S01 appeared on the E01-S03 brunch story branch. This required a fix commit (`c249257`) to remove it before the story could merge cleanly.

The fix commit message explicitly states "remove commute report from brunch story branch" -- confirming cross-contamination between parallel builders sharing a workspace.

## Root cause

The Agent tool was invoked without `isolation: "worktree"`. All three parallel builders checked out different branches in the same working directory. When E01-S01's haiku builder wrote `report-the-commute.md`, it was present in the working tree when E01-S03's sonnet builder committed, causing it to be staged and committed on the wrong branch.

This is the same root cause identified in Run 4 (lesson: `docs/4-reviews/lessons/2026-03-10-test-agentic-sdlc-run04-travel-advisory/e01-destination-profiles/2026-03-10-s00-parallel-dispatch-no-worktree-isolation.md`) but this time it caused an actual defect rather than a theoretical risk.

## Prevention

- The orchestrator MUST use `isolation: "worktree"` when dispatching parallel builders. This is now a confirmed failure mode, not just a theoretical risk.
- Add a convention to CLAUDE.md requiring worktree isolation for parallel dispatch.
- After parallel dispatch completes, the orchestrator should verify each story branch contains only its expected files.
