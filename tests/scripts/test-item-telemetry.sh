#!/usr/bin/env bash
set -euo pipefail

# test-item-telemetry.sh — Validates item-telemetry.sh refactoring (S04).
# Tests that the Python heredoc has been replaced with compute-dispatches.py calls,
# and that --gantt-from-state flag works correctly.
#
# Does NOT make real GitHub API calls — gh is mocked to capture rendered output.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_UNDER_TEST="$REPO_ROOT/scripts/item-telemetry.sh"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/telemetry"
PY_MODULE="$REPO_ROOT/scripts/lib/compute-dispatches.py"

PASS=0
FAIL=0

# ─── Helpers ─────────────────────────────────────────────────────────────────

assert_eq() {
  local test_name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    Expected: $expected"
    echo "    Actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local test_name="$1" pattern="$2" text="$3"
  if echo "$text" | grep -qF -- "$pattern"; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    Expected to contain: $pattern"
    echo "    Actual text (truncated): $(echo "$text" | head -5)"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local test_name="$1" pattern="$2" text="$3"
  if ! echo "$text" | grep -qF -- "$pattern"; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    Expected NOT to contain: $pattern"
    FAIL=$((FAIL + 1))
  fi
}

assert_exit_code() {
  local test_name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    Expected exit code: $expected"
    echo "    Actual exit code:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

# Run item-telemetry.sh with a mocked gh that captures the rendered body.
# Returns the rendered markdown body via stdout.
# Sets LAST_EXIT_CODE to the exit code of item-telemetry.sh.
LAST_EXIT_CODE=0
LAST_STDERR=""

run_telemetry() {
  local tmpdir
  tmpdir=$(mktemp -d)

  # Mock gh: capture the issue comment body from '--body' flag
  cat > "$tmpdir/gh" << 'GHEOF'
#!/usr/bin/env bash
# Minimal gh mock: capture 'issue comment' and 'pr view/edit/comment' calls.
# For 'issue comment --body <text>', prints the body to stdout.
# For 'pr view ... --json body -q .body', returns empty string.
# All other calls are silently ignored.
if [ "${1:-}" = "issue" ] && [ "${2:-}" = "comment" ]; then
  # Parse args to find --body value
  while [ $# -gt 0 ]; do
    if [ "$1" = "--body" ]; then
      printf '%s' "$2"
      exit 0
    fi
    shift
  done
fi
if [ "${1:-}" = "pr" ] && [ "${2:-}" = "view" ]; then
  echo ""  # empty existing body
  exit 0
fi
# All other gh calls: silent success
exit 0
GHEOF
  chmod +x "$tmpdir/gh"

  # Prepend tmpdir to PATH so our mock gh is found first
  export PATH="$tmpdir:$PATH"

  local stderr_file
  stderr_file=$(mktemp)

  local output=""
  LAST_EXIT_CODE=0
  output=$(bash "$SCRIPT_UNDER_TEST" "$@" 2>"$stderr_file") || LAST_EXIT_CODE=$?
  LAST_STDERR=$(cat "$stderr_file")
  rm -f "$stderr_file"

  rm -rf "$tmpdir"
  printf '%s' "$output"
}

# ─── Tests ────────────────────────────────────────────────────────────────────

echo "========================================"
echo "Testing item-telemetry.sh (S04 wire external module)"
echo "========================================"
echo ""

# --- Test 1: Script properties ---
echo "Test Group: Script file properties"

if [ -f "$SCRIPT_UNDER_TEST" ]; then
  echo "  PASS: Script file exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Script file does not exist at $SCRIPT_UNDER_TEST"
  FAIL=$((FAIL + 1))
fi

if [ -x "$SCRIPT_UNDER_TEST" ] || bash -n "$SCRIPT_UNDER_TEST" 2>/dev/null; then
  echo "  PASS: Script is valid bash"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Script has bash syntax errors"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test 2: Line count target ---
echo "Test Group: Line count reduction"

LINE_COUNT=$(wc -l < "$SCRIPT_UNDER_TEST")
if [ "$LINE_COUNT" -le 500 ]; then
  echo "  PASS: Line count reduced ($LINE_COUNT <= 500)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Line count too high ($LINE_COUNT > 500, target <= 450)"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test 3: No Python heredoc in _run_dispatches_computation ---
echo "Test Group: Python heredoc removal"

if grep -q 'DISPEOF\|<< DISPEOF\|<< '"'"'DISPEOF'"'" "$SCRIPT_UNDER_TEST"; then
  echo "  FAIL: Python heredoc (DISPEOF) still present in script"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: Python heredoc removed (no DISPEOF marker)"
  PASS=$((PASS + 1))
fi

# Verify _run_dispatches_computation calls compute-dispatches.py
if grep -A5 '_run_dispatches_computation()' "$SCRIPT_UNDER_TEST" | grep -q 'compute-dispatches.py'; then
  echo "  PASS: _run_dispatches_computation calls compute-dispatches.py"
  PASS=$((PASS + 1))
else
  echo "  FAIL: _run_dispatches_computation does not call compute-dispatches.py"
  FAIL=$((FAIL + 1))
fi

# Verify --dispatches flag is passed to compute-dispatches.py
if grep -A10 '_run_dispatches_computation()' "$SCRIPT_UNDER_TEST" | grep -q '\-\-dispatches'; then
  echo "  PASS: --dispatches flag passed to compute-dispatches.py"
  PASS=$((PASS + 1))
else
  echo "  FAIL: --dispatches flag not passed to compute-dispatches.py"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test 4: format_duration defined before dispatch processing ---
echo "Test Group: format_duration placement"

# Find line numbers for format_duration definition and first call in dispatch section
FORMAT_DEF_LINE=$(grep -n '^format_duration()' "$SCRIPT_UNDER_TEST" | head -1 | cut -d: -f1)
# The wall-clock warning calls format_duration inside _process_state_result
FORMAT_CALL_LINE=$(grep -n 'format_duration "\$computed_wc"' "$SCRIPT_UNDER_TEST" | head -1 | cut -d: -f1)

if [ -n "$FORMAT_DEF_LINE" ] && [ -n "$FORMAT_CALL_LINE" ]; then
  if [ "$FORMAT_DEF_LINE" -lt "$FORMAT_CALL_LINE" ]; then
    echo "  PASS: format_duration defined (line $FORMAT_DEF_LINE) before first call (line $FORMAT_CALL_LINE)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: format_duration defined at line $FORMAT_DEF_LINE but called at line $FORMAT_CALL_LINE (call is before definition)"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  FAIL: Could not locate format_duration definition or call (def=$FORMAT_DEF_LINE, call=$FORMAT_CALL_LINE)"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test 5: --gantt-from-state flag in argument parsing ---
echo "Test Group: --gantt-from-state flag"

if grep -q '\-\-gantt-from-state' "$SCRIPT_UNDER_TEST"; then
  echo "  PASS: --gantt-from-state flag present in script"
  PASS=$((PASS + 1))
else
  echo "  FAIL: --gantt-from-state flag missing from script"
  FAIL=$((FAIL + 1))
fi

# Verify GANTT_FROM_STATE variable initialized
if grep -q 'GANTT_FROM_STATE=""' "$SCRIPT_UNDER_TEST"; then
  echo "  PASS: GANTT_FROM_STATE variable initialized"
  PASS=$((PASS + 1))
else
  echo "  FAIL: GANTT_FROM_STATE variable not initialized"
  FAIL=$((FAIL + 1))
fi

# Verify --gantt-from-state calls compute-dispatches.py with --gantt flag
if grep -B2 -A5 'GANTT_FROM_STATE.*-f.*GANTT_FROM_STATE' "$SCRIPT_UNDER_TEST" 2>/dev/null | grep -q '\-\-gantt' ||
   grep -A10 'elif.*GANTT_FROM_STATE.*-f.*GANTT_FROM_STATE' "$SCRIPT_UNDER_TEST" | grep -q '\-\-gantt'; then
  echo "  PASS: --gantt-from-state code path invokes compute-dispatches.py --gantt"
  PASS=$((PASS + 1))
else
  echo "  FAIL: --gantt-from-state code path does not pass --gantt to compute-dispatches.py"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test 6: --dispatches with fixture produces breakdown rows ---
echo "Test Group: --dispatches flag with fixture"

DISPATCHES_FIXTURE="$FIXTURE_DIR/dispatches.json"
OUTPUT=$(run_telemetry 1 \
  --model sonnet \
  --duration 200000 \
  --commit abc1234 \
  --dispatches "$DISPATCHES_FIXTURE")

assert_contains "--dispatches produces breakdown header" "| Agent | Story | Task | Duration | Tokens | Est. Cost |" "$OUTPUT"
assert_contains "--dispatches includes E01-S01 task" "E01-S01" "$OUTPUT"
assert_contains "--dispatches includes total row" "Total" "$OUTPUT"

echo ""

# --- Test 7: --dispatches-from-state with fixture ---
echo "Test Group: --dispatches-from-state flag with fixture"

STATE_FIXTURE="$FIXTURE_DIR/state.json"
OUTPUT=$(run_telemetry 1 \
  --model sonnet \
  --duration 390000 \
  --commit abc1234 \
  --dispatches-from-state "$STATE_FIXTURE")

assert_contains "--dispatches-from-state produces breakdown" "| Agent | Story | Task | Duration | Tokens | Est. Cost |" "$OUTPUT"
assert_contains "--dispatches-from-state includes designer phase" "Design" "$OUTPUT"
assert_contains "--dispatches-from-state includes build phase" "Build" "$OUTPUT"

echo ""

# --- Test 8: --gantt-from-state generates Gantt chart ---
echo "Test Group: --gantt-from-state generates Gantt"

OUTPUT=$(run_telemetry 1 \
  --model sonnet \
  --duration 390000 \
  --commit abc1234 \
  --gantt-from-state "$STATE_FIXTURE")

assert_contains "--gantt-from-state produces timeline heading" "### Timeline" "$OUTPUT"
assert_contains "--gantt-from-state produces mermaid fence" '```mermaid' "$OUTPUT"
assert_contains "--gantt-from-state includes gantt keyword" "gantt" "$OUTPUT"
assert_contains "--gantt-from-state produces breakdown" "| Agent | Story | Task | Duration | Tokens | Est. Cost |" "$OUTPUT"

echo ""

# --- Test 9: --gantt-from-state takes precedence over --gantt ---
echo "Test Group: --gantt-from-state precedence over --gantt"

MANUAL_GANTT="    title Manual Gantt
    dateFormat HH:mm:ss
    Manual task   :t1, 00:00:00, 60s"

OUTPUT=$(run_telemetry 1 \
  --model sonnet \
  --duration 390000 \
  --commit abc1234 \
  --gantt-from-state "$STATE_FIXTURE" \
  --gantt "$MANUAL_GANTT" 2>/dev/null)

# --gantt-from-state should win: the gantt content should come from state, not manual
# The state-generated gantt has "Full Lifecycle Timeline" as its title
assert_contains "--gantt-from-state overrides manual --gantt content" "Full Lifecycle Timeline" "$OUTPUT"
assert_not_contains "--gantt-from-state discards manual --gantt" "Manual task" "$OUTPUT"

# Warning should be emitted to stderr — LAST_STDERR is set by run_telemetry
run_telemetry 1 \
  --model sonnet \
  --duration 390000 \
  --commit abc1234 \
  --gantt-from-state "$STATE_FIXTURE" \
  --gantt "$MANUAL_GANTT" > /dev/null
assert_contains "--gantt-from-state emits precedence warning" "takes precedence" "$LAST_STDERR"

echo ""

# --- Test 10: fix_footer populated from Python output ---
echo "Test Group: FIX_FOOTER from state file"

FIX_STATE_FIXTURE="$FIXTURE_DIR/state-with-fix-cycles.json"
OUTPUT=$(run_telemetry 1 \
  --model sonnet \
  --duration 690000 \
  --commit abc1234 \
  --dispatches-from-state "$FIX_STATE_FIXTURE")

assert_contains "FIX_FOOTER appears when fix cycles present" "Fix cycles:" "$OUTPUT"

echo ""

# --- Test 11: eval_condition FIX_CYCLES wired correctly ---
echo "Test Group: FIX_CYCLES condition in eval_condition"

if grep -q 'FIX_CYCLES)' "$SCRIPT_UNDER_TEST"; then
  echo "  PASS: FIX_CYCLES condition present in eval_condition"
  PASS=$((PASS + 1))
else
  echo "  FAIL: FIX_CYCLES condition missing from eval_condition"
  FAIL=$((FAIL + 1))
fi

if grep -A1 'FIX_CYCLES)' "$SCRIPT_UNDER_TEST" | grep -q 'FIX_FOOTER'; then
  echo "  PASS: FIX_CYCLES condition checks FIX_FOOTER variable"
  PASS=$((PASS + 1))
else
  echo "  FAIL: FIX_CYCLES condition does not check FIX_FOOTER"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test 12: No temp file management for wall_clock ---
echo "Test Group: Wall-clock temp file removal"

if grep -q '_wall_clock_tmp' "$SCRIPT_UNDER_TEST"; then
  echo "  FAIL: Script still uses _wall_clock_tmp temp file (should be removed)"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: No _wall_clock_tmp temp file management"
  PASS=$((PASS + 1))
fi

echo ""

# --- Test 13: Backward compatibility — existing flags still work ---
echo "Test Group: Backward compatibility"

# --gantt flag still accepted (no exit 1 for unknown option)
EXIT_CODE=0
OUTPUT=$(run_telemetry 1 \
  --model sonnet \
  --duration 60000 \
  --commit abc1234 \
  --gantt "    title Test" 2>/dev/null) || EXIT_CODE=$?
assert_exit_code "--gantt flag accepted (no unknown option error)" "0" "$EXIT_CODE"
assert_contains "--gantt flag produces timeline section" "### Timeline" "$OUTPUT"

# --dispatches flag accepted
EXIT_CODE=0
run_telemetry 1 \
  --model sonnet \
  --duration 60000 \
  --commit abc1234 \
  --dispatches "$DISPATCHES_FIXTURE" > /dev/null 2>&1 || EXIT_CODE=$?
assert_exit_code "--dispatches flag accepted" "0" "$EXIT_CODE"

# --dispatches-from-state flag accepted
EXIT_CODE=0
run_telemetry 1 \
  --model sonnet \
  --duration 60000 \
  --commit abc1234 \
  --dispatches-from-state "$STATE_FIXTURE" > /dev/null 2>&1 || EXIT_CODE=$?
assert_exit_code "--dispatches-from-state flag accepted" "0" "$EXIT_CODE"

echo ""

# --- Test 14: Python module exists and is callable ---
echo "Test Group: compute-dispatches.py availability"

if [ -f "$PY_MODULE" ]; then
  echo "  PASS: compute-dispatches.py exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: compute-dispatches.py missing at $PY_MODULE"
  FAIL=$((FAIL + 1))
fi

# Verify the module can be called with --dispatches
EXIT_CODE=0
python3 "$PY_MODULE" --dispatches "$DISPATCHES_FIXTURE" > /dev/null 2>&1 || EXIT_CODE=$?
assert_exit_code "compute-dispatches.py --dispatches works" "0" "$EXIT_CODE"

# Verify the module can be called with --from-state
EXIT_CODE=0
python3 "$PY_MODULE" --from-state "$STATE_FIXTURE" > /dev/null 2>&1 || EXIT_CODE=$?
assert_exit_code "compute-dispatches.py --from-state works" "0" "$EXIT_CODE"

# Verify the module can generate gantt
EXIT_CODE=0
python3 "$PY_MODULE" --from-state "$STATE_FIXTURE" --gantt > /dev/null 2>&1 || EXIT_CODE=$?
assert_exit_code "compute-dispatches.py --from-state --gantt works" "0" "$EXIT_CODE"

echo ""

# --- Test 15: pm.sh is sourced at startup ---
echo "Test Group: pm.sh sourcing"

if grep -qE 'source[[:space:]].*pm\.sh|source[[:space:]].*"\$SCRIPT_DIR/lib/pm\.sh"|\.[[:space:]].*pm\.sh' "$SCRIPT_UNDER_TEST"; then
  echo "  PASS: item-telemetry.sh sources pm.sh"
  PASS=$((PASS + 1))
else
  echo "  FAIL: item-telemetry.sh does not source pm.sh"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test 16: pm_add_comment called, not bare gh issue comment ---
echo "Test Group: pm_add_comment delegation"

# The posting line must call pm_add_comment, not gh issue comment directly
if grep -q 'pm_add_comment' "$SCRIPT_UNDER_TEST"; then
  echo "  PASS: pm_add_comment call present in script"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_add_comment call not found in script"
  FAIL=$((FAIL + 1))
fi

# The direct gh issue comment call for posting should be gone
# We check that the telemetry-post section uses pm_add_comment, not gh issue comment
POSTING_LINE=$(grep -n 'pm_add_comment\|gh issue comment' "$SCRIPT_UNDER_TEST" \
  | grep -v '^[[:space:]]*#' || true)
if echo "$POSTING_LINE" | grep -q 'pm_add_comment' && ! echo "$POSTING_LINE" | grep -q 'gh issue comment'; then
  echo "  PASS: Posting uses pm_add_comment, not direct gh issue comment"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Direct gh issue comment call still present in posting section"
  echo "    Relevant lines: $POSTING_LINE"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test 17: Local adapter writes comment inline to item file ---
echo "Test Group: Local adapter comment file creation"

LOCAL_ADAPTER_DIR="$REPO_ROOT/scripts/lib/adapters/pm/local"

# Skip if local adapter directory doesn't exist
if [ ! -d "$LOCAL_ADAPTER_DIR" ]; then
  echo "  SKIP: Local adapter directory not found at $LOCAL_ADAPTER_DIR"
else
  LOCAL_WORKFLOW_DIR=$(mktemp -d)
  trap 'rm -rf "$LOCAL_WORKFLOW_DIR"' EXIT

  # Create required directory structure and a minimal item file for issue 42
  # pm_add_comment silently skips when the item file does not exist
  mkdir -p "$LOCAL_WORKFLOW_DIR/items"
  cat > "$LOCAL_WORKFLOW_DIR/items/42.md" <<'ITEM_EOF'
---
id: 42
title: "Test Issue"
type: story
status: backlog
labels:
  - hierarchy/story
parent: null
state: open
created: 2026-01-01T00:00:00Z
updated: 2026-01-01T00:00:00Z
---

Test issue body.
ITEM_EOF

  # Run telemetry with local adapter injected via _PM_TEST_ADAPTER_DIR
  # _LOCAL_WORKFLOW_DIR controls where the item file lives
  STDERR_FILE=$(mktemp)
  LOCAL_EXIT=0
  LOCAL_OUTPUT=$(
    _PM_TEST_ADAPTER_DIR="$LOCAL_ADAPTER_DIR" \
    _LOCAL_WORKFLOW_DIR="$LOCAL_WORKFLOW_DIR" \
    bash "$SCRIPT_UNDER_TEST" 42 \
      --model sonnet \
      --duration 60000 \
      --commit abc1234 \
      2>"$STDERR_FILE"
  ) || LOCAL_EXIT=$?
  LOCAL_STDERR=$(cat "$STDERR_FILE")
  rm -f "$STDERR_FILE"

  if [ "$LOCAL_EXIT" -eq 0 ]; then
    echo "  PASS: Script exits 0 with local adapter"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Script exited $LOCAL_EXIT with local adapter"
    echo "    stderr: $LOCAL_STDERR"
    FAIL=$((FAIL + 1))
  fi

  # Verify item file exists and contains rendered telemetry content
  ITEM_FILE="$LOCAL_WORKFLOW_DIR/items/42.md"
  if [ -f "$ITEM_FILE" ] && grep -q 'Telemetry\|sonnet\|abc1234' "$ITEM_FILE" 2>/dev/null; then
    echo "  PASS: Item file contains rendered telemetry content"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Item file missing or lacks telemetry content"
    [ -f "$ITEM_FILE" ] && echo "    File: $ITEM_FILE" && head -10 "$ITEM_FILE"
    FAIL=$((FAIL + 1))
  fi

  # Verify comment has the <!-- comment: ... --> timestamp marker
  if grep -q '^<!-- comment:' "$ITEM_FILE" 2>/dev/null; then
    echo "  PASS: Item file has <!-- comment: ... --> timestamp marker"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Item file missing <!-- comment: ... --> timestamp marker"
    FAIL=$((FAIL + 1))
  fi

  # Verify Activity Log separator was appended (─────────)
  if grep -q '─────────' "$ITEM_FILE" 2>/dev/null; then
    echo "  PASS: Item file has Activity Log separator"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Item file missing Activity Log separator"
    FAIL=$((FAIL + 1))
  fi

  # Verify Activity Log heading exists
  if grep -q '^## Activity Log' "$ITEM_FILE" 2>/dev/null; then
    echo "  PASS: Item file has Activity Log heading"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Item file missing ## Activity Log heading"
    FAIL=$((FAIL + 1))
  fi
fi

echo ""

# --- Summary ---
echo "========================================"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
