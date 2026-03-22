#!/usr/bin/env bash
# test-local-lifecycle-sh.sh — Tests for scripts/lib/adapters/pm/local/lifecycle.sh
#
# Tests follow the Arrange/Act/Assert pattern. All operations run against
# temporary directories — no GitHub API calls, no mocking needed.
#
# Comments are now inlined into item files (Activity Log section), not
# stored as separate files in .workflow/comments/.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIFECYCLE_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/lifecycle.sh"
COMMON_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/_common.sh"
ITEMS_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/items.sh"
BOARD_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/board.sh"
COMMENTS_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/comments.sh"

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
    echo "    Got: $(echo "$haystack" | head -10)"
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

echo "========================================"
echo "Testing scripts/lib/adapters/pm/local/lifecycle.sh"
echo "========================================"
echo ""

# --- Test Group 0: File existence and size ---
echo "Test Group: File existence"

if [ -f "$LIFECYCLE_SH" ]; then
  echo "  PASS: lifecycle.sh exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: lifecycle.sh not found at $LIFECYCLE_SH"
  FAIL=$((FAIL + 1))
fi

source "$SCRIPT_DIR/lib/thresholds.sh"
LINE_COUNT=$(wc -l < "$LIFECYCLE_SH" 2>/dev/null || echo 9999)
if [ "$LINE_COUNT" -le "$THRESHOLD_ADAPTER_MODULE" ]; then
  echo "  PASS: lifecycle.sh is under $THRESHOLD_ADAPTER_MODULE lines ($LINE_COUNT)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: lifecycle.sh exceeds $THRESHOLD_ADAPTER_MODULE lines ($LINE_COUNT)"
  FAIL=$((FAIL + 1))
fi
echo ""

# --- Helper: run a snippet inside an isolated workflow dir ---
# Sources all required modules into a fresh shell.
run_snippet() {
  local tmpdir="$1"
  local snippet="$2"
  bash --norc --noprofile -c "
    _LOCAL_COMMON_LOADED=''
    _LOCAL_ITEMS_LOADED=''
    _LOCAL_BOARD_LOADED=''
    _LOCAL_COMMENTS_LOADED=''
    _LOCAL_LIFECYCLE_LOADED=''
    _LOCAL_WORKFLOW_DIR='$tmpdir/.workflow'
    source '$COMMON_SH'
    source '$ITEMS_SH'
    source '$BOARD_SH'
    source '$COMMENTS_SH'
    source '$LIFECYCLE_SH'
    $snippet
  "
}

# read_fm_field <file> <field> — extract a frontmatter scalar value.
read_fm_field() {
  local file="$1" field="$2"
  grep "^${field}:" "$file" | head -1 | sed "s/^${field}: *//"
}

# --- Test Group 1: pm_start_work appends Work Started comment to item file ---
echo "Test Group: pm_start_work appends Work Started comment to item file"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'My Story'" > /dev/null
run_snippet "$TMPDIR" "pm_start_work 1 --model sonnet --agent builder" > /dev/null

ITEM_FILE="$TMPDIR/.workflow/items/1.md"
if [ -f "$ITEM_FILE" ]; then
  CONTENT=$(cat "$ITEM_FILE")
  assert_contains "pm_start_work_has_activity_log" "## Activity Log" "$CONTENT"
  assert_contains "pm_start_work_comment_has_work_started_text" "Work Started" "$CONTENT"
  assert_contains "pm_start_work_comment_has_rocket_emoji" "Work Started" "$CONTENT"
else
  echo "  FAIL: pm_start_work item file not found"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 2: pm_start_work sets status to in-progress ---
echo "Test Group: pm_start_work sets status to in-progress"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Status Story'" > /dev/null
ITEM_FILE="$TMPDIR/.workflow/items/1.md"

BEFORE=$(read_fm_field "$ITEM_FILE" status)
assert_eq "pm_start_work_initial_status_is_backlog" "backlog" "$BEFORE"

EXIT_CODE=0
run_snippet "$TMPDIR" "pm_start_work 1 --model sonnet --agent builder" > /dev/null || EXIT_CODE=$?
assert_exit_zero "pm_start_work_exits_zero" "$EXIT_CODE"

AFTER=$(read_fm_field "$ITEM_FILE" status)
assert_eq "pm_start_work_sets_status_in_progress" "in-progress" "$AFTER"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 3: pm_start_work comment contains model and agent fields ---
echo "Test Group: pm_start_work comment contains model and agent fields"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Fields Story'" > /dev/null
run_snippet "$TMPDIR" "pm_start_work 1 --model opus --agent reviewer" > /dev/null

CONTENT=$(cat "$TMPDIR/.workflow/items/1.md")
assert_contains "pm_start_work_comment_has_agent_field" "**Agent**" "$CONTENT"
assert_contains "pm_start_work_comment_has_model_field" "**Model**" "$CONTENT"
assert_contains "pm_start_work_comment_has_started_field" "**Started**" "$CONTENT"
assert_contains "pm_start_work_comment_agent_value" "reviewer" "$CONTENT"
assert_contains "pm_start_work_comment_model_value" "opus" "$CONTENT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 4: pm_start_work defaults model and agent to "unknown" ---
echo "Test Group: pm_start_work defaults model and agent to unknown"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Default Story'" > /dev/null
run_snippet "$TMPDIR" "pm_start_work 1" > /dev/null

CONTENT=$(cat "$TMPDIR/.workflow/items/1.md")
assert_contains "pm_start_work_default_agent_unknown" "unknown" "$CONTENT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 5: pm_start_work comment table format matches GitHub adapter ---
echo "Test Group: pm_start_work comment table format matches GitHub adapter"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Format Story'" > /dev/null
run_snippet "$TMPDIR" "pm_start_work 1 --model haiku --agent designer" > /dev/null

CONTENT=$(cat "$TMPDIR/.workflow/items/1.md")
assert_contains "pm_start_work_table_header_field" "| Field | Value |" "$CONTENT"
assert_contains "pm_start_work_table_separator" "|-------|-------|" "$CONTENT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 6: pm_start_work comment has ISO timestamp ---
echo "Test Group: pm_start_work comment has ISO timestamp"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Timestamp Story'" > /dev/null
run_snippet "$TMPDIR" "pm_start_work 1 --model sonnet --agent builder" > /dev/null

CONTENT=$(cat "$TMPDIR/.workflow/items/1.md")
if echo "$CONTENT" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'; then
  echo "  PASS: pm_start_work_comment_has_iso_timestamp"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_start_work_comment_has_iso_timestamp"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 7: pm_complete_work appends Ready for Review comment ---
echo "Test Group: pm_complete_work appends Ready for Review comment to item file"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Review Story'" > /dev/null
run_snippet "$TMPDIR" "pm_complete_work 1 abc123def456" > /dev/null

ITEM_FILE="$TMPDIR/.workflow/items/1.md"
CONTENT=$(cat "$ITEM_FILE")
assert_contains "pm_complete_work_has_ready_for_review_text" "Ready for Review" "$CONTENT"
assert_contains "pm_complete_work_has_activity_log" "## Activity Log" "$CONTENT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 8: pm_complete_work sets status to in-review ---
echo "Test Group: pm_complete_work sets status to in-review"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'In Review Story'" > /dev/null
ITEM_FILE="$TMPDIR/.workflow/items/1.md"

EXIT_CODE=0
run_snippet "$TMPDIR" "pm_complete_work 1 deadbeef" > /dev/null || EXIT_CODE=$?
assert_exit_zero "pm_complete_work_exits_zero" "$EXIT_CODE"

AFTER=$(read_fm_field "$ITEM_FILE" status)
assert_eq "pm_complete_work_sets_status_in_review" "in-review" "$AFTER"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 9: pm_complete_work comment contains commit hash ---
echo "Test Group: pm_complete_work comment contains commit hash"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Commit Story'" > /dev/null
run_snippet "$TMPDIR" "pm_complete_work 1 cafebabe1234" > /dev/null

CONTENT=$(cat "$TMPDIR/.workflow/items/1.md")
assert_contains "pm_complete_work_comment_has_commit_field" "**Commit**" "$CONTENT"
assert_contains "pm_complete_work_comment_has_completed_field" "**Completed**" "$CONTENT"
assert_contains "pm_complete_work_comment_has_commit_hash" "cafebabe1234" "$CONTENT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 10: pm_complete_work comment table format matches GitHub adapter ---
echo "Test Group: pm_complete_work comment table format matches GitHub adapter"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Format Review Story'" > /dev/null
run_snippet "$TMPDIR" "pm_complete_work 1 0a1b2c3d" > /dev/null

CONTENT=$(cat "$TMPDIR/.workflow/items/1.md")
assert_contains "pm_complete_work_table_header_field" "| Field | Value |" "$CONTENT"
assert_contains "pm_complete_work_table_separator" "|-------|-------|" "$CONTENT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 11: pm_complete_work comment has ISO timestamp ---
echo "Test Group: pm_complete_work comment has ISO timestamp"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Timestamp Review Story'" > /dev/null
run_snippet "$TMPDIR" "pm_complete_work 1 1234abcd" > /dev/null

CONTENT=$(cat "$TMPDIR/.workflow/items/1.md")
if echo "$CONTENT" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'; then
  echo "  PASS: pm_complete_work_comment_has_iso_timestamp"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_complete_work_comment_has_iso_timestamp"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 12: sequential calls create multiple comments in item file ---
echo "Test Group: sequential start then complete creates two comments in item file"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Lifecycle Story'" > /dev/null
run_snippet "$TMPDIR" "pm_start_work 1 --model sonnet --agent builder" > /dev/null
run_snippet "$TMPDIR" "pm_complete_work 1 abc123" > /dev/null

CONTENT=$(cat "$TMPDIR/.workflow/items/1.md")

# Count <!-- comment: --> markers — should be exactly 2
COMMENT_COUNT=$(grep -c '<!-- comment:' "$TMPDIR/.workflow/items/1.md" || true)
assert_eq "pm_lifecycle_two_comments_inline" "2" "$COMMENT_COUNT"

assert_contains "pm_lifecycle_work_started_inline" "Work Started" "$CONTENT"
assert_contains "pm_lifecycle_ready_for_review_inline" "Ready for Review" "$CONTENT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 13: warning printed if pm_set_status fails (non-fatal) ---
echo "Test Group: warning printed if board status update fails (non-fatal)"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "_local_ensure_dirs"

OUT=$(run_snippet "$TMPDIR" "pm_start_work 999 --model sonnet --agent builder" 2>&1)
if echo "$OUT" | grep -qi "warning\|error"; then
  echo "  PASS: pm_start_work_warning_on_board_failure"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_start_work_warning_on_board_failure (expected warning/error output, got: $OUT)"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 14: idempotency guard prevents double-sourcing ---
echo "Test Group: idempotency guard prevents double-sourcing"

TMPDIR=$(mktemp -d)
RESULT=$(bash --norc --noprofile -c "
  _LOCAL_COMMON_LOADED=''
  _LOCAL_ITEMS_LOADED=''
  _LOCAL_BOARD_LOADED=''
  _LOCAL_COMMENTS_LOADED=''
  _LOCAL_LIFECYCLE_LOADED=''
  _LOCAL_WORKFLOW_DIR='$TMPDIR/.workflow'
  source '$COMMON_SH'
  source '$ITEMS_SH'
  source '$BOARD_SH'
  source '$COMMENTS_SH'
  source '$LIFECYCLE_SH'
  source '$LIFECYCLE_SH'
  echo 'sourced_ok'
" 2>&1)
EXIT_CODE=$?

assert_exit_zero "idempotency_guard_double_source_ok" "$EXIT_CODE"
assert_contains "idempotency_guard_no_error" "sourced_ok" "$RESULT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 15: pm_start_work composes on pm_add_comment and pm_set_status ---
echo "Test Group: pm_start_work composes on pm_add_comment and pm_set_status"

TMPDIR=$(mktemp -d)
RESULT=$(bash --norc --noprofile -c "
  _LOCAL_COMMON_LOADED=''
  _LOCAL_ITEMS_LOADED=''
  _LOCAL_BOARD_LOADED=''
  _LOCAL_COMMENTS_LOADED=''
  _LOCAL_LIFECYCLE_LOADED=''
  _LOCAL_WORKFLOW_DIR='$TMPDIR/.workflow'
  source '$COMMON_SH'
  source '$ITEMS_SH'
  source '$BOARD_SH'
  source '$COMMENTS_SH'
  source '$LIFECYCLE_SH'

  _PM_ADD_COMMENT_CALLED=0
  _PM_SET_STATUS_CALLED=0
  pm_add_comment() { _PM_ADD_COMMENT_CALLED=1; echo 'pm_add_comment_called'; }
  pm_set_status()   { _PM_SET_STATUS_CALLED=1; echo 'pm_set_status_called'; }

  pm_start_work 1 --model sonnet --agent builder
  echo \"add_comment_called=\$_PM_ADD_COMMENT_CALLED\"
  echo \"set_status_called=\$_PM_SET_STATUS_CALLED\"
" 2>&1)

assert_contains "pm_start_work_calls_pm_add_comment" "pm_add_comment_called" "$RESULT"
assert_contains "pm_start_work_calls_pm_set_status" "pm_set_status_called" "$RESULT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 16: pm_complete_work composes on pm_add_comment and pm_set_status ---
echo "Test Group: pm_complete_work composes on pm_add_comment and pm_set_status"

TMPDIR=$(mktemp -d)
RESULT=$(bash --norc --noprofile -c "
  _LOCAL_COMMON_LOADED=''
  _LOCAL_ITEMS_LOADED=''
  _LOCAL_BOARD_LOADED=''
  _LOCAL_COMMENTS_LOADED=''
  _LOCAL_LIFECYCLE_LOADED=''
  _LOCAL_WORKFLOW_DIR='$TMPDIR/.workflow'
  source '$COMMON_SH'
  source '$ITEMS_SH'
  source '$BOARD_SH'
  source '$COMMENTS_SH'
  source '$LIFECYCLE_SH'

  _PM_ADD_COMMENT_CALLED=0
  _PM_SET_STATUS_CALLED=0
  pm_add_comment() { _PM_ADD_COMMENT_CALLED=1; echo 'pm_add_comment_called'; }
  pm_set_status()   { _PM_SET_STATUS_CALLED=1; echo 'pm_set_status_called'; }

  pm_complete_work 1 abc123
  echo \"add_comment_called=\$_PM_ADD_COMMENT_CALLED\"
  echo \"set_status_called=\$_PM_SET_STATUS_CALLED\"
" 2>&1)

assert_contains "pm_complete_work_calls_pm_add_comment" "pm_add_comment_called" "$RESULT"
assert_contains "pm_complete_work_calls_pm_set_status" "pm_set_status_called" "$RESULT"

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
