#!/usr/bin/env bash
set -euo pipefail

# test-local-common-core.sh — Tests for _common.sh: file existence, directory
# helpers, ID generation, and path helpers.
#
# Tests follow the Arrange/Act/Assert pattern used across this project.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMMON_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/_common.sh"

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

assert_dir_exists() {
  local test_name="$1" dir="$2"
  if [ -d "$dir" ]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (directory not found: $dir)"
    FAIL=$((FAIL + 1))
  fi
}

echo "========================================"
echo "Testing _common.sh — core helpers"
echo "========================================"
echo ""

# --- Test Group 0: File existence ---
echo "Test Group: File existence"

if [ -f "$COMMON_SH" ]; then
  echo "  PASS: _common.sh exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: _common.sh not found at $COMMON_SH"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test Group 1: _local_ensure_dirs ---
echo "Test Group: _local_ensure_dirs"

TMPDIR=$(mktemp -d)
(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_ensure_dirs
)
assert_dir_exists "_local_ensure_dirs_creates_items" "$TMPDIR/.workflow/items"
assert_dir_exists "_local_ensure_dirs_creates_comments" "$TMPDIR/.workflow/comments"
rm -rf "$TMPDIR"

echo ""

# --- Test Group 2: _local_next_id ---
echo "Test Group: _local_next_id"

TMPDIR=$(mktemp -d)
(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_ensure_dirs
  echo "ID1=$(_local_next_id)"
  echo "ID2=$(_local_next_id)"
  echo "ID3=$(_local_next_id)"
) > "$TMPDIR/out.txt"

assert_eq "_local_next_id_starts_at_1" "1" "$(grep '^ID1=' "$TMPDIR/out.txt" | cut -d= -f2)"
assert_eq "_local_next_id_second_call_returns_2" "2" "$(grep '^ID2=' "$TMPDIR/out.txt" | cut -d= -f2)"
assert_eq "_local_next_id_third_call_returns_3" "3" "$(grep '^ID3=' "$TMPDIR/out.txt" | cut -d= -f2)"
rm -rf "$TMPDIR"

# Absence of _next_id file starts at 1
TMPDIR=$(mktemp -d)
(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_ensure_dirs
  echo "ID=$(_local_next_id)"
) > "$TMPDIR/out.txt"
assert_eq "_local_next_id_no_file_starts_at_1" "1" "$(grep '^ID=' "$TMPDIR/out.txt" | cut -d= -f2)"
rm -rf "$TMPDIR"

echo ""

# --- Test Group 3: _local_item_path ---
echo "Test Group: _local_item_path"

TMPDIR=$(mktemp -d)
RESULT=$(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_item_path 42
)
assert_eq "_local_item_path_returns_correct_path" \
  "$TMPDIR/.workflow/items/42.md" "$RESULT"
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
