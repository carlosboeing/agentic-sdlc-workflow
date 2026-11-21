#!/usr/bin/env bash
set -uo pipefail

# test-fetch-pricing.sh — Offline test for scripts/fetch-pricing.sh.
# Runs a copy of the script in a temporary tree with a fake curl on PATH, so
# no network is used and the real .agentic-workflow/pricing.json is untouched.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0
check() {
  local name="$1" cond="$2"
  if eval "$cond"; then echo "  PASS: $name"; PASS=$((PASS + 1)); else echo "  FAIL: $name"; FAIL=$((FAIL + 1)); fi
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/tree/scripts" "$TMP/bin" "$TMP/fixtures"
cp "$REPO_ROOT/scripts/fetch-pricing.sh" "$TMP/tree/scripts/"
# Temp files land under a directory whose name holds quotes and a dollar sign.
# The script must pass the path to Python as data; spliced into Python source
# it would be a syntax error (or code).
ODD_TMPDIR="$TMP/odd \"dir\" 'x' \$HOME"
mkdir -p "$ODD_TMPDIR"

# Fake curl: writes a fixture to the -o file and prints an HTTP code.
cat > "$TMP/bin/curl" <<'CURL'
#!/usr/bin/env bash
out=""; url=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift ;;
    -w|--max-time) shift ;;
    -*) ;;
    *) url="$1" ;;
  esac
  shift
done
case "$url" in
  *anthropic.com*) src="$FAKE_CURL_DIR/anthropic.html" ;;
  *litellm*) src="$FAKE_CURL_DIR/litellm.json" ;;
  *) src="" ;;
esac
if [ -n "$src" ] && [ -f "$src" ]; then cp "$src" "$out"; printf 200; else printf 404; fi
CURL
# Fake mktemp: BSD mktemp ignores TMPDIR without a template, so create the
# temp file in the hostile directory directly.
cat > "$TMP/bin/mktemp" <<'MKTEMP'
#!/usr/bin/env bash
f="$ODD_TMPDIR/tmp.$$.$RANDOM"
: > "$f" && echo "$f"
MKTEMP
chmod +x "$TMP/bin/curl" "$TMP/bin/mktemp"
export PATH="$TMP/bin:$PATH"
export FAKE_CURL_DIR="$TMP/fixtures"
export ODD_TMPDIR

cat > "$TMP/fixtures/anthropic.html" <<'HTML'
<div><h3>Opus 4.6</h3><p>Input <span>$</span> 5 / MTok</p><p>Output <span>$</span> 25 / MTok</p></div>
<div><h3>Opus 4.1</h3><p>Input <span>$</span> 15 / MTok</p><p>Output <span>$</span> 75 / MTok</p></div>
<div><h3>Sonnet 4.6</h3><p>Input <span>$</span> 3 / MTok</p><p>Output <span>$</span> 15 / MTok</p></div>
<div><h3>Haiku 4.5</h3><p>Input <span>$</span> 1 / MTok</p><p>Output <span>$</span> 5 / MTok</p></div>
HTML
cat > "$TMP/fixtures/litellm.json" <<'JSON'
{
  "claude-opus-4-6": {"input_cost_per_token": 0.000005, "output_cost_per_token": 0.000025},
  "claude-sonnet-4-6": {"input_cost_per_token": 0.000003, "output_cost_per_token": 0.000015},
  "claude-haiku-4-5": {"input_cost_per_token": 0.000001, "output_cost_per_token": 0.000005},
  "anthropic.claude-opus-4-6": {"input_cost_per_token": 0.1, "output_cost_per_token": 0.1}
}
JSON

RUN="$TMP/tree/scripts/fetch-pricing.sh"
CACHE="$TMP/tree/.agentic-workflow/pricing.json"

echo "Test Group: tier 1, pricing page"
out=$(bash "$RUN" 2>/dev/null); rc=$?
check "page_exit_0" '[ "$rc" -eq 0 ]'
check "page_source" '[ "$(printf "%s" "$out" | jq -r .source)" = "anthropic-pricing-page" ]'
check "page_latest_opus_input" '[ "$(printf "%s" "$out" | jq -r .rates.opus.inputPerM)" = "5.0" ]'
check "page_latest_opus_output" '[ "$(printf "%s" "$out" | jq -r .rates.opus.outputPerM)" = "25.0" ]'
check "page_haiku_input" '[ "$(printf "%s" "$out" | jq -r .rates.haiku.inputPerM)" = "1.0" ]'
check "page_writes_cache" '[ -f "$CACHE" ]'

echo "Test Group: tier 2, litellm JSON"
rm -f "$TMP/fixtures/anthropic.html" "$CACHE"
out=$(bash "$RUN" 2>/dev/null); rc=$?
check "litellm_exit_0" '[ "$rc" -eq 0 ]'
check "litellm_source" '[ "$(printf "%s" "$out" | jq -r .source)" = "litellm-community" ]'
check "litellm_sonnet_output" '[ "$(printf "%s" "$out" | jq -r .rates.sonnet.outputPerM)" = "15.0" ]'
check "litellm_skips_provider_prefixed" '[ "$(printf "%s" "$out" | jq -r .rates.opus.inputPerM)" = "5.0" ]'

echo "Test Group: tier 3, cache"
rm -f "$TMP/fixtures/litellm.json"
out=$(bash "$RUN" 2>/dev/null); rc=$?
check "cache_exit_0" '[ "$rc" -eq 0 ]'
check "cache_source" '[ "$(printf "%s" "$out" | jq -r .source)" = "litellm-community" ]'

echo "Test Group: no data"
rm -f "$CACHE"
bash "$RUN" > /dev/null 2>&1; rc=$?
check "no_data_exit_1" '[ "$rc" -eq 1 ]'

echo ""
echo "========================================"
echo "Results: $PASS/$((PASS + FAIL)) passed, $FAIL failed"
echo "========================================"
[ "$FAIL" -eq 0 ]
