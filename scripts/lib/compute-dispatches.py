#!/usr/bin/env python3
"""
compute-dispatches.py — Compute telemetry breakdown/summary rows from dispatch data.

Extracted from issue-telemetry.sh. Produces IDENTICAL output to the embedded
Python heredocs in _run_dispatches_computation() and the state file conversion block.

Usage:
  compute-dispatches.py --dispatches <file>
  compute-dispatches.py --from-state <state-file>

Options:
  --dispatches <file>   Structured dispatch JSON (array of objects with agent, model,
                        task, duration_ms, tokens, phase fields)
  --from-state <file>   Orchestrator state file (.agentic-workflow/runs/<N>/orchestrator.json)
  --pricing <file>      Pricing JSON (default: .agentic-workflow/pricing.json)
  --config <file>       Config JSON (default: .claude/agentic-sdlc-config.json)

Output: JSON to stdout with fields:
  breakdown     — Markdown table rows for per-dispatch detail
  summary       — Markdown table rows for phase-level summary
  cost          — Total estimated cost as numeric string (e.g. "4.79"), or "" if unknown
  duration_ms   — Total sequential duration as string
  tokens        — Total token count as string
  wall_clock_ms — (--from-state only) Wall-clock duration accounting for parallelism
  has_parallel  — (--from-state only) True if parallel dispatches were detected

Importable: All logic lives in top-level functions for unit testing.
"""

import argparse
import json
import sys
from collections import defaultdict

# ──────────────────────────────────────────────────────────────────────────────
# Constants
# ──────────────────────────────────────────────────────────────────────────────

# Token split: 75% input / 25% output — fixed constant based on observed patterns
_SPLIT_IN = 0.75
_SPLIT_OUT = 0.25

# Agent type to telemetry phase mapping (mirrors the embedded Python in telemetry.sh)
AGENT_TO_PHASE = {
    "designer": "Design",
    "planner": "Plan",
    "builder-haiku": "Build",
    "builder-sonnet": "Build",
    "builder-opus": "Build",
    "reviewer": "Review",
    "retro": "Retro",
}


# ──────────────────────────────────────────────────────────────────────────────
# Formatting helpers (identical to embedded Python in issue-telemetry.sh)
# ──────────────────────────────────────────────────────────────────────────────

def fmt_duration(ms):
    """Format milliseconds as human-readable duration (e.g. 146000 → '2m 26s')."""
    secs = ms // 1000
    mins = secs // 60
    rem = secs % 60
    if mins > 0 and rem > 0:
        return f"{mins}m {rem}s"
    elif mins > 0:
        return f"{mins}m"
    else:
        return f"{rem}s"


def fmt_tokens(t):
    """Format token count for display (e.g. 49691 → '49K', 1500000 → '1.50M')."""
    if t >= 1_000_000:
        return f"{t / 1_000_000:.2f}M"
    elif t >= 1000:
        return f"{t // 1000}K"
    else:
        return str(t)


def fmt_cost(dollars):
    """Format cost in dollars (None → '—', 4.79 → '~$4.79')."""
    if dollars is None:
        return "—"
    return f"~${dollars:.2f}"


# ──────────────────────────────────────────────────────────────────────────────
# Pricing
# ──────────────────────────────────────────────────────────────────────────────

def load_pricing(pricing_cache, cfg_file):
    """
    Load pricing rates for known models.

    Resolution order (mirrors embedded Python in issue-telemetry.sh):
      1. Config pricing override (cfg_file .pricing.<model>.inputPerM/outputPerM)
      2. Cached pricing file (pricing_cache .rates.<model>.inputPerM/outputPerM)

    Returns dict: {model: (inputPerM, outputPerM), ...}
    """
    pricing_rates = {}

    # Priority 1: Config override
    try:
        with open(cfg_file) as f:
            cfg = json.load(f)
        cfg_pricing = cfg.get("pricing", {})
        for m in ["opus", "sonnet", "haiku"]:
            mc = cfg_pricing.get(m, {})
            if "inputPerM" in mc and "outputPerM" in mc:
                pricing_rates[m] = (mc["inputPerM"], mc["outputPerM"])
    except Exception:
        pass

    # Priority 2: Cached pricing from fetch-pricing.sh
    if not pricing_rates:
        try:
            with open(pricing_cache) as f:
                cached = json.load(f)
            for m in ["opus", "sonnet", "haiku"]:
                mr = cached.get("rates", {}).get(m, {})
                if "inputPerM" in mr and "outputPerM" in mr:
                    pricing_rates[m] = (mr["inputPerM"], mr["outputPerM"])
        except Exception:
            pass

    return pricing_rates


def blended_rate(model, pricing_rates):
    """
    Compute blended cost rate (dollars per million tokens) for a model.

    Returns None if no pricing data available for the model (triggers '—' cost).
    """
    if model in pricing_rates:
        inp, out = pricing_rates[model]
        return inp * _SPLIT_IN + out * _SPLIT_OUT
    print(
        f"Warning: No pricing data for model '{model}' — cost will show as '—'. "
        "Run fetch-pricing.sh to cache rates, or add a pricing section to agentic-sdlc-config.json.",
        file=sys.stderr,
    )
    return None


# ──────────────────────────────────────────────────────────────────────────────
# Core computation
# ──────────────────────────────────────────────────────────────────────────────

def compute_from_dispatches(dispatches, pricing_rates):
    """
    Compute telemetry output from a list of structured dispatch dicts.

    This is the extracted body of _run_dispatches_computation() in issue-telemetry.sh.

    Each dispatch dict must have:
      agent       — human-readable agent label (e.g. "Builder (sonnet)")
      model       — model name (e.g. "sonnet")
      task        — task label (e.g. "E01-S01 (#61)")
      duration_ms — integer milliseconds
      tokens      — integer token count
      phase       — phase name (e.g. "Build", "Review", "Design")

    Returns dict with: breakdown, summary, cost, duration_ms, tokens
    """
    if not pricing_rates:
        print(
            "Warning: No pricing data found (no config override, no cached pricing at "
            ".agentic-workflow/pricing.json). Run fetch-pricing.sh first.",
            file=sys.stderr,
        )

    total_duration = 0
    total_tokens = 0
    total_cost = 0.0
    breakdown_rows = []
    phase_agg = {}

    # Preserve phase insertion order
    phase_order = []

    for d in dispatches:
        model = d["model"]
        dur_ms = d["duration_ms"]
        tokens = d["tokens"]
        rate = blended_rate(model, pricing_rates)
        cost = tokens / 1_000_000 * rate if rate is not None else None

        total_duration += dur_ms
        total_tokens += tokens
        if cost is not None:
            if total_cost is not None:
                total_cost += cost
        else:
            total_cost = None  # If any dispatch has unknown cost, total is unknown

        agent_label = d.get("agent", model.capitalize())
        task_label = d.get("task", f"Issue #{d.get('issue', '?')}")
        phase = d.get("phase", "Other")

        breakdown_rows.append(
            f"| {agent_label} | {task_label} | {fmt_duration(dur_ms)} | {fmt_tokens(tokens)} | {fmt_cost(cost)} |"
        )

        if phase not in phase_agg:
            phase_agg[phase] = {"duration_ms": 0, "tokens": 0, "cost": 0.0, "count": 0}
            phase_order.append(phase)
        phase_agg[phase]["duration_ms"] += dur_ms
        phase_agg[phase]["tokens"] += tokens
        if cost is not None and phase_agg[phase]["cost"] is not None:
            phase_agg[phase]["cost"] += cost
        else:
            phase_agg[phase]["cost"] = None
        phase_agg[phase]["count"] += 1

    # Build breakdown total row
    breakdown_rows.append(
        f"| | **Total ({len(dispatches)} dispatches)** | **{fmt_duration(total_duration)}** "
        f"| **{fmt_tokens(total_tokens)}** | **{fmt_cost(total_cost)}** |"
    )

    # Build summary rows
    summary_rows = []
    for phase in phase_order:
        a = phase_agg[phase]
        count_suffix = ""
        if a["count"] > 1:
            if phase == "Build":
                count_suffix = f" ({a['count']} stories)"
            else:
                count_suffix = f" ({a['count']} dispatches)"
        # Collect unique models in this phase (preserve insertion order)
        phase_models = list(dict.fromkeys(d["model"] for d in dispatches if d.get("phase") == phase))
        if len(phase_models) == 1:
            agent_desc = f"{phase_models[0]}{count_suffix}"
        else:
            agent_desc = f"mixed ({', '.join(phase_models)}){count_suffix}"
        summary_rows.append(
            f"| {phase} | {agent_desc} | {fmt_duration(a['duration_ms'])} "
            f"| {fmt_tokens(a['tokens'])} | {fmt_cost(a['cost'])} |"
        )
    summary_rows.append(
        f"| **Total** | | **{fmt_duration(total_duration)}** "
        f"| **{fmt_tokens(total_tokens)}** | **{fmt_cost(total_cost)}** |"
    )

    return {
        "breakdown": "\n".join(breakdown_rows),
        "summary": "\n".join(summary_rows),
        "cost": f"{total_cost:.2f}" if total_cost is not None else "",
        "duration_ms": str(total_duration),
        "tokens": str(total_tokens),
    }


def state_to_dispatches(state):
    """
    Convert orchestrator state file dispatches[] to the structured dispatch format.

    This is the extracted state file conversion block from issue-telemetry.sh
    (lines 281-371). Maps agent types to phases and generates human-readable
    task labels from epic/story data.

    Returns a list of structured dispatch dicts (same format as compute_from_dispatches).
    """
    # Build issue-to-title map from epics
    issue_titles = {}
    for epic_key, epic in state.get("epics", {}).items():
        for issue_num, story in epic.get("stories", {}).items():
            branch = story.get("branch", "")
            # Derive a short label from the branch name
            # e.g. "e01-s01/destination-profiles" → "Destination Profiles"
            label = branch.replace(f"{epic_key}-", "").replace("/", " ").replace("-", " ").title()
            issue_titles[int(issue_num)] = label

    dispatches = []
    raw_dispatches = state.get("dispatches", [])

    for d in raw_dispatches:
        agent = d.get("agent", "unknown")
        model = d.get("model", "unknown")
        issue = d.get("issue")
        phase = AGENT_TO_PHASE.get(agent, "Other")

        # Build human-readable agent label
        agent_base = agent.split("-")[0].capitalize()
        if agent_base == "Builder":
            agent_label = f"Builder ({model})"
        elif agent_base == "Reviewer":
            agent_label = f"Reviewer ({model})"
        else:
            agent_label = f"{agent_base.capitalize()} ({model})"

        # Build task label from issue titles or agent type
        if phase == "Design":
            task = f"Design Doc (#{issue})" if issue else "Design Doc"
        elif phase == "Plan":
            task = f"Plan Doc (#{issue})" if issue else "Plan Doc"
        elif phase == "Retro":
            task = f"Retrospective (#{issue})" if issue else "Retrospective"
        elif phase == "Review" and issue:
            if issue in issue_titles:
                title = issue_titles[issue]
                task = f"Review {title} (#{issue})"
            else:
                task = f"PR Review (#{issue})"
        elif issue and issue in issue_titles:
            task = f"{issue_titles[issue]} (#{issue})"
        elif issue:
            task = f"Issue #{issue}"
        else:
            task = agent

        dispatches.append({
            "agent": agent_label,
            "model": model,
            "task": task,
            "duration_ms": d.get("duration_ms", 0),
            "tokens": d.get("tokens", 0),
            "phase": phase,
        })

    return dispatches


def compute_wall_clock(raw_dispatches):
    """
    Compute wall-clock duration from started_at grouping.

    Dispatches with the same started_at ran in parallel → take max(duration_ms).
    Dispatches with different started_at ran sequentially → sum them.

    This is the extracted wall-clock computation from the state file heredoc
    (lines 354-368 of issue-telemetry.sh).

    Returns (wall_clock_ms, has_parallel).
    """
    groups = defaultdict(list)
    for d in raw_dispatches:
        groups[d.get("started_at", "")].append(d)

    wall_clock_ms = 0
    has_parallel = False
    for ts in sorted(groups.keys()):
        group = groups[ts]
        if len(group) > 1:
            has_parallel = True
        wall_clock_ms += max(d.get("duration_ms", 0) for d in group)

    return wall_clock_ms, has_parallel


def compute_from_state(state, pricing_rates):
    """
    Compute telemetry from an orchestrator state file (parsed JSON dict).

    Combines state_to_dispatches + compute_wall_clock + compute_from_dispatches.

    Returns dict with all fields from compute_from_dispatches plus:
      wall_clock_ms  — wall-clock duration accounting for parallelism
      has_parallel   — True if parallel dispatches were detected
    """
    dispatches = state_to_dispatches(state)
    raw_dispatches = state.get("dispatches", [])
    wall_clock_ms, has_parallel = compute_wall_clock(raw_dispatches)

    result = compute_from_dispatches(dispatches, pricing_rates)
    result["wall_clock_ms"] = wall_clock_ms
    result["has_parallel"] = has_parallel
    return result


# ──────────────────────────────────────────────────────────────────────────────
# CLI entry point
# ──────────────────────────────────────────────────────────────────────────────

def main(argv=None):
    """
    Parse CLI arguments and run the appropriate computation mode.

    Outputs JSON to stdout.
    """
    parser = argparse.ArgumentParser(
        description="Compute telemetry breakdown/summary rows from dispatch data."
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument(
        "--dispatches",
        metavar="FILE",
        help="Structured dispatch JSON file (array of dispatch objects)",
    )
    mode.add_argument(
        "--from-state",
        metavar="FILE",
        help="Orchestrator state file (orchestrator.json)",
    )
    parser.add_argument(
        "--pricing",
        metavar="FILE",
        default=".agentic-workflow/pricing.json",
        help="Pricing JSON file (default: .agentic-workflow/pricing.json)",
    )
    parser.add_argument(
        "--config",
        metavar="FILE",
        default=".claude/agentic-sdlc-config.json",
        help="Config JSON file (default: .claude/agentic-sdlc-config.json)",
    )

    args = parser.parse_args(argv)
    pricing_rates = load_pricing(args.pricing, args.config)

    if args.dispatches:
        with open(args.dispatches) as f:
            dispatches = json.load(f)
        result = compute_from_dispatches(dispatches, pricing_rates)
    else:
        # --from-state
        with open(args.from_state) as f:
            state = json.load(f)
        result = compute_from_state(state, pricing_rates)

    json.dump(result, sys.stdout)


if __name__ == "__main__":
    main()
