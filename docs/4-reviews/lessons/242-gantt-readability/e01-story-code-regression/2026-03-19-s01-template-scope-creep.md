---
date: 2026-03-19
author: retro
story: "E01-S01 (#249) -- Story Code in Breakdown Table and Gantt Labels"
tags: [builder, reviewer, scope-creep, template, telemetry]
severity: medium
---

# Template Scope Creep Caught by Reviewer

## What happened

E01-S01's builder modified `scripts/templates/telemetry.md` (updating the breakdown header row from 5 to 6 columns) alongside the `compute-dispatches.py` changes. This template change was explicitly scoped to E01-S02 (issue 250) per the plan. The premature change broke 3 of 44 shell integration tests in `tests/scripts/test-issue-telemetry.sh` because the test assertions still expected the 5-column header.

The reviewer (dispatch 4) correctly identified this as scope creep (C1) and noted the broken tests (C2). The fix was a clean revert of the template change (commit `8039f37`), taking 1m 18s.

## Root cause

The builder saw that the breakdown data rows already had 6 columns (from its own `compute_from_dispatches()` changes) and assumed the template header should match. This is a logical assumption but violates the story's "Files to modify" boundary, which listed only `compute-dispatches.py` and its test file.

## Prevention

- Builders should treat the "Files to modify" section in the story issue as a hard constraint. If a file not listed in that section appears to need modification, the builder should note the gap (e.g., in a code comment or commit message) rather than making the change. This aligns with existing rec O.
- Reviewers should verify that the diff only touches files listed in the story's scope. This is already part of the reviewer's checklist but was the first time it caught a real scope violation in a Python/template split.
