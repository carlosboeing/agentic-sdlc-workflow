#!/usr/bin/env bash
set -euo pipefail

# fetch-pricing.sh — Return current Anthropic API pricing as JSON.
#
# Primary source: .claude/agentic-sdlc-config.json (project source of truth).
# Fallback: hardcoded defaults matching the config at last update.
#
# Usage: ./scripts/fetch-pricing.sh
# Output: JSON to stdout. Always succeeds (returns defaults on error).
#
# The orchestrator calls this at session start and stores the result in
# .claude/state/<backlog>/orchestrator.json under the "pricing" key.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG_FILE="${SCRIPT_DIR}/../.claude/agentic-sdlc-config.json"

python3 << PYEOF
import json, os, sys
from datetime import datetime, timezone

cfg_file = "$CFG_FILE"

# Hardcoded defaults (kept in sync with agentic-sdlc-config.json)
DEFAULTS = {
    "opus":   {"input_per_m": 15.00, "output_per_m": 75.00},
    "sonnet": {"input_per_m": 3.00,  "output_per_m": 15.00},
    "haiku":  {"input_per_m": 1.00,  "output_per_m": 5.00},
}
DEFAULT_SPLIT = {"input": 0.75, "output": 0.25}

source = "hardcoded-defaults"
source_parts = []
rates = {}

# Try reading from config (primary source of truth)
try:
    with open(cfg_file) as f:
        cfg = json.load(f)
    pricing = cfg.get("pricing", {})
    split = pricing.get("tokenSplit", DEFAULT_SPLIT)
    source = "agentic-sdlc-config"

    for model in ["opus", "sonnet", "haiku"]:
        model_cfg = pricing.get(model, {})
        inp = model_cfg.get("inputPerM", DEFAULTS[model]["input_per_m"])
        out = model_cfg.get("outputPerM", DEFAULTS[model]["output_per_m"])
        blended = inp * split.get("input", 0.75) + out * split.get("output", 0.25)
        rates[model] = {
            "input_per_m": inp,
            "output_per_m": out,
            "blended_per_m": round(blended, 2),
            "blended_cents_per_m": round(blended * 100),
        }
        source_parts.append(f"{model}:config")
except Exception:
    # Fallback to hardcoded defaults
    for model in ["opus", "sonnet", "haiku"]:
        r = DEFAULTS[model]
        blended = r["input_per_m"] * 0.75 + r["output_per_m"] * 0.25
        rates[model] = {
            "input_per_m": r["input_per_m"],
            "output_per_m": r["output_per_m"],
            "blended_per_m": round(blended, 2),
            "blended_cents_per_m": round(blended * 100),
        }
        source_parts.append(f"{model}:default")

if not source_parts:
    source_parts = ["defaults"]

result = {
    "source": source,
    "source_detail": ", ".join(source_parts),
    "fetched_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "rates": rates,
}

json.dump(result, sys.stdout, indent=2)
print()
PYEOF
