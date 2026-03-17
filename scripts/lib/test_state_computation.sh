#!/usr/bin/env bash
# test_state_computation.sh — Tests for state.sh computation subcommands.
#
# Tests: overhead, lifecycle-duration, reconstruct subcommands.
#
# Usage: bash scripts/lib/test_state_computation.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_SH="$SCRIPT_DIR/../state.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_BASE_DIR="$REPO_ROOT/.agentic-workflow/runs"

# ─── Helpers ──────────────────────────────────────────────────────────────────

PASS=0
FAIL=0
ERRORS=()

pass() { echo "  PASS: $1"; (( PASS++ )) || true; }
fail() { echo "  FAIL: $1"; ERRORS+=("$1"); (( FAIL++ )) || true; }

assert_equals() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    pass "$desc"
  else
    fail "$desc (expected='$expected' actual='$actual')"
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -q "$needle"; then
    pass "$desc"
  else
    fail "$desc (expected to contain '$needle', got: '$haystack')"
  fi
}

# Create a minimal test state file with known timestamps.
# Uses a Python script file (not heredoc) to avoid interpolation issues.
_create_test_state() {
  local state_dir="$1"
  local start_wall_clock="$2"
  local started_at="$3"
  local state_file="$state_dir/orchestrator.json"

  mkdir -p "$state_dir"

  python3 - "$state_file" "$start_wall_clock" "$started_at" << 'PYEOF'
import json, sys

state_file = sys.argv[1]
start_wall_clock = sys.argv[2]
started_at = sys.argv[3]

state = {
    "version": 1,
    "session": {
        "backlog": 999,
        "mode": "autonomous",
        "orchestrator_model": "sonnet",
        "started_at": started_at,
        "lifecycle_duration_ms": None,
        "start_wall_clock": start_wall_clock,
        "repo": "test/repo",
        "git_main_sha": "abc1234"
    },
    "overhead": {
        "duration_ms": None,
        "estimated_cost": None
    },
    "pricing": {"sonnet": {"input_per_mtok": 3.0, "output_per_mtok": 15.0}},
    "phases": {
        "design":  {"status": "pending"},
        "plan":    {"status": "pending"},
        "build":   {"status": "pending"},
        "review":  {"status": "pending"},
        "retro":   {"status": "pending"}
    },
    "epics": {},
    "dispatches": []
}

with open(state_file, "w") as f:
    json.dump(state, f, indent=2)
    f.write("\n")
PYEOF
  echo "$state_file"
}

# Append a dispatch entry to an existing state file.
_add_dispatch() {
  local state_file="$1"
  local started_at="$2"
  local duration_ms="$3"
  local agent="${4:-builder-sonnet}"

  python3 - "$state_file" "$started_at" "$duration_ms" "$agent" << 'PYEOF'
import json, sys
from datetime import datetime, timedelta

state_file = sys.argv[1]
started_at = sys.argv[2]
duration_ms = int(sys.argv[3])
agent = sys.argv[4]

with open(state_file) as f:
    state = json.load(f)

start_dt = datetime.fromisoformat(started_at.replace("Z", "+00:00"))
end_dt = start_dt + timedelta(milliseconds=duration_ms)
finished_at = end_dt.strftime("%Y-%m-%dT%H:%M:%SZ")

dispatch_id = len(state["dispatches"]) + 1
state["dispatches"].append({
    "id": dispatch_id,
    "agent": agent,
    "model": "sonnet",
    "issue": None,
    "started_at": started_at,
    "finished_at": finished_at,
    "duration_ms": duration_ms,
    "tokens": 50000,
    "tool_uses": 10,
    "result": "success"
})

with open(state_file, "w") as f:
    json.dump(state, f, indent=2)
    f.write("\n")
PYEOF
}

# Set up a temporary state dir under the repo's .agentic-workflow/runs with a
# test backlog number. Returns the backlog number used.
_setup_state_dir() {
  local backlog_num="$1"
  local state_file="$2"
  local test_state_dir="$STATE_BASE_DIR/$backlog_num"
  mkdir -p "$test_state_dir"
  cp "$state_file" "$test_state_dir/orchestrator.json"
  echo "$test_state_dir"
}

_teardown_state_dir() {
  local backlog_num="$1"
  rm -rf "$STATE_BASE_DIR/$backlog_num"
}

# Date helper — portable macOS/Linux
_date_ago() {
  local seconds="$1"
  date -u -v-"${seconds}S" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
    || date -u --date="${seconds} seconds ago" +"%Y-%m-%dT%H:%M:%SZ"
}

# ─── Tests: reconstruct ───────────────────────────────────────────────────────

test_reconstruct_exits_1() {
  echo "Test group: reconstruct"

  local rc=0
  "$STATE_SH" reconstruct 999 >/dev/null 2>&1 || rc=$?
  assert_equals "reconstruct exits with code 1" "1" "$rc"
}

test_reconstruct_stderr_message() {
  local stderr_out
  stderr_out=$("$STATE_SH" reconstruct 999 2>&1 || true)
  assert_contains "reconstruct prints 'not yet implemented' to stderr" \
    "not yet implemented" "$stderr_out"
}

# ─── Tests: lifecycle-duration ────────────────────────────────────────────────

test_lifecycle_duration_writes_ms() {
  echo "Test group: lifecycle-duration"

  local tmp_dir="/tmp/lifecycle_test_$$"
  local started_at
  started_at=$(_date_ago 300)  # 5 minutes ago

  local state_file
  state_file=$(_create_test_state "$tmp_dir" "$started_at" "$started_at")

  _setup_state_dir 99901 "$state_file" > /dev/null

  local output rc=0
  output=$("$STATE_SH" lifecycle-duration --backlog 99901 2>&1) || rc=$?

  local written_ms
  written_ms=$(jq -r '.session.lifecycle_duration_ms' "$STATE_BASE_DIR/99901/orchestrator.json")

  _teardown_state_dir 99901
  rm -rf "$tmp_dir"

  # Should be positive
  if python3 -c "import sys; sys.exit(0 if int('$written_ms') > 0 else 1)" 2>/dev/null; then
    pass "lifecycle-duration writes positive lifecycle_duration_ms"
  else
    fail "lifecycle-duration lifecycle_duration_ms not positive: $written_ms"
  fi

  assert_contains "lifecycle-duration prints 'Lifecycle duration:'" \
    "Lifecycle duration:" "$output"
}

test_lifecycle_duration_ms_reasonable() {
  local tmp_dir="/tmp/lifecycle_reasonable_$$"
  # started_at is exactly 60 seconds ago
  local started_at
  started_at=$(_date_ago 60)

  local state_file
  state_file=$(_create_test_state "$tmp_dir" "$started_at" "$started_at")

  _setup_state_dir 99902 "$state_file" > /dev/null

  "$STATE_SH" lifecycle-duration --backlog 99902 > /dev/null

  local written_ms
  written_ms=$(jq -r '.session.lifecycle_duration_ms' "$STATE_BASE_DIR/99902/orchestrator.json")

  _teardown_state_dir 99902
  rm -rf "$tmp_dir"

  # Should be approximately 60,000ms (allow 55,000-120,000 for test execution time)
  if python3 -c "
import sys
v = int('$written_ms')
sys.exit(0 if 55000 <= v <= 120000 else 1)
" 2>/dev/null; then
    pass "lifecycle-duration value is in reasonable range (~60s)"
  else
    fail "lifecycle-duration value out of range: ${written_ms}ms (expected 55000-120000)"
  fi
}

# ─── Tests: overhead ──────────────────────────────────────────────────────────

test_overhead_no_dispatches() {
  echo "Test group: overhead"

  local tmp_dir="/tmp/overhead_empty_$$"
  # start_wall_clock is 10 minutes ago
  local start_wall_clock
  start_wall_clock=$(_date_ago 600)

  local state_file
  state_file=$(_create_test_state "$tmp_dir" "$start_wall_clock" "$start_wall_clock")

  _setup_state_dir 99903 "$state_file" > /dev/null

  local output rc=0
  output=$("$STATE_SH" overhead --backlog 99903 2>&1) || rc=$?

  local written_ms
  written_ms=$(jq -r '.overhead.duration_ms' "$STATE_BASE_DIR/99903/orchestrator.json")
  local written_cost
  written_cost=$(jq -r '.overhead.estimated_cost' "$STATE_BASE_DIR/99903/orchestrator.json")

  _teardown_state_dir 99903
  rm -rf "$tmp_dir"

  # With no dispatches, critical_path=0, overhead = full wall-clock (~600,000ms)
  if python3 -c "
import sys
v = int('$written_ms')
sys.exit(0 if 550000 <= v <= 700000 else 1)
" 2>/dev/null; then
    pass "overhead (no dispatches) = full wall-clock (~600,000ms)"
  else
    fail "overhead (no dispatches) out of expected range: ${written_ms}ms (expected 550000-700000)"
  fi

  assert_equals "overhead sets estimated_cost to null" "null" "$written_cost"
  assert_contains "overhead prints 'Overhead:'" "Overhead:" "$output"
}

test_overhead_parallel_dispatches() {
  local tmp_dir="/tmp/overhead_parallel_$$"
  # start_wall_clock is 15 minutes ago
  local start_wall_clock
  start_wall_clock=$(_date_ago 900)

  local state_file
  state_file=$(_create_test_state "$tmp_dir" "$start_wall_clock" "$start_wall_clock")

  # Add two parallel dispatches (SAME started_at)
  # Both started 14 min ago; one took 5min (300000ms), other took 8min (480000ms)
  local parallel_start
  parallel_start=$(_date_ago 840)

  _add_dispatch "$state_file" "$parallel_start" "300000" "builder-sonnet"
  _add_dispatch "$state_file" "$parallel_start" "480000" "builder-opus"

  _setup_state_dir 99904 "$state_file" > /dev/null

  "$STATE_SH" overhead --backlog 99904 > /dev/null

  local written_ms
  written_ms=$(jq -r '.overhead.duration_ms' "$STATE_BASE_DIR/99904/orchestrator.json")

  _teardown_state_dir 99904
  rm -rf "$tmp_dir"

  # critical_path = max(300000, 480000) = 480000 (parallel wave uses max)
  # total_wall_clock ≈ 15*60*1000 = 900,000ms
  # overhead ≈ 900,000 - 480,000 = 420,000ms
  # Allow generous range: 200,000 - 700,000
  if python3 -c "
import sys
v = int('$written_ms')
sys.exit(0 if 200000 <= v <= 700000 else 1)
" 2>/dev/null; then
    pass "overhead (parallel dispatches) uses max(duration_ms)"
  else
    fail "overhead (parallel dispatches) out of range: ${written_ms}ms (expected 200000-700000)"
  fi
}

test_overhead_clamped_to_zero() {
  local tmp_dir="/tmp/overhead_clamp_$$"
  # start_wall_clock is only 1 minute ago but dispatch took 2 hours
  local start_wall_clock
  start_wall_clock=$(_date_ago 60)

  local state_file
  state_file=$(_create_test_state "$tmp_dir" "$start_wall_clock" "$start_wall_clock")

  # Dispatch that ran 2 hours (7,200,000ms) — more than total wall-clock
  local dispatch_start
  dispatch_start=$(_date_ago 59)
  _add_dispatch "$state_file" "$dispatch_start" "7200000" "builder-sonnet"

  _setup_state_dir 99905 "$state_file" > /dev/null

  "$STATE_SH" overhead --backlog 99905 > /dev/null

  local written_ms
  written_ms=$(jq -r '.overhead.duration_ms' "$STATE_BASE_DIR/99905/orchestrator.json")

  _teardown_state_dir 99905
  rm -rf "$tmp_dir"

  assert_equals "overhead clamped to 0 when critical_path > total_wall_clock" "0" "$written_ms"
}

test_overhead_estimated_cost_null() {
  local tmp_dir="/tmp/overhead_cost_$$"
  local start_wall_clock
  start_wall_clock=$(_date_ago 300)

  local state_file
  state_file=$(_create_test_state "$tmp_dir" "$start_wall_clock" "$start_wall_clock")

  _setup_state_dir 99906 "$state_file" > /dev/null

  "$STATE_SH" overhead --backlog 99906 > /dev/null

  local written_cost
  written_cost=$(jq -r '.overhead.estimated_cost' "$STATE_BASE_DIR/99906/orchestrator.json")

  _teardown_state_dir 99906
  rm -rf "$tmp_dir"

  assert_equals "overhead.estimated_cost is null" "null" "$written_cost"
}

# ─── Tests: schema file ───────────────────────────────────────────────────────

test_schema_file_valid_json() {
  echo "Test group: schema file"

  local schema_file="$REPO_ROOT/scripts/schemas/orchestrator-state.v1.json"

  if [ ! -f "$schema_file" ]; then
    fail "orchestrator-state.v1.json does not exist: $schema_file"
    return
  fi

  local rc=0
  python3 -c "import json; json.load(open('$schema_file'))" 2>/dev/null || rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "orchestrator-state.v1.json is valid JSON"
  else
    fail "orchestrator-state.v1.json is NOT valid JSON"
  fi
}

test_schema_has_required_fields() {
  local schema_file="$REPO_ROOT/scripts/schemas/orchestrator-state.v1.json"

  if [ ! -f "$schema_file" ]; then
    fail "schema file missing — skipping field checks"
    return
  fi

  for field in "version" "session" "overhead" "pricing" "phases" "epics" "dispatches"; do
    if jq -e ".. | objects | has(\"$field\")" "$schema_file" > /dev/null 2>&1; then
      pass "schema references field: $field"
    else
      fail "schema missing reference to field: $field"
    fi
  done
}

test_schema_has_descriptions() {
  local schema_file="$REPO_ROOT/scripts/schemas/orchestrator-state.v1.json"

  if [ ! -f "$schema_file" ]; then
    fail "schema file missing — skipping description check"
    return
  fi

  local desc_count
  desc_count=$(grep -c '"description"' "$schema_file" 2>/dev/null || echo 0)

  if [ "$desc_count" -ge 5 ]; then
    pass "schema has $desc_count description fields (>= 5)"
  else
    fail "schema has only $desc_count description fields (expected >= 5)"
  fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
  echo "=== state.sh computation subcommands tests ==="
  echo ""

  test_reconstruct_exits_1
  test_reconstruct_stderr_message

  echo ""
  test_lifecycle_duration_writes_ms
  test_lifecycle_duration_ms_reasonable

  echo ""
  test_overhead_no_dispatches
  test_overhead_parallel_dispatches
  test_overhead_clamped_to_zero
  test_overhead_estimated_cost_null

  echo ""
  test_schema_file_valid_json
  test_schema_has_required_fields
  test_schema_has_descriptions

  echo ""
  echo "=== Results: $PASS passed, $FAIL failed ==="

  if [ "$FAIL" -gt 0 ]; then
    echo "Failures:"
    for err in "${ERRORS[@]}"; do
      echo "  - $err"
    done
    exit 1
  fi
}

main "$@"
