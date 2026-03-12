---
date: 2026-03-10
author: retro
story: "Design phase -- Intergalactic Travel Advisory"
tags: [designer, orchestrator, agent-tools, bash, workflow]
severity: medium
---

# Designer Agent Missing Bash Tool -- Orchestrator Must Handle Git Workflow

## What happened

The designer agent does not have `Bash` in its YAML frontmatter tool list. This means the designer cannot run `gh`, `git`, or any shell commands. As a result, the orchestrator had to handle the entire git workflow for the design phase: creating the docs branch, committing the design doc, creating the GitHub Issue (#107), opening the PR (#108), and merging it.

This is the same class of issue that affected the architect in Run 3 (lesson: `89-mythical-creatures/e01-creature-compendium/2026-03-10-s00-architect-missing-bash-tool.md`), which was fixed by adding `Bash` to the architect's tool list. The designer agent was not included in that fix.

## Root cause

The designer agent file (`.claude/agents/designer.md`) does not include `Bash` in its tools list. The agent tool list auditing convention added in the Run 3 retro was not applied to the designer agent.

## Prevention

- Add `Bash` to the designer agent's tool list so it can handle its own git workflow (branch creation, commit, PR, issue linking).
- When applying a fix to one agent (e.g., adding Bash to architect), scan all agents for the same gap. The convention change propagation rule in CLAUDE.md ("proactively update all files that reference the changed convention") applies here.
