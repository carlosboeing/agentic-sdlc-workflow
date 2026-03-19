---
date: 2026-03-19
author: retro
story: "E00 -- Retro analysis of backlog 242 telemetry"
tags: [orchestrator, telemetry, state-file, story-code]
severity: medium
---

# State File Empty Stories Dict Prevents Story Code Extraction in Own Telemetry

## What happened

The backlog-level telemetry posted on issue 248 shows `--` in the Story column for all dispatches, despite the Story column being the primary deliverable of E01. The `_build_story_labels()` function reads from `state.epics.*.stories` in the orchestrator state file, but for backlog 242 this section is empty (`"stories": {}`). The fallback extraction mechanism (E01-S02's contribution) also returned empty because it depends on the same data source.

## Root cause

The orchestrator initializes `epics.e01.stories` and `epics.e02.stories` as empty dicts in the state file and never populates them with story metadata (issue number, branch name, epic assignment). The `state.sh update --story` command updates story status but does not record the branch or epic mapping. The `_build_story_labels()` function expects entries like `{"249": {"branch": "e01-s01/story-code-breakdown"}}` to extract story codes.

## Prevention

- The orchestrator should populate `epics.*.stories` during Phase 4 (branch setup) when it creates story branches. Each entry should include at minimum `{"branch": "<branch-name>", "issue": <issue-number>}`.
- The `state.sh` schema should enforce that story entries include a `branch` field.
- Until this is fixed, the backlog-level telemetry for runs that use `--dispatches-from-state` will show `--` for all story codes. The story code feature works correctly when the state file is properly populated (as tested in the Python test suite).
