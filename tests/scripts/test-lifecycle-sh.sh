#!/usr/bin/env bash
# test-lifecycle-sh.sh — Validates lifecycle.sh adapter module behavior.
# Runs locally using mock adapters and stubs (no live GitHub API calls).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIFECYCLE_SH="$REPO_ROOT/scripts/lib/adapters/pm/github/lifecycle.sh"

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

echo "========================================"
echo "Testing scripts/lib/adapters/pm/github/lifecycle.sh"
echo "========================================"
echo ""

# --- Shared stubs ---
MOCK_DIR=$(mktemp -d)

# Stubs for pm_add_comment and pm_set_status that log calls
COMMENT_LOG=$(mktemp)
STATUS_LOG=$(mktemp)

# We inject mock pm_add_comment and pm_set_status into the shell environment
# alongside the module under test.
MOCK_FUNS=$(cat <<MOCKS
pm_add_comment() { printf 'ITEM=%s\nBODY=%s\n---END---\n' "\$1" "\$2" >> "$COMMENT_LOG"; }
pm_set_status() { echo "\$1|\$2" >> "$STATUS_LOG"; }
MOCKS
)

# --- Test Group 1: File properties ---
echo "Test Group: File properties"

if [ -f "$LIFECYCLE_SH" ]; then
  echo "  PASS: lifecycle.sh exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: lifecycle.sh not found at $LIFECYCLE_SH"
  FAIL=$((FAIL + 1))
fi

if [ -x "$LIFECYCLE_SH" ]; then
  echo "  PASS: lifecycle.sh is executable"
  PASS=$((PASS + 1))
else
  echo "  FAIL: lifecycle.sh is not executable"
  FAIL=$((FAIL + 1))
fi

if [ -f "$LIFECYCLE_SH" ]; then
  LINE_COUNT=$(wc -l < "$LIFECYCLE_SH")
  if [ "$LINE_COUNT" -lt 80 ]; then
    echo "  PASS: lifecycle.sh is under 80 lines ($LINE_COUNT lines)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: lifecycle.sh exceeds 80 lines ($LINE_COUNT lines)"
    FAIL=$((FAIL + 1))
  fi
fi

echo ""

# --- Test Group 2: Function definitions ---
echo "Test Group: Function definitions"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  $MOCK_FUNS
  source \"$LIFECYCLE_SH\"
  declare -f pm_start_work > /dev/null && echo 'start_defined'
  declare -f pm_complete_work > /dev/null && echo 'complete_defined'
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "sourcing_succeeds" "$EXIT_CODE"
assert_contains "pm_start_work_is_defined" "start_defined" "$OUTPUT"
assert_contains "pm_complete_work_is_defined" "complete_defined" "$OUTPUT"

echo ""

# --- Test Group 3: pm_start_work posts Work Started comment ---
echo "Test Group: pm_start_work posts Work Started comment"

> "$COMMENT_LOG"
> "$STATUS_LOG"
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  $MOCK_FUNS
  source \"$LIFECYCLE_SH\"
  pm_start_work 42 --model sonnet --agent builder
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
COMMENT_CALLS=$(cat "$COMMENT_LOG")
rm -f "$TMPOUT"

assert_exit_zero "pm_start_work_exits_zero" "$EXIT_CODE"
assert_contains "pm_start_work_targets_correct_issue" "ITEM=42" "$COMMENT_CALLS"
assert_contains "pm_start_work_includes_rocket_heading" "### 🚀 Work Started" "$COMMENT_CALLS"
assert_contains "pm_start_work_includes_agent_value" "builder" "$COMMENT_CALLS"
assert_contains "pm_start_work_includes_model_value" "sonnet" "$COMMENT_CALLS"
assert_contains "pm_start_work_includes_started_field" "Started" "$COMMENT_CALLS"

echo ""

# --- Test Group 4: pm_start_work sets board to in-progress ---
echo "Test Group: pm_start_work sets board to in-progress"

> "$COMMENT_LOG"
> "$STATUS_LOG"
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  $MOCK_FUNS
  source \"$LIFECYCLE_SH\"
  pm_start_work 42 --model sonnet --agent builder
" > "$TMPOUT" 2>&1
STATUS_CALLS=$(cat "$STATUS_LOG")
rm -f "$TMPOUT"

assert_contains "pm_start_work_sets_in_progress" "42|in-progress" "$STATUS_CALLS"

echo ""

# --- Test Group 5: pm_start_work defaults model and agent to unknown ---
echo "Test Group: pm_start_work defaults --model and --agent to unknown"

> "$COMMENT_LOG"
> "$STATUS_LOG"
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  $MOCK_FUNS
  source \"$LIFECYCLE_SH\"
  pm_start_work 99
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
COMMENT_CALLS=$(cat "$COMMENT_LOG")
rm -f "$TMPOUT"

assert_exit_zero "pm_start_work_no_flags_exits_zero" "$EXIT_CODE"
# Should have two "unknown" values in the table rows
UNKNOWN_COUNT=$(echo "$COMMENT_CALLS" | grep -o "unknown" | wc -l | tr -d ' ')
if [ "$UNKNOWN_COUNT" -ge 2 ]; then
  echo "  PASS: pm_start_work_defaults_model_and_agent_to_unknown (found $UNKNOWN_COUNT)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_start_work_defaults_model_and_agent_to_unknown (expected >=2, got $UNKNOWN_COUNT)"
  echo "    Comment body: $COMMENT_CALLS"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test Group 6: pm_complete_work posts Ready for Review comment ---
echo "Test Group: pm_complete_work posts Ready for Review comment"

> "$COMMENT_LOG"
> "$STATUS_LOG"
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  $MOCK_FUNS
  source \"$LIFECYCLE_SH\"
  pm_complete_work 55 abc123
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
COMMENT_CALLS=$(cat "$COMMENT_LOG")
rm -f "$TMPOUT"

assert_exit_zero "pm_complete_work_exits_zero" "$EXIT_CODE"
assert_contains "pm_complete_work_targets_correct_issue" "ITEM=55" "$COMMENT_CALLS"
assert_contains "pm_complete_work_includes_eyes_heading" "### 👀 Ready for Review" "$COMMENT_CALLS"
assert_contains "pm_complete_work_includes_commit_value" "abc123" "$COMMENT_CALLS"
assert_contains "pm_complete_work_includes_completed_field" "Completed" "$COMMENT_CALLS"

echo ""

# --- Test Group 7: pm_complete_work sets board to in-review ---
echo "Test Group: pm_complete_work sets board to in-review"

> "$COMMENT_LOG"
> "$STATUS_LOG"
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  $MOCK_FUNS
  source \"$LIFECYCLE_SH\"
  pm_complete_work 55 abc123
" > "$TMPOUT" 2>&1
STATUS_CALLS=$(cat "$STATUS_LOG")
rm -f "$TMPOUT"

assert_contains "pm_complete_work_sets_in_review" "55|in-review" "$STATUS_CALLS"

echo ""

# --- Test Group 8: Comment format matches item-start.sh exactly ---
echo "Test Group: Comment format byte-identical to item-start.sh"

> "$COMMENT_LOG"
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  $MOCK_FUNS
  source \"$LIFECYCLE_SH\"
  pm_start_work 1 --model mymodel --agent myagent
" > "$TMPOUT" 2>&1
# Extract body: log format is "ITEM=N\nBODY=<body>\n---END---"
# Read everything after "BODY=" up to "---END---"
BODY=$(awk '/^BODY=/{found=1; sub(/^BODY=/,""); print; next} found && !/^---END---/{print} /^---END---/{found=0}' "$COMMENT_LOG")
rm -f "$TMPOUT"

# Table must have Field/Value header row
assert_contains "start_table_has_header_row" "| Field | Value |" "$BODY"
assert_contains "start_table_has_separator_row" "|-------|-------|" "$BODY"
assert_contains "start_table_has_agent_row" "| **Agent** | myagent |" "$BODY"
assert_contains "start_table_has_model_row" "| **Model** | mymodel |" "$BODY"
# Timestamp must match ISO 8601 UTC Z-suffix format
case "$BODY" in
  *"| **Started** | 20"*"Z |"*)
    echo "  PASS: start_timestamp_is_iso8601_utc"
    PASS=$((PASS + 1))
    ;;
  *)
    echo "  FAIL: start_timestamp_is_iso8601_utc"
    echo "    Body: $BODY"
    FAIL=$((FAIL + 1))
    ;;
esac

echo ""

# --- Test Group 9: Comment format matches item-review.sh exactly ---
echo "Test Group: Comment format byte-identical to item-review.sh"

> "$COMMENT_LOG"
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  $MOCK_FUNS
  source \"$LIFECYCLE_SH\"
  pm_complete_work 1 deadbeef
" > "$TMPOUT" 2>&1
BODY=$(awk '/^BODY=/{found=1; sub(/^BODY=/,""); print; next} found && !/^---END---/{print} /^---END---/{found=0}' "$COMMENT_LOG")
rm -f "$TMPOUT"

assert_contains "review_table_has_header_row" "| Field | Value |" "$BODY"
assert_contains "review_table_has_separator_row" "|-------|-------|" "$BODY"
assert_contains "review_table_has_commit_row" "| **Commit** | deadbeef |" "$BODY"
case "$BODY" in
  *"| **Completed** | 20"*"Z |"*)
    echo "  PASS: review_timestamp_is_iso8601_utc"
    PASS=$((PASS + 1))
    ;;
  *)
    echo "  FAIL: review_timestamp_is_iso8601_utc"
    echo "    Body: $BODY"
    FAIL=$((FAIL + 1))
    ;;
esac

echo ""

# --- Test Group 10: Idempotent sourcing ---
echo "Test Group: Idempotent sourcing (source twice, no errors)"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  $MOCK_FUNS
  source \"$LIFECYCLE_SH\"
  source \"$LIFECYCLE_SH\"
  declare -f pm_start_work > /dev/null && echo 'still_defined'
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "idempotent_sourcing_exits_zero" "$EXIT_CODE"
assert_eq "functions_still_defined_after_double_source" "still_defined" "$OUTPUT"

echo ""

# --- Cleanup ---
rm -f "$COMMENT_LOG" "$STATUS_LOG"
rm -rf "$MOCK_DIR" 2>/dev/null || true

# --- Summary ---
echo "========================================"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
