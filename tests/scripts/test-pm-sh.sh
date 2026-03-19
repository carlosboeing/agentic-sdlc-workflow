#!/usr/bin/env bash
# test-pm-sh.sh — Validates pm.sh dual-source adapter loader behavior.
# Runs locally using mock adapter directories (no live GitHub API calls).
#
# Tests the always-local + optional-external loader pattern:
#   1. Local adapter is always sourced
#   2. Local functions are renamed to _local_pm_*
#   3. External adapter optionally sourced (functions as _external_pm_*)
#   4. pm_* wrappers alias to _local_pm_* (or dual-write wrappers in E02-S02)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PM_SH="$REPO_ROOT/scripts/lib/pm.sh"
ADAPTERS_DIR="$REPO_ROOT/scripts/lib/adapters/pm"

PASS=0
FAIL=0

assert_eq() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"
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
  local test_name="$1"
  local needle="$2"
  local haystack="$3"
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
  local test_name="$1"
  local needle="$2"
  local haystack="$3"
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
  local test_name="$1"
  local exit_code="$2"
  if [ "$exit_code" -eq 0 ]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (expected exit 0, got $exit_code)"
    FAIL=$((FAIL + 1))
  fi
}

assert_exit_nonzero() {
  local test_name="$1"
  local exit_code="$2"
  if [ "$exit_code" -ne 0 ]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (expected non-zero exit, got 0)"
    FAIL=$((FAIL + 1))
  fi
}

echo "========================================"
echo "Testing scripts/lib/pm.sh"
echo "========================================"
echo ""

# --- Test Group 1: File properties ---
echo "Test Group 1: File properties"

if [ -f "$PM_SH" ]; then
  echo "  PASS: pm.sh exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm.sh not found at $PM_SH"
  FAIL=$((FAIL + 1))
fi

if [ -x "$PM_SH" ]; then
  echo "  PASS: pm.sh is executable"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm.sh is not executable"
  FAIL=$((FAIL + 1))
fi

# Verify adapter directories exist
if [ -d "$ADAPTERS_DIR/github" ]; then
  echo "  PASS: adapters/pm/github/ directory exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: adapters/pm/github/ directory not found at $ADAPTERS_DIR/github"
  FAIL=$((FAIL + 1))
fi

if [ -d "$ADAPTERS_DIR/local" ]; then
  echo "  PASS: adapters/pm/local/ directory exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: adapters/pm/local/ directory not found at $ADAPTERS_DIR/local"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test Group 2: _PM_TEST_ADAPTER_DIR override (backward compat) ---
echo "Test Group 2: _PM_TEST_ADAPTER_DIR override (backward compat)"

MOCK_DIR=$(mktemp -d)
MOCK_DIR="${MOCK_DIR}/mock"
mkdir -p "$MOCK_DIR"

cat > "$MOCK_DIR/test_module.sh" <<'MOCK_MODULE'
pm_mock_hello() {
  echo "hello from mock adapter"
}
MOCK_MODULE

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"$MOCK_DIR\"
  source \"$PM_SH\"
  pm_mock_hello
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
MOCK_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "Test_override_sourcing_succeeds" "$EXIT_CODE"
assert_eq "Test_override_function_callable" "hello from mock adapter" "$MOCK_OUTPUT"

echo ""

# --- Test Group 3: Error on missing test adapter directory ---
echo "Test Group 3: Error on missing test adapter directory"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"/nonexistent/adapter/path\"
  source \"$PM_SH\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
ERROR_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_nonzero "Error_exit_when_adapter_dir_missing" "$EXIT_CODE"

if echo "$ERROR_OUTPUT" | grep -qi "error\|not found\|does not exist"; then
  echo "  PASS: Error_message_mentions_missing_adapter"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Error_message_mentions_missing_adapter (got: $ERROR_OUTPUT)"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test Group 4: Error on empty test adapter directory ---
echo "Test Group 4: Error on empty test adapter directory"

EMPTY_DIR=$(mktemp -d)
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"$EMPTY_DIR\"
  source \"$PM_SH\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
ERROR_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"
rmdir "$EMPTY_DIR"

assert_exit_nonzero "Error_exit_when_adapter_dir_empty" "$EXIT_CODE"

if echo "$ERROR_OUTPUT" | grep -qi "error\|no.*sh\|empty\|no modules"; then
  echo "  PASS: Error_message_mentions_empty_adapter"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Error_message_mentions_empty_adapter (got: $ERROR_OUTPUT)"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test Group 5: Idempotent sourcing ---
echo "Test Group 5: Idempotent sourcing (source twice, no errors)"

MOCK_DIR2=$(mktemp -d)
MOCK_DIR2="${MOCK_DIR2}/mock2"
mkdir -p "$MOCK_DIR2"
cat > "$MOCK_DIR2/idempotent_module.sh" <<'IDEMPOTENT'
pm_idempotent_test() {
  echo "idempotent"
}
IDEMPOTENT

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"$MOCK_DIR2\"
  source \"$PM_SH\"
  source \"$PM_SH\"
  pm_idempotent_test
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
IDEMPOTENT_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "Sourcing_pm_sh_twice_no_error" "$EXIT_CODE"
assert_eq "Function_callable_after_double_source" "idempotent" "$IDEMPOTENT_OUTPUT"

echo ""

# --- Test Group 6: Real adapter directory structure ---
echo "Test Group 6: Real adapter directory structure"

if [ -d "$ADAPTERS_DIR/github" ]; then
  echo "  PASS: adapters/pm/github/ exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: adapters/pm/github/ not found"
  FAIL=$((FAIL + 1))
fi

if grep -q "config.sh" "$PM_SH" 2>/dev/null; then
  echo "  PASS: pm.sh references config.sh"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm.sh does not reference config.sh"
  FAIL=$((FAIL + 1))
fi

if grep -q "CFG_PM_ADAPTER" "$PM_SH" 2>/dev/null; then
  echo "  PASS: pm.sh references CFG_PM_ADAPTER"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm.sh does not reference CFG_PM_ADAPTER"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test Group 7: Local functions always available (no external adapter) ---
echo "Test Group 7: Local functions always available (no external adapter)"

# Create a mock config that has no pm.adapter (null / local-only mode)
MOCK_CONFIG_DIR=$(mktemp -d)
MOCK_CONFIG_FILE="$MOCK_CONFIG_DIR/config.json"
cat > "$MOCK_CONFIG_FILE" <<'CONFIG'
{
  "workflowDir": ".workflow",
  "pm": {}
}
CONFIG

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_FILE\"
  source \"$PM_SH\"
  # Verify pm_* functions exist (from local adapter)
  declare -f pm_create_item > /dev/null && echo 'pm_create_item:exists'
  declare -f pm_set_status > /dev/null && echo 'pm_set_status:exists'
  declare -f pm_add_comment > /dev/null && echo 'pm_add_comment:exists'
  declare -f pm_get_item > /dev/null && echo 'pm_get_item:exists'
  declare -f pm_start_work > /dev/null && echo 'pm_start_work:exists'
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
FUNCS_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "Local_functions_loaded_without_error" "$EXIT_CODE"
assert_contains "pm_create_item_exists" "pm_create_item:exists" "$FUNCS_OUTPUT"
assert_contains "pm_set_status_exists" "pm_set_status:exists" "$FUNCS_OUTPUT"
assert_contains "pm_add_comment_exists" "pm_add_comment:exists" "$FUNCS_OUTPUT"
assert_contains "pm_get_item_exists" "pm_get_item:exists" "$FUNCS_OUTPUT"
assert_contains "pm_start_work_exists" "pm_start_work:exists" "$FUNCS_OUTPUT"

echo ""

# --- Test Group 8: _local_pm_* functions exist after sourcing ---
echo "Test Group 8: _local_pm_* function copies exist after sourcing"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_FILE\"
  source \"$PM_SH\"
  # Verify _local_pm_* copies exist
  declare -f _local_pm_create_item > /dev/null && echo '_local_pm_create_item:exists'
  declare -f _local_pm_set_status > /dev/null && echo '_local_pm_set_status:exists'
  declare -f _local_pm_add_comment > /dev/null && echo '_local_pm_add_comment:exists'
  declare -f _local_pm_get_item > /dev/null && echo '_local_pm_get_item:exists'
  declare -f _local_pm_start_work > /dev/null && echo '_local_pm_start_work:exists'
  declare -f _local_pm_link_child > /dev/null && echo '_local_pm_link_child:exists'
  declare -f _local_pm_add_label > /dev/null && echo '_local_pm_add_label:exists'
  declare -f _local_pm_close_item > /dev/null && echo '_local_pm_close_item:exists'
  declare -f _local_pm_reconcile > /dev/null && echo '_local_pm_reconcile:exists'
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
LOCAL_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "Local_pm_copies_created_without_error" "$EXIT_CODE"
assert_contains "_local_pm_create_item_exists" "_local_pm_create_item:exists" "$LOCAL_OUTPUT"
assert_contains "_local_pm_set_status_exists" "_local_pm_set_status:exists" "$LOCAL_OUTPUT"
assert_contains "_local_pm_add_comment_exists" "_local_pm_add_comment:exists" "$LOCAL_OUTPUT"
assert_contains "_local_pm_get_item_exists" "_local_pm_get_item:exists" "$LOCAL_OUTPUT"
assert_contains "_local_pm_start_work_exists" "_local_pm_start_work:exists" "$LOCAL_OUTPUT"
assert_contains "_local_pm_link_child_exists" "_local_pm_link_child:exists" "$LOCAL_OUTPUT"
assert_contains "_local_pm_add_label_exists" "_local_pm_add_label:exists" "$LOCAL_OUTPUT"
assert_contains "_local_pm_close_item_exists" "_local_pm_close_item:exists" "$LOCAL_OUTPUT"
assert_contains "_local_pm_reconcile_exists" "_local_pm_reconcile:exists" "$LOCAL_OUTPUT"

echo ""

# --- Test Group 9: pm_* aliases to _local_pm_* in local-only mode ---
echo "Test Group 9: pm_* aliases to _local_pm_* in local-only mode"

TMPOUT=$(mktemp)
MOCK_WORKFLOW_DIR=$(mktemp -d)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_FILE\"
  export _LOCAL_WORKFLOW_DIR=\"$MOCK_WORKFLOW_DIR\"
  source \"$PM_SH\"
  # Create item via pm_create_item, verify _local_pm_create_item produces same behavior
  id1=\$(pm_create_item story 'Test Item 1')
  id2=\$(_local_pm_create_item story 'Test Item 2')
  echo \"id1=\$id1\"
  echo \"id2=\$id2\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
ALIAS_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"
rm -rf "$MOCK_WORKFLOW_DIR"

assert_exit_zero "Alias_functions_work" "$EXIT_CODE"
assert_contains "pm_create_item_returns_id" "id1=1" "$ALIAS_OUTPUT"
assert_contains "_local_pm_create_item_returns_id" "id2=2" "$ALIAS_OUTPUT"

echo ""

# --- Test Group 10: Exported variables (PM_ADAPTER, PM_ADAPTER_DIR, PM_EXTERNAL) ---
echo "Test Group 10: Exported variables"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_FILE\"
  source \"$PM_SH\"
  echo \"PM_ADAPTER=\$PM_ADAPTER\"
  echo \"PM_EXTERNAL=\${PM_EXTERNAL:-}\"
  echo \"PM_ADAPTER_DIR=\$PM_ADAPTER_DIR\"
  echo \"REPO_ROOT=\$REPO_ROOT\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
VARS_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "Variables_exported_successfully" "$EXIT_CODE"
assert_contains "PM_ADAPTER_is_local" "PM_ADAPTER=local" "$VARS_OUTPUT"
assert_contains "PM_EXTERNAL_is_empty" "PM_EXTERNAL=" "$VARS_OUTPUT"
assert_contains "PM_ADAPTER_DIR_set" "PM_ADAPTER_DIR=" "$VARS_OUTPUT"
assert_contains "REPO_ROOT_set" "REPO_ROOT=" "$VARS_OUTPUT"

echo ""

# --- Test Group 11: External adapter functions loaded as _external_pm_* ---
echo "Test Group 11: External adapter functions via mock external adapter"

# Create a mock external adapter directory with prefix injection
MOCK_EXT_DIR=$(mktemp -d)
MOCK_EXT_DIR="${MOCK_EXT_DIR}/mockext"
mkdir -p "$MOCK_EXT_DIR"

cat > "$MOCK_EXT_DIR/mock_ext.sh" <<'MOCK_EXT'
_PM_FN_PREFIX="${_PM_LOADING_EXTERNAL:+_external_}"

eval "${_PM_FN_PREFIX}pm_set_status() {
  echo \"external_set_status called: \$*\"
}"

eval "${_PM_FN_PREFIX}pm_add_comment() {
  echo \"external_add_comment called: \$*\"
}"
MOCK_EXT

# Create a config pointing to our mock external adapter
MOCK_CONFIG_EXT="$MOCK_CONFIG_DIR/config_ext.json"
cat > "$MOCK_CONFIG_EXT" <<EOF
{
  "workflowDir": ".workflow",
  "pm": {
    "adapter": "mockext"
  }
}
EOF

# Symlink mock external adapter into the adapters directory temporarily
MOCK_EXT_LINK="$ADAPTERS_DIR/mockext"
ln -sfn "$MOCK_EXT_DIR" "$MOCK_EXT_LINK"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_EXT\"
  source \"$PM_SH\"
  # External functions should exist
  declare -f _external_pm_set_status > /dev/null && echo '_external_pm_set_status:exists'
  declare -f _external_pm_add_comment > /dev/null && echo '_external_pm_add_comment:exists'
  # Local functions should also exist
  declare -f _local_pm_set_status > /dev/null && echo '_local_pm_set_status:exists'
  declare -f _local_pm_add_comment > /dev/null && echo '_local_pm_add_comment:exists'
  # pm_* wrappers should exist
  declare -f pm_set_status > /dev/null && echo 'pm_set_status:exists'
  declare -f pm_add_comment > /dev/null && echo 'pm_add_comment:exists'
  # PM_EXTERNAL should be set
  echo \"PM_EXTERNAL=\$PM_EXTERNAL\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
EXT_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "External_adapter_loaded_successfully" "$EXIT_CODE"
assert_contains "External_pm_set_status_exists" "_external_pm_set_status:exists" "$EXT_OUTPUT"
assert_contains "External_pm_add_comment_exists" "_external_pm_add_comment:exists" "$EXT_OUTPUT"
assert_contains "Local_pm_set_status_still_exists" "_local_pm_set_status:exists" "$EXT_OUTPUT"
assert_contains "Local_pm_add_comment_still_exists" "_local_pm_add_comment:exists" "$EXT_OUTPUT"
assert_contains "pm_set_status_wrapper_exists" "pm_set_status:exists" "$EXT_OUTPUT"
assert_contains "pm_add_comment_wrapper_exists" "pm_add_comment:exists" "$EXT_OUTPUT"
assert_contains "PM_EXTERNAL_set_to_mockext" "PM_EXTERNAL=mockext" "$EXT_OUTPUT"

# Cleanup symlink
rm -f "$MOCK_EXT_LINK"

echo ""

# --- Test Group 12: Deprecation note for pm.adapter = "local" ---
echo "Test Group 12: Deprecation note when pm.adapter is 'local'"

MOCK_CONFIG_LOCAL="$MOCK_CONFIG_DIR/config_local.json"
cat > "$MOCK_CONFIG_LOCAL" <<'CONFIG_LOCAL'
{
  "workflowDir": ".workflow",
  "pm": {
    "adapter": "local"
  }
}
CONFIG_LOCAL

TMPOUT=$(mktemp)
TMPERR=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_LOCAL\"
  source \"$PM_SH\"
  echo \"PM_EXTERNAL=\${PM_EXTERNAL:-}\"
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
STDOUT_OUTPUT=$(cat "$TMPOUT")
STDERR_OUTPUT=$(cat "$TMPERR")
rm -f "$TMPOUT" "$TMPERR"

assert_exit_zero "Deprecation_local_loads_without_error" "$EXIT_CODE"
assert_contains "PM_EXTERNAL_empty_for_local" "PM_EXTERNAL=" "$STDOUT_OUTPUT"

# Check for deprecation note on stderr
if echo "$STDERR_OUTPUT" | grep -qi "deprecat\|local.*always"; then
  echo "  PASS: Deprecation_note_printed_to_stderr"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Deprecation_note_printed_to_stderr (stderr: $STDERR_OUTPUT)"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test Group 13: Graceful fallback when external adapter directory missing ---
echo "Test Group 13: Graceful fallback for missing external adapter"

MOCK_CONFIG_MISSING="$MOCK_CONFIG_DIR/config_missing.json"
cat > "$MOCK_CONFIG_MISSING" <<'CONFIG_MISSING'
{
  "workflowDir": ".workflow",
  "pm": {
    "adapter": "nonexistent_adapter"
  }
}
CONFIG_MISSING

TMPOUT=$(mktemp)
TMPERR=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_MISSING\"
  source \"$PM_SH\"
  # Should still have local functions (graceful fallback)
  declare -f pm_create_item > /dev/null && echo 'pm_create_item:exists'
  declare -f _local_pm_create_item > /dev/null && echo '_local_pm_create_item:exists'
  echo \"PM_EXTERNAL=\${PM_EXTERNAL:-}\"
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
FALLBACK_OUTPUT=$(cat "$TMPOUT")
FALLBACK_STDERR=$(cat "$TMPERR")
rm -f "$TMPOUT" "$TMPERR"

assert_exit_zero "Missing_external_does_not_error" "$EXIT_CODE"
assert_contains "Local_functions_available_after_fallback" "pm_create_item:exists" "$FALLBACK_OUTPUT"
assert_contains "Local_copies_available_after_fallback" "_local_pm_create_item:exists" "$FALLBACK_OUTPUT"
assert_contains "PM_EXTERNAL_empty_after_fallback" "PM_EXTERNAL=" "$FALLBACK_OUTPUT"

# Warning should be on stderr
if echo "$FALLBACK_STDERR" | grep -qi "warning\|not found"; then
  echo "  PASS: Warning_printed_for_missing_external"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Warning_printed_for_missing_external (stderr: $FALLBACK_STDERR)"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test Group 14: Idempotency guard tracks local + external state ---
echo "Test Group 14: Idempotency guard with dual-source loader"

MOCK_DIR3=$(mktemp -d)
MOCK_DIR3="${MOCK_DIR3}/mock3"
mkdir -p "$MOCK_DIR3"
cat > "$MOCK_DIR3/test.sh" <<'TEST_MOD'
pm_idem_test() {
  echo "idem_test"
}
TEST_MOD

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"$MOCK_DIR3\"
  source \"$PM_SH\"
  source \"$PM_SH\"
  pm_idem_test
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
IDEM_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "Idempotent_dual_source_no_error" "$EXIT_CODE"
assert_eq "Idempotent_function_still_works" "idem_test" "$IDEM_OUTPUT"

echo ""

# --- Test Group 15: Null/absent pm.adapter is local-only mode ---
echo "Test Group 15: Null/absent pm.adapter is local-only mode"

MOCK_CONFIG_NULL="$MOCK_CONFIG_DIR/config_null.json"
cat > "$MOCK_CONFIG_NULL" <<'CONFIG_NULL'
{
  "workflowDir": ".workflow",
  "pm": {
    "adapter": null
  }
}
CONFIG_NULL

TMPOUT=$(mktemp)
TMPERR=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_NULL\"
  source \"$PM_SH\"
  declare -f pm_create_item > /dev/null && echo 'pm_create_item:exists'
  echo \"PM_EXTERNAL=\${PM_EXTERNAL:-}\"
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
NULL_OUTPUT=$(cat "$TMPOUT")
NULL_STDERR=$(cat "$TMPERR")
rm -f "$TMPOUT" "$TMPERR"

assert_exit_zero "Null_adapter_loads_without_error" "$EXIT_CODE"
assert_contains "Functions_available_with_null_adapter" "pm_create_item:exists" "$NULL_OUTPUT"
assert_contains "PM_EXTERNAL_empty_for_null" "PM_EXTERNAL=" "$NULL_OUTPUT"

# No deprecation note for null (only for explicit "local")
assert_not_contains "No_deprecation_for_null" "deprecat" "$NULL_STDERR"

echo ""

# --- Test Group 16: _local_pm_* functions are callable and produce correct output ---
echo "Test Group 16: _local_pm_* functions produce correct output"

MOCK_WORKFLOW_DIR2=$(mktemp -d)
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_FILE\"
  export _LOCAL_WORKFLOW_DIR=\"$MOCK_WORKFLOW_DIR2\"
  source \"$PM_SH\"
  # Use _local_pm_create_item to create an item, verify it works
  item_id=\$(_local_pm_create_item story 'Local Test Item')
  echo \"item_id=\$item_id\"
  # Verify the item was created on disk
  if [ -f \"$MOCK_WORKFLOW_DIR2/items/\${item_id}.md\" ]; then
    echo 'item_file:created'
  fi
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
LOCAL_CALL_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"
rm -rf "$MOCK_WORKFLOW_DIR2"

assert_exit_zero "Local_pm_functions_callable" "$EXIT_CODE"
assert_contains "Local_pm_create_item_returns_id" "item_id=1" "$LOCAL_CALL_OUTPUT"
assert_contains "Local_pm_creates_file" "item_file:created" "$LOCAL_CALL_OUTPUT"

echo ""

# --- Test Group 17: Config with no pm section at all loads local-only ---
echo "Test Group 17: Config with no pm section at all loads local-only"

MOCK_CONFIG_NO_PM="$MOCK_CONFIG_DIR/config_no_pm.json"
cat > "$MOCK_CONFIG_NO_PM" <<'CONFIG_NO_PM'
{
  "workflowDir": ".workflow"
}
CONFIG_NO_PM

TMPOUT=$(mktemp)
TMPERR=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_NO_PM\"
  source \"$PM_SH\"
  declare -f pm_create_item > /dev/null && echo 'pm_create_item:exists'
  declare -f _local_pm_create_item > /dev/null && echo '_local_pm_create_item:exists'
  echo \"PM_EXTERNAL=\${PM_EXTERNAL:-}\"
  echo \"PM_ADAPTER=\${PM_ADAPTER:-}\"
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
NO_PM_OUTPUT=$(cat "$TMPOUT")
NO_PM_STDERR=$(cat "$TMPERR")
rm -f "$TMPOUT" "$TMPERR"

assert_exit_zero "No_pm_section_loads_without_error" "$EXIT_CODE"
assert_contains "pm_create_item_exists_no_pm_section" "pm_create_item:exists" "$NO_PM_OUTPUT"
assert_contains "_local_pm_create_item_exists_no_pm_section" "_local_pm_create_item:exists" "$NO_PM_OUTPUT"
assert_contains "PM_EXTERNAL_empty_no_pm_section" "PM_EXTERNAL=" "$NO_PM_OUTPUT"
assert_contains "PM_ADAPTER_local_no_pm_section" "PM_ADAPTER=local" "$NO_PM_OUTPUT"
# No deprecation note (no pm.adapter = "local" set)
assert_not_contains "No_deprecation_for_missing_pm_section" "deprecat" "$NO_PM_STDERR"

echo ""

# --- Test Group 18: workflowDir top-level config respected by local adapter ---
echo "Test Group 18: workflowDir top-level config respected by local adapter"

MOCK_CUSTOM_WFDIR=$(mktemp -d)
MOCK_CONFIG_CUSTOM_WF="$MOCK_CONFIG_DIR/config_custom_wf.json"
cat > "$MOCK_CONFIG_CUSTOM_WF" <<EOF
{
  "workflowDir": "$MOCK_CUSTOM_WFDIR",
  "pm": {}
}
EOF

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_CUSTOM_WF\"
  source \"$PM_SH\"
  item_id=\$(pm_create_item story 'WorkflowDir Test')
  echo \"item_id=\$item_id\"
  # Verify item was written in the custom workflowDir
  if [ -f \"$MOCK_CUSTOM_WFDIR/items/\${item_id}.md\" ]; then
    echo 'item_in_custom_dir:yes'
  else
    echo 'item_in_custom_dir:no'
  fi
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
CUSTOM_WF_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"
rm -rf "$MOCK_CUSTOM_WFDIR"

assert_exit_zero "Custom_workflowDir_loads_without_error" "$EXIT_CODE"
assert_contains "Custom_workflowDir_item_stored_in_custom_dir" "item_in_custom_dir:yes" "$CUSTOM_WF_OUTPUT"

echo ""

# --- Test Group 19: pm.local.workflowDir backward compat via pm.sh ---
echo "Test Group 19: pm.local.workflowDir backward compat (old config location via pm.sh)"

MOCK_LEGACY_WFDIR=$(mktemp -d)
MOCK_CONFIG_LEGACY_WF="$MOCK_CONFIG_DIR/config_legacy_wf.json"
cat > "$MOCK_CONFIG_LEGACY_WF" <<EOF
{
  "pm": {
    "local": {
      "workflowDir": "$MOCK_LEGACY_WFDIR"
    }
  }
}
EOF

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE=\"$MOCK_CONFIG_LEGACY_WF\"
  source \"$PM_SH\"
  item_id=\$(pm_create_item story 'Legacy WorkflowDir Test')
  echo \"item_id=\$item_id\"
  # Verify item was written in the legacy workflowDir
  if [ -f \"$MOCK_LEGACY_WFDIR/items/\${item_id}.md\" ]; then
    echo 'item_in_legacy_dir:yes'
  else
    echo 'item_in_legacy_dir:no'
  fi
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
LEGACY_WF_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"
rm -rf "$MOCK_LEGACY_WFDIR"

assert_exit_zero "Legacy_workflowDir_loads_without_error" "$EXIT_CODE"
assert_contains "Legacy_workflowDir_item_stored_in_legacy_dir" "item_in_legacy_dir:yes" "$LEGACY_WF_OUTPUT"

echo ""

# --- Cleanup ---
rm -rf "$MOCK_DIR" "$MOCK_DIR2" "$MOCK_DIR3" "$MOCK_CONFIG_DIR" "$MOCK_EXT_DIR" 2>/dev/null || true

# --- Summary ---
echo "========================================"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
