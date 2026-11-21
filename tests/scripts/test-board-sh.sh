#!/usr/bin/env bash
# test-board-sh.sh — Validates board.sh adapter module (board management functions).
# Tests deterministic helpers and function signatures using mock adapter setup.
# No live GitHub API calls are made.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/thresholds.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PM_SH="$REPO_ROOT/scripts/lib/pm.sh"
BOARD_SH="$REPO_ROOT/scripts/lib/adapters/pm/github/board.sh"
ADAPTERS_DIR="$REPO_ROOT/scripts/lib/adapters/pm/github"
# Use a fully configured fixture board, not the (empty) repository config.
export _CFG_FILE_OVERRIDE="$REPO_ROOT/tests/fixtures/config/github-board.json"

PASS=0
FAIL=0

assert_eq() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"
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

assert_exit_zero() {
  local test_name="$1"
  local exit_code="$2"
  if [ "$exit_code" -eq 0 ]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (expected exit 0, got $exit_code)"
    FAIL=$((FAIL + 1))
  fi
}

assert_exit_nonzero() {
  local test_name="$1"
  local exit_code="$2"
  if [ "$exit_code" -ne 0 ]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (expected non-zero exit, got 0)"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local test_name="$1"
  local needle="$2"
  local haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    Expected to contain: $needle"
    echo "    Actual: $haystack"
    FAIL=$((FAIL + 1))
  fi
}

assert_function_exists() {
  local test_name="$1"
  local func_name="$2"
  local env_output="$3"
  if echo "$env_output" | grep -q "^${func_name}$"; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (function '$func_name' not found)"
    FAIL=$((FAIL + 1))
  fi
}

echo "========================================"
echo "Testing scripts/lib/adapters/pm/github/board.sh"
echo "========================================"
echo ""

# --- Test Group 1: File properties ---
echo "Test Group: File properties"

if [ -f "$BOARD_SH" ]; then
  echo "  PASS: board.sh exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: board.sh not found at $BOARD_SH"
  FAIL=$((FAIL + 1))
fi

# Check file is not too large (should split reconcile if over adapter module threshold)
if [ -f "$BOARD_SH" ]; then
  BOARD_LINES=$(wc -l < "$BOARD_SH" | tr -d ' ')
  if [ "$BOARD_LINES" -le "$THRESHOLD_ADAPTER_MODULE" ]; then
    echo "  PASS: board.sh is within $THRESHOLD_ADAPTER_MODULE-line limit ($BOARD_LINES lines)"
    PASS=$((PASS + 1))
  else
    # If over threshold, reconcile.sh must exist as a split
    if [ -f "$ADAPTERS_DIR/reconcile.sh" ]; then
      echo "  PASS: board.sh exceeds $THRESHOLD_ADAPTER_MODULE lines but reconcile.sh exists as split"
      PASS=$((PASS + 1))
    else
      echo "  FAIL: board.sh is $BOARD_LINES lines (>$THRESHOLD_ADAPTER_MODULE) and reconcile.sh does not exist"
      FAIL=$((FAIL + 1))
    fi
  fi
fi

echo ""

# --- Test Group 2: Function existence via pm.sh sourcing ---
echo "Test Group: Function existence after sourcing via pm.sh"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  source \"$PM_SH\"
  # List all defined functions starting with pm_ or _gh_
  declare -F | awk '{print \$3}' | grep -E '^(pm_|_gh_)' | sort
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
FUNC_LIST=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "Sourcing_pm_sh_with_board_adapter_succeeds" "$EXIT_CODE"

# Public functions
assert_function_exists "pm_set_status_exists" "pm_set_status" "$FUNC_LIST"
assert_function_exists "pm_add_to_board_exists" "pm_add_to_board" "$FUNC_LIST"
assert_function_exists "pm_batch_set_status_exists" "pm_batch_set_status" "$FUNC_LIST"
assert_function_exists "pm_reconcile_exists" "pm_reconcile" "$FUNC_LIST"

# Internal helpers
assert_function_exists "_gh_fetch_item_info_exists" "_gh_fetch_item_info" "$FUNC_LIST"
assert_function_exists "_gh_extract_item_info_exists" "_gh_extract_item_info" "$FUNC_LIST"
assert_function_exists "_gh_mutate_status_exists" "_gh_mutate_status" "$FUNC_LIST"
assert_function_exists "_gh_verify_status_exists" "_gh_verify_status" "$FUNC_LIST"
assert_function_exists "_gh_status_to_option_id_exists" "_gh_status_to_option_id" "$FUNC_LIST"
assert_function_exists "_gh_status_to_display_exists" "_gh_status_to_display" "$FUNC_LIST"

echo ""

# --- Test Group 3: _gh_status_to_option_id mapping ---
echo "Test Group: _gh_status_to_option_id mapping"

for status_pair in "backlog:opt-backlog" "ready:opt-ready" "in-progress:opt-in-progress" "in-review:opt-in-review" "done:opt-done"; do
  status_name="${status_pair%%:*}"
  expected_id="${status_pair##*:}"

  TMPOUT=$(mktemp)
  bash --norc --noprofile -c "
    source \"$PM_SH\"
    _gh_status_to_option_id \"$status_name\"
  " > "$TMPOUT" 2>&1
  EXIT_CODE=$?
  ACTUAL_ID=$(cat "$TMPOUT" | tr -d '\n')
  rm -f "$TMPOUT"

  assert_exit_zero "StatusToOptionId_${status_name}_exits_zero" "$EXIT_CODE"
  assert_eq "StatusToOptionId_${status_name}_returns_correct_id" "$expected_id" "$ACTUAL_ID"
done

# Invalid status should fail
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  source \"$PM_SH\"
  _gh_status_to_option_id \"invalid-status\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
rm -f "$TMPOUT"

assert_exit_nonzero "StatusToOptionId_invalid_status_exits_nonzero" "$EXIT_CODE"

echo ""

# --- Test Group 4: _gh_status_to_display mapping ---
echo "Test Group: _gh_status_to_display mapping"

for status_pair in "backlog:Backlog" "ready:Ready" "in-progress:In Progress" "in-review:In Review" "done:Done"; do
  status_name="${status_pair%%:*}"
  expected_display="${status_pair##*:}"

  TMPOUT=$(mktemp)
  bash --norc --noprofile -c "
    source \"$PM_SH\"
    _gh_status_to_display \"$status_name\"
  " > "$TMPOUT" 2>&1
  EXIT_CODE=$?
  ACTUAL_DISPLAY=$(cat "$TMPOUT" | tr -d '\n')
  rm -f "$TMPOUT"

  assert_exit_zero "StatusToDisplay_${status_name}_exits_zero" "$EXIT_CODE"
  assert_eq "StatusToDisplay_${status_name}_returns_correct_display" "$expected_display" "$ACTUAL_DISPLAY"
done

# Invalid status should fail
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  source \"$PM_SH\"
  _gh_status_to_display \"bogus\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
rm -f "$TMPOUT"

assert_exit_nonzero "StatusToDisplay_invalid_status_exits_nonzero" "$EXIT_CODE"

echo ""

# --- Test Group 5: _gh_extract_item_info ---
echo "Test Group: _gh_extract_item_info extracts ITEM_ID and CURRENT_STATUS"

# Simulate a valid GraphQL response
MOCK_JSON='{"data":{"repository":{"issue":{"projectItems":{"nodes":[{"id":"PVTI_test123","fieldValueByName":{"name":"In Progress"}}]}}}}}'

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  source \"$PM_SH\"
  _gh_extract_item_info '$MOCK_JSON'
  echo \"ITEM_ID=\$ITEM_ID\"
  echo \"CURRENT_STATUS=\$CURRENT_STATUS\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
EXTRACT_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "ExtractItemInfo_valid_json_exits_zero" "$EXIT_CODE"
assert_contains "ExtractItemInfo_sets_ITEM_ID" "ITEM_ID=PVTI_test123" "$EXTRACT_OUTPUT"
assert_contains "ExtractItemInfo_sets_CURRENT_STATUS" "CURRENT_STATUS=In Progress" "$EXTRACT_OUTPUT"

# Test with empty nodes (item not on board)
MOCK_EMPTY='{"data":{"repository":{"issue":{"projectItems":{"nodes":[]}}}}}'

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  source \"$PM_SH\"
  _gh_extract_item_info '$MOCK_EMPTY'
  echo \"ITEM_ID=\$ITEM_ID\"
  echo \"CURRENT_STATUS=\$CURRENT_STATUS\"
" > "$TMPOUT" 2>&1
EXTRACT_EMPTY_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_contains "ExtractItemInfo_empty_nodes_ITEM_ID_empty" "ITEM_ID=" "$EXTRACT_EMPTY_OUTPUT"

echo ""

# --- Test Group 6: pm_set_status rejects invalid status ---
echo "Test Group: pm_set_status rejects invalid status"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  source \"$PM_SH\"
  pm_set_status 999 invalid-status
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
ERROR_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_nonzero "SetStatus_invalid_status_exits_nonzero" "$EXIT_CODE"
assert_contains "SetStatus_invalid_status_error_message" "invalid status" "$ERROR_OUTPUT"

echo ""

# --- Test Group 7: pm_batch_set_status rejects invalid pairs ---
echo "Test Group: pm_batch_set_status rejects invalid input"

# No arguments
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  source \"$PM_SH\"
  pm_batch_set_status
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
rm -f "$TMPOUT"

assert_exit_nonzero "BatchSetStatus_no_args_exits_nonzero" "$EXIT_CODE"

# Invalid pair format
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  source \"$PM_SH\"
  pm_batch_set_status 'bad-format'
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
rm -f "$TMPOUT"

assert_exit_nonzero "BatchSetStatus_invalid_pair_exits_nonzero" "$EXIT_CODE"

# Invalid status in pair
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  source \"$PM_SH\"
  pm_batch_set_status '123:bogus'
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
rm -f "$TMPOUT"

assert_exit_nonzero "BatchSetStatus_invalid_status_in_pair_exits_nonzero" "$EXIT_CODE"

echo ""

# --- Test Group 8: pm_reconcile rejects missing state file ---
echo "Test Group: pm_reconcile rejects missing state file"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  source \"$PM_SH\"
  pm_reconcile --from-state /nonexistent/file.json
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
ERROR_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_nonzero "Reconcile_missing_state_file_exits_nonzero" "$EXIT_CODE"
assert_contains "Reconcile_missing_state_error_message" "required" "$ERROR_OUTPUT"

echo ""

# --- Test Group 9: Logging setup ---
echo "Test Group: Logging uses board-status.log"

# Verify board.sh references the expected log file
if grep -q "board-status.log" "$BOARD_SH" 2>/dev/null; then
  echo "  PASS: board.sh references board-status.log"
  PASS=$((PASS + 1))
else
  echo "  FAIL: board.sh does not reference board-status.log"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test Group 10: pm_add_to_board rejects missing argument ---
echo "Test Group: pm_add_to_board rejects missing argument"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  source \"$PM_SH\"
  pm_add_to_board
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
rm -f "$TMPOUT"

assert_exit_nonzero "AddToBoard_no_args_exits_nonzero" "$EXIT_CODE"

echo ""

# --- Test Group 11: Reconcile split check ---
echo "Test Group: Reconcile split (if board.sh > $THRESHOLD_ADAPTER_MODULE lines, reconcile.sh must exist)"

if [ -f "$BOARD_SH" ]; then
  BOARD_LINES=$(wc -l < "$BOARD_SH" | tr -d ' ')
  if [ "$BOARD_LINES" -gt "$THRESHOLD_ADAPTER_MODULE" ]; then
    if [ -f "$ADAPTERS_DIR/reconcile.sh" ]; then
      echo "  PASS: reconcile.sh exists (board.sh is $BOARD_LINES lines)"
      PASS=$((PASS + 1))

      # Verify reconcile.sh defines pm_reconcile
      TMPOUT=$(mktemp)
      bash --norc --noprofile -c "
        source \"$PM_SH\"
        declare -F | awk '{print \$3}' | grep '^pm_reconcile$'
      " > "$TMPOUT" 2>&1
      RECON_FUNC=$(cat "$TMPOUT")
      rm -f "$TMPOUT"

      assert_function_exists "pm_reconcile_in_reconcile_sh" "pm_reconcile" "$RECON_FUNC"
    else
      echo "  FAIL: board.sh is $BOARD_LINES lines but reconcile.sh is missing"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "  PASS: board.sh is $BOARD_LINES lines (under 200), no split needed"
    PASS=$((PASS + 1))
  fi
fi

echo ""

# --- Test Group 12: All five status values accepted ---
echo "Test Group: All five status values accepted by status helpers"

ALL_ACCEPTED=true
for status in backlog ready in-progress in-review done; do
  TMPOUT=$(mktemp)
  bash --norc --noprofile -c "
    source \"$PM_SH\"
    _gh_status_to_option_id \"$status\" && _gh_status_to_display \"$status\"
  " > "$TMPOUT" 2>&1
  EXIT_CODE=$?
  rm -f "$TMPOUT"

  if [ "$EXIT_CODE" -ne 0 ]; then
    echo "  FAIL: Status '$status' not accepted"
    FAIL=$((FAIL + 1))
    ALL_ACCEPTED=false
  fi
done

if [ "$ALL_ACCEPTED" = true ]; then
  echo "  PASS: All five status values accepted"
  PASS=$((PASS + 1))
fi

echo ""

# --- Test Group: board operations are skipped when no board is configured ---
echo "Test Group: no board configured"

EMPTY_CFG=$(mktemp)
echo '{"pm":{"adapter":"github"},"github":{}}' > "$EMPTY_CFG"
for call in "pm_set_status 1 done" "pm_add_to_board 1" "pm_batch_set_status 1:done"; do
  TMPOUT=$(mktemp)
  # A gh stub that fails loudly proves no GitHub call is attempted.
  STUB_DIR=$(mktemp -d)
  printf '#!/bin/sh\necho "gh called: $*" >&2\nexit 99\n' > "$STUB_DIR/gh"
  chmod +x "$STUB_DIR/gh"
  PATH="$STUB_DIR:$PATH" _CFG_FILE_OVERRIDE="$EMPTY_CFG" bash --norc --noprofile -c "
    source \"$PM_SH\"
    _external_$call
  " > "$TMPOUT" 2>&1
  EXIT_CODE=$?
  OUT=$(cat "$TMPOUT")
  rm -rf "$TMPOUT" "$STUB_DIR"
  assert_exit_zero "NoBoard_${call%% *}_exits_zero" "$EXIT_CODE"
  assert_contains "NoBoard_${call%% *}_prints_notice" "no GitHub project board configured" "$OUT"
  case "$OUT" in
    *"gh called"*) echo "  FAIL: NoBoard_${call%% *}_does_not_call_gh"; FAIL=$((FAIL + 1)) ;;
    *) echo "  PASS: NoBoard_${call%% *}_does_not_call_gh"; PASS=$((PASS + 1)) ;;
  esac
done
rm -f "$EMPTY_CFG"

echo ""

# --- Summary ---
echo "========================================"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
