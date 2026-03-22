---
date: 2026-03-15
author: carlosboeing
agent: orchestrator
story: "Backlog-level telemetry (#83)"
tags: [orchestrator, telemetry, wall-clock, parallelism]
severity: high
---

# Wall-Clock Duration Posted as Sequential Sum

## What happened

The backlog-level telemetry for Run 14 posted `Actual Duration (with parallelism) = 102m 43s` — identical to the sequential sum of all 36 dispatches. The correct wall-clock (critical path through parallel waves) was 74m 4s, a 28m 38s difference. The error was caught during manual review before the PR was merged.

## Root cause

Three failures compounded:

1. **`$SECONDS` tracking failed.** The orchestrator tried to record `$SECONDS` early in the session, but it returned 0 and was never reliably captured at the end. `$SECONDS` resets in subshells and is fragile across long sessions.

2. **No computed fallback.** The state file contains all data needed to compute the critical path (dispatch timestamps, durations, and parallel wave structure), but the orchestrator has no automated way to derive wall-clock from this data. Without a measured or computed value, the orchestrator reused the sequential sum.

3. **No validation.** `item-telemetry.sh` accepts whatever `--wall-clock` value is passed. It does not check whether `wall-clock == duration` is suspicious when the dispatch log shows parallel dispatches.

## Prevention

1. **Compute critical path from the state file.** After the last dispatch completes, the orchestrator should compute wall-clock by walking the dispatch log:
   - Group dispatches by wave (same `started_at` timestamp)
   - For each parallel group, take `max(duration_ms)`
   - Sum the critical path segments
   - This eliminates dependence on `$SECONDS`

2. **Add validation to `item-telemetry.sh`.** When `--wall-clock` equals `--duration` and the state file (or `--dispatches-from-state`) shows parallel dispatches, emit a warning: "Wall-clock equals sequential duration — did you forget to compute the critical path?"

3. **Add a `compute_wall_clock()` function to the orchestrator.** A Python snippet that reads the state file and returns the critical path duration. Run it before calling `item-telemetry.sh`.

4. **Do not use `$SECONDS` as the primary wall-clock source.** It is unreliable across long sessions, subshells, and session interruptions. Use the computed critical path as the primary source, and `$SECONDS` as a cross-check if available.
