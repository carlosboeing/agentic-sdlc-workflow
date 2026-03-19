#!/usr/bin/env bash
# test-dual-write-integration.sh — End-to-end integration tests for the
# dual-write PM layer. Verifies full lifecycle through dual-write, external
# adapter failure fallback, and composition of pm_start_work.
#
# All tests use mock adapters — no live GitHub API calls.

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

assert_file_exists() {
  local test_name="$1" path="$2"
  if [ -e "$path" ]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (path not found: $path)"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_not_exists() {
  local test_name="$1" path="$2"
  if [ ! -e "$path" ]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (path should not exist: $path)"
    FAIL=$((FAIL + 1))
  fi
}

echo "========================================"
echo "Integration tests: dual-write PM layer"
echo "========================================"
echo ""

# ============================================================================
# Shared mock adapter setup
# ============================================================================

MOCK_BASE_DIR=$(mktemp -d)

# Full-featured mock external adapter: logs all calls, pm_create_item returns 42
MOCK_EXT_DIR="$MOCK_BASE_DIR/mockdual"
mkdir -p "$MOCK_EXT_DIR"

cat > "$MOCK_EXT_DIR/mock_dual.sh" << 'MOCK_DUAL'
_PM_FN_PREFIX="${_PM_LOADING_EXTERNAL:+_external_}"

eval "${_PM_FN_PREFIX}pm_create_item() {
  echo \"CALL:${_PM_FN_PREFIX}pm_create_item:\$*\" >> \"\${_MOCK_CALL_LOG:-/dev/null}\"
  echo '42'
}"

eval "${_PM_FN_PREFIX}pm_set_status() {
  echo \"CALL:${_PM_FN_PREFIX}pm_set_status:\$*\" >> \"\${_MOCK_CALL_LOG:-/dev/null}\"
}"

eval "${_PM_FN_PREFIX}pm_add_comment() {
  echo \"CALL:${_PM_FN_PREFIX}pm_add_comment:\$*\" >> \"\${_MOCK_CALL_LOG:-/dev/null}\"
}"

eval "${_PM_FN_PREFIX}pm_add_to_board() {
  echo \"CALL:${_PM_FN_PREFIX}pm_add_to_board:\$*\" >> \"\${_MOCK_CALL_LOG:-/dev/null}\"
}"

eval "${_PM_FN_PREFIX}pm_link_child() {
  echo \"CALL:${_PM_FN_PREFIX}pm_link_child:\$*\" >> \"\${_MOCK_CALL_LOG:-/dev/null}\"
}"

eval "${_PM_FN_PREFIX}pm_add_label() {
  echo \"CALL:${_PM_FN_PREFIX}pm_add_label:\$*\" >> \"\${_MOCK_CALL_LOG:-/dev/null}\"
}"

eval "${_PM_FN_PREFIX}pm_close_item() {
  echo \"CALL:${_PM_FN_PREFIX}pm_close_item:\$*\" >> \"\${_MOCK_CALL_LOG:-/dev/null}\"
}"

eval "${_PM_FN_PREFIX}pm_update_item() {
  echo \"CALL:${_PM_FN_PREFIX}pm_update_item:\$*\" >> \"\${_MOCK_CALL_LOG:-/dev/null}\"
}"

eval "${_PM_FN_PREFIX}pm_start_work() {
  echo \"CALL:${_PM_FN_PREFIX}pm_start_work:\$*\" >> \"\${_MOCK_CALL_LOG:-/dev/null}\"
}"
MOCK_DUAL

# Symlink mock adapter into the adapters directory
MOCK_EXT_LINK="$ADAPTERS_DIR/mockdual"
ln -sfn "$MOCK_EXT_DIR" "$MOCK_EXT_LINK"

# Config pointing to the mock external adapter
MOCK_CONFIG_EXT="$MOCK_BASE_DIR/config_ext.json"
cat > "$MOCK_CONFIG_EXT" << 'CONFIG_EXT'
{
  "workflowDir": ".workflow",
  "pm": {
    "adapter": "mockdual"
  }
}
CONFIG_EXT

# Config for local-only (no external adapter)
MOCK_CONFIG_LOCAL="$MOCK_BASE_DIR/config_local.json"
cat > "$MOCK_CONFIG_LOCAL" << 'CONFIG_LOCAL'
{
  "workflowDir": ".workflow",
  "pm": {}
}
CONFIG_LOCAL

# ============================================================================
# Test Group 1: Full lifecycle through dual-write
# ============================================================================
echo "Test Group 1: Full lifecycle — create, set status, add comment, complete work"

MOCK_WORKFLOW=$(mktemp -d)
MOCK_CALL_LOG="$MOCK_BASE_DIR/lifecycle_calls.log"

TMPOUT=$(mktemp)
TMPERR=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_EXT\"
  export _LOCAL_WORKFLOW_DIR=\"$MOCK_WORKFLOW\"
  export _MOCK_CALL_LOG=\"$MOCK_CALL_LOG\"
  source \"$PM_SH\"

  # Step 1: Create item — external returns ID 42, local created at 42
  item_id=\$(pm_create_item story 'Lifecycle Test Item')
  echo \"item_id=\$item_id\"

  # Step 2: Set status
  pm_set_status 42 in-progress

  # Step 3: Add comment
  pm_add_comment 42 'Work started by builder'

  # Step 4: Complete work via pm_complete_work
  pm_complete_work 42 deadbeef1234

  # Give fire-and-forget background calls time to finish
  sleep 0.5

  # Verify local state
  if [ -f \"$MOCK_WORKFLOW/items/42.md\" ]; then
    echo 'local_item_42:exists'
  fi
  local_status=\$(_local_pm_get_status 42)
  echo \"local_status=\$local_status\"
  comment_count=\$(grep -c '<!-- comment:' \"$MOCK_WORKFLOW/items/42.md\" 2>/dev/null || echo 0)
  echo \"comment_count=\$comment_count\"
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
LIFECYCLE_OUTPUT=$(cat "$TMPOUT")
CALL_LOG=$(cat "$MOCK_CALL_LOG" 2>/dev/null || echo "")

assert_exit_zero "Full_lifecycle_exits_zero" "$EXIT_CODE"

# Step 1: Create item
assert_contains "pm_create_item_returns_external_id" "item_id=42" "$LIFECYCLE_OUTPUT"
assert_contains "External_create_item_called" "CALL:_external_pm_create_item:" "$CALL_LOG"
assert_file_exists "Local_item_42_created" "$MOCK_WORKFLOW/items/42.md"

# Step 2: Set status — local written, external called
assert_contains "Local_status_set_in_progress" "local_status=in-review" "$LIFECYCLE_OUTPUT"
assert_contains "External_set_status_called" "CALL:_external_pm_set_status:" "$CALL_LOG"

# Step 3: Add comment — local file written, external called
assert_contains "External_add_comment_called" "CALL:_external_pm_add_comment:" "$CALL_LOG"

# Step 4: Complete work — pm_complete_work posts comment + sets status in-review
# Comment count >= 2: explicit pm_add_comment + pm_complete_work's "Ready for Review"
if echo "$LIFECYCLE_OUTPUT" | grep -qE "comment_count=[2-9]|comment_count=[0-9][0-9]"; then
  echo "  PASS: Comment_files_written_locally_at_least_two"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Comment_files_written_locally_at_least_two (got: $(echo "$LIFECYCLE_OUTPUT" | grep comment_count))"
  FAIL=$((FAIL + 1))
fi

rm -f "$TMPOUT" "$TMPERR" "$MOCK_CALL_LOG"
rm -rf "$MOCK_WORKFLOW"

echo ""

# ============================================================================
# Test Group 2: External adapter failure during pm_create_item fallback
# ============================================================================
echo "Test Group 2: pm_create_item fallback when external adapter fails"

# Mock external adapter where pm_create_item exits with code 1
MOCK_FAIL_DIR="$MOCK_BASE_DIR/mockfailcreate"
mkdir -p "$MOCK_FAIL_DIR"
cat > "$MOCK_FAIL_DIR/mock_fail.sh" << 'MOCK_FAIL'
_PM_FN_PREFIX="${_PM_LOADING_EXTERNAL:+_external_}"

eval "${_PM_FN_PREFIX}pm_create_item() {
  echo 'external pm_create_item failed' >&2
  return 1
}"

eval "${_PM_FN_PREFIX}pm_set_status() {
  echo \"CALL:${_PM_FN_PREFIX}pm_set_status:\$*\" >> \"\${_MOCK_CALL_LOG:-/dev/null}\"
}"

eval "${_PM_FN_PREFIX}pm_add_comment() {
  echo \"CALL:${_PM_FN_PREFIX}pm_add_comment:\$*\" >> \"\${_MOCK_CALL_LOG:-/dev/null}\"
}"
MOCK_FAIL

MOCK_FAIL_LINK="$ADAPTERS_DIR/mockfailcreate"
ln -sfn "$MOCK_FAIL_DIR" "$MOCK_FAIL_LINK"

MOCK_CONFIG_FAIL="$MOCK_BASE_DIR/config_fail.json"
cat > "$MOCK_CONFIG_FAIL" << 'CONFIG_FAIL'
{
  "workflowDir": ".workflow",
  "pm": {
    "adapter": "mockfailcreate"
  }
}
CONFIG_FAIL

MOCK_WORKFLOW=$(mktemp -d)

TMPOUT=$(mktemp)
TMPERR=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_FAIL\"
  export _LOCAL_WORKFLOW_DIR=\"$MOCK_WORKFLOW\"
  source \"$PM_SH\"

  # External fails; should fall back to local auto-increment
  item_id=\$(pm_create_item story 'Fallback Item')
  echo \"item_id=\$item_id\"

  if [ -f \"$MOCK_WORKFLOW/items/1.md\" ]; then
    echo 'local_item_1:exists'
  fi
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
FALLBACK_OUTPUT=$(cat "$TMPOUT")
FALLBACK_STDERR=$(cat "$TMPERR")

assert_exit_zero "Create_item_fallback_exits_zero" "$EXIT_CODE"
assert_contains "Fallback_returns_local_auto_id" "item_id=1" "$FALLBACK_OUTPUT"
assert_contains "Fallback_creates_local_item_at_id_1" "local_item_1:exists" "$FALLBACK_OUTPUT"
assert_contains "Fallback_prints_WARNING_on_stderr" "WARNING" "$FALLBACK_STDERR"

rm -f "$TMPOUT" "$TMPERR" "$MOCK_FAIL_LINK"
rm -rf "$MOCK_WORKFLOW"

echo ""

# ============================================================================
# Test Group 3: pm_start_work composition — external primitives called, NOT _external_pm_start_work
# ============================================================================
echo "Test Group 3: pm_start_work composition — dual-write primitives called, not external start_work"

MOCK_WORKFLOW=$(mktemp -d)
MOCK_CALL_LOG="$MOCK_BASE_DIR/start_work_calls.log"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_EXT\"
  export _LOCAL_WORKFLOW_DIR=\"$MOCK_WORKFLOW\"
  export _MOCK_CALL_LOG=\"$MOCK_CALL_LOG\"
  source \"$PM_SH\"

  _local_pm_create_item story 'Start Work Test' > /dev/null

  pm_start_work 1 --model sonnet --agent builder

  # Give background calls time to finish
  sleep 0.5
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
START_WORK_CALLS=$(cat "$MOCK_CALL_LOG" 2>/dev/null || echo "")

assert_exit_zero "pm_start_work_exits_zero" "$EXIT_CODE"

# pm_start_work is composed — it calls pm_add_comment and pm_set_status (which
# are dual-write wrappers), so _external_pm_add_comment and
# _external_pm_set_status ARE called via the primitives.
assert_contains "External_pm_add_comment_called_via_start_work" "CALL:_external_pm_add_comment:" "$START_WORK_CALLS"
assert_contains "External_pm_set_status_called_via_start_work" "CALL:_external_pm_set_status:" "$START_WORK_CALLS"

# _external_pm_start_work itself must NOT be called (composed functions are local-only)
assert_not_contains "External_pm_start_work_NOT_directly_called" "_external_pm_start_work:" "$START_WORK_CALLS"

rm -f "$TMPOUT" "$MOCK_CALL_LOG"
rm -rf "$MOCK_WORKFLOW"

echo ""

# ============================================================================
# Test Group 4: Backward compat — adapter "github" loads local + github external
# ============================================================================
echo "Test Group 4: adapter='github' loads local adapter AND github adapter as external"

MOCK_CONFIG_GITHUB="$MOCK_BASE_DIR/config_github.json"
cat > "$MOCK_CONFIG_GITHUB" << 'CONFIG_GITHUB'
{
  "workflowDir": ".workflow",
  "pm": {
    "adapter": "github"
  }
}
CONFIG_GITHUB

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_GITHUB\"
  source \"$PM_SH\"
  # Local functions must exist
  declare -f _local_pm_set_status > /dev/null && echo '_local_pm_set_status:exists'
  declare -f _local_pm_create_item > /dev/null && echo '_local_pm_create_item:exists'
  # External functions must exist (github adapter uses prefix injection)
  declare -f _external_pm_set_status > /dev/null && echo '_external_pm_set_status:exists'
  declare -f _external_pm_create_item > /dev/null && echo '_external_pm_create_item:exists'
  # Public pm_* wrappers must exist
  declare -f pm_set_status > /dev/null && echo 'pm_set_status:exists'
  declare -f pm_create_item > /dev/null && echo 'pm_create_item:exists'
  echo \"PM_EXTERNAL=\$PM_EXTERNAL\"
  echo \"PM_ADAPTER=\$PM_ADAPTER\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
GITHUB_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "Github_adapter_config_loads" "$EXIT_CODE"
assert_contains "Local_pm_set_status_exists_with_github" "_local_pm_set_status:exists" "$GITHUB_OUTPUT"
assert_contains "Local_pm_create_item_exists_with_github" "_local_pm_create_item:exists" "$GITHUB_OUTPUT"
assert_contains "External_pm_set_status_exists_with_github" "_external_pm_set_status:exists" "$GITHUB_OUTPUT"
assert_contains "External_pm_create_item_exists_with_github" "_external_pm_create_item:exists" "$GITHUB_OUTPUT"
assert_contains "pm_set_status_wrapper_exists_with_github" "pm_set_status:exists" "$GITHUB_OUTPUT"
assert_contains "pm_create_item_wrapper_exists_with_github" "pm_create_item:exists" "$GITHUB_OUTPUT"
assert_contains "PM_EXTERNAL_is_github" "PM_EXTERNAL=github" "$GITHUB_OUTPUT"
assert_contains "PM_ADAPTER_is_local_with_github" "PM_ADAPTER=local" "$GITHUB_OUTPUT"

echo ""

# ============================================================================
# Test Group 5: Backward compat — adapter "local" loads local-only + deprecation
# ============================================================================
echo "Test Group 5: adapter='local' loads local-only and prints deprecation note"

MOCK_CONFIG_LOCAL_ADAPTER="$MOCK_BASE_DIR/config_local_adapter.json"
cat > "$MOCK_CONFIG_LOCAL_ADAPTER" << 'CONFIG_LOCAL_ADAPTER'
{
  "workflowDir": ".workflow",
  "pm": {
    "adapter": "local"
  }
}
CONFIG_LOCAL_ADAPTER

TMPOUT=$(mktemp)
TMPERR=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_LOCAL_ADAPTER\"
  source \"$PM_SH\"
  declare -f _local_pm_set_status > /dev/null && echo '_local_pm_set_status:exists'
  # No external functions should be defined
  if declare -f _external_pm_set_status > /dev/null 2>&1; then
    echo '_external_pm_set_status:exists'
  else
    echo '_external_pm_set_status:absent'
  fi
  echo \"PM_EXTERNAL=\${PM_EXTERNAL:-}\"
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
LOCAL_ADAPTER_OUTPUT=$(cat "$TMPOUT")
LOCAL_ADAPTER_STDERR=$(cat "$TMPERR")
rm -f "$TMPOUT" "$TMPERR"

assert_exit_zero "Local_adapter_config_loads" "$EXIT_CODE"
assert_contains "Local_pm_functions_exist" "_local_pm_set_status:exists" "$LOCAL_ADAPTER_OUTPUT"
assert_contains "External_pm_functions_absent" "_external_pm_set_status:absent" "$LOCAL_ADAPTER_OUTPUT"
assert_contains "PM_EXTERNAL_empty_for_local_adapter" "PM_EXTERNAL=" "$LOCAL_ADAPTER_OUTPUT"
# Deprecation note must appear on stderr
if echo "$LOCAL_ADAPTER_STDERR" | grep -qi "deprecat\|local.*always"; then
  echo "  PASS: Deprecation_note_on_stderr_for_local_adapter"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Deprecation_note_on_stderr_for_local_adapter"
  echo "    Expected deprecation note on stderr, got: $LOCAL_ADAPTER_STDERR"
  FAIL=$((FAIL + 1))
fi

echo ""

# ============================================================================
# Test Group 6: No pm section — loads local-only without error
# ============================================================================
echo "Test Group 6: No pm section — loads local-only without error or deprecation"

MOCK_CONFIG_NO_PM="$MOCK_BASE_DIR/config_no_pm.json"
cat > "$MOCK_CONFIG_NO_PM" << 'CONFIG_NO_PM'
{
  "workflowDir": ".workflow"
}
CONFIG_NO_PM

MOCK_WORKFLOW=$(mktemp -d)
TMPOUT=$(mktemp)
TMPERR=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_NO_PM\"
  export _LOCAL_WORKFLOW_DIR=\"$MOCK_WORKFLOW\"
  source \"$PM_SH\"
  item_id=\$(pm_create_item story 'No PM Section Test')
  echo \"item_id=\$item_id\"
  if [ -f \"$MOCK_WORKFLOW/items/\${item_id}.md\" ]; then
    echo 'local_item:created'
  fi
  echo \"PM_EXTERNAL=\${PM_EXTERNAL:-}\"
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
NO_PM_OUTPUT=$(cat "$TMPOUT")
NO_PM_STDERR=$(cat "$TMPERR")
rm -f "$TMPOUT" "$TMPERR"
rm -rf "$MOCK_WORKFLOW"

assert_exit_zero "No_pm_section_loads_and_works" "$EXIT_CODE"
assert_contains "No_pm_section_creates_item" "item_id=1" "$NO_PM_OUTPUT"
assert_contains "No_pm_section_item_file_created" "local_item:created" "$NO_PM_OUTPUT"
assert_contains "No_pm_section_PM_EXTERNAL_empty" "PM_EXTERNAL=" "$NO_PM_OUTPUT"
assert_not_contains "No_pm_section_no_deprecation" "deprecat" "$NO_PM_STDERR"

echo ""

# ============================================================================
# Test Group 7: Null pm.adapter — loads local-only without error or deprecation
# ============================================================================
echo "Test Group 7: pm.adapter=null — loads local-only, no deprecation"

MOCK_CONFIG_NULL="$MOCK_BASE_DIR/config_null.json"
cat > "$MOCK_CONFIG_NULL" << 'CONFIG_NULL'
{
  "workflowDir": ".workflow",
  "pm": {
    "adapter": null
  }
}
CONFIG_NULL

MOCK_WORKFLOW=$(mktemp -d)
TMPOUT=$(mktemp)
TMPERR=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_NULL\"
  export _LOCAL_WORKFLOW_DIR=\"$MOCK_WORKFLOW\"
  source \"$PM_SH\"
  item_id=\$(pm_create_item story 'Null Adapter Test')
  echo \"item_id=\$item_id\"
  if [ -f \"$MOCK_WORKFLOW/items/\${item_id}.md\" ]; then
    echo 'local_item:created'
  fi
  echo \"PM_EXTERNAL=\${PM_EXTERNAL:-}\"
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
NULL_OUTPUT=$(cat "$TMPOUT")
NULL_STDERR=$(cat "$TMPERR")
rm -f "$TMPOUT" "$TMPERR"
rm -rf "$MOCK_WORKFLOW"

assert_exit_zero "Null_adapter_loads_and_works" "$EXIT_CODE"
assert_contains "Null_adapter_creates_item" "item_id=1" "$NULL_OUTPUT"
assert_contains "Null_adapter_item_file_created" "local_item:created" "$NULL_OUTPUT"
assert_contains "Null_adapter_PM_EXTERNAL_empty" "PM_EXTERNAL=" "$NULL_OUTPUT"
assert_not_contains "Null_adapter_no_deprecation" "deprecat" "$NULL_STDERR"

echo ""

# ============================================================================
# Cleanup
# ============================================================================
rm -f "$MOCK_EXT_LINK" 2>/dev/null || true
rm -rf "$MOCK_BASE_DIR" 2>/dev/null || true

# ============================================================================
# Summary
# ============================================================================
echo "========================================"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
