---
date: 2026-03-15
author: carlosboeing
agent: orchestrator
story: "E00-Setup — PR review findings and insights from Run 12"
tags: [orchestrator, reviewer, content-consistency, board-management, convention-propagation]
severity: medium
---

# PR Review Findings and Insights — Run 12

## Review Findings (from PR #68 review)

### W1: Convention propagation incomplete for In Progress timing (FIXED)

**What happened:** The `orchestrator.md` change moved the backlog In Progress transition from Phase 5 to Phase 1, but `CLAUDE.md` line 138 still said "Orchestrator (sequentially, before dispatch)" — implying the transition happens at builder dispatch time.

**Fix:** Updated CLAUDE.md board status table to reflect the new earlier timing. Commit `e46f05f`.

**Prevention:** Always grep for the concept being changed across all interconnected docs. The convention propagation checklist in CLAUDE.md exists for this reason.

### W2: Inconsistent dash style in review-002.md (FIXED)

**What happened:** `review-002.md` title uses `--` (double hyphen) while all other content files use `—` (em dash). This is a cross-builder consistency issue — different builders in Wave 1 made different formatting choices.

**Root cause:** No explicit formatting standard in the design doc or plan for dash style. Each builder chose independently.

**Prevention:** The planner should include explicit formatting conventions (dash style, date format) in the plan's content rules section when multiple builders produce structurally similar content. See retro recommendation E (format templates for cross-story parallel content).

### W3: Inconsistent date format in review-002.md (FIXED)

**What happened:** `Date Reviewed` uses American format `March 15, 2026` while all other reviews use international format `15 March 2026`.

**Root cause:** Same as W2 — no explicit date format in the design doc.

### S1: Retro frontmatter backlog-pr field says "pending" (FIXED)

**What happened:** The retro doc was written before the PR was created, so `backlog-pr: pending` was correct at the time. But it should be updated once the PR number is known.

**Prevention:** The orchestrator should update the retro doc's frontmatter after the backlog PR is created.

### S2: Guide comparison matrix adds "Cuisine" category

**What happened:** The design doc specified 5 categories (Safety, Amenities, Historical Significance, Instagram-Worthiness, Overall Value). The guide added "Cuisine" as a 6th. This exceeds the minimum and doesn't replace any specified category — it's a creative addition by the builder.

**Status:** No fix needed. Noted for traceability.

## Insights (from orchestrator during the run)

### Config pricing vs. fetch-pricing divergence

The `agentic-sdlc-config.json` has Opus at $15/$75 per M tokens (input/output), while `fetch-pricing.sh` returns $5/$25 (older rates). With the configured 75/25 input/output split, the config computes to ~$30/M blended. Run 12 validates that `item-telemetry.sh` uses config pricing for accurate cost estimates.

### Board drift is a persistent platform bug

The GitHub Projects API accepts status mutations successfully (returns 200), but statuses silently revert later. Observed in Runs 3, 10, 11, and now 12. In Run 12, all stories reverted from In Review to In Progress, and closed issues (#57, #59, #67) reverted from Done to In Progress. The orchestrator had to re-apply all statuses after the run.

### Parallel builder formatting divergence

When multiple builders produce structurally similar content in parallel (Wave 1: 3 reviews), they make independent formatting choices (dash style, date format) unless the plan specifies explicit conventions. This is the same issue identified in Run 5 (retro recommendation E).
