---
date: 2026-03-11
author: carlosboeing
agent: retro
story: "E02-S02 -- Council Recommendation"
tags: [orchestrator, github-api, rate-limiting, telemetry]
severity: high
---

# GitHub GraphQL Rate Limiting Blocked Operations in Wave 3

## What happened

During Wave 3 (E02-S02, the final story), the GitHub GraphQL API rate limit was exceeded. This blocked board updates and telemetry posting. The `gh issue view` and `gh project item-list` commands returned rate-limit errors.

This is the second consecutive run (also observed in Run 6) where rate limiting impacted operations, suggesting the cumulative API usage across design, plan, build, and review phases consistently approaches the limit for 5-story runs.

## Root cause

Each story lifecycle generates multiple GraphQL API calls: `item-add`, `item-list`, `item-edit` for board management, `addSubIssue` for hierarchy, plus `issue view` and `issue comment` for telemetry. With 5 stories, 2 epics, design/plan phase board operations, and the `tr -d` workaround requiring `item-list` calls, the total API consumption exceeds the hourly rate limit.

## Prevention

- The orchestrator should batch board operations where possible and introduce backoff when nearing the limit.
- Consider caching `item-list` results in the state file to reduce redundant API calls.
- The `tr -d '\x00-\x1f'` pipe needed for `jq` to parse `gh project item-list` output adds an extra call that could be avoided if the GitHub CLI fixed its control character output.
