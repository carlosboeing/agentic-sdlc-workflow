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

# ─── Tests: update --add-story ────────────────────────────────────────────────
#
# These tests use a shared state file with an epic pre-registered. Each test
# that writes to the state file uses its own backlog number to avoid conflicts.

# Build a state file that has epic e01 already registered, for add-story tests.
_create_state_with_epic() {
  local state_dir="$1"
  local state_file="$state_dir/orchestrator.json"

  mkdir -p "$state_dir"

  python3 - "$state_file" << 'PYEOF'
import json, sys

state_file = sys.argv[1]

state = {
    "version": 1,
    "session": {
        "backlog": 999,
        "mode": "autonomous",
        "orchestrator_model": "sonnet",
        "started_at": "2026-01-01T00:00:00Z",
        "lifecycle_duration_ms": None,
        "start_wall_clock": "2026-01-01T00:00:00Z",
        "repo": "test/repo",
        "git_main_sha": "abc1234"
    },
    "overhead": {"duration_ms": None, "estimated_cost": None},
    "pricing": {
        "source": "anthropic-pricing-page",
        "source_detail": "opus:4.6, sonnet:4.6, haiku:4.5",
        "fetched_at": "2026-01-01T00:00:00Z",
        "rates": {
            "opus":   {"inputPerM": 5.0, "outputPerM": 25.0},
            "sonnet": {"inputPerM": 3.0, "outputPerM": 15.0},
            "haiku":  {"inputPerM": 1.0, "outputPerM":  5.0}
        }
    },
    "phases": {
        "design":  {"status": "pending"},
        "plan":    {"status": "pending"},
        "build":   {"status": "pending"},
        "review":  {"status": "pending"},
        "retro":   {"status": "pending"}
    },
    "epics": {
        "e01-test-epic": {
            "base_sha": "deadbeef",
            "stories": {}
        }
    },
    "dispatches": []
}

with open(state_file, "w") as f:
    json.dump(state, f, indent=2)
    f.write("\n")
PYEOF
  echo "$state_file"
}

test_add_story_registers_story() {
  echo "Test group: update --add-story"

  local tmp_dir="/tmp/add_story_basic_$$"
  local state_file
  state_file=$(_create_state_with_epic "$tmp_dir")

  _setup_state_dir 99920 "$state_file" > /dev/null

  local output rc=0
  output=$("$STATE_SH" update --add-story 157 \
    --epic e01-test-epic \
    --branch e01-s01/my-story \
    --difficulty medium \
    --model sonnet \
    --backlog 99920 2>&1) || rc=$?

  local written_status
  written_status=$(jq -r '.epics["e01-test-epic"].stories["157"].status' \
    "$STATE_BASE_DIR/99920/orchestrator.json")
  local written_branch
  written_branch=$(jq -r '.epics["e01-test-epic"].stories["157"].branch' \
    "$STATE_BASE_DIR/99920/orchestrator.json")
  local written_difficulty
  written_difficulty=$(jq -r '.epics["e01-test-epic"].stories["157"].difficulty' \
    "$STATE_BASE_DIR/99920/orchestrator.json")
  local written_model
  written_model=$(jq -r '.epics["e01-test-epic"].stories["157"].model' \
    "$STATE_BASE_DIR/99920/orchestrator.json")

  _teardown_state_dir 99920
  rm -rf "$tmp_dir"

  assert_equals "add-story sets initial status to pending" "pending" "$written_status"
  assert_equals "add-story records branch" "e01-s01/my-story" "$written_branch"
  assert_equals "add-story records difficulty" "medium" "$written_difficulty"
  assert_equals "add-story records model" "sonnet" "$written_model"
  assert_equals "add-story exits 0" "0" "$rc"
  assert_contains "add-story prints confirmation message" "registered in epic" "$output"
}

test_add_story_duplicate_fails() {
  local tmp_dir="/tmp/add_story_dup_$$"
  local state_file
  state_file=$(_create_state_with_epic "$tmp_dir")

  _setup_state_dir 99921 "$state_file" > /dev/null

  # Register story once
  "$STATE_SH" update --add-story 158 \
    --epic e01-test-epic --branch e01-s01/slug \
    --difficulty easy --model haiku \
    --backlog 99921 > /dev/null

  # Second registration should fail
  local rc=0
  local stderr_out
  stderr_out=$("$STATE_SH" update --add-story 158 \
    --epic e01-test-epic --branch e01-s01/slug \
    --difficulty easy --model haiku \
    --backlog 99921 2>&1) || rc=$?

  _teardown_state_dir 99921
  rm -rf "$tmp_dir"

  if [ "$rc" -ne 0 ]; then
    pass "add-story duplicate exits non-zero"
  else
    fail "add-story duplicate should exit non-zero but exited 0"
  fi
  assert_contains "add-story duplicate prints error" "already registered" "$stderr_out"
}

test_add_story_missing_epic_fails() {
  local tmp_dir="/tmp/add_story_noepic_$$"
  local state_file
  state_file=$(_create_state_with_epic "$tmp_dir")

  _setup_state_dir 99922 "$state_file" > /dev/null

  local rc=0
  local stderr_out
  stderr_out=$("$STATE_SH" update --add-story 159 \
    --epic e99-nonexistent \
    --branch e99-s01/slug \
    --difficulty easy --model haiku \
    --backlog 99922 2>&1) || rc=$?

  _teardown_state_dir 99922
  rm -rf "$tmp_dir"

  if [ "$rc" -ne 0 ]; then
    pass "add-story with unknown epic exits non-zero"
  else
    fail "add-story with unknown epic should exit non-zero but exited 0"
  fi
  assert_contains "add-story unknown epic prints error" "not found" "$stderr_out"
}

test_add_story_invalid_difficulty_fails() {
  local tmp_dir="/tmp/add_story_diff_$$"
  local state_file
  state_file=$(_create_state_with_epic "$tmp_dir")

  _setup_state_dir 99923 "$state_file" > /dev/null

  local rc=0
  local stderr_out
  stderr_out=$("$STATE_SH" update --add-story 160 \
    --epic e01-test-epic \
    --branch e01-s01/slug \
    --difficulty very-hard --model opus \
    --backlog 99923 2>&1) || rc=$?

  _teardown_state_dir 99923
  rm -rf "$tmp_dir"

  if [ "$rc" -ne 0 ]; then
    pass "add-story with invalid difficulty exits non-zero"
  else
    fail "add-story with invalid difficulty should exit non-zero but exited 0"
  fi
  assert_contains "add-story invalid difficulty prints error" "invalid" "$stderr_out"
}

test_add_story_missing_required_flags() {
  local tmp_dir="/tmp/add_story_flags_$$"
  local state_file
  state_file=$(_create_state_with_epic "$tmp_dir")

  _setup_state_dir 99924 "$state_file" > /dev/null

  # Missing --epic
  local rc=0
  "$STATE_SH" update --add-story 161 \
    --branch e01-s01/slug --difficulty easy --model haiku \
    --backlog 99924 > /dev/null 2>&1 || rc=$?
  if [ "$rc" -ne 0 ]; then
    pass "add-story missing --epic exits non-zero"
  else
    fail "add-story missing --epic should exit non-zero but exited 0"
  fi

  # Missing story number (no positional arg)
  rc=0
  "$STATE_SH" update --add-story \
    --epic e01-test-epic --branch e01-s01/slug --difficulty easy --model haiku \
    --backlog 99924 > /dev/null 2>&1 || rc=$?
  if [ "$rc" -ne 0 ]; then
    pass "add-story missing story number exits non-zero"
  else
    fail "add-story missing story number should exit non-zero but exited 0"
  fi

  _teardown_state_dir 99924
  rm -rf "$tmp_dir"
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

  local content
  content=$(cat "$schema_file")

  for field in "version" "session" "overhead" "pricing" "phases" "epics" "dispatches"; do
    if echo "$content" | grep -q "\"$field\""; then
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

test_schema_pricing_structure() {
  echo "Test group: schema pricing structure"

  local schema_file="$REPO_ROOT/scripts/schemas/orchestrator-state.v1.json"

  if [ ! -f "$schema_file" ]; then
    fail "schema file missing — skipping pricing structure checks"
    return
  fi

  local content
  content=$(cat "$schema_file")

  # Must have nested 'rates' key, not flat model keys
  if echo "$content" | python3 -c "
import json, sys
schema = json.load(sys.stdin)
pricing = schema.get('properties', {}).get('pricing', {})
props = pricing.get('properties', {})
sys.exit(0 if 'rates' in props else 1)
" 2>/dev/null; then
    pass "schema pricing has nested 'rates' property"
  else
    fail "schema pricing missing 'rates' property (should not be flat map)"
  fi

  # Must use 'inputPerM'/'outputPerM' not 'input_per_mtok'/'output_per_mtok'
  if echo "$content" | grep -q '"inputPerM"'; then
    pass "schema pricing rates use 'inputPerM' (matches fetch-pricing.sh output)"
  else
    fail "schema pricing rates missing 'inputPerM' key"
  fi

  if echo "$content" | grep -q '"outputPerM"'; then
    pass "schema pricing rates use 'outputPerM' (matches fetch-pricing.sh output)"
  else
    fail "schema pricing rates missing 'outputPerM' key"
  fi

  # Must have metadata fields source, fetched_at
  for meta_field in "source" "fetched_at"; do
    if echo "$content" | python3 -c "
import json, sys
schema = json.load(sys.stdin)
pricing = schema.get('properties', {}).get('pricing', {})
props = pricing.get('properties', {})
sys.exit(0 if '$meta_field' in props else 1)
" 2>/dev/null; then
      pass "schema pricing has metadata field: $meta_field"
    else
      fail "schema pricing missing metadata field: $meta_field"
    fi
  done

  # Must NOT use old snake_case keys input_per_mtok / output_per_mtok
  if echo "$content" | grep -q '"input_per_mtok"'; then
    fail "schema pricing still uses deprecated 'input_per_mtok' key"
  else
    pass "schema pricing does not use deprecated 'input_per_mtok' key"
  fi

  if echo "$content" | grep -q '"output_per_mtok"'; then
    fail "schema pricing still uses deprecated 'output_per_mtok' key"
  else
    pass "schema pricing does not use deprecated 'output_per_mtok' key"
  fi
}

test_schema_verdict_enum_values() {
  echo "Test group: schema verdict enum values"

  local schema_file="$REPO_ROOT/scripts/schemas/orchestrator-state.v1.json"

  if [ ! -f "$schema_file" ]; then
    fail "schema file missing — skipping verdict checks"
    return
  fi

  local content
  content=$(cat "$schema_file")

  # Must use APPROVE and REQUEST_CHANGES (matching reviewer.md/orchestrator.md)
  if echo "$content" | grep -q "'APPROVE'"; then
    pass "schema verdict description references 'APPROVE'"
  else
    fail "schema verdict description should reference 'APPROVE' (not 'APPROVED')"
  fi

  if echo "$content" | grep -q "'REQUEST_CHANGES'"; then
    pass "schema verdict description references 'REQUEST_CHANGES'"
  else
    fail "schema verdict description should reference 'REQUEST_CHANGES' (not 'CHANGES_REQUESTED')"
  fi

  # Must NOT use deprecated APPROVED or CHANGES_REQUESTED
  if echo "$content" | grep -q "'APPROVED'"; then
    fail "schema verdict still uses deprecated 'APPROVED' value"
  else
    pass "schema verdict does not use deprecated 'APPROVED' value"
  fi

  if echo "$content" | grep -q "'CHANGES_REQUESTED'"; then
    fail "schema verdict still uses deprecated 'CHANGES_REQUESTED' value"
  else
    pass "schema verdict does not use deprecated 'CHANGES_REQUESTED' value"
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
  test_add_story_registers_story
  test_add_story_duplicate_fails
  test_add_story_missing_epic_fails
  test_add_story_invalid_difficulty_fails
  test_add_story_missing_required_flags

  echo ""
  test_schema_file_valid_json
  test_schema_has_required_fields
  test_schema_has_descriptions

  echo ""
  test_schema_pricing_structure

  echo ""
  test_schema_verdict_enum_values

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
