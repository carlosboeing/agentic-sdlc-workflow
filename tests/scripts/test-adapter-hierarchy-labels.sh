#!/usr/bin/env bash
# test-adapter-hierarchy-labels.sh — Validates hierarchy.sh and labels.sh adapter modules.
# Runs locally using mock functions (no live GitHub API calls).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/thresholds.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HIERARCHY_SH="$REPO_ROOT/scripts/lib/adapters/pm/github/hierarchy.sh"
LABELS_SH="$REPO_ROOT/scripts/lib/adapters/pm/github/labels.sh"

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

assert_contains() {
  local test_name="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    Expected to contain: $needle"
    echo "    Actual: $haystack"
    FAIL=$((FAIL + 1))
  fi
}

echo "========================================"
echo "Testing adapters/pm/github/hierarchy.sh + labels.sh"
echo "========================================"
echo ""

# --- Test Group 1: File properties ---
echo "Test Group: File properties"

for f in "$HIERARCHY_SH" "$LABELS_SH"; do
  base=$(basename "$f")
  if [ -f "$f" ]; then
    echo "  PASS: $base exists"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $base not found at $f"
    FAIL=$((FAIL + 1))
  fi
  if [ -x "$f" ]; then
    echo "  PASS: $base is executable"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $base is not executable"
    FAIL=$((FAIL + 1))
  fi
done

# Line count constraints
HIERARCHY_LINES=$(wc -l < "$HIERARCHY_SH" 2>/dev/null || echo 999)
if [ "$HIERARCHY_LINES" -le "$THRESHOLD_SMALL_MODULE" ]; then
  echo "  PASS: hierarchy.sh is under $THRESHOLD_SMALL_MODULE lines ($HIERARCHY_LINES)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: hierarchy.sh exceeds $THRESHOLD_SMALL_MODULE lines ($HIERARCHY_LINES)"
  FAIL=$((FAIL + 1))
fi

LABELS_LINES=$(wc -l < "$LABELS_SH" 2>/dev/null || echo 999)
if [ "$LABELS_LINES" -le "$THRESHOLD_SMALL_MODULE" ]; then
  echo "  PASS: labels.sh is under $THRESHOLD_SMALL_MODULE lines ($LABELS_LINES)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: labels.sh exceeds $THRESHOLD_SMALL_MODULE lines ($LABELS_LINES)"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test Group 2: pm_link_child with mock gh ---
echo "Test Group: pm_link_child (mock gh)"

# Build a mock gh that stubs the issue-view and graphql calls
MOCK_BIN_DIR=$(mktemp -d)
cat > "$MOCK_BIN_DIR/gh" <<'MOCK_GH'
#!/usr/bin/env bash
# Minimal gh mock for hierarchy tests.
# gh issue view --json id -q '.id // empty' returns just the ID string (not JSON).
if [[ "$*" == *"issue view 10"*"--json id"* ]]; then
  echo 'parent-node-id-10'
elif [[ "$*" == *"issue view 20"*"--json id"* ]]; then
  echo 'child-node-id-20'
elif [[ "$*" == "api graphql"* ]]; then
  echo '{"data":{"addSubIssue":{"subIssue":{"id":"child-node-id-20"}}}}'
fi
MOCK_GH
chmod +x "$MOCK_BIN_DIR/gh"

TMPOUT=$(mktemp)
PATH="$MOCK_BIN_DIR:$PATH" bash --norc --noprofile -c "
  export CFG_REPO='owner/repo'
  source '$HIERARCHY_SH'
  pm_link_child 10 20
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "pm_link_child_exits_zero" "$EXIT_CODE"
assert_contains "pm_link_child_confirmation_message" "20" "$OUTPUT"

echo ""

# --- Test Group 3: pm_link_child error on missing node ID ---
echo "Test Group: pm_link_child error on empty node ID"

cat > "$MOCK_BIN_DIR/gh" <<'MOCK_GH_EMPTY'
#!/usr/bin/env bash
# Returns empty output for parent (simulates missing/no node ID), valid id for child
if [[ "$*" == *"issue view 99"*"--json id"* ]]; then
  : # output nothing — simulates gh -q '.id // empty' on an issue with no id
elif [[ "$*" == *"issue view 20"*"--json id"* ]]; then
  echo 'child-node-id-20'
fi
MOCK_GH_EMPTY
chmod +x "$MOCK_BIN_DIR/gh"

TMPOUT=$(mktemp)
PATH="$MOCK_BIN_DIR:$PATH" bash --norc --noprofile -c "
  export CFG_REPO='owner/repo'
  source '$HIERARCHY_SH'
  pm_link_child 99 20
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
rm -f "$TMPOUT"

assert_exit_nonzero "pm_link_child_fails_on_missing_parent_node_id" "$EXIT_CODE"

echo ""

# --- Test Group 3b: pm_link_child error on missing child node ID ---
echo "Test Group: pm_link_child error on missing child node ID"

cat > "$MOCK_BIN_DIR/gh" <<'MOCK_GH_MISSING_CHILD'
#!/usr/bin/env bash
# Returns valid id for parent, empty for child (simulates missing child)
if [[ "$*" == *"issue view 10"*"--json id"* ]]; then
  echo 'parent-node-id-10'
elif [[ "$*" == *"issue view 99"*"--json id"* ]]; then
  : # output nothing — simulates gh -q '.id // empty' on an issue with no id
fi
MOCK_GH_MISSING_CHILD
chmod +x "$MOCK_BIN_DIR/gh"

TMPOUT=$(mktemp)
PATH="$MOCK_BIN_DIR:$PATH" bash --norc --noprofile -c "
  export CFG_REPO='owner/repo'
  source '$HIERARCHY_SH'
  pm_link_child 10 99
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_nonzero "pm_link_child_fails_on_missing_child_node_id" "$EXIT_CODE"
assert_contains "pm_link_child_error_message_mentions_child" "99" "$OUTPUT"

echo ""

# --- Test Group 3c: pm_link_child error on GraphQL mutation failure ---
echo "Test Group: pm_link_child error on GraphQL mutation failure"

cat > "$MOCK_BIN_DIR/gh" <<'MOCK_GH_GRAPHQL_FAIL'
#!/usr/bin/env bash
# Returns valid node IDs but fails on the graphql mutation
if [[ "$*" == *"issue view 10"*"--json id"* ]]; then
  echo 'parent-node-id-10'
elif [[ "$*" == *"issue view 20"*"--json id"* ]]; then
  echo 'child-node-id-20'
elif [[ "$*" == "api graphql"* ]]; then
  echo '{"errors":[{"message":"Not Found"}]}' >&2
  exit 1
fi
MOCK_GH_GRAPHQL_FAIL
chmod +x "$MOCK_BIN_DIR/gh"

TMPOUT=$(mktemp)
PATH="$MOCK_BIN_DIR:$PATH" bash --norc --noprofile -c "
  export CFG_REPO='owner/repo'
  source '$HIERARCHY_SH'
  pm_link_child 10 20
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_nonzero "pm_link_child_fails_on_graphql_error" "$EXIT_CODE"
assert_contains "pm_link_child_graphql_error_message" "ERROR" "$OUTPUT"

echo ""

# --- Test Group 4: pm_add_label without --create-if-missing (success) ---
echo "Test Group: pm_add_label without --create-if-missing (label exists)"

cat > "$MOCK_BIN_DIR/gh" <<'MOCK_GH_LABEL'
#!/usr/bin/env bash
# gh issue edit --add-label succeeds
if [[ "$*" == *"issue edit"* && "$*" == *"--add-label"* ]]; then
  exit 0
fi
MOCK_GH_LABEL
chmod +x "$MOCK_BIN_DIR/gh"

TMPOUT=$(mktemp)
PATH="$MOCK_BIN_DIR:$PATH" bash --norc --noprofile -c "
  export CFG_REPO='owner/repo'
  source '$LABELS_SH'
  pm_add_label 42 'type/feature'
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
rm -f "$TMPOUT"

assert_exit_zero "pm_add_label_exits_zero_when_label_exists" "$EXIT_CODE"

echo ""

# --- Test Group 5: pm_add_label without --create-if-missing (gh fails = label missing) ---
echo "Test Group: pm_add_label without --create-if-missing (label missing → fail)"

cat > "$MOCK_BIN_DIR/gh" <<'MOCK_GH_NOLABEL'
#!/usr/bin/env bash
# gh issue edit fails when label doesn't exist
if [[ "$*" == *"issue edit"* && "$*" == *"--add-label"* ]]; then
  echo "error: label 'nonexistent' not found" >&2
  exit 1
fi
MOCK_GH_NOLABEL
chmod +x "$MOCK_BIN_DIR/gh"

TMPOUT=$(mktemp)
PATH="$MOCK_BIN_DIR:$PATH" bash --norc --noprofile -c "
  export CFG_REPO='owner/repo'
  source '$LABELS_SH'
  pm_add_label 42 'nonexistent'
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
rm -f "$TMPOUT"

assert_exit_nonzero "pm_add_label_fails_when_label_missing_no_create_flag" "$EXIT_CODE"

echo ""

# --- Test Group 6: pm_add_label with --create-if-missing ---
echo "Test Group: pm_add_label with --create-if-missing (creates then adds)"

LABEL_CREATE_CALLED=0
LABEL_EDIT_CALLED=0

cat > "$MOCK_BIN_DIR/gh" <<'MOCK_GH_CREATE'
#!/usr/bin/env bash
LOG_FILE="${MOCK_LOG_FILE:-/dev/null}"
if [[ "$*" == *"label create"* ]]; then
  echo "created" >> "$LOG_FILE"
  exit 0
fi
if [[ "$*" == *"issue edit"* && "$*" == *"--add-label"* ]]; then
  echo "applied" >> "$LOG_FILE"
  exit 0
fi
MOCK_GH_CREATE
chmod +x "$MOCK_BIN_DIR/gh"

LOG=$(mktemp)
TMPOUT=$(mktemp)
PATH="$MOCK_BIN_DIR:$PATH" MOCK_LOG_FILE="$LOG" bash --norc --noprofile -c "
  export CFG_REPO='owner/repo'
  export MOCK_LOG_FILE='$LOG'
  source '$LABELS_SH'
  pm_add_label 42 'backlog/109-pm-abstraction' --create-if-missing --color '5319E7'
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
LOG_CONTENT=$(cat "$LOG")
rm -f "$TMPOUT" "$LOG"

assert_exit_zero "pm_add_label_with_create_if_missing_exits_zero" "$EXIT_CODE"
assert_contains "pm_add_label_calls_label_create" "created" "$LOG_CONTENT"
assert_contains "pm_add_label_calls_issue_edit" "applied" "$LOG_CONTENT"

echo ""

# --- Test Group 7: pm_add_label default color ---
echo "Test Group: pm_add_label default color is 5319E7"

COLOR_USED=""
cat > "$MOCK_BIN_DIR/gh" <<'MOCK_GH_COLOR'
#!/usr/bin/env bash
LOG_FILE="${MOCK_LOG_FILE:-/dev/null}"
if [[ "$*" == *"label create"* ]]; then
  echo "$@" >> "$LOG_FILE"
  exit 0
fi
if [[ "$*" == *"issue edit"* ]]; then
  exit 0
fi
MOCK_GH_COLOR
chmod +x "$MOCK_BIN_DIR/gh"

LOG=$(mktemp)
TMPOUT=$(mktemp)
PATH="$MOCK_BIN_DIR:$PATH" MOCK_LOG_FILE="$LOG" bash --norc --noprofile -c "
  export CFG_REPO='owner/repo'
  export MOCK_LOG_FILE='$LOG'
  source '$LABELS_SH'
  pm_add_label 42 'backlog/new' --create-if-missing
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
LOG_CONTENT=$(cat "$LOG")
rm -f "$TMPOUT" "$LOG"

assert_exit_zero "pm_add_label_default_color_exits_zero" "$EXIT_CODE"
assert_contains "pm_add_label_uses_default_color_5319E7" "5319E7" "$LOG_CONTENT"

echo ""

# --- Cleanup ---
rm -rf "$MOCK_BIN_DIR"

# --- Summary ---
echo "========================================"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
