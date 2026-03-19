---
date: 2026-03-19
author: designer
story: "E00-Setup — Backlog #243 Phase Restructuring (Revision 2)"
tags: [design, architecture, platform-constraint, claude-code]
severity: critical
---

# Subagent Nesting Hard Cap Invalidated Design

## What happened

The original design doc for Phase Restructuring (Revision 1) recommended Approach E (Prompt Augmentation), which required builders (subagents) to dispatch reviewers (sub-subagents) via the Agent tool. The design stated: "The Agent tool supports arbitrary nesting depth" and "There are no known Claude Code platform limitations that prevent 3-level nesting."

Both claims were wrong. The Claude Code platform has a hard cap: subagents cannot spawn other subagents. The Agent/Task tool is explicitly excluded from subagent tool access. This is documented in the official Claude Code documentation and confirmed via GitHub issue anthropics/claude-code#4182.

The constraint was already documented in CLAUDE.md (added between Revision 1 and Revision 2) but the original design was written before this was confirmed.

## Root cause

The designer (Revision 1) checked CLAUDE.md's Known Platform Limitations section and noted that no nesting depth limit was listed. The designer assumed the absence of a documented limitation meant no limitation existed. The designer did not verify the assumption against the official Claude Code documentation or issue tracker.

## Prevention

- **Verify every platform capability your design depends on** against official documentation, not just project-level docs. CLAUDE.md lists known limitations but may not be complete.
- **When a design depends on an untested platform feature** (like 3-level agent nesting), the design MUST include a "Feasibility and Verification" section documenting how each assumption was verified.
- **Web search is essential for platform constraint discovery.** The official Claude Code docs and GitHub issue tracker are the authoritative sources. Project-level docs are derivative.
- **Absence of a documented limitation is not evidence of no limitation.** The correct approach is to search for positive confirmation that the feature works, not to assume it works because no one said it doesn't.
