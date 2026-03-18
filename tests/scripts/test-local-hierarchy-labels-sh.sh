#!/usr/bin/env bash
# test-local-hierarchy-labels-sh.sh — Tests for:
#   scripts/lib/adapters/pm/local/hierarchy.sh
#   scripts/lib/adapters/pm/local/labels.sh
#
# Tests follow the Arrange/Act/Assert pattern. All operations run against
# temporary directories; no external services are required.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMMON_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/_common.sh"
ITEMS_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/items.sh"
HIERARCHY_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/hierarchy.sh"
LABELS_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/labels.sh"

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

assert_not_contains() {
  local test_name="$1" needle="$2" haystack="$3"
  if ! echo "$haystack" | grep -qF "$needle"; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    Expected NOT to contain: $needle"
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
echo "Testing local/hierarchy.sh + local/labels.sh"
echo "========================================"
echo ""

# --- Test Group 0: File existence and line count ---
echo "Test Group: File existence and line count"

for sh_file in "$HIERARCHY_SH" "$LABELS_SH"; do
  base=$(basename "$sh_file")
  if [ -f "$sh_file" ]; then
    echo "  PASS: $base exists"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $base not found at $sh_file"
    FAIL=$((FAIL + 1))
  fi

  LINE_COUNT=$(wc -l < "$sh_file" 2>/dev/null || echo 9999)
  if [ "$LINE_COUNT" -le 200 ]; then
    echo "  PASS: $base is under 200 lines ($LINE_COUNT)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $base exceeds 200 lines ($LINE_COUNT)"
    FAIL=$((FAIL + 1))
  fi
done
echo ""

# --- Helper: run a snippet inside an isolated workflow dir ---
# Sources _common.sh, items.sh, hierarchy.sh, and labels.sh in sequence.
run_snippet() {
  local tmpdir="$1"
  local snippet="$2"
  bash --norc --noprofile -c "
    _LOCAL_COMMON_LOADED=''
    _LOCAL_HIERARCHY_LOADED=''
    _LOCAL_LABELS_LOADED=''
    _LOCAL_WORKFLOW_DIR='$tmpdir/.workflow'
    source '$COMMON_SH'
    source '$ITEMS_SH'
    source '$HIERARCHY_SH'
    source '$LABELS_SH'
    $snippet
  "
}

# --- Test Group 1: pm_link_child sets parent field in child item ---
echo "Test Group: pm_link_child sets parent field"

TMPDIR=$(mktemp -d)
# Create parent item (id=1) and child item (id=2)
run_snippet "$TMPDIR" "pm_create_item backlog 'Parent Item'" > /dev/null
run_snippet "$TMPDIR" "pm_create_item story 'Child Item'" > /dev/null

run_snippet "$TMPDIR" "pm_link_child 1 2" > /dev/null
EXIT_CODE=$?

assert_exit_zero "pm_link_child_exits_zero" "$EXIT_CODE"

PARENT_VAL=$(grep '^parent:' "$TMPDIR/.workflow/items/2.md" | sed 's/parent: //')
assert_eq "pm_link_child_sets_parent_field" "1" "$PARENT_VAL"

# Parent item's own frontmatter should not be modified
PARENT_SELF=$(grep '^parent:' "$TMPDIR/.workflow/items/1.md" | sed 's/parent: //')
assert_eq "pm_link_child_does_not_touch_parent_item" "null" "$PARENT_SELF"

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
# Item 99 does not exist

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
# Item 99 does not exist as parent

OUT=$(run_snippet "$TMPDIR" "pm_link_child 99 1" 2>&1)
EXIT_CODE=$?

assert_exit_nonzero "pm_link_child_missing_parent_fails" "$EXIT_CODE"
assert_contains "pm_link_child_missing_parent_message" "99" "$OUT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 5: pm_link_child idempotency guard ---
echo "Test Group: hierarchy.sh idempotency guard prevents double-sourcing"

TMPDIR=$(mktemp -d)
# Source hierarchy.sh twice — second source must be a no-op
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
echo ""

# --- Test Group 6: pm_add_label appends label to existing labels array ---
echo "Test Group: pm_add_label appends new label"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Labeled Story'" > /dev/null

run_snippet "$TMPDIR" "pm_add_label 1 type/feature" > /dev/null
EXIT_CODE=$?

assert_exit_zero "pm_add_label_exits_zero" "$EXIT_CODE"

# hierarchy/story was added at creation; type/feature should now also be present
if grep -q "type/feature" "$TMPDIR/.workflow/items/1.md"; then
  echo "  PASS: pm_add_label_label_present"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_add_label_label_present"
  FAIL=$((FAIL + 1))
fi

# hierarchy/story must still be present (not replaced)
if grep -q "hierarchy/story" "$TMPDIR/.workflow/items/1.md"; then
  echo "  PASS: pm_add_label_original_label_preserved"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_add_label_original_label_preserved"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 7: pm_add_label is idempotent (duplicate is a no-op) ---
echo "Test Group: pm_add_label is idempotent"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Idem Story'" > /dev/null
run_snippet "$TMPDIR" "pm_add_label 1 type/feature" > /dev/null
run_snippet "$TMPDIR" "pm_add_label 1 type/feature" > /dev/null

# Count occurrences of "type/feature" in the labels block — must be exactly 1
COUNT=$(grep -c "type/feature" "$TMPDIR/.workflow/items/1.md" || true)
assert_eq "pm_add_label_idempotent_no_duplicate" "1" "$COUNT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 8: pm_add_label works with item that has only hierarchy label ---
echo "Test Group: pm_add_label on item with one existing label"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item epic 'Sparse Epic'" > /dev/null

run_snippet "$TMPDIR" "pm_add_label 1 difficulty/hard" > /dev/null
EXIT_CODE=$?

assert_exit_zero "pm_add_label_sparse_exits_zero" "$EXIT_CODE"

if grep -q "difficulty/hard" "$TMPDIR/.workflow/items/1.md"; then
  echo "  PASS: pm_add_label_sparse_label_present"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_add_label_sparse_label_present"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 9: pm_add_label ignores --create-if-missing flag ---
echo "Test Group: pm_add_label ignores --create-if-missing flag"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Flag Story'" > /dev/null

OUT=$(run_snippet "$TMPDIR" "pm_add_label 1 backlog/111-local-first-pm --create-if-missing" 2>&1)
EXIT_CODE=$?

assert_exit_zero "pm_add_label_create_if_missing_exits_zero" "$EXIT_CODE"

if grep -q "backlog/111-local-first-pm" "$TMPDIR/.workflow/items/1.md"; then
  echo "  PASS: pm_add_label_create_if_missing_label_added"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_add_label_create_if_missing_label_added"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 10: pm_add_label ignores --color flag ---
echo "Test Group: pm_add_label ignores --color flag"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Color Story'" > /dev/null

OUT=$(run_snippet "$TMPDIR" "pm_add_label 1 type/bug --color ff0000" 2>&1)
EXIT_CODE=$?

assert_exit_zero "pm_add_label_color_flag_exits_zero" "$EXIT_CODE"

if grep -q "type/bug" "$TMPDIR/.workflow/items/1.md"; then
  echo "  PASS: pm_add_label_color_flag_label_added"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_add_label_color_flag_label_added"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 11: pm_add_label ignores --description flag ---
echo "Test Group: pm_add_label ignores --description flag"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Desc Story'" > /dev/null

OUT=$(run_snippet "$TMPDIR" "pm_add_label 1 type/docs --description 'Documentation label'" 2>&1)
EXIT_CODE=$?

assert_exit_zero "pm_add_label_description_flag_exits_zero" "$EXIT_CODE"

if grep -q "type/docs" "$TMPDIR/.workflow/items/1.md"; then
  echo "  PASS: pm_add_label_description_flag_label_added"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_add_label_description_flag_label_added"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 12: pm_add_label accepts all flags together ---
echo "Test Group: pm_add_label accepts all optional flags together"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'All Flags Story'" > /dev/null

OUT=$(run_snippet "$TMPDIR" \
  "pm_add_label 1 test/label --create-if-missing --color 5319E7 --description 'test label'" 2>&1)
EXIT_CODE=$?

assert_exit_zero "pm_add_label_all_flags_exits_zero" "$EXIT_CODE"

if grep -q "test/label" "$TMPDIR/.workflow/items/1.md"; then
  echo "  PASS: pm_add_label_all_flags_label_added"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_add_label_all_flags_label_added"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 13: labels.sh idempotency guard ---
echo "Test Group: labels.sh idempotency guard prevents double-sourcing"

TMPDIR=$(mktemp -d)
OUT=$(bash --norc --noprofile -c "
  _LOCAL_COMMON_LOADED=''
  _LOCAL_LABELS_LOADED=''
  _LOCAL_WORKFLOW_DIR='$TMPDIR/.workflow'
  source '$COMMON_SH'
  source '$ITEMS_SH'
  source '$LABELS_SH'
  source '$LABELS_SH'
  echo 'double-source-ok'
" 2>&1)
EXIT_CODE=$?

assert_exit_zero "labels_idempotency_guard_exits_zero" "$EXIT_CODE"
assert_contains "labels_idempotency_guard_output" "double-source-ok" "$OUT"

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
