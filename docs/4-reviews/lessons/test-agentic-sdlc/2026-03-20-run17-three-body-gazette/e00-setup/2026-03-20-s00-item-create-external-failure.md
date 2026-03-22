---
date: 2026-03-20
author: carlosboeing
agent: designer
story: "E00 Setup -- Designer phase (backlog #303)"
tags: [designer, issue-tracking, design, pm-scripts]
severity: medium
---

# item-create.sh External Failure Causes Number Collision with PR

## What happened
Running `item-create.sh docs` to create the design doc issue returned "WARNING: External pm_create_item failed. Falling back to local-only." The script created a local PM item (.workflow/items/304.md) and reported success with number 304, but the GitHub issue was never created. When `gh pr create` ran next, it got number 304 from GitHub. The PR body referenced `Closes #304` which pointed to itself (a PR closing itself), not a separate issue.

## Root cause
`item-create.sh` has a fallback path that creates only the local PM item when the GitHub API call fails. It still reports success and a local ID number. The next GitHub-created entity (in this case, the PR) takes the same number from GitHub's auto-increment, causing a collision between the local PM ID and the actual GitHub object.

## Prevention
- After `item-create.sh` reports success, verify the GitHub issue actually exists before proceeding: `gh issue view <N>` should return an issue (not a 404 or a PR).
- If the external create failed, create the issue manually with `gh issue create` and update the local PM item's ID to match the actual GitHub issue number.
- The orchestrator or designer should check for the "WARNING: External pm_create_item failed" message and treat it as a recoverable error, not a silent success.
