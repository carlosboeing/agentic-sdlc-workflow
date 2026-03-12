---
date: 2026-03-12
author: retro
story: "E01-S02 (#8) — The Open-Plan Migration"
tags: [builder, orchestrator, worktree, git, remote-push]
severity: medium
---

# Builder in Worktree Did Not Push Story Branch to Remote

## What happened

E01-S02's builder (haiku, running in a worktree) completed its story branch locally but did not push it to the remote. The orchestrator had to manually push the branch before merging. Without this intervention, the branch would have existed only locally, risking data loss.

## Root cause

Builder agent instructions cover pushing branches, but the behavior may differ when the builder runs inside a worktree rather than the main checkout. The worktree's git context (shared `.git` directory) should support `git push` identically, but the builder may not have been configured to push explicitly in worktree mode.

## Prevention

- Builder agent instructions should explicitly state that story branches must be pushed to remote regardless of whether the builder is in the main tree or a worktree.
- The orchestrator should verify remote branch existence after each worktree-dispatched builder completes, before proceeding to merge.
