---
date: 2026-03-19
author: orchestrator
story: "E00-Setup — Backlog #243 Phase Restructuring"
tags: [orchestrator, designer, process, research, systemic]
severity: critical
---

# Research First, Not Assume First — Systemic Pattern

## What happened

Across backlog #243 and prior runs, a consistent pattern emerged: agents (orchestrator, designer) work from training data assumptions instead of actively researching current reality. Three incidents in one session:

1. **Subagent nesting** — Orchestrator proposed Approach E (builder dispatches reviewer) without checking if subagents can spawn subagents. A 1-minute official doc lookup would have revealed the hard cap. Cost: 2 wasted dispatch cycles (~20 minutes, ~260K tokens).

2. **Agent tool metrics** — For 14+ runs, we captured 3 of ~10 available fields from the Agent tool return data. `duration_api_ms` (API time excluding stalls), `input_tokens`/`output_tokens` (for accurate cost), and `total_cost_usd` (direct platform cost) were all available but never used. Every cost estimate, throughput calculation, and "stalled" detection was working with incomplete data.

3. **Gantt stall visualization** — Identified as a problem in the workflow optimization analysis, discussed at length, proposed complex workarounds — but nobody researched whether the platform already provides the data to solve it (`duration_api_ms`).

## Root cause

Agents default to reasoning from training data (which is stale by definition) instead of using available research tools (WebSearch, WebFetch, MCP servers) to check current reality. The tools exist and are available — they're just treated as optional "nice to have" rather than mandatory first steps.

This creates a compounding problem: early assumptions become "facts" that downstream agents build upon. By the time someone challenges the assumption, multiple design-plan-build cycles may have executed on a false premise.

## The pattern

1. Agent encounters a technical question ("can subagents dispatch agents?", "what metrics does the Agent tool return?")
2. Agent reasons from training data → produces a plausible-sounding answer
3. Answer is treated as fact by all downstream agents
4. Only discovered as wrong when a human challenges it or a runtime failure occurs
5. Cost: wasted cycles, suboptimal solutions, accumulated technical debt

## Prevention

### For the orchestrator
- Before discussing ANY approach with the user that depends on platform capabilities, **research the platform docs first**
- Before proposing solutions to observed problems (stalled Gantt bars, missing metrics), **research what the platform already provides**
- When a technical question arises during conversation, say "let me research that" instead of reasoning from memory

### For the designer
- The Research & Feasibility Verification section (added in this session) is a start
- Research should happen BEFORE generating approaches, not after selecting one
- Every design doc should cite sources for platform capabilities it depends on

### For ALL agents
- **WebSearch and WebFetch should be among the first tools used**, not the last
- "I know this from training data" is not verification — it's an assumption
- The threshold for "should I research this?" should be very low — if there's any doubt, research
- Check CLAUDE.md "Known Platform Limitations" but don't trust it as complete — it only contains limitations that have been discovered and documented

### Convention change needed
- Orchestrator agent: add mandatory research step before discussing approaches with user
- Designer agent: research requirements already added (this session)
- Both: default to "research then propose" not "propose then maybe research"
