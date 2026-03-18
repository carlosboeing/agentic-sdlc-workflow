#!/usr/bin/env bash
set -euo pipefail

# test-local-common-body.sh — Tests for _common.sh: _local_read_body,
# _local_write_body, and idempotency guard.
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
updated: 2026-03-18T14:00:00Z
---

## Acceptance Criteria
- [ ] GET /api/auth/callback returns token
- [ ] Token is stored in secure cookie
EOF
}

echo "========================================"
echo "Testing _common.sh — body helpers / idempotency"
echo "========================================"
echo ""

# --- Test Group 1: _local_read_body ---
echo "Test Group: _local_read_body"

TMPDIR=$(mktemp -d)
ITEM_FILE="$TMPDIR/3.md"
make_item "$ITEM_FILE"

BODY=$(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_read_body "$ITEM_FILE"
)

assert_contains "_local_read_body_contains_acceptance_criteria" "Acceptance Criteria" "$BODY"
assert_contains "_local_read_body_contains_first_checkbox" "GET /api/auth/callback" "$BODY"

if echo "$BODY" | grep -q '^status:'; then
  echo "  FAIL: _local_read_body_excludes_frontmatter (found status: in body)"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: _local_read_body_excludes_frontmatter"
  PASS=$((PASS + 1))
fi
rm -rf "$TMPDIR"

echo ""

# --- Test Group 2: _local_write_body ---
echo "Test Group: _local_write_body"

TMPDIR=$(mktemp -d)
ITEM_FILE="$TMPDIR/3.md"
make_item "$ITEM_FILE"

NEW_BODY="## Updated Body
- [ ] New checkbox item"

(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_write_body "$ITEM_FILE" "$NEW_BODY"
)

BODY_AFTER=$(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_read_body "$ITEM_FILE"
)
assert_contains "_local_write_body_sets_new_content" "Updated Body" "$BODY_AFTER"

TITLE_AFTER=$(grep '^title:' "$ITEM_FILE" | sed 's/^title: *//' | sed 's/^"\(.*\)"$/\1/')
assert_contains "_local_write_body_preserves_frontmatter" "E01-S01" "$TITLE_AFTER"

if echo "$BODY_AFTER" | grep -q "GET /api/auth/callback"; then
  echo "  FAIL: _local_write_body_replaces_old_content (old content still present)"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: _local_write_body_replaces_old_content"
  PASS=$((PASS + 1))
fi
rm -rf "$TMPDIR"

echo ""

# --- Test Group 3: Idempotency guard ---
echo "Test Group: Idempotency guard"

TMPDIR=$(mktemp -d)
(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  source "$COMMON_SH"
  echo "LOADED_OK"
) > "$TMPDIR/out.txt"
assert_contains "_idempotency_guard_double_source_no_error" "LOADED_OK" "$(cat "$TMPDIR/out.txt")"
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
