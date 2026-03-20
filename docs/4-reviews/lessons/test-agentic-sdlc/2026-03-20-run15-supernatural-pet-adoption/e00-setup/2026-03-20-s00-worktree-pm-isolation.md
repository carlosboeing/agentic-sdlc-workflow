---
date: 2026-03-20
author: retro
story: "E00 Setup -- Planner worktree dispatch"
tags: [planner, orchestrator, worktree, local-pm, convention]
severity: high
---

# Worktree-Isolated Planner Creates PM Items in Wrong Location

## What happened
The planner, dispatched with `isolation: "worktree"`, created local PM items (`.workflow/items/*.md` files) in the worktree directory. After the planner's PR (#300) was merged into the integration branch, only the plan document was included -- the PM item files remained in the ephemeral worktree. The orchestrator had to manually create PM items on the integration branch (commit `c60fb40`).

## Root cause
The local-first PM adapter (backlog #227) writes to `.workflow/items/` in the current working directory. When the planner runs in a worktree, the CWD is the worktree path, not the main repo's working tree. The planner's PR only captures files committed to the `docs/` branch -- `.workflow/items/` files are not part of the plan PR because they are infrastructure files, not plan content.

## Prevention
- Option A: After merging a worktree-dispatched planner's PR, the orchestrator should copy `.workflow/items/` files from the worktree (or from the merged branch diff) to the integration branch's working tree.
- Option B: Modify the local PM adapter to detect worktree mode (check if CWD differs from the git toplevel of the main repo) and write to the main repo's `.workflow/items/` path instead of the worktree's.
- Option C: Have the planner include `.workflow/items/` files in its PR commit alongside the plan document.
- This is the first run after the local-first PM system (backlog #227) was integrated with worktree isolation. The interaction was not tested during BL227 because that backlog did not use worktree-isolated planners.
