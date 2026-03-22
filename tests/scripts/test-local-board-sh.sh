#!/usr/bin/env bash
# test-local-board-sh.sh — Tests for scripts/lib/adapters/pm/local/board.sh
#
# Tests follow the Arrange/Act/Assert pattern. All operations run against
# temporary directories — no GitHub API calls, no mocking needed.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BOARD_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/board.sh"
COMMON_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/_common.sh"
ITEMS_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/items.sh"

PASS=0
FAIL=0

assert_eq() {
  local test_name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    Expected: $(echo "$expected" | head -5)"
    echo "    Actual:   $(echo "$actual" | head -5)"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local test_name="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF -- "$needle"; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    Expected to contain: $needle"
    echo "    Got: $haystack"
    FAIL=$((FAIL + 1))
  fi
}

assert_exit_zero() {
  local test_name="$1" exit_code="$2"
  if [ "$exit_code" -eq 0 ]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (expected exit 0, got $exit_code)"
    FAIL=$((FAIL + 1))
  fi
}

assert_exit_nonzero() {
  local test_name="$1" exit_code="$2"
  if [ "$exit_code" -ne 0 ]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (expected non-zero exit, got 0)"
    FAIL=$((FAIL + 1))
  fi
}

echo "========================================"
echo "Testing scripts/lib/adapters/pm/local/board.sh"
echo "========================================"
echo ""

# --- Test Group 0: File existence ---
echo "Test Group: File existence"

if [ -f "$BOARD_SH" ]; then
  echo "  PASS: board.sh exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: board.sh not found at $BOARD_SH"
  FAIL=$((FAIL + 1))
fi

source "$SCRIPT_DIR/lib/thresholds.sh"
LINE_COUNT=$(wc -l < "$BOARD_SH" 2>/dev/null || echo 9999)
if [ "$LINE_COUNT" -le "$THRESHOLD_ADAPTER_MODULE" ]; then
  echo "  PASS: board.sh is under $THRESHOLD_ADAPTER_MODULE lines ($LINE_COUNT)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: board.sh exceeds $THRESHOLD_ADAPTER_MODULE lines ($LINE_COUNT)"
  FAIL=$((FAIL + 1))
fi
echo ""

# --- Helper: run a snippet inside an isolated workflow dir ---
# Sources _common.sh, items.sh, and board.sh into a fresh shell.
run_snippet() {
  local tmpdir="$1"
  local snippet="$2"
  bash --norc --noprofile -c "
    _LOCAL_COMMON_LOADED=''
    _LOCAL_ITEMS_LOADED=''
    _LOCAL_BOARD_LOADED=''
    _LOCAL_WORKFLOW_DIR='$tmpdir/.workflow'
    source '$COMMON_SH'
    source '$ITEMS_SH'
    source '$BOARD_SH'
    $snippet
  "
}

# read_fm_field <file> <field> — extract a frontmatter scalar value.
read_fm_field() {
  local file="$1" field="$2"
  grep "^${field}:" "$file" | head -1 | sed "s/^${field}: *//"
}

# --- Test Group 1: pm_set_status updates frontmatter status field ---
echo "Test Group: pm_set_status updates frontmatter status field"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Board Story'" > /dev/null
ITEM_FILE="$TMPDIR/.workflow/items/1.md"

BEFORE=$(read_fm_field "$ITEM_FILE" status)
assert_eq "pm_set_status_initial_status_is_backlog" "backlog" "$BEFORE"

OUT=$(run_snippet "$TMPDIR" "pm_set_status 1 in-progress")
EXIT_CODE=$?
assert_exit_zero "pm_set_status_exits_zero" "$EXIT_CODE"

AFTER=$(read_fm_field "$ITEM_FILE" status)
assert_eq "pm_set_status_updates_status_field" "in-progress" "$AFTER"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 2: pm_set_status prints confirmation message ---
echo "Test Group: pm_set_status prints confirmation message"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Confirm Story'" > /dev/null

OUT=$(run_snippet "$TMPDIR" "pm_set_status 1 ready")
assert_contains "pm_set_status_confirmation_has_hash_id" "#1" "$OUT"
assert_contains "pm_set_status_confirmation_has_arrow" "->" "$OUT"
assert_contains "pm_set_status_confirmation_has_status" "ready" "$OUT"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 3: pm_set_status updates the `updated` timestamp ---
echo "Test Group: pm_set_status updates the updated timestamp"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Timestamp Story'" > /dev/null
ITEM_FILE="$TMPDIR/.workflow/items/1.md"

TS_BEFORE=$(read_fm_field "$ITEM_FILE" updated)
sleep 1
run_snippet "$TMPDIR" "pm_set_status 1 in-review" > /dev/null
TS_AFTER=$(read_fm_field "$ITEM_FILE" updated)

if [ "$TS_BEFORE" != "$TS_AFTER" ]; then
  echo "  PASS: pm_set_status_updated_timestamp_changes"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_set_status_updated_timestamp_changes (before=$TS_BEFORE, after=$TS_AFTER)"
  FAIL=$((FAIL + 1))
fi
rm -rf "$TMPDIR"
echo ""

# --- Test Group 4: pm_set_status logs to board-status.log ---
echo "Test Group: pm_set_status logs to board-status.log"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Log Story'" > /dev/null
# board-status.log lives in the agentic-workflow dir within the workflow dir
run_snippet "$TMPDIR" "pm_set_status 1 ready" > /dev/null

LOG_FILE="$TMPDIR/.workflow/logs/board-status.log"
if [ -f "$LOG_FILE" ]; then
  echo "  PASS: pm_set_status_log_file_created"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_set_status_log_file_created (not found at $LOG_FILE)"
  FAIL=$((FAIL + 1))
fi

if [ -f "$LOG_FILE" ] && grep -q "issue=1" "$LOG_FILE"; then
  echo "  PASS: pm_set_status_log_contains_issue_id"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_set_status_log_contains_issue_id (log: $(cat "$LOG_FILE" 2>/dev/null))"
  FAIL=$((FAIL + 1))
fi

if [ -f "$LOG_FILE" ] && grep -q "status=ready" "$LOG_FILE"; then
  echo "  PASS: pm_set_status_log_contains_status"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_set_status_log_contains_status (log: $(cat "$LOG_FILE" 2>/dev/null))"
  FAIL=$((FAIL + 1))
fi

# Log format: [ISO-timestamp] key=value key=value
if [ -f "$LOG_FILE" ] && grep -qE '^\[20[0-9]{2}-[0-9]{2}-[0-9]{2}T' "$LOG_FILE"; then
  echo "  PASS: pm_set_status_log_iso_timestamp_format"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_set_status_log_iso_timestamp_format (log: $(cat "$LOG_FILE" 2>/dev/null))"
  FAIL=$((FAIL + 1))
fi
rm -rf "$TMPDIR"
echo ""

# --- Test Group 5: pm_set_status skips when already at target ---
echo "Test Group: pm_set_status skips when already at target status"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Skip Story'" > /dev/null
# Move to in-progress first
run_snippet "$TMPDIR" "pm_set_status 1 in-progress" > /dev/null
ITEM_FILE="$TMPDIR/.workflow/items/1.md"
TS_BEFORE=$(read_fm_field "$ITEM_FILE" updated)

# Call again with same status
OUT=$(run_snippet "$TMPDIR" "pm_set_status 1 in-progress")
EXIT_CODE=$?
assert_exit_zero "pm_set_status_skip_exits_zero" "$EXIT_CODE"
assert_contains "pm_set_status_skip_message_has_id" "#1" "$OUT"
assert_contains "pm_set_status_skip_message_has_status" "in-progress" "$OUT"
assert_contains "pm_set_status_skip_message_has_already" "already" "$OUT"

TS_AFTER=$(read_fm_field "$ITEM_FILE" updated)
assert_eq "pm_set_status_skip_does_not_change_timestamp" "$TS_BEFORE" "$TS_AFTER"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 6: pm_set_status error on invalid status ---
echo "Test Group: pm_set_status error on invalid status"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Invalid Status Story'" > /dev/null

OUT=$(run_snippet "$TMPDIR" "pm_set_status 1 invalid-status" 2>&1)
EXIT_CODE=$?
assert_exit_nonzero "pm_set_status_invalid_status_fails" "$EXIT_CODE"
assert_contains "pm_set_status_invalid_status_message" "invalid" "$OUT"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 7: pm_set_status error on missing item ---
echo "Test Group: pm_set_status error on nonexistent item"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "_local_ensure_dirs"

OUT=$(run_snippet "$TMPDIR" "pm_set_status 999 ready" 2>&1)
EXIT_CODE=$?
assert_exit_nonzero "pm_set_status_missing_item_fails" "$EXIT_CODE"
assert_contains "pm_set_status_missing_item_message" "999" "$OUT"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 8: pm_set_status accepts all valid status values ---
echo "Test Group: pm_set_status accepts all valid status values"

for STATUS in backlog ready in-progress in-review done; do
  TMPDIR=$(mktemp -d)
  run_snippet "$TMPDIR" "pm_create_item story 'Status Test $STATUS'" > /dev/null
  EXIT_CODE=0
  run_snippet "$TMPDIR" "pm_set_status 1 $STATUS" > /dev/null || EXIT_CODE=$?
  assert_exit_zero "pm_set_status_accepts_$STATUS" "$EXIT_CODE"
  ITEM_FILE="$TMPDIR/.workflow/items/1.md"
  ACTUAL=$(read_fm_field "$ITEM_FILE" status)
  assert_eq "pm_set_status_sets_$STATUS" "$STATUS" "$ACTUAL"
  rm -rf "$TMPDIR"
done
echo ""

# --- Test Group 9: pm_add_to_board is a no-op ---
echo "Test Group: pm_add_to_board is a no-op"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Board Story'" > /dev/null

OUT=$(run_snippet "$TMPDIR" "pm_add_to_board 1")
EXIT_CODE=$?
assert_exit_zero "pm_add_to_board_exits_zero" "$EXIT_CODE"
assert_contains "pm_add_to_board_output_has_id" "#1" "$OUT"
assert_contains "pm_add_to_board_output_has_added" "added" "$OUT"
assert_contains "pm_add_to_board_output_has_board" "board" "$OUT"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 10: pm_add_to_board usage error ---
echo "Test Group: pm_add_to_board usage error with no arguments"

TMPDIR=$(mktemp -d)
OUT=$(run_snippet "$TMPDIR" "pm_add_to_board" 2>&1)
EXIT_CODE=$?
assert_exit_nonzero "pm_add_to_board_no_args_fails" "$EXIT_CODE"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 11: pm_batch_set_status with multiple pairs ---
echo "Test Group: pm_batch_set_status with multiple pairs"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Story A'" > /dev/null
run_snippet "$TMPDIR" "pm_create_item story 'Story B'" > /dev/null
run_snippet "$TMPDIR" "pm_create_item story 'Story C'" > /dev/null

OUT=$(run_snippet "$TMPDIR" "pm_batch_set_status '1:ready' '2:in-progress' '3:in-review'")
EXIT_CODE=$?
assert_exit_zero "pm_batch_set_status_exits_zero" "$EXIT_CODE"

STAT_1=$(read_fm_field "$TMPDIR/.workflow/items/1.md" status)
STAT_2=$(read_fm_field "$TMPDIR/.workflow/items/2.md" status)
STAT_3=$(read_fm_field "$TMPDIR/.workflow/items/3.md" status)
assert_eq "pm_batch_set_status_item1_ready" "ready" "$STAT_1"
assert_eq "pm_batch_set_status_item2_in_progress" "in-progress" "$STAT_2"
assert_eq "pm_batch_set_status_item3_in_review" "in-review" "$STAT_3"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 12: pm_batch_set_status error on malformed pair ---
echo "Test Group: pm_batch_set_status error on malformed pair"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Story'" > /dev/null

# Pair without colon separator
OUT=$(run_snippet "$TMPDIR" "pm_batch_set_status 'badpair'" 2>&1)
EXIT_CODE=$?
assert_exit_nonzero "pm_batch_set_status_malformed_pair_fails" "$EXIT_CODE"
assert_contains "pm_batch_set_status_malformed_pair_message" "Invalid" "$OUT"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 13: pm_batch_set_status no arguments error ---
echo "Test Group: pm_batch_set_status error with no arguments"

TMPDIR=$(mktemp -d)
OUT=$(run_snippet "$TMPDIR" "pm_batch_set_status" 2>&1)
EXIT_CODE=$?
assert_exit_nonzero "pm_batch_set_status_no_args_fails" "$EXIT_CODE"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 14: pm_get_status reads status from frontmatter ---
echo "Test Group: pm_get_status reads status from frontmatter"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Get Status Story'" > /dev/null
run_snippet "$TMPDIR" "pm_set_status 1 in-review" > /dev/null

OUT=$(run_snippet "$TMPDIR" "pm_get_status 1")
EXIT_CODE=$?
assert_exit_zero "pm_get_status_exits_zero" "$EXIT_CODE"
assert_eq "pm_get_status_returns_status" "in-review" "$OUT"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 15: pm_get_status error on missing item ---
echo "Test Group: pm_get_status error on nonexistent item"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "_local_ensure_dirs"
OUT=$(run_snippet "$TMPDIR" "pm_get_status 999" 2>&1)
EXIT_CODE=$?
assert_exit_nonzero "pm_get_status_missing_item_fails" "$EXIT_CODE"
assert_contains "pm_get_status_missing_item_message" "999" "$OUT"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 16: board log format matches [ISO-timestamp] key=value ---
echo "Test Group: board log entries match format contract"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Log Format Story'" > /dev/null
run_snippet "$TMPDIR" "pm_set_status 1 done" > /dev/null

LOG_FILE="$TMPDIR/.workflow/logs/board-status.log"
if [ -f "$LOG_FILE" ]; then
  # Each line must start with [ISO-timestamp] followed by key=value pairs
  INVALID_LINES=$(grep -vE '^\[20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\] ' "$LOG_FILE" | wc -l | tr -d ' ')
  if [ "$INVALID_LINES" -eq 0 ]; then
    echo "  PASS: board_log_all_lines_match_format"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: board_log_all_lines_match_format ($INVALID_LINES invalid lines: $(cat "$LOG_FILE"))"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  FAIL: board_log_format_log_file_missing"
  FAIL=$((FAIL + 1))
fi
rm -rf "$TMPDIR"
echo ""

# --- Test Group 17: pm_batch_set_status partial output includes each ID ---
echo "Test Group: pm_batch_set_status output includes each item ID"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Alpha'" > /dev/null
run_snippet "$TMPDIR" "pm_create_item story 'Beta'" > /dev/null

OUT=$(run_snippet "$TMPDIR" "pm_batch_set_status '1:ready' '2:done'")
assert_contains "pm_batch_set_status_output_has_id1" "#1" "$OUT"
assert_contains "pm_batch_set_status_output_has_id2" "#2" "$OUT"
rm -rf "$TMPDIR"
echo ""

# --- Summary ---
echo "========================================"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
