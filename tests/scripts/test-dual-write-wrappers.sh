#!/usr/bin/env bash
# test-dual-write-wrappers.sh — Validates dual-write wrapper generation and
# function classification in pm.sh.
#
# Tests the three function categories:
#   1. Dual-write: pm_set_status, pm_add_comment, etc. — call both local and external
#   2. Local-only: pm_get_item, pm_list_items, pm_get_status — local only, no external
#   3. Composed: pm_start_work, pm_complete_work, etc. — local only (composes on dual-write primitives)
#   4. Special: pm_create_item — external sync for ID, local with that ID, fallback
#
# Uses mock adapters (no live API calls).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PM_SH="$REPO_ROOT/scripts/lib/pm.sh"
ADAPTERS_DIR="$REPO_ROOT/scripts/lib/adapters/pm"

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
    echo "    Actual: $haystack"
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
    echo "    Actual: $haystack"
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

# ============================================================================
# Setup: Create mock external adapter with call-tracking
# ============================================================================

MOCK_BASE_DIR=$(mktemp -d)
MOCK_EXT_DIR="$MOCK_BASE_DIR/mockext"
mkdir -p "$MOCK_EXT_DIR"

# Mock external adapter that logs calls to a tracking file
cat > "$MOCK_EXT_DIR/mock_ext.sh" << 'MOCK_EXT'
_PM_FN_PREFIX="${_PM_LOADING_EXTERNAL:+_external_}"

eval "${_PM_FN_PREFIX}pm_set_status() {
  echo \"CALL:${_PM_FN_PREFIX}pm_set_status:\$*\" >> \"\${_MOCK_CALL_LOG}\"
}"

eval "${_PM_FN_PREFIX}pm_add_comment() {
  echo \"CALL:${_PM_FN_PREFIX}pm_add_comment:\$*\" >> \"\${_MOCK_CALL_LOG}\"
}"

eval "${_PM_FN_PREFIX}pm_add_to_board() {
  echo \"CALL:${_PM_FN_PREFIX}pm_add_to_board:\$*\" >> \"\${_MOCK_CALL_LOG}\"
}"

eval "${_PM_FN_PREFIX}pm_batch_set_status() {
  echo \"CALL:${_PM_FN_PREFIX}pm_batch_set_status:\$*\" >> \"\${_MOCK_CALL_LOG}\"
}"

eval "${_PM_FN_PREFIX}pm_link_child() {
  echo \"CALL:${_PM_FN_PREFIX}pm_link_child:\$*\" >> \"\${_MOCK_CALL_LOG}\"
}"

eval "${_PM_FN_PREFIX}pm_add_label() {
  echo \"CALL:${_PM_FN_PREFIX}pm_add_label:\$*\" >> \"\${_MOCK_CALL_LOG}\"
}"

eval "${_PM_FN_PREFIX}pm_done() {
  echo \"CALL:${_PM_FN_PREFIX}pm_done:\$*\" >> \"\${_MOCK_CALL_LOG}\"
}"

eval "${_PM_FN_PREFIX}pm_update_item() {
  echo \"CALL:${_PM_FN_PREFIX}pm_update_item:\$*\" >> \"\${_MOCK_CALL_LOG}\"
}"

eval "${_PM_FN_PREFIX}pm_create_item() {
  echo \"CALL:${_PM_FN_PREFIX}pm_create_item:\$*\" >> \"\${_MOCK_CALL_LOG}\"
  echo \"42\"
}"

eval "${_PM_FN_PREFIX}pm_get_item() {
  echo \"CALL:${_PM_FN_PREFIX}pm_get_item:\$*\" >> \"\${_MOCK_CALL_LOG}\"
}"

eval "${_PM_FN_PREFIX}pm_list_items() {
  echo \"CALL:${_PM_FN_PREFIX}pm_list_items:\$*\" >> \"\${_MOCK_CALL_LOG}\"
}"

eval "${_PM_FN_PREFIX}pm_start_work() {
  echo \"CALL:${_PM_FN_PREFIX}pm_start_work:\$*\" >> \"\${_MOCK_CALL_LOG}\"
}"

eval "${_PM_FN_PREFIX}pm_complete_work() {
  echo \"CALL:${_PM_FN_PREFIX}pm_complete_work:\$*\" >> \"\${_MOCK_CALL_LOG}\"
}"

eval "${_PM_FN_PREFIX}pm_post_telemetry() {
  echo \"CALL:${_PM_FN_PREFIX}pm_post_telemetry:\$*\" >> \"\${_MOCK_CALL_LOG}\"
}"

eval "${_PM_FN_PREFIX}pm_reconcile() {
  echo \"CALL:${_PM_FN_PREFIX}pm_reconcile:\$*\" >> \"\${_MOCK_CALL_LOG}\"
}"
MOCK_EXT

# Create config pointing to mock external adapter
MOCK_CONFIG_FILE="$MOCK_BASE_DIR/config.json"
cat > "$MOCK_CONFIG_FILE" << 'CONFIG'
{
  "workflowDir": ".workflow",
  "pm": {
    "adapter": "mockext"
  }
}
CONFIG

# Config for no-external mode (use "local" which triggers deprecation and
# sets PM_EXTERNAL="" — this is the canonical way to disable external sync)
MOCK_CONFIG_LOCAL="$MOCK_BASE_DIR/config_local.json"
cat > "$MOCK_CONFIG_LOCAL" << 'CONFIG_LOCAL'
{
  "workflowDir": ".workflow",
  "pm": {
    "adapter": "local"
  }
}
CONFIG_LOCAL

# Symlink mock external adapter into adapters dir
MOCK_EXT_LINK="$ADAPTERS_DIR/mockext"
ln -sfn "$MOCK_EXT_DIR" "$MOCK_EXT_LINK"

echo "========================================"
echo "Testing dual-write wrapper generation"
echo "========================================"
echo ""

# ============================================================================
# Test Group 1: Dual-write — pm_set_status calls both local and external
# ============================================================================
echo "Test Group 1: Dual-write — pm_set_status calls both local and external"

MOCK_WORKFLOW=$(mktemp -d)
MOCK_CALL_LOG="$MOCK_BASE_DIR/calls_g1.log"

TMPOUT=$(mktemp)
TMPERR=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_FILE\"
  export _LOCAL_WORKFLOW_DIR=\"$MOCK_WORKFLOW\"
  export _MOCK_CALL_LOG=\"$MOCK_CALL_LOG\"
  source \"$PM_SH\"

  # Create an item first so pm_set_status can find it
  _local_pm_create_item story 'Test Item 1' > /dev/null

  # Call pm_set_status — should dual-write
  pm_set_status 1 in-progress

  # Give background process a moment to finish
  sleep 0.3

  # Check the local status was set
  local_status=\$(_local_pm_get_status 1)
  echo \"local_status=\$local_status\"
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
CALL_LOG_CONTENT=$(cat "$MOCK_CALL_LOG" 2>/dev/null || echo "")

assert_exit_zero "pm_set_status_exits_zero" "$EXIT_CODE"
assert_contains "Local_status_set_to_in_progress" "local_status=in-progress" "$OUTPUT"
assert_contains "External_pm_set_status_called" "CALL:_external_pm_set_status:" "$CALL_LOG_CONTENT"

rm -f "$TMPOUT" "$TMPERR" "$MOCK_CALL_LOG"
rm -rf "$MOCK_WORKFLOW"

echo ""

# ============================================================================
# Test Group 2: Dual-write — pm_add_comment calls both local and external
# ============================================================================
echo "Test Group 2: Dual-write — pm_add_comment calls both local and external"

MOCK_WORKFLOW=$(mktemp -d)
MOCK_CALL_LOG="$MOCK_BASE_DIR/calls_g2.log"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_FILE\"
  export _LOCAL_WORKFLOW_DIR=\"$MOCK_WORKFLOW\"
  export _MOCK_CALL_LOG=\"$MOCK_CALL_LOG\"
  source \"$PM_SH\"

  _local_pm_create_item story 'Test Item' > /dev/null

  pm_add_comment 1 'Hello world'

  sleep 0.3

  # Check local comment was inlined in item file
  if grep -q '<!-- comment:' \"$MOCK_WORKFLOW/items/1.md\" 2>/dev/null; then
    echo 'local_comment:created'
  fi
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
CALL_LOG_CONTENT=$(cat "$MOCK_CALL_LOG" 2>/dev/null || echo "")

assert_exit_zero "pm_add_comment_exits_zero" "$EXIT_CODE"
assert_contains "Local_comment_created" "local_comment:created" "$OUTPUT"
assert_contains "External_pm_add_comment_called" "CALL:_external_pm_add_comment:" "$CALL_LOG_CONTENT"

rm -f "$TMPOUT" "$MOCK_CALL_LOG"
rm -rf "$MOCK_WORKFLOW"

echo ""

# ============================================================================
# Test Group 3: Local-only — pm_get_item does NOT call external
# ============================================================================
echo "Test Group 3: Local-only — pm_get_item does NOT call external"

MOCK_WORKFLOW=$(mktemp -d)
MOCK_CALL_LOG="$MOCK_BASE_DIR/calls_g3.log"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_FILE\"
  export _LOCAL_WORKFLOW_DIR=\"$MOCK_WORKFLOW\"
  export _MOCK_CALL_LOG=\"$MOCK_CALL_LOG\"
  source \"$PM_SH\"

  _local_pm_create_item story 'Get Item Test' > /dev/null

  pm_get_item 1

  sleep 0.3
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
CALL_LOG_CONTENT=$(cat "$MOCK_CALL_LOG" 2>/dev/null || echo "")

assert_exit_zero "pm_get_item_exits_zero" "$EXIT_CODE"
assert_contains "pm_get_item_returns_local_data" "Get Item Test" "$OUTPUT"
assert_not_contains "External_pm_get_item_NOT_called" "_external_pm_get_item" "$CALL_LOG_CONTENT"

rm -f "$TMPOUT" "$MOCK_CALL_LOG"
rm -rf "$MOCK_WORKFLOW"

echo ""

# ============================================================================
# Test Group 4: Local-only — pm_list_items does NOT call external
# ============================================================================
echo "Test Group 4: Local-only — pm_list_items does NOT call external"

MOCK_WORKFLOW=$(mktemp -d)
MOCK_CALL_LOG="$MOCK_BASE_DIR/calls_g4.log"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_FILE\"
  export _LOCAL_WORKFLOW_DIR=\"$MOCK_WORKFLOW\"
  export _MOCK_CALL_LOG=\"$MOCK_CALL_LOG\"
  source \"$PM_SH\"

  _local_pm_create_item story 'List Test' > /dev/null

  pm_list_items

  sleep 0.3
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
CALL_LOG_CONTENT=$(cat "$MOCK_CALL_LOG" 2>/dev/null || echo "")

assert_exit_zero "pm_list_items_exits_zero" "$EXIT_CODE"
assert_contains "pm_list_items_returns_local_data" "List Test" "$OUTPUT"
assert_not_contains "External_pm_list_items_NOT_called" "_external_pm_list_items" "$CALL_LOG_CONTENT"

rm -f "$TMPOUT" "$MOCK_CALL_LOG"
rm -rf "$MOCK_WORKFLOW"

echo ""

# ============================================================================
# Test Group 5: Local-only — pm_get_status does NOT call external
# ============================================================================
echo "Test Group 5: Local-only — pm_get_status does NOT call external"

MOCK_WORKFLOW=$(mktemp -d)
MOCK_CALL_LOG="$MOCK_BASE_DIR/calls_g5.log"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_FILE\"
  export _LOCAL_WORKFLOW_DIR=\"$MOCK_WORKFLOW\"
  export _MOCK_CALL_LOG=\"$MOCK_CALL_LOG\"
  source \"$PM_SH\"

  _local_pm_create_item story 'Status Test' > /dev/null

  result=\$(pm_get_status 1)
  echo \"status=\$result\"

  sleep 0.3
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
CALL_LOG_CONTENT=$(cat "$MOCK_CALL_LOG" 2>/dev/null || echo "")

assert_exit_zero "pm_get_status_exits_zero" "$EXIT_CODE"
assert_contains "pm_get_status_returns_local_status" "status=backlog" "$OUTPUT"
assert_not_contains "External_pm_get_status_NOT_called" "_external_pm_get_status" "$CALL_LOG_CONTENT"

rm -f "$TMPOUT" "$MOCK_CALL_LOG"
rm -rf "$MOCK_WORKFLOW"

echo ""

# ============================================================================
# Test Group 6: Composed — pm_start_work calls dual-write primitives, NOT external_pm_start_work
# ============================================================================
echo "Test Group 6: Composed — pm_start_work uses dual-write primitives"

MOCK_WORKFLOW=$(mktemp -d)
MOCK_CALL_LOG="$MOCK_BASE_DIR/calls_g6.log"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_FILE\"
  export _LOCAL_WORKFLOW_DIR=\"$MOCK_WORKFLOW\"
  export _MOCK_CALL_LOG=\"$MOCK_CALL_LOG\"
  source \"$PM_SH\"

  _local_pm_create_item story 'Start Work Test' > /dev/null

  pm_start_work 1 --model sonnet --agent builder

  sleep 0.3
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
CALL_LOG_CONTENT=$(cat "$MOCK_CALL_LOG" 2>/dev/null || echo "")

assert_exit_zero "pm_start_work_exits_zero" "$EXIT_CODE"
# External dual-write primitives SHOULD be called (via pm_add_comment, pm_set_status wrappers)
assert_contains "External_pm_add_comment_called_via_composition" "CALL:_external_pm_add_comment:" "$CALL_LOG_CONTENT"
assert_contains "External_pm_set_status_called_via_composition" "CALL:_external_pm_set_status:" "$CALL_LOG_CONTENT"
# External pm_start_work itself should NOT be called (composed functions are local-only)
assert_not_contains "External_pm_start_work_NOT_called" "_external_pm_start_work" "$CALL_LOG_CONTENT"

rm -f "$TMPOUT" "$MOCK_CALL_LOG"
rm -rf "$MOCK_WORKFLOW"

echo ""

# ============================================================================
# Test Group 7: Composed — pm_complete_work uses dual-write primitives
# ============================================================================
echo "Test Group 7: Composed — pm_complete_work uses dual-write primitives"

MOCK_WORKFLOW=$(mktemp -d)
MOCK_CALL_LOG="$MOCK_BASE_DIR/calls_g7.log"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_FILE\"
  export _LOCAL_WORKFLOW_DIR=\"$MOCK_WORKFLOW\"
  export _MOCK_CALL_LOG=\"$MOCK_CALL_LOG\"
  source \"$PM_SH\"

  _local_pm_create_item story 'Complete Work Test' > /dev/null

  pm_complete_work 1 abc123

  sleep 0.3
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
CALL_LOG_CONTENT=$(cat "$MOCK_CALL_LOG" 2>/dev/null || echo "")

assert_exit_zero "pm_complete_work_exits_zero" "$EXIT_CODE"
assert_contains "External_pm_add_comment_called_via_complete" "CALL:_external_pm_add_comment:" "$CALL_LOG_CONTENT"
assert_contains "External_pm_set_status_called_via_complete" "CALL:_external_pm_set_status:" "$CALL_LOG_CONTENT"
assert_not_contains "External_pm_complete_work_NOT_called" "_external_pm_complete_work" "$CALL_LOG_CONTENT"

rm -f "$TMPOUT" "$MOCK_CALL_LOG"
rm -rf "$MOCK_WORKFLOW"

echo ""

# ============================================================================
# Test Group 8: pm_create_item special wrapper — returns external ID
# ============================================================================
echo "Test Group 8: pm_create_item special wrapper — returns external ID"

MOCK_WORKFLOW=$(mktemp -d)
MOCK_CALL_LOG="$MOCK_BASE_DIR/calls_g8.log"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_FILE\"
  export _LOCAL_WORKFLOW_DIR=\"$MOCK_WORKFLOW\"
  export _MOCK_CALL_LOG=\"$MOCK_CALL_LOG\"
  source \"$PM_SH\"

  # pm_create_item should call external synchronously and return external ID (42)
  item_id=\$(pm_create_item story 'External ID Test')
  echo \"item_id=\$item_id\"

  # The local item should exist with the external ID
  if [ -f \"$MOCK_WORKFLOW/items/42.md\" ]; then
    echo 'local_item_at_42:exists'
  fi

  # Verify the _next_id counter was bumped
  next_id=\$(cat \"$MOCK_WORKFLOW/_next_id\")
  echo \"next_id=\$next_id\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
CALL_LOG_CONTENT=$(cat "$MOCK_CALL_LOG" 2>/dev/null || echo "")

assert_exit_zero "pm_create_item_exits_zero" "$EXIT_CODE"
assert_contains "pm_create_item_returns_external_id" "item_id=42" "$OUTPUT"
assert_contains "Local_item_created_with_external_id" "local_item_at_42:exists" "$OUTPUT"
assert_contains "Next_id_bumped_past_external_id" "next_id=43" "$OUTPUT"
assert_contains "External_pm_create_item_called" "CALL:_external_pm_create_item:" "$CALL_LOG_CONTENT"

rm -f "$TMPOUT" "$MOCK_CALL_LOG"
rm -rf "$MOCK_WORKFLOW"

echo ""

# ============================================================================
# Test Group 9: pm_create_item fallback — external fails, local takes over
# ============================================================================
echo "Test Group 9: pm_create_item fallback — external fails"

# Create a failing external adapter
MOCK_FAIL_DIR="$MOCK_BASE_DIR/mockfail"
mkdir -p "$MOCK_FAIL_DIR"
cat > "$MOCK_FAIL_DIR/mock_fail.sh" << 'MOCK_FAIL'
_PM_FN_PREFIX="${_PM_LOADING_EXTERNAL:+_external_}"

eval "${_PM_FN_PREFIX}pm_create_item() {
  echo 'external create failed' >&2
  return 1
}"

eval "${_PM_FN_PREFIX}pm_set_status() {
  echo \"CALL:${_PM_FN_PREFIX}pm_set_status:\$*\" >> \"\${_MOCK_CALL_LOG}\"
}"

eval "${_PM_FN_PREFIX}pm_add_comment() {
  echo \"CALL:${_PM_FN_PREFIX}pm_add_comment:\$*\" >> \"\${_MOCK_CALL_LOG}\"
}"
MOCK_FAIL

MOCK_FAIL_LINK="$ADAPTERS_DIR/mockfail"
ln -sfn "$MOCK_FAIL_DIR" "$MOCK_FAIL_LINK"

MOCK_CONFIG_FAIL="$MOCK_BASE_DIR/config_fail.json"
cat > "$MOCK_CONFIG_FAIL" << 'CONFIG_FAIL'
{
  "workflowDir": ".workflow",
  "pm": {
    "adapter": "mockfail"
  }
}
CONFIG_FAIL

MOCK_WORKFLOW=$(mktemp -d)
MOCK_CALL_LOG="$MOCK_BASE_DIR/calls_g9.log"

TMPOUT=$(mktemp)
TMPERR=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_FAIL\"
  export _LOCAL_WORKFLOW_DIR=\"$MOCK_WORKFLOW\"
  export _MOCK_CALL_LOG=\"$MOCK_CALL_LOG\"
  source \"$PM_SH\"

  # External create_item fails, should fall back to local
  item_id=\$(pm_create_item story 'Fallback Test')
  echo \"item_id=\$item_id\"

  # The local item should exist with auto-incremented ID (1)
  if [ -f \"$MOCK_WORKFLOW/items/1.md\" ]; then
    echo 'local_item_at_1:exists'
  fi
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
STDERR=$(cat "$TMPERR")

assert_exit_zero "pm_create_item_fallback_exits_zero" "$EXIT_CODE"
assert_contains "pm_create_item_fallback_returns_local_id" "item_id=1" "$OUTPUT"
assert_contains "Local_item_created_at_auto_id" "local_item_at_1:exists" "$OUTPUT"
# Warning should be emitted on stderr
assert_contains "Fallback_warning_on_stderr" "WARNING" "$STDERR"

rm -f "$TMPOUT" "$TMPERR" "$MOCK_CALL_LOG" "$MOCK_FAIL_LINK"
rm -rf "$MOCK_WORKFLOW"

echo ""

# ============================================================================
# Test Group 10: No-external mode — pm_* goes directly to _local_pm_*
# ============================================================================
echo "Test Group 10: No-external mode — pm_* goes directly to _local_pm_*"

MOCK_WORKFLOW=$(mktemp -d)
MOCK_CALL_LOG="$MOCK_BASE_DIR/calls_g10.log"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_LOCAL\"
  export _LOCAL_WORKFLOW_DIR=\"$MOCK_WORKFLOW\"
  export _MOCK_CALL_LOG=\"$MOCK_CALL_LOG\"
  source \"$PM_SH\"

  # Verify no _external_pm_* functions exist
  if declare -f _external_pm_set_status > /dev/null 2>&1; then
    echo 'external_exists:yes'
  else
    echo 'external_exists:no'
  fi

  # Create item and set status — should use local only
  item_id=\$(pm_create_item story 'No External Test')
  echo \"item_id=\$item_id\"

  pm_set_status \$item_id in-progress

  sleep 0.1
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
CALL_LOG_CONTENT=$(cat "$MOCK_CALL_LOG" 2>/dev/null || echo "")

assert_exit_zero "No_external_mode_exits_zero" "$EXIT_CODE"
assert_contains "No_external_functions_defined" "external_exists:no" "$OUTPUT"
assert_contains "Local_create_item_auto_id" "item_id=1" "$OUTPUT"
# No external calls should have been logged
assert_eq "No_external_calls_logged" "" "$CALL_LOG_CONTENT"

rm -f "$TMPOUT" "$MOCK_CALL_LOG"
rm -rf "$MOCK_WORKFLOW"

echo ""

# ============================================================================
# Test Group 11: Wrapper handles missing _external_pm_* gracefully
# ============================================================================
echo "Test Group 11: Wrapper handles missing external function"

# Create a partial external adapter (only pm_set_status, no pm_add_to_board)
MOCK_PARTIAL_DIR="$MOCK_BASE_DIR/mockpartial"
mkdir -p "$MOCK_PARTIAL_DIR"
cat > "$MOCK_PARTIAL_DIR/mock_partial.sh" << 'MOCK_PARTIAL'
_PM_FN_PREFIX="${_PM_LOADING_EXTERNAL:+_external_}"

eval "${_PM_FN_PREFIX}pm_set_status() {
  echo \"CALL:${_PM_FN_PREFIX}pm_set_status:\$*\" >> \"\${_MOCK_CALL_LOG}\"
}"

eval "${_PM_FN_PREFIX}pm_create_item() {
  echo \"CALL:${_PM_FN_PREFIX}pm_create_item:\$*\" >> \"\${_MOCK_CALL_LOG}\"
  echo \"99\"
}"
MOCK_PARTIAL

MOCK_PARTIAL_LINK="$ADAPTERS_DIR/mockpartial"
ln -sfn "$MOCK_PARTIAL_DIR" "$MOCK_PARTIAL_LINK"

MOCK_CONFIG_PARTIAL="$MOCK_BASE_DIR/config_partial.json"
cat > "$MOCK_CONFIG_PARTIAL" << 'CONFIG_PARTIAL'
{
  "workflowDir": ".workflow",
  "pm": {
    "adapter": "mockpartial"
  }
}
CONFIG_PARTIAL

MOCK_WORKFLOW=$(mktemp -d)
MOCK_CALL_LOG="$MOCK_BASE_DIR/calls_g11.log"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_PARTIAL\"
  export _LOCAL_WORKFLOW_DIR=\"$MOCK_WORKFLOW\"
  export _MOCK_CALL_LOG=\"$MOCK_CALL_LOG\"
  source \"$PM_SH\"

  _local_pm_create_item story 'Partial Test' > /dev/null

  # pm_add_to_board should work (local call), but no external call (not defined)
  pm_add_to_board 1
  echo \"add_to_board_rc=\$?\"

  sleep 0.3
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
CALL_LOG_CONTENT=$(cat "$MOCK_CALL_LOG" 2>/dev/null || echo "")

assert_exit_zero "Partial_external_exits_zero" "$EXIT_CODE"
assert_contains "add_to_board_returns_zero" "add_to_board_rc=0" "$OUTPUT"
# External pm_add_to_board should NOT appear in call log (not defined)
assert_not_contains "External_pm_add_to_board_skipped" "_external_pm_add_to_board" "$CALL_LOG_CONTENT"

rm -f "$TMPOUT" "$MOCK_CALL_LOG" "$MOCK_PARTIAL_LINK"
rm -rf "$MOCK_WORKFLOW"

echo ""

# ============================================================================
# Test Group 12: Fire-and-forget logs to external-sync.log
# ============================================================================
echo "Test Group 12: Fire-and-forget logs to external-sync.log"

# Create an external adapter that writes to stderr (which goes to log)
MOCK_LOG_DIR="$MOCK_BASE_DIR/mocklog"
mkdir -p "$MOCK_LOG_DIR"
cat > "$MOCK_LOG_DIR/mock_log.sh" << 'MOCK_LOG'
_PM_FN_PREFIX="${_PM_LOADING_EXTERNAL:+_external_}"

eval "${_PM_FN_PREFIX}pm_set_status() {
  echo 'external log entry for pm_set_status' >&2
}"

eval "${_PM_FN_PREFIX}pm_create_item() {
  echo '77'
}"
MOCK_LOG

MOCK_LOG_LINK="$ADAPTERS_DIR/mocklog"
ln -sfn "$MOCK_LOG_DIR" "$MOCK_LOG_LINK"

MOCK_CONFIG_LOG="$MOCK_BASE_DIR/config_log.json"
cat > "$MOCK_CONFIG_LOG" << 'CONFIG_LOG'
{
  "workflowDir": ".workflow",
  "pm": {
    "adapter": "mocklog"
  }
}
CONFIG_LOG

MOCK_WORKFLOW=$(mktemp -d)

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_LOG\"
  export _LOCAL_WORKFLOW_DIR=\"$MOCK_WORKFLOW\"
  source \"$PM_SH\"

  _local_pm_create_item story 'Log Test' > /dev/null

  pm_set_status 1 in-progress

  sleep 0.5

  # pm.sh sets REPO_ROOT to the actual repo root; the sync log is at
  # \$REPO_ROOT/.agentic-workflow/logs/external-sync.log
  SYNC_LOG=\"\$REPO_ROOT/.agentic-workflow/logs/external-sync.log\"
  if [ -f \"\$SYNC_LOG\" ]; then
    echo 'sync_log:exists'
    cat \"\$SYNC_LOG\"
  else
    echo 'sync_log:missing'
  fi
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")

assert_exit_zero "Fire_and_forget_log_exits_zero" "$EXIT_CODE"
assert_contains "Sync_log_exists" "sync_log:exists" "$OUTPUT"
assert_contains "Sync_log_has_content" "external log entry" "$OUTPUT"

# Clean up the sync log created in the real repo
rm -f "$REPO_ROOT/.agentic-workflow/logs/external-sync.log" 2>/dev/null || true
rm -f "$TMPOUT" "$MOCK_LOG_LINK"
rm -rf "$MOCK_WORKFLOW"

echo ""

# ============================================================================
# Test Group 13: Wrapper return value is from local adapter
# ============================================================================
echo "Test Group 13: Wrapper return value is from local adapter"

MOCK_WORKFLOW=$(mktemp -d)
MOCK_CALL_LOG="$MOCK_BASE_DIR/calls_g13.log"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_FILE\"
  export _LOCAL_WORKFLOW_DIR=\"$MOCK_WORKFLOW\"
  export _MOCK_CALL_LOG=\"$MOCK_CALL_LOG\"
  source \"$PM_SH\"

  _local_pm_create_item story 'Return Value Test' > /dev/null

  # pm_set_status on valid item should return local's exit code (0)
  pm_set_status 1 in-progress
  echo \"set_status_rc=\$?\"

  # pm_set_status on nonexistent item should return local's error code
  pm_set_status 999 in-progress 2>/dev/null
  echo \"set_status_missing_rc=\$?\"

  sleep 0.3
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")

assert_contains "Return_code_success_from_local" "set_status_rc=0" "$OUTPUT"
assert_contains "Return_code_error_from_local" "set_status_missing_rc=1" "$OUTPUT"

rm -f "$TMPOUT" "$MOCK_CALL_LOG"
rm -rf "$MOCK_WORKFLOW"

echo ""

# ============================================================================
# Test Group 14: Function classification arrays are defined
# ============================================================================
echo "Test Group 14: Function classification arrays are defined"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_FILE\"
  export _MOCK_CALL_LOG=\"/dev/null\"
  source \"$PM_SH\"

  # Check _PM_LOCAL_ONLY_FUNCTIONS
  echo \"local_only_count=\${#_PM_LOCAL_ONLY_FUNCTIONS[@]}\"
  for fn in \"\${_PM_LOCAL_ONLY_FUNCTIONS[@]}\"; do
    echo \"local_only:\$fn\"
  done

  # Check _PM_COMPOSED_FUNCTIONS
  echo \"composed_count=\${#_PM_COMPOSED_FUNCTIONS[@]}\"
  for fn in \"\${_PM_COMPOSED_FUNCTIONS[@]}\"; do
    echo \"composed:\$fn\"
  done
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")

assert_exit_zero "Classification_arrays_defined" "$EXIT_CODE"
assert_contains "Local_only_has_pm_get_item" "local_only:pm_get_item" "$OUTPUT"
assert_contains "Local_only_has_pm_list_items" "local_only:pm_list_items" "$OUTPUT"
assert_contains "Local_only_has_pm_get_status" "local_only:pm_get_status" "$OUTPUT"
assert_contains "Composed_has_pm_start_work" "composed:pm_start_work" "$OUTPUT"
assert_contains "Composed_has_pm_complete_work" "composed:pm_complete_work" "$OUTPUT"
assert_contains "Composed_has_pm_post_telemetry" "composed:pm_post_telemetry" "$OUTPUT"
assert_contains "Composed_has_pm_reconcile" "composed:pm_reconcile" "$OUTPUT"

rm -f "$TMPOUT"

echo ""

# ============================================================================
# Test Group 15: _pm_external_fire_and_forget helper exists
# ============================================================================
echo "Test Group 15: _pm_external_fire_and_forget helper exists"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_FILE\"
  export _MOCK_CALL_LOG=\"/dev/null\"
  source \"$PM_SH\"

  if declare -f _pm_external_fire_and_forget > /dev/null 2>&1; then
    echo 'fire_and_forget:exists'
  else
    echo 'fire_and_forget:missing'
  fi
" > "$TMPOUT" 2>&1
OUTPUT=$(cat "$TMPOUT")

assert_contains "Fire_and_forget_helper_exists" "fire_and_forget:exists" "$OUTPUT"

rm -f "$TMPOUT"

echo ""

# ============================================================================
# Test Group 16: _pm_generate_wrapper helper exists
# ============================================================================
echo "Test Group 16: _pm_generate_wrapper helper exists"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_FILE\"
  export _MOCK_CALL_LOG=\"/dev/null\"
  source \"$PM_SH\"

  if declare -f _pm_generate_wrapper > /dev/null 2>&1; then
    echo 'generate_wrapper:exists'
  else
    echo 'generate_wrapper:missing'
  fi
" > "$TMPOUT" 2>&1
OUTPUT=$(cat "$TMPOUT")

assert_contains "Generate_wrapper_helper_exists" "generate_wrapper:exists" "$OUTPUT"

rm -f "$TMPOUT"

echo ""

# ============================================================================
# Cleanup
# ============================================================================
rm -f "$MOCK_EXT_LINK" 2>/dev/null || true
rm -rf "$MOCK_BASE_DIR" 2>/dev/null || true

# --- Summary ---
echo "========================================"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
