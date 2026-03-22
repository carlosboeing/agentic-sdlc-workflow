---
date: 2026-03-18
author: carlosboeing
agent: builder
story: "E03-S03 (#222) — item-telemetry.sh Adapter Refactor"
tags: [builder, worktree, git, platform, pathing]
severity: high
---

# Worktree Path Confusion: Read/Edit Tools vs Bash CWD

## What happened

The builder was dispatched in a worktree at
`.claude/worktrees/agent-a535f706` on branch `worktree-agent-a535f706`.

The task said to check out and work on `e03-s03/telemetry-refactor`.
Running `git checkout e03-s03/telemetry-refactor` in Bash (CWD = the
worktree) succeeded — it changed THIS worktree to the story branch.

However, Read and Edit tool calls using the path
`/Users/carlos/Projects/carlos/agentic-sdlc-workflow/...` (the main repo
root) were targeting the main working tree, not the worktree. The main
working tree was on a different branch (`e03-s01/local-lifecycle`).

The result: edits appeared to succeed (no errors), tests were run via `cd
/Users/carlos/.../agentic-sdlc-workflow && bash ...` (main tree) and
passed, but git status showed no changes. The edited files were in the
MAIN working tree which was then switched by the orchestrator — losing the
uncommitted edits silently.

## Root cause

1. Read/Edit tools use the ABSOLUTE path given. If the absolute path points
   to the main repo root, the tool operates on the main working tree.
2. Bash CWD is the WORKTREE (`.claude/worktrees/agent-a535f706`), so
   relative paths (`scripts/item-telemetry.sh`) refer to worktree files.
3. When the orchestrator switches the main working tree to another branch
   mid-session, any uncommitted edits in the main working tree are lost.

## Prevention

- ALWAYS use absolute paths rooted in the worktree, not the main repo root:
  ```
  WORKTREE_PATH=$(pwd)
  # Use: $WORKTREE_PATH/scripts/item-telemetry.sh
  # Not: /path/to/repo/scripts/item-telemetry.sh
  ```
- Verify the path prefix before every Read/Edit call when in a worktree:
  the path MUST start with `$(pwd)/` (the worktree root), not the main
  repo root.
- After making edits, immediately run `git status --short` (Bash, relative
  path) to confirm the changes appear as tracked modifications in the
  worktree — not just in the main working tree.
- The correct approach: `git checkout e03-s03/telemetry-refactor` in the
  worktree, then use paths like
  `/path/to/.claude/worktrees/agent-XXXX/scripts/...` for all Read/Edit
  operations.
