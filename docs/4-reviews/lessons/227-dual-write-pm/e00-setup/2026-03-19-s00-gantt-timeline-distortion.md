---
date: 2026-03-19
author: orchestrator
story: "E00 — Orchestrator telemetry (post-build session)"
tags: [orchestrator, telemetry, gantt, duration, agent-tool]
severity: medium
---

# Gantt Timeline Distortion from Agent Tool Duration and Session Gaps

## What happened

The Gantt chart for BL227 was unreadable due to two compounding issues:

1. **E01-S01 reported 91m duration but only 82K tokens.** The sibling builds (E01-S02, E01-S03) used more tokens (114K, 98K) but completed in 9m and 5m respectively. The Agent tool's `duration_ms` includes wall-clock time — so a usage limit pause mid-build inflates the number. There is no separate "active compute time" metric.

2. **A 9-hour session gap** (API 529 error → user resumed next day) created dead space in the timeline. Gap compression was attempted (collapsing idle gaps to 30s spacers) but the 91m anomalous bar still dominated the compressed chart.

## Root cause

- The Agent tool's `duration_ms` is wall-clock, not compute time. Usage limit waits, API throttling, and session interruptions are included.
- The Gantt renderer uses `duration_ms` directly as bar width. One anomalous value distorts the entire chart scale.
- Gap compression addressed the inter-wave idle time but not the intra-dispatch idle time (usage limit waits within a single Agent tool call).

## What to fix

1. **Detect anomalous durations.** Compare tokens/duration ratio across sibling dispatches in the same wave. Flag outliers (e.g., E01-S01: 82K tokens / 91m = 15 tok/s vs E01-S02: 114K / 9m = 211 tok/s — a 14x ratio difference).

2. **Gap compression in Gantt.** Collapse idle gaps between waves to small spacers so the X-axis shows agent running time. The implementation was built and reverted (commit `4f51e4d`, reverted in `645be97`) — it worked mechanically but interacted badly with problem 1. Needs both fixes together.

3. **Consider adding a `gantt_note` template variable.** When gaps are compressed, render a note below the chart explaining the compression. The template and script plumbing was built (in the reverted commit) and can be re-used.

## Prevention

- Future backlog item to address Gantt timeline accuracy (could be part of existing BL166 Telemetry Diagrams).
- The state file schema could add an optional `active_duration_ms` field for dispatches where anomaly detection adjusts the value.
