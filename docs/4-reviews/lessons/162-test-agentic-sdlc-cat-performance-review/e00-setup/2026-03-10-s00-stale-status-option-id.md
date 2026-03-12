---
date: 2026-03-10
author: architect
story: "E00-S00 — Plan creation for #162"
tags: [architecture, github-api, board-management]
severity: medium
---

# Stale Status Option ID in Architect Agent File

## What happened

The architect agent file (`.claude/agents/architect.md`) contains a "Planned" status option ID of `2b7091c1` which does not match the project board's actual option ID. The correct ID is `61757ea9` as documented in `CLAUDE.md`. All 7 `item-edit` calls failed with "The single select option Id does not belong to the field" before retrying with the correct ID.

## Root cause

The architect agent file has its own copy of status option IDs that diverged from the canonical values in `CLAUDE.md`. The agent file was not updated when the project board option IDs were last verified.

## Prevention

- Agent files should reference CLAUDE.md for status option IDs rather than duplicating them.
- When status option IDs are updated in CLAUDE.md, propagate changes to all agent files that reference them.
- The architect agent should always use the CLAUDE.md values as the source of truth.
