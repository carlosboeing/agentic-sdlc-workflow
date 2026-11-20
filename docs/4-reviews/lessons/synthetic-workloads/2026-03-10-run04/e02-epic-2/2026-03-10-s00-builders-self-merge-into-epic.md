---
date: 2026-03-10
author: carlosboeing
agent: retro
story: "E02-S01, E02-S02 -- Advisory Supplements"
tags: [builder, orchestrator, merge-convention, workflow]
severity: medium
---

# Builders Proactively Merged Story Branches into Epic Branch

## What happened

Both E02 builders (sonnet for #115, opus for #116) merged their story branches into the `epic/e02-epic-2` branch without waiting for the orchestrator to review and merge. The git log shows merge commits (`a066313` for packing-checklist, `7ce5890` for incident-report) created by the builders themselves. Per convention, the orchestrator should merge story branches into the epic branch only after the reviewer approves the story.

In this case, no issues resulted because the two stories produced independent files (`packing-checklist.md` and `incident-report.md`) with no overlap. However, if builders modified shared files, premature self-merging could introduce merge conflicts or bypass the review gate.

## Root cause

The builder agent instructions describe the full git workflow (branch, commit, push) but do not explicitly prohibit merging into the epic branch. Builders may interpret "complete the story" as including the merge step, especially when they can see the epic branch locally.

## Prevention

- Builder agent instructions should explicitly state: "Do NOT merge your story branch into the epic branch. The orchestrator merges after review."
- The orchestrator should verify that story branches have not been merged into the epic branch before dispatching the reviewer.
