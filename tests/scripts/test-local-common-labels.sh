#!/usr/bin/env bash
set -euo pipefail

# test-local-common-labels.sh — Tests for _common.sh: _local_fm_read_labels
# and _local_fm_append_label, including end-of-frontmatter edge case (C2 fix).
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

# Standard item: labels in the middle of frontmatter
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
  - hierarchy/story
  - backlog/111-local-first-pm
parent: 1
state: open
created: 2026-03-18T14:00:00Z
updated: 2026-03-18T14:00:00Z
---

## Acceptance Criteria
- [ ] GET /api/auth/callback returns token
EOF
}

# Edge-case item: labels: is the LAST field before closing --- (C2)
make_item_labels_last() {
  local file="$1"
  cat > "$file" <<'EOF'
---
id: 7
title: "Labels-last item"
type: story
status: open
updated: 2026-03-18T14:00:00Z
labels:
  - type/feature
---

## Body
EOF
}

echo "========================================"
echo "Testing _common.sh — label helpers"
echo "========================================"
echo ""

# --- Test Group 1: _local_fm_read_labels ---
echo "Test Group: _local_fm_read_labels"

TMPDIR=$(mktemp -d)
ITEM_FILE="$TMPDIR/3.md"
make_item "$ITEM_FILE"

LABELS=$(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_fm_read_labels "$ITEM_FILE"
)

assert_contains "_local_fm_read_labels_type_feature" "type/feature" "$LABELS"
assert_contains "_local_fm_read_labels_difficulty_easy" "difficulty/easy" "$LABELS"
assert_contains "_local_fm_read_labels_hierarchy_story" "hierarchy/story" "$LABELS"
assert_contains "_local_fm_read_labels_backlog_label" "backlog/111-local-first-pm" "$LABELS"

LABEL_COUNT=$(echo "$LABELS" | grep -c '.' || true)
assert_eq "_local_fm_read_labels_count_is_4" "4" "$LABEL_COUNT"
rm -rf "$TMPDIR"

echo ""

# --- Test Group 2: _local_fm_append_label (standard) ---
echo "Test Group: _local_fm_append_label (standard)"

TMPDIR=$(mktemp -d)
ITEM_FILE="$TMPDIR/3.md"
make_item "$ITEM_FILE"

(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_fm_append_label "$ITEM_FILE" "new-label/foo"
)

LABELS_AFTER=$(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_fm_read_labels "$ITEM_FILE"
)
assert_contains "_local_fm_append_label_adds_new_label" "new-label/foo" "$LABELS_AFTER"

# Idempotency: appending an existing label must not create a duplicate
(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_fm_append_label "$ITEM_FILE" "type/feature"
)

LABELS_IDEM=$(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_fm_read_labels "$ITEM_FILE"
)
COUNT=$(echo "$LABELS_IDEM" | grep -c '^type/feature$' || true)
assert_eq "_local_fm_append_label_idempotent_no_duplicate" "1" "$COUNT"
rm -rf "$TMPDIR"

echo ""

# --- Test Group 3: _local_fm_append_label — labels last (C2) ---
echo "Test Group: _local_fm_append_label (labels last before closing --- — C2)"

TMPDIR=$(mktemp -d)
ITEM_FILE="$TMPDIR/7.md"
make_item_labels_last "$ITEM_FILE"

(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_fm_append_label "$ITEM_FILE" "hierarchy/story"
)

LABELS_LAST=$(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_fm_read_labels "$ITEM_FILE"
)
assert_contains "_local_fm_append_label_labels_last_adds_label" "hierarchy/story" "$LABELS_LAST"

# Original label must still be present
assert_contains "_local_fm_append_label_labels_last_keeps_existing" "type/feature" "$LABELS_LAST"

# Body must be intact (no frontmatter bleed into body section)
BODY_AFTER=$(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR/.workflow"
  source "$COMMON_SH"
  _local_read_body "$ITEM_FILE"
)
assert_contains "_local_fm_append_label_labels_last_body_intact" "## Body" "$BODY_AFTER"
rm -rf "$TMPDIR"

# --- Summary ---
echo "========================================"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
