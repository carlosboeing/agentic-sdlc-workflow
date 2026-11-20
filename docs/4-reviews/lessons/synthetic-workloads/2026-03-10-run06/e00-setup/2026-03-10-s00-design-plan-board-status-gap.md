---
date: 2026-03-10
author: carlosboeing
agent: orchestrator
story: "E00-Setup — Design/Plan phase board management"
tags: [orchestrator, board-management, design, plan, github-api]
severity: medium
---

# Design/Plan Issues Stuck in "In Progress" After Merge

## What happened

After auto-merging the design doc PR (#164) and plan PR (#173) into the integration branch, the orchestrator called `issue-merged.sh` to close the issues (#163, #165) and set their board status to Done. The script reported "not found on project board" for both issues, leaving them stuck in "In Progress" on the board even though the issues were closed.

The root cause was a race condition: the designer/planner agents added the issues to the board, but by the time `issue-merged.sh` ran, the `gh project item-list` query returned stale data and couldn't find the items by issue number. The `jq` select filter returned empty, so the status update was skipped.

## Root cause

1. **Stale board data after add:** `gh project item-add` succeeded, but the subsequent `gh project item-list` query (used by `issue-merged.sh`) didn't reflect the newly added items immediately.
2. **No retry logic in `issue-merged.sh`:** The script tries once to find the item ID and gives up silently if not found.
3. **Orchestrator didn't verify:** After calling `issue-merged.sh`, the orchestrator didn't verify the board status was actually updated.

## Prevention

1. **Orchestrator must verify board status** after calling `issue-merged.sh` for design/plan issues — query the board directly with known item IDs and fix if needed.
2. **Consider adding retry logic to `issue-merged.sh`** — wait 2-3 seconds and retry if the item isn't found on the first attempt.
3. **Cache board item IDs in the state file** when issues are first added to the board, so the orchestrator can use them directly instead of relying on `item-list` queries.
4. **Orchestrator should own design/plan board transitions** the same way it owns story board transitions — set the status directly using known item IDs rather than delegating to `issue-merged.sh`.
