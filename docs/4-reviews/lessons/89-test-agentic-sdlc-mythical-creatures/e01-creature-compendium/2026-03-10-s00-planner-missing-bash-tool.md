---
date: 2026-03-10
author: orchestrator
story: "Pre-dispatch — planner agent setup"
tags: [orchestrator, architecture, dispatch, agent-config]
severity: medium
---

# Planner Agent Missing Bash Tool

## What happened

The planner agent was dispatched to create the implementation plan for backlog #89. It successfully wrote the plan document but could not execute any GitHub CLI commands (`gh issue create`, `gh api graphql`, `gh project item-add`, etc.) because `Bash` was not in its tool list.

The planner worked around this by generating a shell script (`scripts/setup-field-guide-issues.sh`) with all the `gh` commands, then asked the orchestrator to run it. This added an unnecessary manual step and broke the autonomous flow.

## Root cause

The planner agent's YAML frontmatter listed:
```
tools: Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, Task
```

`Bash` was omitted, even though the planner's own instructions contain dozens of `gh` and `git` commands it's expected to run (issue creation, sub-issue linking, project board updates, branch creation, PR creation).

## Prevention

- Added `Bash` to the planner's tool list: `Read, Write, Edit, Grep, Glob, Bash, WebSearch, WebFetch, Task`
- When adding instructions to an agent that reference CLI commands, verify the agent's `tools` field includes `Bash`
- The planner's phase boundary ("does not modify code") is not violated — `gh` and `git` commands are GitHub/git operations, not production code changes
