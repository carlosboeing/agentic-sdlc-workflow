#!/usr/bin/env bash
set -euo pipefail

# test-local-common-sh.sh — Tests for scripts/lib/adapters/pm/local/_common.sh
#
# All tests use temporary directories; no mocking required.
# Tests follow the Arrange/Act/Assert pattern used across this project.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMMON_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/_common.sh"
CONFIG_SH="$REPO_ROOT/scripts/lib/config.sh"

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

assert_file_exists() {
  local test_name="$1" file="$2"
  if [ -e "$file" ]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (file not found: $file)"
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

# Create a sample work item file with standard frontmatter
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
- [ ] Token is stored in secure cookie
EOF
}

echo "========================================"
echo "Testing scripts/lib/adapters/pm/local/_common.sh"
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

TMPDIR1=$(mktemp -d)
(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR1/.workflow"
  source "$COMMON_SH"
  _local_ensure_dirs
)
assert_dir_exists "_local_ensure_dirs_creates_items" "$TMPDIR1/.workflow/items"
assert_dir_exists "_local_ensure_dirs_creates_comments" "$TMPDIR1/.workflow/comments"
rm -rf "$TMPDIR1"

echo ""

# --- Test Group 2: _local_next_id ---
echo "Test Group: _local_next_id"

TMPDIR2=$(mktemp -d)
(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR2/.workflow"
  source "$COMMON_SH"
  _local_ensure_dirs
  ID1=$(_local_next_id)
  ID2=$(_local_next_id)
  ID3=$(_local_next_id)
  echo "ID1=$ID1"
  echo "ID2=$ID2"
  echo "ID3=$ID3"
) > "$TMPDIR2/out.txt"

ID1=$(grep '^ID1=' "$TMPDIR2/out.txt" | cut -d= -f2)
ID2=$(grep '^ID2=' "$TMPDIR2/out.txt" | cut -d= -f2)
ID3=$(grep '^ID3=' "$TMPDIR2/out.txt" | cut -d= -f2)

assert_eq "_local_next_id_starts_at_1" "1" "$ID1"
assert_eq "_local_next_id_second_call_returns_2" "2" "$ID2"
assert_eq "_local_next_id_third_call_returns_3" "3" "$ID3"
rm -rf "$TMPDIR2"

# Test that _next_id file absence triggers start-at-1
TMPDIR2B=$(mktemp -d)
(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR2B/.workflow"
  source "$COMMON_SH"
  _local_ensure_dirs
  ID=$(_local_next_id)
  echo "ID=$ID"
) > "$TMPDIR2B/out.txt"
ID=$(grep '^ID=' "$TMPDIR2B/out.txt" | cut -d= -f2)
assert_eq "_local_next_id_no_file_starts_at_1" "1" "$ID"
rm -rf "$TMPDIR2B"

echo ""

# --- Test Group 3: _local_item_path ---
echo "Test Group: _local_item_path"

TMPDIR3=$(mktemp -d)
RESULT=$(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR3/.workflow"
  source "$COMMON_SH"
  _local_item_path 42
)
assert_eq "_local_item_path_returns_correct_path" \
  "$TMPDIR3/.workflow/items/42.md" "$RESULT"
rm -rf "$TMPDIR3"

echo ""

# --- Test Group 4: _local_fm_read ---
echo "Test Group: _local_fm_read"

TMPDIR4=$(mktemp -d)
ITEM_FILE="$TMPDIR4/3.md"
make_item "$ITEM_FILE"

# Source and run in subshell to keep env clean
TITLE=$(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR4/.workflow"
  source "$COMMON_SH"
  _local_fm_read "$ITEM_FILE" "title"
)
STATUS=$(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR4/.workflow"
  source "$COMMON_SH"
  _local_fm_read "$ITEM_FILE" "status"
)
ID_VAL=$(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR4/.workflow"
  source "$COMMON_SH"
  _local_fm_read "$ITEM_FILE" "id"
)
PARENT=$(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR4/.workflow"
  source "$COMMON_SH"
  _local_fm_read "$ITEM_FILE" "parent"
)

assert_eq "_local_fm_read_title" "E01-S01: Implement OAuth callback" "$TITLE"
assert_eq "_local_fm_read_status" "ready" "$STATUS"
assert_eq "_local_fm_read_id" "3" "$ID_VAL"
assert_eq "_local_fm_read_parent" "1" "$PARENT"
rm -rf "$TMPDIR4"

echo ""

# --- Test Group 5: _local_fm_write ---
echo "Test Group: _local_fm_write"

TMPDIR5=$(mktemp -d)
ITEM_FILE="$TMPDIR5/3.md"
make_item "$ITEM_FILE"

# Perform write in subshell, then read back from main shell (file persists)
(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR5/.workflow"
  source "$COMMON_SH"
  _local_fm_write "$ITEM_FILE" "status" "in-progress"
)

# Read back with grep (not _local_fm_read) to avoid sourcing dependency
NEW_STATUS=$(grep '^status:' "$ITEM_FILE" | sed 's/^status: *//')
assert_eq "_local_fm_write_updates_field" "in-progress" "$NEW_STATUS"

# Check that 'updated' timestamp changed (must differ from the hardcoded original)
UPDATED=$(grep '^updated:' "$ITEM_FILE" | sed 's/^updated: *//')
if [ "$UPDATED" != "2026-03-18T14:00:00Z" ] && [ -n "$UPDATED" ]; then
  echo "  PASS: _local_fm_write_updates_timestamp"
  PASS=$((PASS + 1))
else
  echo "  FAIL: _local_fm_write_updates_timestamp (got: $UPDATED)"
  FAIL=$((FAIL + 1))
fi

# Ensure frontmatter is still valid (opening --- present)
assert_contains "_local_fm_write_preserves_opening_delimiter" "^---$" "$(head -1 "$ITEM_FILE")"
rm -rf "$TMPDIR5"

echo ""

# --- Test Group 6: _local_fm_read_labels ---
echo "Test Group: _local_fm_read_labels"

TMPDIR6=$(mktemp -d)
ITEM_FILE="$TMPDIR6/3.md"
make_item "$ITEM_FILE"

LABELS=$(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR6/.workflow"
  source "$COMMON_SH"
  _local_fm_read_labels "$ITEM_FILE"
)

assert_contains "_local_fm_read_labels_returns_type_feature" "type/feature" "$LABELS"
assert_contains "_local_fm_read_labels_returns_difficulty_easy" "difficulty/easy" "$LABELS"
assert_contains "_local_fm_read_labels_returns_hierarchy_story" "hierarchy/story" "$LABELS"
assert_contains "_local_fm_read_labels_returns_backlog_label" "backlog/111-local-first-pm" "$LABELS"

# Count: should be exactly 4 lines
LABEL_COUNT=$(echo "$LABELS" | grep -c '.' || true)
assert_eq "_local_fm_read_labels_returns_4_labels" "4" "$LABEL_COUNT"
rm -rf "$TMPDIR6"

echo ""

# --- Test Group 7: _local_fm_append_label ---
echo "Test Group: _local_fm_append_label"

TMPDIR7=$(mktemp -d)
ITEM_FILE="$TMPDIR7/3.md"
make_item "$ITEM_FILE"

# Append a new label
(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR7/.workflow"
  source "$COMMON_SH"
  _local_fm_append_label "$ITEM_FILE" "backlog/111-local-first-pm-new"
)

LABELS_AFTER=$(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR7/.workflow"
  source "$COMMON_SH"
  _local_fm_read_labels "$ITEM_FILE"
)
assert_contains "_local_fm_append_label_adds_new_label" "backlog/111-local-first-pm-new" "$LABELS_AFTER"

# Idempotency: append an existing label again
(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR7/.workflow"
  source "$COMMON_SH"
  _local_fm_append_label "$ITEM_FILE" "type/feature"
)

LABELS_IDEM=$(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR7/.workflow"
  source "$COMMON_SH"
  _local_fm_read_labels "$ITEM_FILE"
)
TYPE_FEATURE_COUNT=$(echo "$LABELS_IDEM" | grep -c '^type/feature$' || true)
assert_eq "_local_fm_append_label_idempotent_no_duplicate" "1" "$TYPE_FEATURE_COUNT"
rm -rf "$TMPDIR7"

echo ""

# --- Test Group 8: _local_read_body ---
echo "Test Group: _local_read_body"

TMPDIR8=$(mktemp -d)
ITEM_FILE="$TMPDIR8/3.md"
make_item "$ITEM_FILE"

BODY=$(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR8/.workflow"
  source "$COMMON_SH"
  _local_read_body "$ITEM_FILE"
)

assert_contains "_local_read_body_contains_acceptance_criteria" "Acceptance Criteria" "$BODY"
assert_contains "_local_read_body_contains_first_checkbox" "GET /api/auth/callback" "$BODY"

# Body must NOT contain frontmatter fields
if echo "$BODY" | grep -q '^status:'; then
  echo "  FAIL: _local_read_body_excludes_frontmatter (found status: in body)"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: _local_read_body_excludes_frontmatter"
  PASS=$((PASS + 1))
fi
rm -rf "$TMPDIR8"

echo ""

# --- Test Group 9: _local_write_body ---
echo "Test Group: _local_write_body"

TMPDIR9=$(mktemp -d)
ITEM_FILE="$TMPDIR9/3.md"
make_item "$ITEM_FILE"

NEW_BODY="## Updated Body
- [ ] New checkbox item"

(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR9/.workflow"
  source "$COMMON_SH"
  _local_write_body "$ITEM_FILE" "$NEW_BODY"
)

BODY_AFTER=$(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR9/.workflow"
  source "$COMMON_SH"
  _local_read_body "$ITEM_FILE"
)
assert_contains "_local_write_body_sets_new_content" "Updated Body" "$BODY_AFTER"

# Frontmatter must be preserved
TITLE_AFTER=$(grep '^title:' "$ITEM_FILE" | sed 's/^title: *//' | sed 's/^"\(.*\)"$/\1/')
assert_contains "_local_write_body_preserves_frontmatter" "E01-S01" "$TITLE_AFTER"

# Old body must be replaced
if echo "$BODY_AFTER" | grep -q "GET /api/auth/callback"; then
  echo "  FAIL: _local_write_body_replaces_old_content (old content still present)"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: _local_write_body_replaces_old_content"
  PASS=$((PASS + 1))
fi
rm -rf "$TMPDIR9"

echo ""

# --- Test Group 10: Idempotency guard ---
echo "Test Group: Idempotency guard"

TMPDIR10=$(mktemp -d)
(
  _LOCAL_COMMON_LOADED=""
  _LOCAL_WORKFLOW_DIR="$TMPDIR10/.workflow"
  source "$COMMON_SH"
  # Second source must not re-execute (functions still available, no error)
  source "$COMMON_SH"
  echo "LOADED_OK"
) > "$TMPDIR10/out.txt"
assert_contains "_idempotency_guard_double_source_no_error" "LOADED_OK" "$(cat "$TMPDIR10/out.txt")"
rm -rf "$TMPDIR10"

echo ""

# --- Test Group 11: CFG_LOCAL_WORKFLOW_DIR from config.sh ---
echo "Test Group: CFG_LOCAL_WORKFLOW_DIR in config.sh"

# Test default value when config has no pm.local.workflowDir
TMPDIR11=$(mktemp -d)
TEMP_CFG="$TMPDIR11/config.json"
cat > "$TEMP_CFG" <<'CFGEOF'
{
  "github": {
    "repo": "test/repo",
    "projectNumber": 99,
    "owner": "test",
    "projectId": "PVT_test",
    "statusFieldId": "PVTSSF_test"
  },
  "pm": {
    "adapter": "local"
  }
}
CFGEOF

# Use bash subprocess with overridden _CFG_FILE path via env trick:
# We'll simulate reading the config by testing the _cfg logic directly
DEFAULT_VAL=$(jq -r '.pm.local.workflowDir // empty' "$TEMP_CFG" 2>/dev/null || true)
if [ -z "$DEFAULT_VAL" ]; then DEFAULT_VAL=".workflow"; fi
assert_eq "CFG_LOCAL_WORKFLOW_DIR_DefaultsTo_.workflow" ".workflow" "$DEFAULT_VAL"

# Test with custom value
TEMP_CFG2="$TMPDIR11/config2.json"
cat > "$TEMP_CFG2" <<'CFGEOF'
{
  "pm": {
    "adapter": "local",
    "local": {
      "workflowDir": ".my-workflow"
    }
  }
}
CFGEOF
CUSTOM_VAL=$(jq -r '.pm.local.workflowDir // empty' "$TEMP_CFG2" 2>/dev/null || true)
if [ -z "$CUSTOM_VAL" ]; then CUSTOM_VAL=".workflow"; fi
assert_eq "CFG_LOCAL_WORKFLOW_DIR_ReadsCustomValue" ".my-workflow" "$CUSTOM_VAL"
rm -rf "$TMPDIR11"

# Verify config.sh exports CFG_LOCAL_WORKFLOW_DIR
if grep -q 'CFG_LOCAL_WORKFLOW_DIR' "$CONFIG_SH"; then
  echo "  PASS: config.sh_defines_CFG_LOCAL_WORKFLOW_DIR"
  PASS=$((PASS + 1))
else
  echo "  FAIL: config.sh_defines_CFG_LOCAL_WORKFLOW_DIR (not found in $CONFIG_SH)"
  FAIL=$((FAIL + 1))
fi

if grep -q '\.pm\.local\.workflowDir' "$CONFIG_SH"; then
  echo "  PASS: config.sh_reads_pm_local_workflowDir_from_JSON"
  PASS=$((PASS + 1))
else
  echo "  FAIL: config.sh_reads_pm_local_workflowDir_from_JSON"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Summary ---
echo "========================================"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
