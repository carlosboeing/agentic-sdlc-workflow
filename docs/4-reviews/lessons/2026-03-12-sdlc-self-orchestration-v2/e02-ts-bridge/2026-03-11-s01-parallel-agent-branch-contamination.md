---
date: 2026-03-11
author: builder
story: "E02-S01 (#198) — cc-bridge.ts TypeScript Bridge Implementation"
tags: [builder, orchestrator, git, parallel-dispatch, branch-safety]
severity: high
---

# Parallel Agent Branch Contamination

## What happened

When three builder agents ran in parallel (E01-S01, E02-S01, E05-S01), they
shared the same working directory. Other agents' `git checkout` and `git
commit` operations switched the active branch mid-session, causing:

1. `git branch --show-current` returned a different branch than expected
   between consecutive bash calls.
2. A commit from E05-S01 landed on the E02-S01 story branch because the
   branch had been switched by another agent before the commit ran.
3. `git stash --include-untracked` stashed files from all agents, not just the
   current one.

## Root cause

All parallel builder agents share a single git working tree. The Agent tool
dispatches them as subagents in the same process/cwd, so every `git checkout`
affects all agents. There is no isolation between their git operations.

## Prevention

- **Always chain `git checkout <branch> && git add && git commit` in a single
  bash command** to minimise the window where another agent can switch branches.
- **Verify the branch immediately before every commit** with
  `git branch --show-current` in the same command chain.
- **Use `git push --force-with-lease` after rebase** when cleaning up
  contamination commits.
- **Consider worktree isolation** for true parallel dispatch -- each agent gets
  its own worktree directory, eliminating shared-state conflicts.
- The orchestrator should consider serializing builders or using git worktrees
  when dispatching in parallel.
