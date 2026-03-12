---
date: 2026-03-12
author: retro
story: "E01 Wave 1 — Parallel worktree dispatch"
tags: [orchestrator, worktree, git, parallel-dispatch]
severity: medium
---

# Worktree-Dispatched Builders Leave Untracked Files in Main Working Tree

## What happened

After Wave 1 completed (3 parallel builders via `isolation: "worktree"`), an untracked file was left in the main working tree. This blocked subsequent merge operations, requiring the orchestrator to run `rm -rf` cleanup before proceeding with epic merges.

## Root cause

Worktree isolation creates separate working directories for each builder, but those worktrees share the same `.git` directory as the main checkout. When worktrees are cleaned up after agent completion, some artifacts may remain in the main tree's file system — likely directory stubs or temporary files created during the worktree lifecycle.

## Prevention

- After all worktree-dispatched builders complete, the orchestrator should run a `git status` check on the main working tree and clean up any untracked files before proceeding to merges.
- Consider adding a `git clean -n` (dry run) step to the post-parallel-dispatch verification to detect stale files without accidentally deleting wanted changes.
