---
date: 2026-03-20
author: retro
story: "E00 Setup -- Designer phase (PR #291)"
tags: [designer, orchestrator, convention, issue-tracking]
severity: medium
---

# Designer Did Not Create Design Doc Issue

## What happened
The designer dispatched for Run 15 (backlog #290) opened PR #291 for the design doc but did not create a separate `type/docs` issue to track the design doc work. The convention in CLAUDE.md's hierarchy diagram shows a "Design doc issue" as a child of the backlog item, but the designer only created the PR. PR #291 used `Closes #291` (self-referential -- a PR closing itself).

## Root cause
The `designer.md` agent instructions do not include an explicit step to create a docs issue before starting work. The convention is implied by the CLAUDE.md hierarchy diagram (`Design doc issue (#24) -- designer creates, links to backlog`) but is not stated as a procedural requirement.

## Prevention
- Add explicit "create design doc issue" step to `designer.md`: "Before writing the design doc, create a `type/docs` issue using `item-create.sh docs --title '[#<backlog>] Write design doc for <topic>' ...` and link it as a child of the backlog issue."
- The orchestrator could also enforce this: after the design dispatch completes, verify that a docs issue exists linked to the backlog item.
