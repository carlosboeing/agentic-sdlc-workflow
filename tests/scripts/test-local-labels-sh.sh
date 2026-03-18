#!/usr/bin/env bash
# test-local-labels-sh.sh — Tests for local/labels.sh
# Arrange/Act/Assert pattern; all operations use temporary directories.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMMON_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/_common.sh"
ITEMS_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/items.sh"
LABELS_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/labels.sh"

PASS=0
FAIL=0

assert_eq() {
  local test_name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $test_name"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"; echo "    Expected: $expected"; echo "    Actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_contains() {
  local test_name="$1" needle="$2" file="$3"
  if grep -qF "$needle" "$file"; then
    echo "  PASS: $test_name"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (pattern '$needle' not found in $file)"
    FAIL=$((FAIL + 1))
  fi
}

assert_exit_zero() {
  local test_name="$1" exit_code="$2"
  if [ "$exit_code" -eq 0 ]; then
    echo "  PASS: $test_name"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (expected exit 0, got $exit_code)"
    FAIL=$((FAIL + 1))
  fi
}

echo "========================================"
echo "Testing local/labels.sh"
echo "========================================"
echo ""

# --- Test Group 0: File existence and line count ---
echo "Test Group: File existence and line count"
if [ -f "$LABELS_SH" ]; then
  echo "  PASS: labels.sh exists"; PASS=$((PASS + 1))
else
  echo "  FAIL: labels.sh not found at $LABELS_SH"; FAIL=$((FAIL + 1))
fi
LINE_COUNT=$(wc -l < "$LABELS_SH" 2>/dev/null || echo 9999)
if [ "$LINE_COUNT" -le 200 ]; then
  echo "  PASS: labels.sh is under 200 lines ($LINE_COUNT)"; PASS=$((PASS + 1))
else
  echo "  FAIL: labels.sh exceeds 200 lines ($LINE_COUNT)"; FAIL=$((FAIL + 1))
fi
echo ""

# run_snippet — execute a bash snippet in an isolated workflow dir
run_snippet() {
  local tmpdir="$1" snippet="$2"
  bash --norc --noprofile -c "
    _LOCAL_COMMON_LOADED=''
    _LOCAL_LABELS_LOADED=''
    _LOCAL_WORKFLOW_DIR='$tmpdir/.workflow'
    source '$COMMON_SH'
    source '$ITEMS_SH'
    source '$LABELS_SH'
    $snippet
  "
}

# --- Test Group 1: pm_add_label appends label to existing labels array ---
echo "Test Group: pm_add_label appends new label"
TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Labeled Story'" > /dev/null
run_snippet "$TMPDIR" "pm_add_label 1 type/feature" > /dev/null; EXIT_CODE=$?
assert_exit_zero "pm_add_label_exits_zero" "$EXIT_CODE"
assert_file_contains "pm_add_label_label_present" "type/feature" "$TMPDIR/.workflow/items/1.md"
assert_file_contains "pm_add_label_original_preserved" "hierarchy/story" "$TMPDIR/.workflow/items/1.md"
rm -rf "$TMPDIR"; echo ""

# --- Test Group 2: pm_add_label is idempotent (duplicate is a no-op) ---
echo "Test Group: pm_add_label is idempotent"
TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Idem Story'" > /dev/null
run_snippet "$TMPDIR" "pm_add_label 1 type/feature" > /dev/null
run_snippet "$TMPDIR" "pm_add_label 1 type/feature" > /dev/null
COUNT=$(grep -c "type/feature" "$TMPDIR/.workflow/items/1.md" || true)
assert_eq "pm_add_label_idempotent_no_duplicate" "1" "$COUNT"
rm -rf "$TMPDIR"; echo ""

# --- Test Group 3: pm_add_label works with empty labels array ---
# Tests _local_fm_append_label when labels: has no "  - " entries (distinct path).
echo "Test Group: pm_add_label works with empty labels array"
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.workflow/items"
printf -- '---\nid: 1\ntitle: "Empty Labels Item"\ntype: story\nstatus: backlog\nlabels:\nparent: null\nstate: open\ncreated: 2026-01-01T00:00:00Z\nupdated: 2026-01-01T00:00:00Z\n---\n\nItem body.\n' \
  > "$TMPDIR/.workflow/items/1.md"
run_snippet "$TMPDIR" "pm_add_label 1 type/feature" > /dev/null; EXIT_CODE=$?
assert_exit_zero "pm_add_label_empty_labels_exits_zero" "$EXIT_CODE"
assert_file_contains "pm_add_label_empty_labels_added" "type/feature" "$TMPDIR/.workflow/items/1.md"
COUNT=$(grep -c "type/feature" "$TMPDIR/.workflow/items/1.md" || true)
assert_eq "pm_add_label_empty_labels_no_duplicate" "1" "$COUNT"
rm -rf "$TMPDIR"; echo ""

# --- Test Group 4: pm_add_label ignores optional flags ---
# Tests --create-if-missing, --color, --description, and all three together.
echo "Test Group: pm_add_label ignores optional flags"
TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Flag Story'" > /dev/null
run_snippet "$TMPDIR" "pm_add_label 1 tag/a --create-if-missing" > /dev/null; EXIT_CODE=$?
assert_exit_zero "pm_add_label_create_if_missing_exits_zero" "$EXIT_CODE"
assert_file_contains "pm_add_label_create_if_missing_added" "tag/a" "$TMPDIR/.workflow/items/1.md"
run_snippet "$TMPDIR" "pm_add_label 1 tag/b --color ff0000" > /dev/null; EXIT_CODE=$?
assert_exit_zero "pm_add_label_color_exits_zero" "$EXIT_CODE"
assert_file_contains "pm_add_label_color_added" "tag/b" "$TMPDIR/.workflow/items/1.md"
run_snippet "$TMPDIR" "pm_add_label 1 tag/c --description 'some desc'" > /dev/null; EXIT_CODE=$?
assert_exit_zero "pm_add_label_description_exits_zero" "$EXIT_CODE"
assert_file_contains "pm_add_label_description_added" "tag/c" "$TMPDIR/.workflow/items/1.md"
run_snippet "$TMPDIR" \
  "pm_add_label 1 tag/d --create-if-missing --color 5319E7 --description 'all flags'" > /dev/null
EXIT_CODE=$?
assert_exit_zero "pm_add_label_all_flags_exits_zero" "$EXIT_CODE"
assert_file_contains "pm_add_label_all_flags_added" "tag/d" "$TMPDIR/.workflow/items/1.md"
rm -rf "$TMPDIR"; echo ""

# --- Test Group 5: labels.sh idempotency guard ---
echo "Test Group: labels.sh idempotency guard"
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
" 2>&1); EXIT_CODE=$?
assert_exit_zero "labels_idempotency_guard_exits_zero" "$EXIT_CODE"
if echo "$OUT" | grep -qF "double-source-ok"; then
  echo "  PASS: labels_idempotency_guard_output"; PASS=$((PASS + 1))
else
  echo "  FAIL: labels_idempotency_guard_output"; FAIL=$((FAIL + 1))
fi
rm -rf "$TMPDIR"; echo ""

# --- Summary ---
echo "========================================"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "========================================"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
