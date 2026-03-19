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

## pm.sh idempotency guard (related, same file)

The idempotency guard in pm.sh (lines 29-41) is broken and over-engineered:

1. **Guard never matches.** `_PM_SH_COMPUTED_EXT` is computed at line 35 before `config.sh` is sourced (line 93), so it's always empty on the first call. The saved value at line 287 is also empty. On the second call, `CFG_PM_ADAPTER` is set (persists from first load), so `_PM_SH_COMPUTED_EXT="github"` but `_PM_SH_LOADED_EXTERNAL=""` — mismatch, guard fails, loader re-executes every time.

2. **Over-engineered tracking.** The guard tracks three things (`_PM_SH_LOADED`, `_PM_SH_LOADED_DIR`, `_PM_SH_LOADED_EXTERNAL`) to detect config changes between calls. But config never changes mid-session — if it does, everything breaks anyway. The guard should just be `[ -n "${_PM_SH_LOADED:-}" ]`.

3. **Unnecessary exports.** `PM_ADAPTER`, `PM_ADAPTER_DIR`, `PM_EXTERNAL` are exported (line 282) but every consumer sources pm.sh directly (same process). No known subprocess reads these without sourcing. The exports may be unnecessary but need an audit before removing — could have subtle downstream effects.

### What to fix

- Simplify guard to `[ -n "${_PM_SH_LOADED:-}" ]` — one variable, one check.
- Audit whether `export PM_ADAPTER PM_ADAPTER_DIR PM_EXTERNAL` is needed by any subprocess.
- Document the rationale for export vs shell variable choices in pm.sh.
