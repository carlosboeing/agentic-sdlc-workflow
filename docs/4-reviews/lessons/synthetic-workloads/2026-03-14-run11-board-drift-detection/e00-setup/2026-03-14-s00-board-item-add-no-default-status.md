---
date: 2026-03-14
author: carlosboeing
agent: orchestrator
story: "Phase 0 — Board item initialization"
tags: [orchestrator, github-api, board, convention-gap]
severity: medium
---

# gh project item-add Does Not Set a Default Status

## What happened

During Phase 0 of backlog #41, the orchestrator added the issue to the project board via `gh project item-add` but did not explicitly set the status. The item appeared on the board with `status: null`, making it invisible in status-filtered views.

## Root cause

`gh project item-add` adds the item to the project but does not assign a status value. The board's "Backlog" column requires an explicit `item-set-status.sh <N> backlog` call after adding.

## Prevention

Phase 0 must always include both steps sequentially:
1. `gh project item-add <project-number> --owner <owner> --url <url>`
2. `./scripts/item-set-status.sh <N> backlog`

Update the orchestrator agent's Phase 0 instructions to make the status-set call explicit after every `item-add`.
