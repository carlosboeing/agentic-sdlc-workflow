---
date: 2026-03-13
author: orchestrator
story: "Phase 0/2 — Board status updates after planner"
tags: [orchestrator, github-api, rate-limit, performance]
severity: medium
---

# GraphQL Rate Limit Exhaustion from item-list Queries

## What happened

The planner's 58 API calls (creating issues, adding to board, setting statuses) exhausted the GitHub GraphQL rate limit (5000 points/hour). After the planner completed, the orchestrator couldn't set stories to Todo because `item-set-status.sh` uses `gh project item-list` which is a heavy query fetching all 200+ project items.

## Root cause

`gh project item-list` generates a complex GraphQL query that costs many points (fetches all items with all fields). The `item-set-status.sh` script calls it twice per invocation (once for lookup, once for post-mutation verification). Combined with the planner's high API usage, this exhausted the budget.

## Prevention

Use a lighter GraphQL query to look up individual item IDs:

```graphql
query {
  repository(owner: "carlosboeing", name: "agentic-sdlc-workflow") {
    issue(number: $N) {
      projectItems(first: 1) {
        nodes { id }
      }
    }
  }
}
```

This costs ~1 point vs potentially 200+ for `item-list`. Consider updating `item-set-status.sh` to use this approach instead of `item-list`, or adding a `--item-id` flag to bypass the lookup entirely when the ID is already known.
