#!/usr/bin/env bash
# test-server-adapter.sh — Tests for the server PM shell adapter.
#
# Tests:
#   1. Directory structure and file existence
#   2. _workflow_server_url reads from WORKFLOW_SERVER_URL env var
#   3. _workflow_server_url reads from .agentic-workflow/server.port file
#   4. _workflow_server_url prefers env var over port file
#   5. _workflow_server_url returns error when no source available
#   6. _server_pm_curl_post constructs correct curl commands
#   7. _server_pm_curl_get constructs correct curl commands
#   8. Server adapter functions exist after sourcing
#   9. pm.sh routes to server adapter when pm.adapter is "server"
#  10. pm.sh falls back to local adapter when server is not running
#  11. Config variables for server section

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ADAPTERS_DIR="$REPO_ROOT/scripts/lib/adapters/pm"
SERVER_ADAPTER_DIR="$ADAPTERS_DIR/server"
PM_SH="$REPO_ROOT/scripts/lib/pm.sh"
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
echo "Testing Server PM Shell Adapter"
echo "========================================"
echo ""

# =========================================================================
# Test Group 1: Directory structure
# =========================================================================
echo "Test Group 1: Server adapter directory structure"

if [ -d "$SERVER_ADAPTER_DIR" ]; then
  echo "  PASS: adapters/pm/server/ directory exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: adapters/pm/server/ directory not found"
  FAIL=$((FAIL + 1))
fi

for f in _common.sh items.sh board.sh comments.sh hierarchy.sh labels.sh lifecycle.sh; do
  if [ -f "$SERVER_ADAPTER_DIR/$f" ]; then
    echo "  PASS: server/$f exists"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: server/$f not found"
    FAIL=$((FAIL + 1))
  fi
done

echo ""

# =========================================================================
# Test Group 2: _workflow_server_url reads from WORKFLOW_SERVER_URL env var
# =========================================================================
echo "Test Group 2: _workflow_server_url reads from env var"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  source '$SERVER_ADAPTER_DIR/_common.sh'
  export WORKFLOW_SERVER_URL='http://127.0.0.1:9999'
  url=\$(_workflow_server_url 2>/dev/null)
  echo \"url=\$url\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
URL_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "Env_var_server_url_succeeds" "$EXIT_CODE"
assert_eq "Env_var_server_url_value" "url=http://127.0.0.1:9999" "$URL_OUTPUT"

echo ""

# =========================================================================
# Test Group 3: _workflow_server_url reads from port file
# =========================================================================
echo "Test Group 3: _workflow_server_url reads from port file"

MOCK_WF_DIR=$(mktemp -d)
echo "8765" > "$MOCK_WF_DIR/server.port"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _SERVER_WORKFLOW_DIR='$MOCK_WF_DIR'
  source '$SERVER_ADAPTER_DIR/_common.sh'
  # Unset env var so it falls through to file
  unset WORKFLOW_SERVER_URL
  url=\$(_workflow_server_url 2>/dev/null)
  echo \"url=\$url\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
URL_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT" "$MOCK_WF_DIR/server.port"
rmdir "$MOCK_WF_DIR"

assert_exit_zero "Port_file_server_url_succeeds" "$EXIT_CODE"
assert_eq "Port_file_server_url_value" "url=http://127.0.0.1:8765" "$URL_OUTPUT"

echo ""

# =========================================================================
# Test Group 4: _workflow_server_url prefers env var over port file
# =========================================================================
echo "Test Group 4: Env var takes precedence over port file"

MOCK_WF_DIR=$(mktemp -d)
echo "1111" > "$MOCK_WF_DIR/server.port"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _SERVER_WORKFLOW_DIR='$MOCK_WF_DIR'
  export WORKFLOW_SERVER_URL='http://127.0.0.1:2222'
  source '$SERVER_ADAPTER_DIR/_common.sh'
  url=\$(_workflow_server_url 2>/dev/null)
  echo \"url=\$url\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
URL_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT" "$MOCK_WF_DIR/server.port"
rmdir "$MOCK_WF_DIR"

assert_exit_zero "Env_var_precedence_succeeds" "$EXIT_CODE"
assert_eq "Env_var_precedence_value" "url=http://127.0.0.1:2222" "$URL_OUTPUT"

echo ""

# =========================================================================
# Test Group 5: _workflow_server_url fails when no source available
# =========================================================================
echo "Test Group 5: _workflow_server_url fails when no source"

MOCK_WF_DIR=$(mktemp -d)

TMPOUT=$(mktemp)
TMPERR=$(mktemp)
bash --norc --noprofile -c "
  export _SERVER_WORKFLOW_DIR='$MOCK_WF_DIR'
  unset WORKFLOW_SERVER_URL 2>/dev/null || true
  source '$SERVER_ADAPTER_DIR/_common.sh'
  _workflow_server_url
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
STDERR_OUTPUT=$(cat "$TMPERR")
rm -f "$TMPOUT" "$TMPERR"
rmdir "$MOCK_WF_DIR"

assert_exit_nonzero "No_source_returns_nonzero" "$EXIT_CODE"
assert_contains "Error_message_on_no_source" "server" "$STDERR_OUTPUT"

echo ""

# =========================================================================
# Test Group 6: Server adapter functions exist after sourcing _common.sh
# =========================================================================
echo "Test Group 6: Server adapter helper functions exist"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export WORKFLOW_SERVER_URL='http://127.0.0.1:9999'
  source '$SERVER_ADAPTER_DIR/_common.sh'
  declare -f _workflow_server_url > /dev/null && echo '_workflow_server_url:exists'
  declare -f _server_health_check > /dev/null && echo '_server_health_check:exists'
  declare -f _server_pm_curl_post > /dev/null && echo '_server_pm_curl_post:exists'
  declare -f _server_pm_curl_get > /dev/null && echo '_server_pm_curl_get:exists'
  declare -f _server_pm_curl_patch > /dev/null && echo '_server_pm_curl_patch:exists'
  declare -f _server_pm_curl_delete > /dev/null && echo '_server_pm_curl_delete:exists'
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
HELPERS_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "Common_helpers_source_ok" "$EXIT_CODE"
assert_contains "workflow_server_url_exists" "_workflow_server_url:exists" "$HELPERS_OUTPUT"
assert_contains "server_health_check_exists" "_server_health_check:exists" "$HELPERS_OUTPUT"
assert_contains "curl_post_exists" "_server_pm_curl_post:exists" "$HELPERS_OUTPUT"
assert_contains "curl_get_exists" "_server_pm_curl_get:exists" "$HELPERS_OUTPUT"
assert_contains "curl_patch_exists" "_server_pm_curl_patch:exists" "$HELPERS_OUTPUT"
assert_contains "curl_delete_exists" "_server_pm_curl_delete:exists" "$HELPERS_OUTPUT"

echo ""

# =========================================================================
# Test Group 7: All pm_* functions exist after sourcing all adapter files
# =========================================================================
echo "Test Group 7: All pm_* functions exist in server adapter"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export WORKFLOW_SERVER_URL='http://127.0.0.1:9999'
  for f in '$SERVER_ADAPTER_DIR'/*.sh; do
    source \"\$f\"
  done
  declare -f pm_create_item > /dev/null && echo 'pm_create_item:exists'
  declare -f pm_get_item > /dev/null && echo 'pm_get_item:exists'
  declare -f pm_list_items > /dev/null && echo 'pm_list_items:exists'
  declare -f pm_update_item > /dev/null && echo 'pm_update_item:exists'
  declare -f pm_close_item > /dev/null && echo 'pm_close_item:exists'
  declare -f pm_set_status > /dev/null && echo 'pm_set_status:exists'
  declare -f pm_get_status > /dev/null && echo 'pm_get_status:exists'
  declare -f pm_batch_set_status > /dev/null && echo 'pm_batch_set_status:exists'
  declare -f pm_add_to_board > /dev/null && echo 'pm_add_to_board:exists'
  declare -f pm_add_comment > /dev/null && echo 'pm_add_comment:exists'
  declare -f pm_link_child > /dev/null && echo 'pm_link_child:exists'
  declare -f pm_add_label > /dev/null && echo 'pm_add_label:exists'
  declare -f pm_start_work > /dev/null && echo 'pm_start_work:exists'
  declare -f pm_complete_work > /dev/null && echo 'pm_complete_work:exists'
  declare -f pm_post_telemetry > /dev/null && echo 'pm_post_telemetry:exists'
  declare -f pm_append_body > /dev/null && echo 'pm_append_body:exists'
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
FN_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "Server_adapter_sources_ok" "$EXIT_CODE"
assert_contains "pm_create_item_exists" "pm_create_item:exists" "$FN_OUTPUT"
assert_contains "pm_get_item_exists" "pm_get_item:exists" "$FN_OUTPUT"
assert_contains "pm_list_items_exists" "pm_list_items:exists" "$FN_OUTPUT"
assert_contains "pm_update_item_exists" "pm_update_item:exists" "$FN_OUTPUT"
assert_contains "pm_close_item_exists" "pm_close_item:exists" "$FN_OUTPUT"
assert_contains "pm_set_status_exists" "pm_set_status:exists" "$FN_OUTPUT"
assert_contains "pm_get_status_exists" "pm_get_status:exists" "$FN_OUTPUT"
assert_contains "pm_batch_set_status_exists" "pm_batch_set_status:exists" "$FN_OUTPUT"
assert_contains "pm_add_to_board_exists" "pm_add_to_board:exists" "$FN_OUTPUT"
assert_contains "pm_add_comment_exists" "pm_add_comment:exists" "$FN_OUTPUT"
assert_contains "pm_link_child_exists" "pm_link_child:exists" "$FN_OUTPUT"
assert_contains "pm_add_label_exists" "pm_add_label:exists" "$FN_OUTPUT"
assert_contains "pm_start_work_exists" "pm_start_work:exists" "$FN_OUTPUT"
assert_contains "pm_complete_work_exists" "pm_complete_work:exists" "$FN_OUTPUT"
assert_contains "pm_post_telemetry_exists" "pm_post_telemetry:exists" "$FN_OUTPUT"
assert_contains "pm_append_body_exists" "pm_append_body:exists" "$FN_OUTPUT"

echo ""

# =========================================================================
# Test Group 8: Prefix injection (_PM_LOADING_EXTERNAL)
# =========================================================================
echo "Test Group 8: Prefix injection works for server adapter"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export WORKFLOW_SERVER_URL='http://127.0.0.1:9999'
  export _PM_LOADING_EXTERNAL=1
  for f in '$SERVER_ADAPTER_DIR'/*.sh; do
    source \"\$f\"
  done
  declare -f _external_pm_create_item > /dev/null && echo '_external_pm_create_item:exists'
  declare -f _external_pm_set_status > /dev/null && echo '_external_pm_set_status:exists'
  declare -f _external_pm_add_comment > /dev/null && echo '_external_pm_add_comment:exists'
  declare -f _external_pm_link_child > /dev/null && echo '_external_pm_link_child:exists'
  # pm_* should NOT exist when loading as external
  declare -f pm_create_item > /dev/null && echo 'pm_create_item:exists' || echo 'pm_create_item:absent'
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
PREFIX_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "Prefix_injection_sources_ok" "$EXIT_CODE"
assert_contains "External_pm_create_item_exists" "_external_pm_create_item:exists" "$PREFIX_OUTPUT"
assert_contains "External_pm_set_status_exists" "_external_pm_set_status:exists" "$PREFIX_OUTPUT"
assert_contains "External_pm_add_comment_exists" "_external_pm_add_comment:exists" "$PREFIX_OUTPUT"
assert_contains "External_pm_link_child_exists" "_external_pm_link_child:exists" "$PREFIX_OUTPUT"
assert_contains "pm_create_item_absent_with_prefix" "pm_create_item:absent" "$PREFIX_OUTPUT"

echo ""

# =========================================================================
# Test Group 9: pm.sh routes to server adapter when pm.adapter = "server"
# =========================================================================
echo "Test Group 9: pm.sh routes to server adapter"

MOCK_CONFIG_DIR=$(mktemp -d)
MOCK_CONFIG_FILE="$MOCK_CONFIG_DIR/config.json"
cat > "$MOCK_CONFIG_FILE" <<'CONFIG'
{
  "workflowDir": ".workflow",
  "pm": {
    "adapter": "server"
  }
}
CONFIG

TMPOUT=$(mktemp)
TMPERR=$(mktemp)
# Server is NOT running so pm.sh should fall back to local
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE='$MOCK_CONFIG_FILE'
  # No WORKFLOW_SERVER_URL, no server.port file, so health check will fail
  source '$PM_SH'
  # After fallback, pm_* functions should still exist (from local adapter)
  declare -f pm_create_item > /dev/null && echo 'pm_create_item:exists'
  declare -f pm_set_status > /dev/null && echo 'pm_set_status:exists'
  declare -f pm_add_comment > /dev/null && echo 'pm_add_comment:exists'
  echo \"PM_ADAPTER=\$PM_ADAPTER\"
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
ROUTE_OUTPUT=$(cat "$TMPOUT")
ROUTE_STDERR=$(cat "$TMPERR")
rm -f "$TMPOUT" "$TMPERR"

assert_exit_zero "Server_adapter_route_loads_ok" "$EXIT_CODE"
assert_contains "pm_create_item_available_after_fallback" "pm_create_item:exists" "$ROUTE_OUTPUT"
assert_contains "pm_set_status_available_after_fallback" "pm_set_status:exists" "$ROUTE_OUTPUT"
assert_contains "pm_add_comment_available_after_fallback" "pm_add_comment:exists" "$ROUTE_OUTPUT"
# Should have a warning about server not running
assert_contains "Warning_about_server_down" "WARNING" "$ROUTE_STDERR"

echo ""

# =========================================================================
# Test Group 10: pm.sh server adapter fallback preserves local functions
# =========================================================================
echo "Test Group 10: Server fallback uses local adapter"

MOCK_WORKFLOW_DIR=$(mktemp -d)
TMPOUT=$(mktemp)
TMPERR=$(mktemp)
bash --norc --noprofile -c "
  export _CFG_FILE_OVERRIDE='$MOCK_CONFIG_FILE'
  export _LOCAL_WORKFLOW_DIR='$MOCK_WORKFLOW_DIR'
  source '$PM_SH'
  # Actually create an item (should use local adapter)
  item_id=\$(pm_create_item story 'Fallback Test Item')
  echo \"item_id=\$item_id\"
  # Verify item file exists
  if [ -f \"$MOCK_WORKFLOW_DIR/items/\${item_id}.md\" ]; then
    echo 'item_file:created'
  fi
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
FALLBACK_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT" "$TMPERR"
rm -rf "$MOCK_WORKFLOW_DIR"

assert_exit_zero "Fallback_creates_item_ok" "$EXIT_CODE"
assert_contains "Fallback_item_returns_id" "item_id=" "$FALLBACK_OUTPUT"
assert_contains "Fallback_item_file_created" "item_file:created" "$FALLBACK_OUTPUT"

echo ""

# =========================================================================
# Test Group 11: Config variables for server section
# =========================================================================
echo "Test Group 11: Config exports server variables"

MOCK_SERVER_CONFIG=$(mktemp)
cat > "$MOCK_SERVER_CONFIG" <<'CONFIG'
{
  "workflowDir": ".workflow",
  "server": {
    "port": 3456,
    "portRange": [3000, 4000],
    "idleTimeoutMinutes": 30,
    "logLevel": "info"
  },
  "pm": {
    "adapter": "server"
  }
}
CONFIG

TMPOUT=$(mktemp)
_CFG_FILE_OVERRIDE="$MOCK_SERVER_CONFIG" bash --norc --noprofile -c "
  source '$CONFIG_SH'
  echo \"CFG_SERVER_PORT=\$CFG_SERVER_PORT\"
  echo \"CFG_SERVER_PORT_RANGE_MIN=\$CFG_SERVER_PORT_RANGE_MIN\"
  echo \"CFG_SERVER_PORT_RANGE_MAX=\$CFG_SERVER_PORT_RANGE_MAX\"
  echo \"CFG_SERVER_IDLE_TIMEOUT=\$CFG_SERVER_IDLE_TIMEOUT\"
  echo \"CFG_SERVER_LOG_LEVEL=\$CFG_SERVER_LOG_LEVEL\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
SERVER_CFG=$(cat "$TMPOUT")
rm -f "$TMPOUT" "$MOCK_SERVER_CONFIG"

assert_exit_zero "Server_config_loads_ok" "$EXIT_CODE"
assert_contains "CFG_SERVER_PORT_value" "CFG_SERVER_PORT=3456" "$SERVER_CFG"
assert_contains "CFG_SERVER_PORT_RANGE_MIN_value" "CFG_SERVER_PORT_RANGE_MIN=3000" "$SERVER_CFG"
assert_contains "CFG_SERVER_PORT_RANGE_MAX_value" "CFG_SERVER_PORT_RANGE_MAX=4000" "$SERVER_CFG"
assert_contains "CFG_SERVER_IDLE_TIMEOUT_value" "CFG_SERVER_IDLE_TIMEOUT=30" "$SERVER_CFG"
assert_contains "CFG_SERVER_LOG_LEVEL_value" "CFG_SERVER_LOG_LEVEL=info" "$SERVER_CFG"

echo ""

# =========================================================================
# Test Group 12: Config defaults when server section absent
# =========================================================================
echo "Test Group 12: Config defaults when server section absent"

MOCK_NOSERVER_CONFIG=$(mktemp)
cat > "$MOCK_NOSERVER_CONFIG" <<'CONFIG'
{
  "workflowDir": ".workflow"
}
CONFIG

TMPOUT=$(mktemp)
_CFG_FILE_OVERRIDE="$MOCK_NOSERVER_CONFIG" bash --norc --noprofile -c "
  source '$CONFIG_SH'
  echo \"CFG_SERVER_PORT=\$CFG_SERVER_PORT\"
  echo \"CFG_SERVER_PORT_RANGE_MIN=\$CFG_SERVER_PORT_RANGE_MIN\"
  echo \"CFG_SERVER_PORT_RANGE_MAX=\$CFG_SERVER_PORT_RANGE_MAX\"
  echo \"CFG_SERVER_IDLE_TIMEOUT=\$CFG_SERVER_IDLE_TIMEOUT\"
  echo \"CFG_SERVER_LOG_LEVEL=\$CFG_SERVER_LOG_LEVEL\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
DEFAULT_CFG=$(cat "$TMPOUT")
rm -f "$TMPOUT" "$MOCK_NOSERVER_CONFIG"

assert_exit_zero "Server_config_defaults_ok" "$EXIT_CODE"
assert_contains "CFG_SERVER_PORT_default" "CFG_SERVER_PORT=0" "$DEFAULT_CFG"
assert_contains "CFG_SERVER_PORT_RANGE_MIN_default" "CFG_SERVER_PORT_RANGE_MIN=3100" "$DEFAULT_CFG"
assert_contains "CFG_SERVER_PORT_RANGE_MAX_default" "CFG_SERVER_PORT_RANGE_MAX=3199" "$DEFAULT_CFG"
assert_contains "CFG_SERVER_IDLE_TIMEOUT_default" "CFG_SERVER_IDLE_TIMEOUT=30" "$DEFAULT_CFG"
assert_contains "CFG_SERVER_LOG_LEVEL_default" "CFG_SERVER_LOG_LEVEL=info" "$DEFAULT_CFG"

echo ""

# =========================================================================
# Test Group 13: Idempotency guard for server adapter _common.sh
# =========================================================================
echo "Test Group 13: Idempotency guard"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export WORKFLOW_SERVER_URL='http://127.0.0.1:9999'
  source '$SERVER_ADAPTER_DIR/_common.sh'
  source '$SERVER_ADAPTER_DIR/_common.sh'
  declare -f _workflow_server_url > /dev/null && echo '_workflow_server_url:exists'
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
IDEM_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "Idempotent_double_source_ok" "$EXIT_CODE"
assert_contains "Function_after_double_source" "_workflow_server_url:exists" "$IDEM_OUTPUT"

echo ""

# =========================================================================
# Test Group 14: Error handling for non-200 HTTP responses
# =========================================================================
echo "Test Group 14: Error handling for HTTP failures"

TMPOUT=$(mktemp)
TMPERR=$(mktemp)
# Use a port that is not listening to simulate connection refused
bash --norc --noprofile -c "
  export WORKFLOW_SERVER_URL='http://127.0.0.1:19999'
  source '$SERVER_ADAPTER_DIR/_common.sh'
  source '$SERVER_ADAPTER_DIR/items.sh'
  pm_get_item 42 2>&1
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
rm -f "$TMPOUT" "$TMPERR"

assert_exit_nonzero "Connection_refused_returns_error" "$EXIT_CODE"

echo ""

# =========================================================================
# Test Group 15: _server_health_check fails for unreachable server
# =========================================================================
echo "Test Group 15: Health check fails when server unreachable"

TMPOUT=$(mktemp)
TMPERR=$(mktemp)
bash --norc --noprofile -c "
  export WORKFLOW_SERVER_URL='http://127.0.0.1:19999'
  source '$SERVER_ADAPTER_DIR/_common.sh'
  _server_health_check 2>/dev/null
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
rm -f "$TMPOUT" "$TMPERR"

assert_exit_nonzero "Health_check_fails_for_unreachable" "$EXIT_CODE"

echo ""

# =========================================================================
# Test Group 16: _server_escape_json handles control characters
# =========================================================================
echo "Test Group 16: _server_escape_json handles control characters"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export WORKFLOW_SERVER_URL='http://127.0.0.1:9999'
  source '$SERVER_ADAPTER_DIR/_common.sh'

  # Test tab escaping
  result=\$(_server_escape_json \$'hello\tworld')
  echo \"tab_result=\$result\"

  # Test carriage return escaping
  result=\$(_server_escape_json \$'line1\rline2')
  echo \"cr_result=\$result\"

  # Test backspace escaping
  result=\$(_server_escape_json \$'back\bspace')
  echo \"bs_result=\$result\"

  # Test form feed escaping
  result=\$(_server_escape_json \$'form\ffeed')
  echo \"ff_result=\$result\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
ESCAPE_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "Escape_json_control_chars_ok" "$EXIT_CODE"
assert_contains "Tab_escaped" "tab_result=hello\\tworld" "$ESCAPE_OUTPUT"
assert_contains "CR_escaped" "cr_result=line1\\rline2" "$ESCAPE_OUTPUT"
assert_contains "BS_escaped" "bs_result=back\\bspace" "$ESCAPE_OUTPUT"
assert_contains "FF_escaped" "ff_result=form\\ffeed" "$ESCAPE_OUTPUT"

echo ""

# =========================================================================
# Test Group 17: pm_add_comment validates argument count
# =========================================================================
echo "Test Group 17: pm_add_comment validates argument count"

TMPOUT=$(mktemp)
TMPERR=$(mktemp)
bash --norc --noprofile -c "
  export WORKFLOW_SERVER_URL='http://127.0.0.1:9999'
  source '$SERVER_ADAPTER_DIR/_common.sh'
  source '$SERVER_ADAPTER_DIR/comments.sh'
  pm_add_comment 2>&1
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
COMMENT_STDERR=$(cat "$TMPERR")
COMMENT_STDOUT=$(cat "$TMPOUT")
rm -f "$TMPOUT" "$TMPERR"

assert_exit_nonzero "pm_add_comment_no_args_fails" "$EXIT_CODE"
assert_contains "pm_add_comment_usage_message" "Usage:" "$COMMENT_STDERR$COMMENT_STDOUT"

# One argument should also fail
TMPOUT=$(mktemp)
TMPERR=$(mktemp)
bash --norc --noprofile -c "
  export WORKFLOW_SERVER_URL='http://127.0.0.1:9999'
  source '$SERVER_ADAPTER_DIR/_common.sh'
  source '$SERVER_ADAPTER_DIR/comments.sh'
  pm_add_comment 42 2>&1
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
rm -f "$TMPOUT" "$TMPERR"

assert_exit_nonzero "pm_add_comment_one_arg_fails" "$EXIT_CODE"

echo ""

# =========================================================================
# Test Group 18: pm_link_child validates argument count
# =========================================================================
echo "Test Group 18: pm_link_child validates argument count"

TMPOUT=$(mktemp)
TMPERR=$(mktemp)
bash --norc --noprofile -c "
  export WORKFLOW_SERVER_URL='http://127.0.0.1:9999'
  source '$SERVER_ADAPTER_DIR/_common.sh'
  source '$SERVER_ADAPTER_DIR/hierarchy.sh'
  pm_link_child 2>&1
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
LINK_STDERR=$(cat "$TMPERR")
LINK_STDOUT=$(cat "$TMPOUT")
rm -f "$TMPOUT" "$TMPERR"

assert_exit_nonzero "pm_link_child_no_args_fails" "$EXIT_CODE"
assert_contains "pm_link_child_usage_message" "Usage:" "$LINK_STDERR$LINK_STDOUT"

# One argument should also fail
TMPOUT=$(mktemp)
TMPERR=$(mktemp)
bash --norc --noprofile -c "
  export WORKFLOW_SERVER_URL='http://127.0.0.1:9999'
  source '$SERVER_ADAPTER_DIR/_common.sh'
  source '$SERVER_ADAPTER_DIR/hierarchy.sh'
  pm_link_child 42 2>&1
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
rm -f "$TMPOUT" "$TMPERR"

assert_exit_nonzero "pm_link_child_one_arg_fails" "$EXIT_CODE"

echo ""

# =========================================================================
# Test Group 19: pm_complete_work validates argument count
# =========================================================================
echo "Test Group 19: pm_complete_work validates argument count"

TMPOUT=$(mktemp)
TMPERR=$(mktemp)
bash --norc --noprofile -c "
  export WORKFLOW_SERVER_URL='http://127.0.0.1:9999'
  source '$SERVER_ADAPTER_DIR/_common.sh'
  source '$SERVER_ADAPTER_DIR/lifecycle.sh'
  pm_complete_work 2>&1
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
COMPLETE_STDERR=$(cat "$TMPERR")
COMPLETE_STDOUT=$(cat "$TMPOUT")
rm -f "$TMPOUT" "$TMPERR"

assert_exit_nonzero "pm_complete_work_no_args_fails" "$EXIT_CODE"
assert_contains "pm_complete_work_usage_message" "Usage:" "$COMPLETE_STDERR$COMPLETE_STDOUT"

# One argument should also fail
TMPOUT=$(mktemp)
TMPERR=$(mktemp)
bash --norc --noprofile -c "
  export WORKFLOW_SERVER_URL='http://127.0.0.1:9999'
  source '$SERVER_ADAPTER_DIR/_common.sh'
  source '$SERVER_ADAPTER_DIR/lifecycle.sh'
  pm_complete_work 42 2>&1
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
rm -f "$TMPOUT" "$TMPERR"

assert_exit_nonzero "pm_complete_work_one_arg_fails" "$EXIT_CODE"

echo ""

# =========================================================================
# Test Group 20: pm_add_label calls item label association endpoint
# =========================================================================
echo "Test Group 20: pm_add_label calls item label association endpoint"

# Verify that pm_add_label function body includes the /api/items/$item_id/labels path
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export WORKFLOW_SERVER_URL='http://127.0.0.1:9999'
  source '$SERVER_ADAPTER_DIR/_common.sh'
  source '$SERVER_ADAPTER_DIR/labels.sh'
  fn_body=\$(declare -f pm_add_label)
  echo \"\$fn_body\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
LABEL_FN_BODY=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "pm_add_label_sources_ok" "$EXIT_CODE"
assert_contains "pm_add_label_calls_item_label_endpoint" "/api/items/" "$LABEL_FN_BODY"
assert_contains "pm_add_label_calls_labels_subpath" "/labels" "$LABEL_FN_BODY"

echo ""

# =========================================================================
# Test Group 21: pm.adapter "server" is read from config; the shipped
# default is local-only
# =========================================================================
echo "Test Group 21: Config pm.adapter value"

SERVER_CFG=$(mktemp)
echo '{"pm": {"adapter": "server"}}' > "$SERVER_CFG"
TMPOUT=$(mktemp)
_CFG_FILE_OVERRIDE="$SERVER_CFG" bash --norc --noprofile -c "
  source '$CONFIG_SH'
  echo \"CFG_PM_ADAPTER=\$CFG_PM_ADAPTER\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
CFG_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT" "$SERVER_CFG"

assert_exit_zero "Config_loads_ok" "$EXIT_CODE"
assert_contains "PM_adapter_is_server" "CFG_PM_ADAPTER=server" "$CFG_OUTPUT"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  source '$CONFIG_SH'
  echo \"CFG_PM_ADAPTER=[\$CFG_PM_ADAPTER]\"
" > "$TMPOUT" 2>&1
CFG_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_contains "Shipped_default_is_local_only" "CFG_PM_ADAPTER=[]" "$CFG_OUTPUT"

echo ""

# =========================================================================
# Test Group 22: pm_add_doc_comment validates argument count
# =========================================================================
echo "Test Group 22: pm_add_doc_comment validates argument count"

TMPOUT=$(mktemp)
TMPERR=$(mktemp)
bash --norc --noprofile -c "
  export WORKFLOW_SERVER_URL='http://127.0.0.1:9999'
  source '$SERVER_ADAPTER_DIR/_common.sh'
  source '$SERVER_ADAPTER_DIR/comments.sh'
  pm_add_doc_comment 2>&1
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
DOC_COMMENT_STDERR=$(cat "$TMPERR")
DOC_COMMENT_STDOUT=$(cat "$TMPOUT")
rm -f "$TMPOUT" "$TMPERR"

assert_exit_nonzero "pm_add_doc_comment_no_args_fails" "$EXIT_CODE"
assert_contains "pm_add_doc_comment_usage_message" "Usage:" "$DOC_COMMENT_STDERR$DOC_COMMENT_STDOUT"

# One argument should also fail
TMPOUT=$(mktemp)
TMPERR=$(mktemp)
bash --norc --noprofile -c "
  export WORKFLOW_SERVER_URL='http://127.0.0.1:9999'
  source '$SERVER_ADAPTER_DIR/_common.sh'
  source '$SERVER_ADAPTER_DIR/comments.sh'
  pm_add_doc_comment '2-design/overview.md' 2>&1
" > "$TMPOUT" 2>"$TMPERR"
EXIT_CODE=$?
rm -f "$TMPOUT" "$TMPERR"

assert_exit_nonzero "pm_add_doc_comment_one_arg_fails" "$EXIT_CODE"

echo ""

# =========================================================================
# Test Group 23: pm_add_doc_comment calls correct HTTP endpoint
# =========================================================================
echo "Test Group 23: pm_add_doc_comment calls correct HTTP endpoint"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export WORKFLOW_SERVER_URL='http://127.0.0.1:9999'
  source '$SERVER_ADAPTER_DIR/_common.sh'
  source '$SERVER_ADAPTER_DIR/comments.sh'
  fn_body=\$(declare -f pm_add_doc_comment)
  echo \"\$fn_body\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
DOC_FN_BODY=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "pm_add_doc_comment_sources_ok" "$EXIT_CODE"
assert_contains "pm_add_doc_comment_calls_documents_endpoint" "/api/documents/" "$DOC_FN_BODY"
assert_contains "pm_add_doc_comment_calls_comments_subpath" "/comments" "$DOC_FN_BODY"

echo ""

# =========================================================================
# Test Group 24: pm_add_doc_comment is registered in server adapter
# =========================================================================
echo "Test Group 24: pm_add_doc_comment registered in server adapter"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export WORKFLOW_SERVER_URL='http://127.0.0.1:9999'
  for f in '$SERVER_ADAPTER_DIR'/*.sh; do
    source \"\$f\"
  done
  declare -f pm_add_doc_comment > /dev/null && echo 'pm_add_doc_comment:exists'
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
REG_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "pm_add_doc_comment_registration_ok" "$EXIT_CODE"
assert_contains "pm_add_doc_comment_registered" "pm_add_doc_comment:exists" "$REG_OUTPUT"

echo ""

# --- Cleanup ---
rm -rf "$MOCK_CONFIG_DIR" 2>/dev/null || true

# --- Summary ---
echo "========================================"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
