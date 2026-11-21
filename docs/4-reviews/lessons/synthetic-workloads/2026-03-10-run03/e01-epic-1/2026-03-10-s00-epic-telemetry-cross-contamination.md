---
date: 2026-03-10
author: carlosboeing
agent: orchestrator
story: "Epic telemetry — #94, #95"
tags: [orchestrator, telemetry, combined-pr]
severity: medium
---

# Epic Telemetry Cross-Contamination

## What happened

The orchestrator posted identical aggregate telemetry (all 7 stories across both epics) on both the E01 epic issue and the E02 epic issue. The E01 breakdown showed E02 stories (#100, #101, #102) and vice versa.

Additionally, the estimated cost was inflated: the `--model sonnet` flag priced all 548K tokens at the sonnet rate (~$3.29), when the actual per-story cost from the breakdown was ~$1.30 (3 haiku + 3 sonnet + 1 opus).

## Root cause

The combined PR strategy (both epics in one PR) led the orchestrator to treat telemetry as a single aggregate, posting the same comment on both epic issues. Each epic should get telemetry for only its own stories:
- E01: stories #96, #97, #98, #99
- E02: stories #100, #101, #102
- PR #104: full combined breakdown (correct to show all 7)

## Prevention

- When posting epic-level telemetry, filter the breakdown to only include stories that belong to that specific epic (check the `epic/` label on each story)
- The combined PR telemetry is the only place where all stories should appear together
- For mixed-model epics, either compute per-model costs in the breakdown (accurate) or note that the headline cost is an estimate. The breakdown table is the source of truth for cost.
