#!/usr/bin/env bash
set -euo pipefail

# test-local-common-fm.sh — Tests for _common.sh: _local_fm_read and
# _local_fm_write, including special-character safety (C1 fix).
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

assert_contains() {
  local test_name="$1" pattern="$2" actual="$3"
  if echo "$actual" | grep -q "$pattern"; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (pattern '$pattern' not found)"
    echo "    Actual: $actual"
    FAIL=$((FAIL + 1))
  fi
}

make_item() {
  local file="$1"
  cat > "$file" <<'EOF'
---
id: 3
title: "E01-S01: Implement OAuth callback"
type: story
status: ready
labels:
  - type/feature
  - difficulty/easy
parent: 1
state: open
created: 2026-03-18T14:00:00Z
updated: 2026-03-18T14:00:00Z
---

## Acceptance Criteria
- [ ] GET /api/auth/callback returns token
EOF
}

echo "========================================"
echo "Testing _common.sh — fm_read / fm_write"
echo "========================================"
echo ""

# --- Test Group 1: _local_fm_read ---
echo "Test Group: _local_fm_read"

TMPDIR=$(mktemp -d)
ITEM_FILE="$TMPDIR/3.md"
make_item "$ITEM_FILE"

TITLE=$(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_fm_read "$ITEM_FILE" "title"
)
STATUS=$(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_fm_read "$ITEM_FILE" "status"
)
ID_VAL=$(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_fm_read "$ITEM_FILE" "id"
)
PARENT=$(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_fm_read "$ITEM_FILE" "parent"
)

assert_eq "_local_fm_read_title" "E01-S01: Implement OAuth callback" "$TITLE"
assert_eq "_local_fm_read_status" "ready" "$STATUS"
assert_eq "_local_fm_read_id" "3" "$ID_VAL"
assert_eq "_local_fm_read_parent" "1" "$PARENT"
rm -rf "$TMPDIR"

echo ""

# --- Test Group 2: _local_fm_write (basic) ---
echo "Test Group: _local_fm_write (basic)"

TMPDIR=$(mktemp -d)
ITEM_FILE="$TMPDIR/3.md"
make_item "$ITEM_FILE"

(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_fm_write "$ITEM_FILE" "status" "in-progress"
)

NEW_STATUS=$(grep '^status:' "$ITEM_FILE" | sed 's/^status: *//')
assert_eq "_local_fm_write_updates_field" "in-progress" "$NEW_STATUS"

UPDATED=$(grep '^updated:' "$ITEM_FILE" | sed 's/^updated: *//')
if [ "$UPDATED" != "2026-03-18T14:00:00Z" ] && [ -n "$UPDATED" ]; then
  echo "  PASS: _local_fm_write_updates_timestamp"
  PASS=$((PASS + 1))
else
  echo "  FAIL: _local_fm_write_updates_timestamp (got: $UPDATED)"
  FAIL=$((FAIL + 1))
fi

assert_contains "_local_fm_write_preserves_opening_delimiter" "^---$" "$(head -1 "$ITEM_FILE")"
rm -rf "$TMPDIR"

echo ""

# --- Test Group 3: _local_fm_write — special characters (C1) ---
echo "Test Group: _local_fm_write (special characters — C1)"

# C1a: value containing pipe character (sed delimiter injection)
TMPDIR=$(mktemp -d)
ITEM_FILE="$TMPDIR/3.md"
make_item "$ITEM_FILE"
(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_fm_write "$ITEM_FILE" "status" "pipe|value"
)
assert_eq "_local_fm_write_pipe_in_value" \
  "pipe|value" "$(grep '^status:' "$ITEM_FILE" | sed 's/^status: *//')"
rm -rf "$TMPDIR"

# C1b: value containing ampersand (sed & = matched text)
TMPDIR=$(mktemp -d)
ITEM_FILE="$TMPDIR/3.md"
make_item "$ITEM_FILE"
(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_fm_write "$ITEM_FILE" "status" "amp&value"
)
assert_eq "_local_fm_write_ampersand_in_value" \
  "amp&value" "$(grep '^status:' "$ITEM_FILE" | sed 's/^status: *//')"
rm -rf "$TMPDIR"

# C1c: value containing backslash
TMPDIR=$(mktemp -d)
ITEM_FILE="$TMPDIR/3.md"
make_item "$ITEM_FILE"
(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_fm_write "$ITEM_FILE" "status" 'back\slash'
)
assert_eq "_local_fm_write_backslash_in_value" \
  'back\slash' "$(grep '^status:' "$ITEM_FILE" | sed 's/^status: *//')"
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
