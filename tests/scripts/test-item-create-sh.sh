#!/usr/bin/env bash
# test-item-create-sh.sh — Tests for scripts/item-create.sh
#
# Tests the CLI wrapper that routes through pm_create_item.
# Uses _PM_TEST_ADAPTER_DIR to avoid GitHub API calls.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ISSUE_CREATE="$REPO_ROOT/scripts/item-create.sh"
LOCAL_ADAPTER_DIR="$REPO_ROOT/scripts/lib/adapters/pm/local"

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
  if echo "$haystack" | grep -qF -- "$needle"; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    Expected to contain: $needle"
    echo "    Got: $(echo "$haystack" | head -5)"
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
echo "Testing scripts/item-create.sh"
echo "========================================"
echo ""

# --- Test Group 0: File existence ---
echo "Test Group: File existence"

if [ -f "$ISSUE_CREATE" ]; then
  echo "  PASS: item-create.sh exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: item-create.sh not found at $ISSUE_CREATE"
  FAIL=$((FAIL + 1))
fi

if [ -x "$ISSUE_CREATE" ]; then
  echo "  PASS: item-create.sh is executable"
  PASS=$((PASS + 1))
else
  echo "  FAIL: item-create.sh is not executable"
  FAIL=$((FAIL + 1))
fi
echo ""

# Helper to run item-create.sh in a test environment
run_create() {
  local tmpdir="$1"
  shift
  _PM_TEST_ADAPTER_DIR="$LOCAL_ADAPTER_DIR" \
  _LOCAL_WORKFLOW_DIR="$tmpdir/.workflow" \
  _LOCAL_COMMON_LOADED="" \
  _LOCAL_ITEMS_LOADED="" \
  _LOCAL_COMMENTS_LOADED="" \
  _PM_SH_LOADED="" \
  _PM_SH_LOADED_DIR="" \
  bash "$ISSUE_CREATE" "$@"
}

# --- Test Group 1: Creates story item ---
echo "Test Group: Creates story item with --title"

TMPDIR=$(mktemp -d)
OUT=$(run_create "$TMPDIR" story --title "My Story Title" 2>/dev/null)
EXIT_CODE=$?

assert_exit_zero "create_story_exits_zero" "$EXIT_CODE"
assert_eq "create_story_returns_id" "1" "$OUT"

ITEM_FILE="$TMPDIR/.workflow/items/1.md"
if [ -f "$ITEM_FILE" ]; then
  echo "  PASS: create_story_creates_item_file"
  PASS=$((PASS + 1))
else
  echo "  FAIL: create_story_creates_item_file"
  FAIL=$((FAIL + 1))
fi

TITLE=$(grep '^title:' "$ITEM_FILE" | sed 's/title: //;s/^\"//;s/\"$//')
assert_eq "create_story_title_correct" "My Story Title" "$TITLE"

TYPE=$(grep '^type:' "$ITEM_FILE" | sed 's/type: //')
assert_eq "create_story_type_correct" "story" "$TYPE"

if grep -q 'hierarchy/story' "$ITEM_FILE"; then
  echo "  PASS: create_story_hierarchy_label"
  PASS=$((PASS + 1))
else
  echo "  FAIL: create_story_hierarchy_label"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 2: Creates epic item ---
echo "Test Group: Creates epic item"

TMPDIR=$(mktemp -d)
OUT=$(run_create "$TMPDIR" epic --title "[E01] My Epic" 2>/dev/null)
EXIT_CODE=$?

assert_exit_zero "create_epic_exits_zero" "$EXIT_CODE"
assert_eq "create_epic_returns_id" "1" "$OUT"

ITEM_FILE="$TMPDIR/.workflow/items/1.md"
TYPE=$(grep '^type:' "$ITEM_FILE" | sed 's/type: //')
assert_eq "create_epic_type_correct" "epic" "$TYPE"

if grep -q 'hierarchy/epic' "$ITEM_FILE"; then
  echo "  PASS: create_epic_hierarchy_label"
  PASS=$((PASS + 1))
else
  echo "  FAIL: create_epic_hierarchy_label"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 3: Creates docs item ---
echo "Test Group: Creates docs item"

TMPDIR=$(mktemp -d)
OUT=$(run_create "$TMPDIR" docs --title "Write design doc" 2>/dev/null)
EXIT_CODE=$?

assert_exit_zero "create_docs_exits_zero" "$EXIT_CODE"

ITEM_FILE="$TMPDIR/.workflow/items/1.md"
TYPE=$(grep '^type:' "$ITEM_FILE" | sed 's/type: //')
assert_eq "create_docs_type_correct" "docs" "$TYPE"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 4: --body flag ---
echo "Test Group: --body flag passes body content"

TMPDIR=$(mktemp -d)
run_create "$TMPDIR" story --title "Body Story" --body "This is the body content" > /dev/null 2>&1

ITEM_FILE="$TMPDIR/.workflow/items/1.md"
BODY=$(awk '/^---$/{c++; if(c==2){f=1; next}} f{print}' "$ITEM_FILE")
assert_contains "create_body_content" "This is the body content" "$BODY"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 5: --label flag (single) ---
echo "Test Group: --label flag adds label"

TMPDIR=$(mktemp -d)
run_create "$TMPDIR" story --title "Label Story" --label "backlog/242-slug" > /dev/null 2>&1

ITEM_FILE="$TMPDIR/.workflow/items/1.md"
if grep -q 'backlog/242-slug' "$ITEM_FILE"; then
  echo "  PASS: create_single_label_present"
  PASS=$((PASS + 1))
else
  echo "  FAIL: create_single_label_present (file: $(cat "$ITEM_FILE"))"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 6: --label flag (multiple) ---
echo "Test Group: Multiple --label flags"

TMPDIR=$(mktemp -d)
run_create "$TMPDIR" story --title "Multi Label Story" \
  --label "backlog/242-slug" --label "difficulty/easy" > /dev/null 2>&1

ITEM_FILE="$TMPDIR/.workflow/items/1.md"
if grep -q 'backlog/242-slug' "$ITEM_FILE"; then
  echo "  PASS: create_multi_label_1"
  PASS=$((PASS + 1))
else
  echo "  FAIL: create_multi_label_1"
  FAIL=$((FAIL + 1))
fi

if grep -q 'difficulty/easy' "$ITEM_FILE"; then
  echo "  PASS: create_multi_label_2"
  PASS=$((PASS + 1))
else
  echo "  FAIL: create_multi_label_2"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 7: Error without --title ---
echo "Test Group: Error without --title"

TMPDIR=$(mktemp -d)
OUT=$(run_create "$TMPDIR" story 2>&1)
EXIT_CODE=$?

assert_exit_nonzero "create_no_title_fails" "$EXIT_CODE"
assert_contains "create_no_title_error_message" "title" "$OUT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 8: Error without level argument ---
echo "Test Group: Error without level argument"

TMPDIR=$(mktemp -d)
OUT=$(run_create "$TMPDIR" 2>&1)
EXIT_CODE=$?

assert_exit_nonzero "create_no_level_fails" "$EXIT_CODE"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 9: prints only issue number to stdout ---
echo "Test Group: Only issue number printed to stdout"

TMPDIR=$(mktemp -d)
STDOUT=$(run_create "$TMPDIR" story --title "Stdout Story" 2>/dev/null)

# stdout should be just the number, nothing else
assert_eq "create_stdout_is_number_only" "1" "$STDOUT"

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
