---
date: 2026-03-15
author: orchestrator
story: "E00-Setup — Telemetry cost underreporting in aggregate breakdowns"
tags: [orchestrator, telemetry, pricing, config]
severity: critical
---

# Telemetry Cost Underreporting — Orchestrator Used Wrong Rates

## What happened

Run 12 backlog-level telemetry reported total cost of ~$4.77 when the correct figure was ~$12.55 — a 2.6x underreport. All Opus dispatch costs were computed at $10/M (the `fetch-pricing.sh` hardcoded default) instead of $30/M (the `agentic-sdlc-config.json` rate).

Per-story telemetry (posted by `item-telemetry.sh` with `--model` and `--tokens`) was correct because the script reads from config. But the epic-level and backlog-level telemetry used `--breakdown` and `--summary` strings that the orchestrator wrote manually with hardcoded/memorized rates.

## Root cause

The orchestrator computed costs mentally (e.g., "35K tokens * $10/M = ~$0.35") without reading the config file first. The config file has Opus at $15/$75 input/output, which with the 75/25 split yields $30/M blended — 3x higher than the memorized $10/M.

The `item-telemetry.sh` script computes costs correctly for simple per-story posts, but for aggregate telemetry (`--breakdown`, `--summary`), the orchestrator constructs the markdown strings directly — and those strings contained the wrong numbers.

## Prevention

1. **orchestrator.md** now has a "Cost Computation (CRITICAL)" section requiring the orchestrator to read rates from config before computing any cost estimates.
2. **CLAUDE.md** now has a matching warning in the telemetry section.
3. Future improvement: `item-telemetry.sh` could accept structured dispatch data (model + tokens per row) and compute breakdown costs internally, eliminating the need for the orchestrator to do manual math.
