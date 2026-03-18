#!/usr/bin/env bash
# test-local-lifecycle-sh.sh — Tests for scripts/lib/adapters/pm/local/lifecycle.sh
#
# Tests follow the Arrange/Act/Assert pattern. All operations run against
# temporary directories — no GitHub API calls, no mocking needed.
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

LINE_COUNT=$(wc -l < "$LIFECYCLE_SH" 2>/dev/null || echo 9999)
if [ "$LINE_COUNT" -le 200 ]; then
  echo "  PASS: lifecycle.sh is under 200 lines ($LINE_COUNT)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: lifecycle.sh exceeds 200 lines ($LINE_COUNT)"
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

# --- Test Group 1: pm_start_work creates comment with "Work Started" heading ---
echo "Test Group: pm_start_work creates Work Started comment"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'My Story'" > /dev/null
run_snippet "$TMPDIR" "pm_start_work 1 --model sonnet --agent builder" > /dev/null

COMMENT_DIR="$TMPDIR/.workflow/comments/1"
if [ -d "$COMMENT_DIR" ]; then
  echo "  PASS: pm_start_work_creates_comment_dir"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_start_work_creates_comment_dir (not found: $COMMENT_DIR)"
  FAIL=$((FAIL + 1))
fi

COMMENT_FILE=$(ls "$COMMENT_DIR/" 2>/dev/null | head -1)
assert_eq "pm_start_work_comment_filename" "001-work-started.md" "$COMMENT_FILE"

if [ -f "$COMMENT_DIR/$COMMENT_FILE" ]; then
  CONTENT=$(cat "$COMMENT_DIR/$COMMENT_FILE")
  assert_contains "pm_start_work_comment_has_heading" "### " "$CONTENT"
  assert_contains "pm_start_work_comment_has_work_started_text" "Work Started" "$CONTENT"
  assert_contains "pm_start_work_comment_has_rocket_emoji" "### 🚀 Work Started" "$CONTENT"
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

COMMENT_FILE=$(ls "$TMPDIR/.workflow/comments/1/" | head -1)
CONTENT=$(cat "$TMPDIR/.workflow/comments/1/$COMMENT_FILE")

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

COMMENT_FILE=$(ls "$TMPDIR/.workflow/comments/1/" | head -1)
CONTENT=$(cat "$TMPDIR/.workflow/comments/1/$COMMENT_FILE")

assert_contains "pm_start_work_default_agent_unknown" "unknown" "$CONTENT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 5: pm_start_work comment table format matches GitHub adapter ---
echo "Test Group: pm_start_work comment table format matches GitHub adapter"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Format Story'" > /dev/null
run_snippet "$TMPDIR" "pm_start_work 1 --model haiku --agent designer" > /dev/null

COMMENT_FILE=$(ls "$TMPDIR/.workflow/comments/1/" | head -1)
CONTENT=$(cat "$TMPDIR/.workflow/comments/1/$COMMENT_FILE")

# Must have Markdown table with correct headers
assert_contains "pm_start_work_table_header_field" "| Field | Value |" "$CONTENT"
assert_contains "pm_start_work_table_separator" "|-------|-------|" "$CONTENT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 6: pm_start_work comment has ISO timestamp ---
echo "Test Group: pm_start_work comment has ISO timestamp"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Timestamp Story'" > /dev/null
run_snippet "$TMPDIR" "pm_start_work 1 --model sonnet --agent builder" > /dev/null

COMMENT_FILE=$(ls "$TMPDIR/.workflow/comments/1/" | head -1)
CONTENT=$(cat "$TMPDIR/.workflow/comments/1/$COMMENT_FILE")

if echo "$CONTENT" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'; then
  echo "  PASS: pm_start_work_comment_has_iso_timestamp"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_start_work_comment_has_iso_timestamp (content: $CONTENT)"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 7: pm_complete_work creates comment with "Ready for Review" heading ---
echo "Test Group: pm_complete_work creates Ready for Review comment"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Review Story'" > /dev/null
run_snippet "$TMPDIR" "pm_complete_work 1 abc123def456" > /dev/null

COMMENT_DIR="$TMPDIR/.workflow/comments/1"
if [ -d "$COMMENT_DIR" ]; then
  echo "  PASS: pm_complete_work_creates_comment_dir"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_complete_work_creates_comment_dir (not found: $COMMENT_DIR)"
  FAIL=$((FAIL + 1))
fi

COMMENT_FILE=$(ls "$COMMENT_DIR/" 2>/dev/null | head -1)
assert_eq "pm_complete_work_comment_filename" "001-ready-for-review.md" "$COMMENT_FILE"

if [ -f "$COMMENT_DIR/$COMMENT_FILE" ]; then
  CONTENT=$(cat "$COMMENT_DIR/$COMMENT_FILE")
  assert_contains "pm_complete_work_comment_has_heading" "### " "$CONTENT"
  assert_contains "pm_complete_work_comment_has_ready_for_review_text" "Ready for Review" "$CONTENT"
  assert_contains "pm_complete_work_comment_has_eyes_emoji" "### 👀 Ready for Review" "$CONTENT"
fi

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

COMMENT_FILE=$(ls "$TMPDIR/.workflow/comments/1/" | head -1)
CONTENT=$(cat "$TMPDIR/.workflow/comments/1/$COMMENT_FILE")

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

COMMENT_FILE=$(ls "$TMPDIR/.workflow/comments/1/" | head -1)
CONTENT=$(cat "$TMPDIR/.workflow/comments/1/$COMMENT_FILE")

assert_contains "pm_complete_work_table_header_field" "| Field | Value |" "$CONTENT"
assert_contains "pm_complete_work_table_separator" "|-------|-------|" "$CONTENT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 11: pm_complete_work comment has ISO timestamp ---
echo "Test Group: pm_complete_work comment has ISO timestamp"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Timestamp Review Story'" > /dev/null
run_snippet "$TMPDIR" "pm_complete_work 1 1234abcd" > /dev/null

COMMENT_FILE=$(ls "$TMPDIR/.workflow/comments/1/" | head -1)
CONTENT=$(cat "$TMPDIR/.workflow/comments/1/$COMMENT_FILE")

if echo "$CONTENT" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'; then
  echo "  PASS: pm_complete_work_comment_has_iso_timestamp"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_complete_work_comment_has_iso_timestamp (content: $CONTENT)"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 12: sequential calls create multiple comments ---
echo "Test Group: sequential start then complete creates two comment files"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Lifecycle Story'" > /dev/null
run_snippet "$TMPDIR" "pm_start_work 1 --model sonnet --agent builder" > /dev/null
run_snippet "$TMPDIR" "pm_complete_work 1 abc123" > /dev/null

COUNT=$(ls "$TMPDIR/.workflow/comments/1/" | wc -l | tr -d ' ')
assert_eq "pm_lifecycle_two_comments_created" "2" "$COUNT"

FILES=$(ls "$TMPDIR/.workflow/comments/1/" | sort)
assert_contains "pm_lifecycle_first_comment_work_started" "001-work-started.md" "$FILES"
assert_contains "pm_lifecycle_second_comment_ready_for_review" "002-ready-for-review.md" "$FILES"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 13: warning printed if pm_set_status fails (non-fatal) ---
echo "Test Group: warning printed if board status update fails (non-fatal)"

TMPDIR=$(mktemp -d)
# Do NOT create an item — pm_set_status will fail, but the function should
# still exit 0 (non-fatal) and print a warning to stderr.
run_snippet "$TMPDIR" "_local_ensure_dirs"

OUT=$(run_snippet "$TMPDIR" "pm_start_work 999 --model sonnet --agent builder" 2>&1)
# pm_add_comment will also fail since item 999 doesn't exist but workflow dir exists.
# The key: the function itself should not hard-exit (set -e may propagate).
# We verify that the output contains a warning about board status.
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
# Verify that pm_start_work doesn't write files directly — only via pm_add_comment.
# Intercept pm_add_comment and pm_set_status to verify they're called.
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

  # Override after sourcing to track calls
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
