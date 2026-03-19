#!/usr/bin/env bash
# test-swap-wrappers.sh — Validates that all wrapper scripts delegate to pm_*
# functions and preserve their original CLI interface.
# Runs locally using mock adapters (no live GitHub API calls).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0

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

assert_contains() {
  local test_name="$1" needle="$2" haystack="$3"
  case "$haystack" in
    *"$needle"*)
      echo "  PASS: $test_name"
      PASS=$((PASS + 1))
      ;;
    *)
      echo "  FAIL: $test_name"
      echo "    Expected to contain: $needle"
      echo "    Actual: $haystack"
      FAIL=$((FAIL + 1))
      ;;
  esac
}

assert_not_contains() {
  local test_name="$1" needle="$2" haystack="$3"
  case "$haystack" in
    *"$needle"*)
      echo "  FAIL: $test_name"
      echo "    Should NOT contain: $needle"
      FAIL=$((FAIL + 1))
      ;;
    *)
      echo "  PASS: $test_name"
      PASS=$((PASS + 1))
      ;;
  esac
}

echo "========================================"
echo "Testing wrapper scripts (E03-S01 Swap)"
echo "========================================"
echo ""

# --- Shared mock setup ---
MOCK_DIR=$(mktemp -d)
CALL_LOG="$MOCK_DIR/calls.log"
> "$CALL_LOG"

# Create a mock adapter that logs all pm_* calls
mkdir -p "$MOCK_DIR/adapter"
cat > "$MOCK_DIR/adapter/mock.sh" << 'MOCK_ADAPTER'
pm_set_status() {
  echo "CALL:pm_set_status|$*" >> "${_MOCK_CALL_LOG}"
  echo "mock:pm_set_status $*"
}
pm_batch_set_status() {
  echo "CALL:pm_batch_set_status|$*" >> "${_MOCK_CALL_LOG}"
  echo "mock:pm_batch_set_status $*"
}
pm_start_work() {
  echo "CALL:pm_start_work|$*" >> "${_MOCK_CALL_LOG}"
  echo "mock:pm_start_work $*"
}
pm_complete_work() {
  echo "CALL:pm_complete_work|$*" >> "${_MOCK_CALL_LOG}"
  echo "mock:pm_complete_work $*"
}
pm_done() {
  echo "CALL:pm_done|$*" >> "${_MOCK_CALL_LOG}"
  echo "mock:pm_done $*"
}
pm_create_item() {
  echo "CALL:pm_create_item|$*" >> "${_MOCK_CALL_LOG}"
  # Return a mock issue number
  echo "999"
}
pm_add_to_board() {
  echo "CALL:pm_add_to_board|$*" >> "${_MOCK_CALL_LOG}"
  echo "mock:pm_add_to_board $*"
}
pm_add_label() {
  echo "CALL:pm_add_label|$*" >> "${_MOCK_CALL_LOG}"
  echo "mock:pm_add_label $*"
}
pm_add_comment() {
  echo "CALL:pm_add_comment|$*" >> "${_MOCK_CALL_LOG}"
  echo "mock:pm_add_comment $*"
}
pm_reconcile() {
  echo "CALL:pm_reconcile|$*" >> "${_MOCK_CALL_LOG}"
  echo "mock:pm_reconcile $*"
}
pm_get_item() {
  echo "CALL:pm_get_item|$*" >> "${_MOCK_CALL_LOG}"
  # Return mock JSON for --json body
  if [[ "$*" == *"--json"* ]]; then
    echo '{"body":"test body with #<this-issue> ref"}'
  else
    echo "mock:pm_get_item $*"
  fi
}
pm_update_item() {
  echo "CALL:pm_update_item|$*" >> "${_MOCK_CALL_LOG}"
  echo "mock:pm_update_item $*"
}
MOCK_ADAPTER

# =====================================================
# Test Group 1: item-set-status.sh is a wrapper
# =====================================================
echo "Test Group: item-set-status.sh delegates to pm_set_status"

> "$CALL_LOG"
TMPOUT=$(mktemp)
export _PM_TEST_ADAPTER_DIR="$MOCK_DIR/adapter"
export _MOCK_CALL_LOG="$CALL_LOG"
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"$MOCK_DIR/adapter\"
  export _MOCK_CALL_LOG=\"$CALL_LOG\"
  \"$REPO_ROOT/scripts/item-set-status.sh\" 42 in-progress
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
CALLS=$(cat "$CALL_LOG")
rm -f "$TMPOUT"

assert_exit_zero "issue_set_status_exits_zero" "$EXIT_CODE"
assert_contains "issue_set_status_calls_pm_set_status" "CALL:pm_set_status|42 in-progress" "$CALLS"

echo ""

# Test: item-set-status.sh preserves error on missing args
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"$MOCK_DIR/adapter\"
  export _MOCK_CALL_LOG=\"$CALL_LOG\"
  \"$REPO_ROOT/scripts/item-set-status.sh\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_nonzero "issue_set_status_errors_on_no_args" "$EXIT_CODE"
assert_contains "issue_set_status_shows_usage_on_no_args" "Usage" "$OUTPUT"

echo ""

# =====================================================
# Test Group 2: batch-set-status.sh is a wrapper
# =====================================================
echo "Test Group: batch-set-status.sh delegates to pm_batch_set_status"

> "$CALL_LOG"
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"$MOCK_DIR/adapter\"
  export _MOCK_CALL_LOG=\"$CALL_LOG\"
  \"$REPO_ROOT/scripts/batch-set-status.sh\" 100:ready 101:in-progress
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
CALLS=$(cat "$CALL_LOG")
rm -f "$TMPOUT"

assert_exit_zero "batch_set_status_exits_zero" "$EXIT_CODE"
assert_contains "batch_set_status_calls_pm_batch_set_status" "CALL:pm_batch_set_status|100:ready 101:in-progress" "$CALLS"

echo ""

# Test: batch-set-status.sh preserves error on missing args
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"$MOCK_DIR/adapter\"
  export _MOCK_CALL_LOG=\"$CALL_LOG\"
  \"$REPO_ROOT/scripts/batch-set-status.sh\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_nonzero "batch_set_status_errors_on_no_args" "$EXIT_CODE"
assert_contains "batch_set_status_shows_usage_on_no_args" "Usage" "$OUTPUT"

echo ""

# =====================================================
# Test Group 3: item-start.sh is a wrapper
# =====================================================
echo "Test Group: item-start.sh delegates to pm_start_work"

> "$CALL_LOG"
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"$MOCK_DIR/adapter\"
  export _MOCK_CALL_LOG=\"$CALL_LOG\"
  \"$REPO_ROOT/scripts/item-start.sh\" 42 --model sonnet --agent builder
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
CALLS=$(cat "$CALL_LOG")
rm -f "$TMPOUT"

assert_exit_zero "issue_start_exits_zero" "$EXIT_CODE"
assert_contains "issue_start_calls_pm_start_work" "CALL:pm_start_work|42 --model sonnet --agent builder" "$CALLS"
# Should preserve the echo output
assert_contains "issue_start_prints_started_message" "started" "$OUTPUT"

echo ""

# Test: item-start.sh preserves error on missing args
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"$MOCK_DIR/adapter\"
  export _MOCK_CALL_LOG=\"$CALL_LOG\"
  \"$REPO_ROOT/scripts/item-start.sh\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_nonzero "issue_start_errors_on_no_args" "$EXIT_CODE"
assert_contains "issue_start_shows_usage_on_no_args" "Usage" "$OUTPUT"

echo ""

# =====================================================
# Test Group 4: item-review.sh is a wrapper
# =====================================================
echo "Test Group: item-review.sh delegates to pm_complete_work"

> "$CALL_LOG"
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"$MOCK_DIR/adapter\"
  export _MOCK_CALL_LOG=\"$CALL_LOG\"
  \"$REPO_ROOT/scripts/item-review.sh\" 55 abc123
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
CALLS=$(cat "$CALL_LOG")
rm -f "$TMPOUT"

assert_exit_zero "issue_review_exits_zero" "$EXIT_CODE"
assert_contains "issue_review_calls_pm_complete_work" "CALL:pm_complete_work|55 abc123" "$CALLS"
assert_contains "issue_review_prints_review_message" "review" "$OUTPUT"

echo ""

# Test: item-review.sh preserves error on missing args
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"$MOCK_DIR/adapter\"
  export _MOCK_CALL_LOG=\"$CALL_LOG\"
  \"$REPO_ROOT/scripts/item-review.sh\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_nonzero "issue_review_errors_on_no_args" "$EXIT_CODE"
assert_contains "issue_review_shows_usage_on_no_args" "Usage" "$OUTPUT"

echo ""

# =====================================================
# Test Group 5: item-close.sh is a wrapper
# =====================================================
echo "Test Group: item-close.sh delegates to pm_done"

> "$CALL_LOG"
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"$MOCK_DIR/adapter\"
  export _MOCK_CALL_LOG=\"$CALL_LOG\"
  \"$REPO_ROOT/scripts/item-close.sh\" 77
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
CALLS=$(cat "$CALL_LOG")
rm -f "$TMPOUT"

assert_exit_zero "issue_close_exits_zero" "$EXIT_CODE"
assert_contains "issue_close_calls_pm_done" "CALL:pm_done|77" "$CALLS"

echo ""

# Test: item-close.sh preserves error on missing args
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"$MOCK_DIR/adapter\"
  export _MOCK_CALL_LOG=\"$CALL_LOG\"
  \"$REPO_ROOT/scripts/item-close.sh\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_nonzero "issue_close_errors_on_no_args" "$EXIT_CODE"
assert_contains "issue_close_shows_usage_on_no_args" "Usage" "$OUTPUT"

echo ""

# =====================================================
# Test Group 6: reconcile-board.sh is a wrapper
# =====================================================
echo "Test Group: reconcile-board.sh delegates to pm_reconcile"

# Create a minimal state file for the test
STATE_FILE="$MOCK_DIR/test-state.json"
cat > "$STATE_FILE" << 'STATE_JSON'
{
  "session": {"backlog": 100},
  "dispatches": [],
  "epics": {}
}
STATE_JSON

> "$CALL_LOG"
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"$MOCK_DIR/adapter\"
  export _MOCK_CALL_LOG=\"$CALL_LOG\"
  \"$REPO_ROOT/scripts/reconcile-board.sh\" --from-state \"$STATE_FILE\" --dry-run
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
CALLS=$(cat "$CALL_LOG")
rm -f "$TMPOUT"

assert_exit_zero "reconcile_board_exits_zero" "$EXIT_CODE"
assert_contains "reconcile_board_calls_pm_reconcile" "CALL:pm_reconcile|--from-state" "$CALLS"

echo ""

# Test: reconcile-board.sh preserves error on missing args
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"$MOCK_DIR/adapter\"
  export _MOCK_CALL_LOG=\"$CALL_LOG\"
  \"$REPO_ROOT/scripts/reconcile-board.sh\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_nonzero "reconcile_board_errors_on_no_args" "$EXIT_CODE"

echo ""

# =====================================================
# Test Group 7: setup-labels.sh is a wrapper
# =====================================================
echo "Test Group: setup-labels.sh delegates to pm_add_label"

> "$CALL_LOG"
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"$MOCK_DIR/adapter\"
  export _MOCK_CALL_LOG=\"$CALL_LOG\"
  \"$REPO_ROOT/scripts/setup-labels.sh\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
CALLS=$(cat "$CALL_LOG")
rm -f "$TMPOUT"

assert_exit_zero "setup_labels_exits_zero" "$EXIT_CODE"
# Should call pm_add_label for each standard label
assert_contains "setup_labels_creates_type_feature" "pm_add_label" "$CALLS"
assert_contains "setup_labels_creates_difficulty_easy" "difficulty/easy" "$CALLS"
assert_contains "setup_labels_creates_hierarchy_backlog" "hierarchy/backlog" "$CALLS"
# pm_add_label should be called with --create-if-missing
assert_contains "setup_labels_uses_create_if_missing" "--create-if-missing" "$CALLS"

echo ""

# =====================================================
# Test Group 8: No gh CLI calls in wrapper scripts
# =====================================================
echo "Test Group: No direct gh CLI calls in wrapper scripts"

SCRIPTS=(
  "item-set-status.sh"
  "batch-set-status.sh"
  "item-start.sh"
  "item-review.sh"
  "item-close.sh"
  "reconcile-board.sh"
  "setup-labels.sh"
)

for script in "${SCRIPTS[@]}"; do
  SCRIPT_PATH="$REPO_ROOT/scripts/$script"
  # Look for direct gh CLI calls (not commented out, not in comments)
  # Exclude lines that are comments and lines that source pm.sh
  GH_CALLS=$(grep -n "^[^#]*\bgh\b" "$SCRIPT_PATH" 2>/dev/null | grep -v "# " | grep -v "source" || true)
  if [ -z "$GH_CALLS" ]; then
    echo "  PASS: ${script}_has_no_direct_gh_calls"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${script}_has_no_direct_gh_calls"
    echo "    Found gh calls: $GH_CALLS"
    FAIL=$((FAIL + 1))
  fi
done

# item-create.sh is special: it still has gh CLI calls for
# placeholder replacement and title prefixing (orchestrator-level concerns).
# But it should NOT have gh calls for board/label/issue-create operations
# (those go through pm_*).
SCRIPT_PATH="$REPO_ROOT/scripts/item-create.sh"
# Check that pm_create_item, pm_add_to_board, pm_set_status, pm_add_label are used
if grep -q "pm_create_item" "$SCRIPT_PATH" && \
   grep -q "pm_add_to_board" "$SCRIPT_PATH" && \
   grep -q "pm_set_status" "$SCRIPT_PATH" && \
   grep -q "pm_add_label" "$SCRIPT_PATH"; then
  echo "  PASS: issue_create_backlog_uses_pm_functions"
  PASS=$((PASS + 1))
else
  echo "  FAIL: issue_create_backlog_uses_pm_functions"
  FAIL=$((FAIL + 1))
fi

echo ""

# =====================================================
# Test Group 9: All wrappers have shebang and set -euo pipefail
# =====================================================
echo "Test Group: All wrappers have shebang and set -euo pipefail"

ALL_SCRIPTS=(
  "item-set-status.sh"
  "batch-set-status.sh"
  "item-start.sh"
  "item-review.sh"
  "item-close.sh"
  "item-create.sh"
  "reconcile-board.sh"
  "setup-labels.sh"
)

for script in "${ALL_SCRIPTS[@]}"; do
  SCRIPT_PATH="$REPO_ROOT/scripts/$script"
  FIRST_LINE=$(head -1 "$SCRIPT_PATH")
  if [ "$FIRST_LINE" = "#!/usr/bin/env bash" ]; then
    echo "  PASS: ${script}_has_correct_shebang"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${script}_has_correct_shebang (got: $FIRST_LINE)"
    FAIL=$((FAIL + 1))
  fi

  if grep -q "set -euo pipefail" "$SCRIPT_PATH"; then
    echo "  PASS: ${script}_has_set_euo_pipefail"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${script}_has_set_euo_pipefail"
    FAIL=$((FAIL + 1))
  fi
done

echo ""

# =====================================================
# Test Group 10: All wrappers source pm.sh
# =====================================================
echo "Test Group: All wrappers source pm.sh"

for script in "${ALL_SCRIPTS[@]}"; do
  SCRIPT_PATH="$REPO_ROOT/scripts/$script"
  if grep -q 'pm\.sh' "$SCRIPT_PATH"; then
    echo "  PASS: ${script}_sources_pm_sh"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${script}_sources_pm_sh"
    FAIL=$((FAIL + 1))
  fi
done

echo ""

# =====================================================
# Test Group 11: item-create.sh preserves arg parsing
# =====================================================
echo "Test Group: item-create.sh preserves argument parsing"

# Test missing required args
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"$MOCK_DIR/adapter\"
  export _MOCK_CALL_LOG=\"$CALL_LOG\"
  \"$REPO_ROOT/scripts/item-create.sh\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_nonzero "issue_create_backlog_errors_on_no_args" "$EXIT_CODE"
assert_contains "issue_create_backlog_requires_title_and_slug" "title" "$OUTPUT"

echo ""

# =====================================================
# Test Group 12: Wrapper line counts are small
# =====================================================
echo "Test Group: Wrapper scripts are thin (reduced line counts)"

check_line_count() {
  local script="$1" max="$2"
  local script_path="$REPO_ROOT/scripts/$script"
  local line_count
  line_count=$(wc -l < "$script_path" | tr -d ' ')
  if [ "$line_count" -le "$max" ]; then
    echo "  PASS: ${script}_is_thin (${line_count} lines, max ${max})"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${script}_is_thin (${line_count} lines, max ${max})"
    FAIL=$((FAIL + 1))
  fi
}

# Thresholds: original lines -> wrapper lines (approx targets from AC)
# item-set-status.sh:    158 -> ~10 (generous: 25 with comments)
# batch-set-status.sh:    158 -> ~10 (generous: 25 with comments)
# item-start.sh:          50 -> ~10 (generous: 25 with comments)
# item-review.sh:         37 -> ~10 (generous: 25 with comments)
# item-close.sh:          26 -> ~10 (generous: 25 with comments)
# reconcile-board.sh:     163 -> ~10 (generous: 25 with comments)
# setup-labels.sh:         45 -> ~25 (generous: 65 with loop + labels)
# item-create.sh: merged issue-create.sh + issue-create-backlog.sh (generous: 175)
check_line_count "item-set-status.sh" 25
check_line_count "batch-set-status.sh" 25
check_line_count "item-start.sh" 25
check_line_count "item-review.sh" 25
check_line_count "item-close.sh" 25
check_line_count "reconcile-board.sh" 25
check_line_count "setup-labels.sh" 65
check_line_count "item-create.sh" 175

echo ""

# --- Cleanup ---
rm -rf "$MOCK_DIR" 2>/dev/null || true

# --- Summary ---
echo "========================================"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
