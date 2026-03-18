#!/usr/bin/env bash
# test-local-hierarchy-sh.sh — Tests for local/hierarchy.sh
# Arrange/Act/Assert pattern; all operations use temporary directories.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMMON_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/_common.sh"
ITEMS_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/items.sh"
HIERARCHY_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/hierarchy.sh"

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

assert_contains() {
  local test_name="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
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
echo "Testing local/hierarchy.sh"
echo "========================================"
echo ""

# --- Test Group 0: File existence and line count ---
echo "Test Group: File existence and line count"

if [ -f "$HIERARCHY_SH" ]; then
  echo "  PASS: hierarchy.sh exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: hierarchy.sh not found at $HIERARCHY_SH"
  FAIL=$((FAIL + 1))
fi

LINE_COUNT=$(wc -l < "$HIERARCHY_SH" 2>/dev/null || echo 9999)
if [ "$LINE_COUNT" -le 200 ]; then
  echo "  PASS: hierarchy.sh is under 200 lines ($LINE_COUNT)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: hierarchy.sh exceeds 200 lines ($LINE_COUNT)"
  FAIL=$((FAIL + 1))
fi
echo ""

# run_snippet — execute a bash snippet in an isolated workflow dir
run_snippet() {
  local tmpdir="$1"
  local snippet="$2"
  bash --norc --noprofile -c "
    _LOCAL_COMMON_LOADED=''
    _LOCAL_HIERARCHY_LOADED=''
    _LOCAL_WORKFLOW_DIR='$tmpdir/.workflow'
    source '$COMMON_SH'
    source '$ITEMS_SH'
    source '$HIERARCHY_SH'
    $snippet
  "
}

# --- Test Group 1: pm_link_child sets parent field in child item ---
echo "Test Group: pm_link_child sets parent field"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item backlog 'Parent Item'" > /dev/null
run_snippet "$TMPDIR" "pm_create_item story 'Child Item'" > /dev/null

run_snippet "$TMPDIR" "pm_link_child 1 2" > /dev/null
EXIT_CODE=$?

assert_exit_zero "pm_link_child_exits_zero" "$EXIT_CODE"

PARENT_VAL=$(grep '^parent:' "$TMPDIR/.workflow/items/2.md" | sed 's/parent: //')
assert_eq "pm_link_child_sets_parent_field" "1" "$PARENT_VAL"

PARENT_SELF=$(grep '^parent:' "$TMPDIR/.workflow/items/1.md" | sed 's/parent: //')
assert_eq "pm_link_child_parent_item_unchanged" "null" "$PARENT_SELF"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 2: pm_link_child prints confirmation message ---
echo "Test Group: pm_link_child prints confirmation message"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item backlog 'Parent'" > /dev/null
run_snippet "$TMPDIR" "pm_create_item story 'Child'" > /dev/null

OUT=$(run_snippet "$TMPDIR" "pm_link_child 1 2")
EXIT_CODE=$?

assert_exit_zero "pm_link_child_message_exits_zero" "$EXIT_CODE"
assert_eq "pm_link_child_message_exact" "Linked #2 as sub-issue of #1" "$OUT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 3: pm_link_child error when child does not exist ---
echo "Test Group: pm_link_child error on nonexistent child item"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item backlog 'Parent Only'" > /dev/null

OUT=$(run_snippet "$TMPDIR" "pm_link_child 1 99" 2>&1)
EXIT_CODE=$?

assert_exit_nonzero "pm_link_child_missing_child_fails" "$EXIT_CODE"
assert_contains "pm_link_child_missing_child_message" "99" "$OUT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 4: pm_link_child error when parent does not exist ---
echo "Test Group: pm_link_child error on nonexistent parent item"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Child Only'" > /dev/null

OUT=$(run_snippet "$TMPDIR" "pm_link_child 99 1" 2>&1)
EXIT_CODE=$?

assert_exit_nonzero "pm_link_child_missing_parent_fails" "$EXIT_CODE"
assert_contains "pm_link_child_missing_parent_message" "99" "$OUT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 5: hierarchy.sh idempotency guard ---
echo "Test Group: hierarchy.sh idempotency guard"

TMPDIR=$(mktemp -d)
OUT=$(bash --norc --noprofile -c "
  _LOCAL_COMMON_LOADED=''
  _LOCAL_HIERARCHY_LOADED=''
  _LOCAL_WORKFLOW_DIR='$TMPDIR/.workflow'
  source '$COMMON_SH'
  source '$ITEMS_SH'
  source '$HIERARCHY_SH'
  source '$HIERARCHY_SH'
  echo 'double-source-ok'
" 2>&1)
EXIT_CODE=$?

assert_exit_zero "hierarchy_idempotency_guard_exits_zero" "$EXIT_CODE"
assert_contains "hierarchy_idempotency_guard_output" "double-source-ok" "$OUT"

rm -rf "$TMPDIR"

# --- Summary ---
echo "========================================"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
