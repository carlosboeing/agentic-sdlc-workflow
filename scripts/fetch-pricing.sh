#!/usr/bin/env bash
set -euo pipefail

# fetch-pricing.sh — Fetch current Anthropic API pricing and output as JSON.
#
# Fetches from https://www.anthropic.com/pricing and parses token rates for the
# latest opus, sonnet, and haiku models. Falls back to hardcoded defaults if
# fetch or parse fails.
#
# Usage: ./scripts/fetch-pricing.sh
# Output: JSON to stdout. Always succeeds (returns defaults on error).
#
# The orchestrator calls this at session start and stores the result in
# .claude/state/<backlog>/orchestrator.json under the "pricing" key.

TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

# Fetch the pricing page
HTTP_CODE=$(curl -sL --max-time 15 -o "$TMPFILE" -w "%{http_code}" \
  "https://www.anthropic.com/pricing" 2>/dev/null) || HTTP_CODE="000"

export HTTP_CODE TMPFILE

python3 << 'PYEOF'
import json, os, re, sys
from datetime import datetime, timezone

KNOWN_RATES = {
    "opus":   {"input_per_m": 15.00, "output_per_m": 75.00},
    "sonnet": {"input_per_m": 3.00,  "output_per_m": 15.00},
    "haiku":  {"input_per_m": 1.00,  "output_per_m": 5.00},
}

http_code = os.environ.get("HTTP_CODE", "000")
tmpfile = os.environ.get("TMPFILE", "")

found_rates = {}

if http_code == "200" and tmpfile:
    try:
        with open(tmpfile, "r", errors="replace") as f:
            html = f.read()

        text = re.sub(r"<[^>]+>", " ", html)
        text = re.sub(r"\s+", " ", text)

        # The pricing page has entries like:
        #   "Opus 4.6 Most intelligent... Input Prompts ≤ 200K tokens $ 5 / MTok ... Output Prompts ≤ 200K tokens $ 25 / MTok"
        #   "Opus 4.5 Input $ 5 / MTok Output $ 25 / MTok"
        #   "Haiku 4.5 ... Input $ 1 / MTok Output $ 5 / MTok"
        #
        # Regex uses .*? between "Input" and "$" to handle optional "Prompts ≤ 200K tokens".
        # Constrains search to 500 chars from model name to avoid cross-model matching.
        model_pattern = re.compile(
            r"(Opus|Sonnet|Haiku)\s+(\d+(?:\.\d+)?)"
            r".{0,300}?"
            r"Input.{0,50}?\$\s*(\d+(?:\.\d+)?)\s*/\s*MTok"
            r".{0,300}?"
            r"Output.{0,50}?\$\s*(\d+(?:\.\d+)?)\s*/\s*MTok",
            re.IGNORECASE
        )

        family_versions = {}
        for match in model_pattern.finditer(text):
            family = match.group(1).lower()
            version = float(match.group(2))
            input_price = float(match.group(3))
            output_price = float(match.group(4))

            if input_price <= 0 or output_price <= 0:
                continue

            if family not in family_versions:
                family_versions[family] = []
            family_versions[family].append((version, input_price, output_price))

        # Pick latest (highest version) for each family
        for family, versions in family_versions.items():
            versions.sort(key=lambda x: x[0], reverse=True)
            latest = versions[0]
            found_rates[family] = {
                "input_per_m": latest[1],
                "output_per_m": latest[2],
                "version": str(latest[0]),
            }
    except Exception:
        pass

# Build result
rates = {}
source_parts = []
for model in ["opus", "sonnet", "haiku"]:
    if model in found_rates:
        r = found_rates[model]
        source_parts.append(f"{model}:{r.get('version', 'web')}")
    else:
        r = KNOWN_RATES[model]
        source_parts.append(f"{model}:default")

    blended = r["input_per_m"] * 0.75 + r["output_per_m"] * 0.25
    rates[model] = {
        "input_per_m": r["input_per_m"],
        "output_per_m": r["output_per_m"],
        "blended_per_m": round(blended, 2),
        "blended_cents_per_m": round(blended * 100),
    }

has_web = any("default" not in s for s in source_parts)
source = "anthropic-pricing-page" if has_web else "hardcoded-defaults"

result = {
    "source": source,
    "source_detail": ", ".join(source_parts),
    "fetched_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "rates": rates,
}

json.dump(result, sys.stdout, indent=2)
print()
PYEOF
