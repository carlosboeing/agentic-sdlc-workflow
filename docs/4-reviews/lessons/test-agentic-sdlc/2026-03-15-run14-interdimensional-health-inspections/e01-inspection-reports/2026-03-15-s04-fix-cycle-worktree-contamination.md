---
date: 2026-03-15
author: retro
story: "E01-S04 (#92) -- Special Event Inspection: The Probability Cafe"
tags: [orchestrator, worktree, fix-cycle, cross-contamination]
severity: high
---

# Worktree Cross-Contamination During Fix Cycle Dispatch

## What happened

During E01-S04's second fix cycle (dispatch 19, commit `9aa16c7`), the file `violation-quantum-bistro.md` from E02-S01's story appeared on the E01-S04 branch. The third reviewer pass (dispatch 20) flagged this as a critical issue. The orchestrator resolved it by manually removing the file in commit `d537441`.

## Root cause

The fix cycle builder for E01-S04 was dispatched in a worktree that still contained artifacts from the Wave 2 parallel dispatch. E02-S01 (which produced `violation-quantum-bistro.md`) ran in the same wave as E01-S04. The existing "Post-worktree cleanup" convention (`git clean -fd` after parallel dispatch) was applied after the initial Wave 2 build but not re-applied before the fix cycle dispatch. The stale file was picked up by the builder's git operations.

## Prevention

1. The orchestrator must run post-worktree cleanup (`git status --short` + `git clean -fd`) before **every** worktree-dispatched builder, including fix cycle dispatches -- not only after the initial parallel wave.
2. After fix cycle dispatches, verify the story branch contains only expected files before merging: `git diff --name-only <epic-branch>...<story-branch>` should list only files belonging to that story.
3. Consider adding a pre-commit check in the builder agent that verifies no files outside the story's expected path are staged.
