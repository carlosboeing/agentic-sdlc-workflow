#!/usr/bin/env bash
set -euo pipefail

# fetch-pricing.sh — Fetch current Anthropic API pricing and cache locally.
#
# Three-tier resolution:
#   1. PRIMARY:   Scrape https://www.anthropic.com/pricing (live rates)
#   2. SECONDARY: Fetch BerriAI/litellm community pricing JSON
#   3. FALLBACK:  Read local cache from previous successful fetch
#
# On successful fetch (tier 1 or 2), writes cache to .agentic-workflow/pricing.json.
# On failure, falls back to cached data from a previous run.
#
# Output: JSON to stdout. Exit 0 on success (live or cached), exit 1 if no data.
#
# Note: The config file pricing section is an OPTIONAL OVERRIDE handled by
# item-telemetry.sh at consumption time — this script does NOT read the config.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CACHE_DIR="$REPO_ROOT/.agentic-workflow"
CACHE_FILE="$CACHE_DIR/pricing.json"


# ─── Tier 1: Scrape anthropic.com/pricing ─────────────────────────────────────

_fetch_from_web() {
  local tmpfile
  tmpfile=$(mktemp)

  local http_code
  http_code=$(curl -sL --max-time 15 -o "$tmpfile" -w "%{http_code}" \
    "https://www.anthropic.com/pricing" 2>/dev/null) || http_code="000"

  if [ "$http_code" != "200" ]; then
    rm -f "$tmpfile"
    return 1
  fi

  local result
  result=$(python3 << PYEOF
import json, re, sys
from datetime import datetime, timezone

with open("$tmpfile", "r", errors="replace") as f:
    html = f.read()

text = re.sub(r"<[^>]+>", " ", html)
text = re.sub(r"\s+", " ", text)

pattern = re.compile(
    r"((?:Opus|Sonnet|Haiku)\s+[\d.]+)"
    r".{0,150}?"
    r"Input\s+\\\$\s+([\d.]+)\s*/\s*MTok"
    r".{0,80}?"
    r"Output\s+\\\$\s+([\d.]+)\s*/\s*MTok"
)

family_versions = {}
for m in pattern.finditer(text):
    name_ver = m.group(1).strip().split()
    family = name_ver[0].lower()
    version = float(name_ver[1]) if len(name_ver) > 1 else 0.0
    inp = float(m.group(2))
    out = float(m.group(3))
    if inp <= 0 or out <= 0:
        continue
    if family not in family_versions:
        family_versions[family] = []
    family_versions[family].append((version, inp, out))

# Need all three families
for f in ["opus", "sonnet", "haiku"]:
    if f not in family_versions:
        sys.exit(1)

rates = {}
source_parts = []
for family in ["opus", "sonnet", "haiku"]:
    versions = sorted(family_versions[family], key=lambda x: x[0], reverse=True)
    latest = versions[0]
    rates[family] = {"inputPerM": latest[1], "outputPerM": latest[2]}
    source_parts.append(f"{family}:{latest[0]}")

result = {
    "source": "anthropic-pricing-page",
    "source_detail": ", ".join(source_parts),
    "fetched_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "rates": rates,
}
json.dump(result, sys.stdout, indent=2)
print()
PYEOF
  )

  rm -f "$tmpfile"

  if [ -z "$result" ]; then
    return 1
  fi

  echo "$result"
}

# ─── Tier 2: BerriAI/litellm community JSON ──────────────────────────────────

_fetch_from_litellm() {
  local tmpfile
  tmpfile=$(mktemp)

  local http_code
  http_code=$(curl -sL --max-time 15 -o "$tmpfile" -w "%{http_code}" \
    "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json" 2>/dev/null) || http_code="000"

  if [ "$http_code" != "200" ]; then
    rm -f "$tmpfile"
    return 1
  fi

  local result
  result=$(python3 << PYEOF
import json, re, sys
from datetime import datetime, timezone

with open("$tmpfile") as f:
    data = json.load(f)

# Find latest Claude models (direct Anthropic, not AWS/GCP/Azure variants)
families = {}
for key, val in data.items():
    # Match patterns like "claude-opus-4-6", "claude-sonnet-4-6", "claude-haiku-4-5"
    # Skip provider-prefixed entries (anthropic., aws., azure_ai/, etc.)
    if "/" in key or "." in key:
        continue
    m = re.match(r"claude-(opus|sonnet|haiku)-([\d]+)(?:-([\d]+))?", key)
    if not m:
        continue
    family = m.group(1)
    major = int(m.group(2))
    minor = int(m.group(3)) if m.group(3) else 0
    version = major + minor / 10.0
    inp = val.get("input_cost_per_token", 0) * 1_000_000
    out = val.get("output_cost_per_token", 0) * 1_000_000
    if inp <= 0 or out <= 0:
        continue
    if family not in families:
        families[family] = []
    families[family].append((version, inp, out))

for f in ["opus", "sonnet", "haiku"]:
    if f not in families:
        sys.exit(1)

rates = {}
source_parts = []
for family in ["opus", "sonnet", "haiku"]:
    versions = sorted(families[family], key=lambda x: x[0], reverse=True)
    latest = versions[0]
    rates[family] = {"inputPerM": latest[1], "outputPerM": latest[2]}
    source_parts.append(f"{family}:{latest[0]}")

result = {
    "source": "litellm-community",
    "source_detail": ", ".join(source_parts),
    "fetched_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "rates": rates,
}
json.dump(result, sys.stdout, indent=2)
print()
PYEOF
  )

  rm -f "$tmpfile"

  if [ -z "$result" ]; then
    return 1
  fi

  echo "$result"
}

# ─── Tier 3: Local cache fallback ─────────────────────────────────────────────

_read_cache() {
  if [ -f "$CACHE_FILE" ]; then
    cat "$CACHE_FILE"
    return 0
  fi
  return 1
}

# ─── Main ─────────────────────────────────────────────────────────────────────

# Tier 1: Live web fetch
if RESULT=$(_fetch_from_web 2>/dev/null); then
  mkdir -p "$CACHE_DIR"
  echo "$RESULT" > "$CACHE_FILE"
  echo "$RESULT"
  echo "Pricing fetched from anthropic.com/pricing" >&2
  exit 0
fi

echo "Warning: Anthropic pricing page fetch failed, trying litellm..." >&2

# Tier 2: litellm community JSON
if RESULT=$(_fetch_from_litellm 2>/dev/null); then
  mkdir -p "$CACHE_DIR"
  echo "$RESULT" > "$CACHE_FILE"
  echo "$RESULT"
  echo "Pricing fetched from litellm community JSON" >&2
  exit 0
fi

echo "Warning: litellm fetch also failed, trying local cache..." >&2

# Tier 3: Cached data from previous run
if RESULT=$(_read_cache); then
  CACHED_DATE=$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('fetched_at','unknown'))" 2>/dev/null || echo "unknown")
  echo "$RESULT"
  echo "Warning: Using cached pricing from $CACHED_DATE (live fetch failed)" >&2
  exit 0
fi

# No data at all
echo "Error: No pricing data available (web fetch failed, no local cache)" >&2
exit 1
