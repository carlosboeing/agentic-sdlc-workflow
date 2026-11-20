---
date: 2026-03-10
author: carlosboeing
agent: retro
story: "E01-S01/S02/S03 (#112, #113, #114) -- Wave 1 parallel dispatch"
tags: [orchestrator, parallel-dispatch, worktree, git, race-condition]
severity: high
---

# Parallel Builders Share Working Directory Without Worktree Isolation

## What happened

Wave 1 dispatched 3 haiku builders concurrently for E01-S01 (#112), E01-S02 (#113), and E01-S03 (#114). All three builders operated in the same working directory without git worktree isolation (`isolation: "worktree"` was not used in the Agent tool dispatch). Each builder checked out its own story branch from the epic branch, but because they shared the working directory, branch checkout operations could theoretically race.

No failures occurred in this run because the three stories wrote to independent files (`kepler-442b.md`, `gliese-667c.md`, `proxima-station.md`) in the same directory. However, if two builders attempted `git checkout` simultaneously, or if stories modified shared files, the lack of isolation could cause data loss or corrupted commits.

## Root cause

The Agent tool supports `isolation: "worktree"` for creating isolated git worktrees per subagent, but the orchestrator did not use this parameter. The convention docs do not mandate worktree isolation for parallel dispatch.

## Prevention

- The orchestrator should use `isolation: "worktree"` when dispatching parallel builders to eliminate branch checkout races.
- CLAUDE.md's parallel dispatch section should recommend (or require) worktree isolation when more than one builder runs concurrently.
- At minimum, the orchestrator should verify after parallel dispatch that each story branch contains only its expected files and no cross-contamination occurred.
