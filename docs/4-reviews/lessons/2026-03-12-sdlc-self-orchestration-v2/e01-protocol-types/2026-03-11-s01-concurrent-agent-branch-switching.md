---
date: 2026-03-11
author: builder
story: "E01-S01 (#196) — Protocol Types + CcStreamParser Core"
tags: [builder, git, concurrency, parallel-dispatch]
severity: high
---

# Concurrent Agent Git Branch Switching

## What happened

Multiple story agents (E01-S01, E02-S01, E05-S01) were dispatched in parallel (Wave 1).
Each agent calls `git checkout <story-branch>` during setup. Because all agents share the
same git working directory, each checkout overwrites the other agents' working tree
context. This caused:

1. Commits made while ostensibly "on branch X" actually landed on whichever branch
   another agent had switched to between shell invocations.
2. Untracked implementation files were lost when another agent's `git checkout` was
   processed between my `Write` tool call and my `git add` call.
3. Files I created with the Write tool appeared missing in `git status` because the
   working tree had been switched to a different branch mid-flow.

## Root cause

Each `Bash` tool call is an independent shell invocation. The git `HEAD` is a single
file (`.git/HEAD`) shared across all concurrent agent processes. When Agent A runs
`git checkout branch-A` and Agent B runs `git checkout branch-B`, whichever executes
last wins for the next shell invocation — regardless of what the previous `git checkout`
returned.

The CLAUDE.md note "Agent threads always have their cwd reset between bash calls" is
about the working directory, but the same principle applies to git branch state: any
git checkout state made in a previous Bash call may be overwritten by the time the next
call executes.

## Prevention

1. **Chain all git-dependent operations in a single Bash call** using `&&` to minimise
   the window where another agent can switch the branch. Instead of:
   ```bash
   git checkout e01-s01/protocol-types  # Agent B may switch here
   git add files && git commit           # Now on wrong branch
   ```
   Use:
   ```bash
   git checkout e01-s01/protocol-types && git add files && git commit
   ```

2. **Always prefix `git` operations with the explicit `-C <repo-path>`** and chain with
   branch verification:
   ```bash
   git -C /repo checkout branch && git -C /repo add file && git -C /repo commit -m "..."
   ```

3. **Use `git cherry-pick` for recovery** when commits land on the wrong branch.
   Dangling commits are recoverable via `git reflog`.

4. **Verify `git branch --show-current` immediately before commits** (in the same
   shell invocation, not a separate call).

5. **Prefer `git add` with explicit absolute paths** to avoid ambiguity about what's
   being staged across concurrent working tree states.

## Note for orchestrator

When dispatching parallel builders, consider using `git worktree add` to give each
agent an isolated checkout of the same repo. This would eliminate branch-switching
interference entirely.
