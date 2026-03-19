---
date: 2026-03-10
author: orchestrator
story: "All Wave 1 stories (#96, #97, #98, #100)"
tags: [orchestrator, github-api, board-status, parallel-dispatch]
severity: critical
---

# Board Status Skipped Stages During Parallel Dispatch

## What happened

The project board lifecycle should be: **Planned → Todo → In Progress → In Review → Done**. During the Run 3 build, Wave 1 stories (#96, #97, #98) jumped directly from **Planned to Done**, skipping every intermediate stage. The board was visually wrong for the entire duration of the build.

Two distinct failures:

### Failure 1: Missing Todo transition

After the plan PR was merged, no agent set the 7 story statuses from "Planned" to "Todo". The orchestrator skipped this step and went straight to dispatching builders. The CLAUDE.md convention says:

> **Todo** — Plan approved, ready for builder dispatch. Set by: Human (on plan PR merge).

In autonomous mode, the orchestrator acts in place of the human and must perform this transition.

### Failure 2: Parallel builder board updates silently failed

Wave 1 dispatched 4 builders concurrently (3 haiku + 1 sonnet). Each builder ran `item-start.sh` (→ In Progress) and `item-review.sh` (→ In Review). The 3 haiku builders' board updates were silently lost — likely due to a GitHub Projects API race condition when 4 agents hit `gh project item-edit` simultaneously. The sonnet builder's updates succeeded, as did all Wave 2/3 builders (lower concurrency).

The `issue-merged.sh` calls at the end (run sequentially by the orchestrator) worked correctly, masking the problem by jumping everything to Done.

## Root cause

1. **Todo transition was nobody's job in autonomous mode.** The CLAUDE.md says "Set by: Human (on plan PR merge)" but in autonomous mode there is no human. The orchestrator auto-merged the plan PR but didn't assume the human's responsibility for the Todo transition.

2. **GitHub Projects API doesn't handle concurrent `item-edit` calls reliably.** The `item-start.sh` and `item-review.sh` scripts each do `gh project item-list` + `gh project item-edit`, and 4 concurrent instances likely saw stale data or hit rate limits without surfacing errors.

## Prevention

1. **Orchestrator must set stories to Todo after plan PR merge.** Add an explicit step: after merging the plan PR in autonomous mode, iterate through all stories and set them to "Todo" on the board (sequentially).

2. **Orchestrator must set stories to In Progress before dispatching builders.** Don't rely on builder scripts for board updates. The orchestrator sets the status sequentially before dispatch (one `gh project item-edit` per story, no concurrency).

3. **Orchestrator must verify board status after each wave.** After parallel builders complete, query the board and fix any stories that didn't transition correctly. This is a sequential operation so it won't hit concurrency issues.

4. **Builder scripts should still update the board** as a defense-in-depth measure, but the orchestrator is the source of truth for board status.
