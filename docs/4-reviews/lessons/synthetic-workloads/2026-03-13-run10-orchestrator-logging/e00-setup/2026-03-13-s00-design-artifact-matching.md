---
date: 2026-03-13
author: carlosboeing
agent: orchestrator
story: "Phase 0 — Artifact detection for design/plan skip"
tags: [orchestrator, design, artifact-matching, convention-gap]
severity: high
---

# Design Artifact Matching Uses Unreliable Grep

## What happened

During Phase 0 of backlog #27, the orchestrator ran `grep -rl "27" docs/2-design/` to check for existing design docs. The grep matched files that contained the number "27" anywhere in their text (e.g., line counts, word counts, dates) but actually belonged to different backlog items (`backlog: 14` and `backlog: 1` in their YAML frontmatter). The orchestrator incorrectly concluded the design phase could be skipped.

## Root cause

The artifact matching logic does a raw content grep for the backlog issue number. This is unreliable because:

1. Short numbers like "27" appear frequently as incidental text (word counts, line numbers, dates)
2. Design docs have a YAML `backlog:` field that specifies which backlog item they belong to, but the grep doesn't target this field
3. File naming conventions don't include the backlog issue number

## Prevention

The orchestrator's artifact matching should use structured metadata, not raw grep. Options (from most to least reliable):

1. **Grep the YAML frontmatter field:** `grep -rl "^backlog: 27$" docs/2-design/` — matches only files where the frontmatter `backlog` field equals 27
2. **Include backlog number in filename:** e.g., `2026-03-13-backlog-27-orchestrator-logging.md` — enables glob matching
3. **Query GitHub issues:** Check if a `type/docs` issue with the `backlog/27-*` label exists and is closed (indicates design was approved)

Recommended: Option 1 (frontmatter grep) as the primary check, with Option 3 as a fallback. Update the orchestrator agent's Phase 0 instructions to use `grep -rl "^backlog: 27$"` instead of `grep -rl "27"`.
