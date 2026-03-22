---
date: 2026-03-10
author: carlosboeing
agent: retro
story: "E01 (#110), E02 (#111) -- Epic PR reviews"
tags: [reviewer, epic-pr, usage-limits, review-gap]
severity: medium
---

# Epic PR Reviews Skipped Due to Usage Limits

## What happened

Both epic PRs (#118 for E01, #119 for E02) were merged without a formal reviewer agent sign-off. The Sentinel security review ran on both PRs (and approved), but the mandatory reviewer dispatch described in the workflow convention (step 10: "Dispatch reviewer on the epic PR") was not completed. PR #119 received a second Sentinel review that returned "COMMENT" on an empty diff (likely a timing issue where the squash merge had already occurred).

In production, this would mean the final integration review gate was skipped. Per-story reviews had already passed, so the risk was limited to integration-level issues (e.g., merge conflicts, cross-story inconsistencies in the combined diff).

## Root cause

Usage limits (likely API rate limits or session token limits) prevented the orchestrator from dispatching the reviewer agent on the epic PRs. The orchestrator proceeded to merge rather than waiting or retrying.

## Prevention

- The orchestrator should treat the epic PR review as a hard gate: do not merge until the reviewer agent has been dispatched and returned a verdict.
- If usage limits prevent reviewer dispatch, the orchestrator should flag the PR as "review pending" and defer the merge rather than proceeding without review.
- Consider a fallback: if the reviewer agent cannot be dispatched, the PR should remain open for human review.
