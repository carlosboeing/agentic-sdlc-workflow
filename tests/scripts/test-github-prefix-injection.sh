#!/usr/bin/env bash
# test-github-prefix-injection.sh — Validates that all 7 GitHub adapter modules
# support prefix injection via _PM_LOADING_EXTERNAL.
#
# Tests:
#   - Each module sourced with _PM_LOADING_EXTERNAL=1 defines _external_pm_* functions
#   - Each module sourced without _PM_LOADING_EXTERNAL defines bare pm_* functions
#   - All 15 public functions are correctly prefixed in both modes
#   - Private helpers remain unprefixed in both modes
#   - Normal (no-external) mode produces zero behavioral change

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ADAPTERS_DIR="$REPO_ROOT/scripts/lib/adapters/pm/github"

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

assert_function_defined() {
  local test_name="$1" func_name="$2" result="$3"
  if echo "$result" | grep -qx "$func_name"; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (function '$func_name' not found)"
    echo "    Defined functions: $result"
    FAIL=$((FAIL + 1))
  fi
}

assert_function_not_defined() {
  local test_name="$1" func_name="$2" result="$3"
  if echo "$result" | grep -qx "$func_name"; then
    echo "  FAIL: $test_name (function '$func_name' should NOT be defined)"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  fi
}

echo "========================================"
echo "Testing GitHub adapter prefix injection"
echo "========================================"
echo ""

# --- Test Group 1: board.sh prefix injection ---
echo "Test Group: board.sh — external mode defines _external_pm_* functions"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_LOADING_EXTERNAL=1
  source \"$ADAPTERS_DIR/board.sh\"
  declare -F | awk '{print \$3}' | grep -E '^(pm_|_external_pm_|_gh_|_board_)' | sort
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
BOARD_EXT_FUNCS=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "board_sh_sources_in_external_mode" "$EXIT_CODE"
assert_function_defined "_external_pm_set_status_defined_in_external_mode" "_external_pm_set_status" "$BOARD_EXT_FUNCS"
assert_function_defined "_external_pm_add_to_board_defined_in_external_mode" "_external_pm_add_to_board" "$BOARD_EXT_FUNCS"
assert_function_defined "_external_pm_batch_set_status_defined_in_external_mode" "_external_pm_batch_set_status" "$BOARD_EXT_FUNCS"
assert_function_not_defined "bare_pm_set_status_NOT_defined_in_external_mode" "pm_set_status" "$BOARD_EXT_FUNCS"
assert_function_not_defined "bare_pm_add_to_board_NOT_defined_in_external_mode" "pm_add_to_board" "$BOARD_EXT_FUNCS"
assert_function_not_defined "bare_pm_batch_set_status_NOT_defined_in_external_mode" "pm_batch_set_status" "$BOARD_EXT_FUNCS"

echo ""
echo "Test Group: board.sh — normal mode defines bare pm_* functions"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  unset _PM_LOADING_EXTERNAL
  source \"$ADAPTERS_DIR/board.sh\"
  declare -F | awk '{print \$3}' | grep -E '^(pm_|_external_pm_)' | sort
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
BOARD_NORM_FUNCS=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "board_sh_sources_in_normal_mode" "$EXIT_CODE"
assert_function_defined "bare_pm_set_status_defined_in_normal_mode" "pm_set_status" "$BOARD_NORM_FUNCS"
assert_function_defined "bare_pm_add_to_board_defined_in_normal_mode" "pm_add_to_board" "$BOARD_NORM_FUNCS"
assert_function_defined "bare_pm_batch_set_status_defined_in_normal_mode" "pm_batch_set_status" "$BOARD_NORM_FUNCS"
assert_function_not_defined "_external_pm_set_status_NOT_defined_in_normal_mode" "_external_pm_set_status" "$BOARD_NORM_FUNCS"

echo ""

# --- Test Group 2: comments.sh prefix injection ---
echo "Test Group: comments.sh — external mode defines _external_pm_* functions"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_LOADING_EXTERNAL=1
  source \"$ADAPTERS_DIR/comments.sh\"
  declare -F | awk '{print \$3}' | grep -E '^(pm_|_external_pm_)' | sort
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
COMMENTS_EXT_FUNCS=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "comments_sh_sources_in_external_mode" "$EXIT_CODE"
assert_function_defined "_external_pm_add_comment_defined_in_external_mode" "_external_pm_add_comment" "$COMMENTS_EXT_FUNCS"
assert_function_defined "_external_pm_post_telemetry_defined_in_external_mode" "_external_pm_post_telemetry" "$COMMENTS_EXT_FUNCS"
assert_function_not_defined "bare_pm_add_comment_NOT_defined_in_external_mode" "pm_add_comment" "$COMMENTS_EXT_FUNCS"
assert_function_not_defined "bare_pm_post_telemetry_NOT_defined_in_external_mode" "pm_post_telemetry" "$COMMENTS_EXT_FUNCS"

echo ""
echo "Test Group: comments.sh — normal mode defines bare pm_* functions"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  unset _PM_LOADING_EXTERNAL
  source \"$ADAPTERS_DIR/comments.sh\"
  declare -F | awk '{print \$3}' | grep -E '^(pm_|_external_pm_)' | sort
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
COMMENTS_NORM_FUNCS=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "comments_sh_sources_in_normal_mode" "$EXIT_CODE"
assert_function_defined "bare_pm_add_comment_defined_in_normal_mode" "pm_add_comment" "$COMMENTS_NORM_FUNCS"
assert_function_defined "bare_pm_post_telemetry_defined_in_normal_mode" "pm_post_telemetry" "$COMMENTS_NORM_FUNCS"
assert_function_not_defined "_external_pm_add_comment_NOT_defined_in_normal_mode" "_external_pm_add_comment" "$COMMENTS_NORM_FUNCS"

echo ""

# --- Test Group 3: hierarchy.sh prefix injection ---
echo "Test Group: hierarchy.sh — external mode defines _external_pm_link_child"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_LOADING_EXTERNAL=1
  source \"$ADAPTERS_DIR/hierarchy.sh\"
  declare -F | awk '{print \$3}' | grep -E '^(pm_|_external_pm_)' | sort
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
HIER_EXT_FUNCS=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "hierarchy_sh_sources_in_external_mode" "$EXIT_CODE"
assert_function_defined "_external_pm_link_child_defined_in_external_mode" "_external_pm_link_child" "$HIER_EXT_FUNCS"
assert_function_not_defined "bare_pm_link_child_NOT_defined_in_external_mode" "pm_link_child" "$HIER_EXT_FUNCS"

echo ""
echo "Test Group: hierarchy.sh — normal mode defines bare pm_link_child"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  unset _PM_LOADING_EXTERNAL
  source \"$ADAPTERS_DIR/hierarchy.sh\"
  declare -F | awk '{print \$3}' | grep -E '^(pm_|_external_pm_)' | sort
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
HIER_NORM_FUNCS=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "hierarchy_sh_sources_in_normal_mode" "$EXIT_CODE"
assert_function_defined "bare_pm_link_child_defined_in_normal_mode" "pm_link_child" "$HIER_NORM_FUNCS"
assert_function_not_defined "_external_pm_link_child_NOT_defined_in_normal_mode" "_external_pm_link_child" "$HIER_NORM_FUNCS"

echo ""

# --- Test Group 4: items.sh prefix injection ---
echo "Test Group: items.sh — external mode defines _external_pm_* functions"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_LOADING_EXTERNAL=1
  source \"$ADAPTERS_DIR/items.sh\"
  declare -F | awk '{print \$3}' | grep -E '^(pm_|_external_pm_)' | sort
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
ITEMS_EXT_FUNCS=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "items_sh_sources_in_external_mode" "$EXIT_CODE"
assert_function_defined "_external_pm_create_item_defined_in_external_mode" "_external_pm_create_item" "$ITEMS_EXT_FUNCS"
assert_function_defined "_external_pm_get_item_defined_in_external_mode" "_external_pm_get_item" "$ITEMS_EXT_FUNCS"
assert_function_defined "_external_pm_list_items_defined_in_external_mode" "_external_pm_list_items" "$ITEMS_EXT_FUNCS"
assert_function_defined "_external_pm_update_item_defined_in_external_mode" "_external_pm_update_item" "$ITEMS_EXT_FUNCS"
assert_function_defined "_external_pm_close_item_defined_in_external_mode" "_external_pm_close_item" "$ITEMS_EXT_FUNCS"
assert_function_not_defined "bare_pm_create_item_NOT_defined_in_external_mode" "pm_create_item" "$ITEMS_EXT_FUNCS"
assert_function_not_defined "bare_pm_close_item_NOT_defined_in_external_mode" "pm_close_item" "$ITEMS_EXT_FUNCS"

echo ""
echo "Test Group: items.sh — normal mode defines bare pm_* functions"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  unset _PM_LOADING_EXTERNAL
  source \"$ADAPTERS_DIR/items.sh\"
  declare -F | awk '{print \$3}' | grep -E '^(pm_|_external_pm_)' | sort
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
ITEMS_NORM_FUNCS=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "items_sh_sources_in_normal_mode" "$EXIT_CODE"
assert_function_defined "bare_pm_create_item_defined_in_normal_mode" "pm_create_item" "$ITEMS_NORM_FUNCS"
assert_function_defined "bare_pm_get_item_defined_in_normal_mode" "pm_get_item" "$ITEMS_NORM_FUNCS"
assert_function_defined "bare_pm_list_items_defined_in_normal_mode" "pm_list_items" "$ITEMS_NORM_FUNCS"
assert_function_defined "bare_pm_update_item_defined_in_normal_mode" "pm_update_item" "$ITEMS_NORM_FUNCS"
assert_function_defined "bare_pm_close_item_defined_in_normal_mode" "pm_close_item" "$ITEMS_NORM_FUNCS"
assert_function_not_defined "_external_pm_create_item_NOT_defined_in_normal_mode" "_external_pm_create_item" "$ITEMS_NORM_FUNCS"

echo ""

# --- Test Group 5: labels.sh prefix injection ---
echo "Test Group: labels.sh — external mode defines _external_pm_add_label"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_LOADING_EXTERNAL=1
  source \"$ADAPTERS_DIR/labels.sh\"
  declare -F | awk '{print \$3}' | grep -E '^(pm_|_external_pm_)' | sort
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
LABELS_EXT_FUNCS=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "labels_sh_sources_in_external_mode" "$EXIT_CODE"
assert_function_defined "_external_pm_add_label_defined_in_external_mode" "_external_pm_add_label" "$LABELS_EXT_FUNCS"
assert_function_not_defined "bare_pm_add_label_NOT_defined_in_external_mode" "pm_add_label" "$LABELS_EXT_FUNCS"

echo ""
echo "Test Group: labels.sh — normal mode defines bare pm_add_label"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  unset _PM_LOADING_EXTERNAL
  source \"$ADAPTERS_DIR/labels.sh\"
  declare -F | awk '{print \$3}' | grep -E '^(pm_|_external_pm_)' | sort
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
LABELS_NORM_FUNCS=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "labels_sh_sources_in_normal_mode" "$EXIT_CODE"
assert_function_defined "bare_pm_add_label_defined_in_normal_mode" "pm_add_label" "$LABELS_NORM_FUNCS"
assert_function_not_defined "_external_pm_add_label_NOT_defined_in_normal_mode" "_external_pm_add_label" "$LABELS_NORM_FUNCS"

echo ""

# --- Test Group 6: lifecycle.sh prefix injection ---
echo "Test Group: lifecycle.sh — external mode defines _external_pm_* functions"

COMMENT_LOG=$(mktemp)
STATUS_LOG=$(mktemp)
MOCK_FUNS="pm_add_comment() { true; }; pm_set_status() { true; }; _external_pm_add_comment() { true; }; _external_pm_set_status() { true; }"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  $MOCK_FUNS
  export _PM_LOADING_EXTERNAL=1
  source \"$ADAPTERS_DIR/lifecycle.sh\"
  declare -F | awk '{print \$3}' | grep -E '^(pm_|_external_pm_)' | sort
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
LIFECYCLE_EXT_FUNCS=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "lifecycle_sh_sources_in_external_mode" "$EXIT_CODE"
assert_function_defined "_external_pm_start_work_defined_in_external_mode" "_external_pm_start_work" "$LIFECYCLE_EXT_FUNCS"
assert_function_defined "_external_pm_complete_work_defined_in_external_mode" "_external_pm_complete_work" "$LIFECYCLE_EXT_FUNCS"
assert_function_not_defined "bare_pm_start_work_NOT_defined_in_external_mode" "pm_start_work" "$LIFECYCLE_EXT_FUNCS"
assert_function_not_defined "bare_pm_complete_work_NOT_defined_in_external_mode" "pm_complete_work" "$LIFECYCLE_EXT_FUNCS"

echo ""
echo "Test Group: lifecycle.sh — normal mode defines bare pm_* functions"

MOCK_FUNS_BARE="pm_add_comment() { true; }; pm_set_status() { true; }"
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  $MOCK_FUNS_BARE
  unset _PM_LOADING_EXTERNAL
  source \"$ADAPTERS_DIR/lifecycle.sh\"
  declare -F | awk '{print \$3}' | grep -E '^(pm_start|pm_complete|_external_pm_)' | sort
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
LIFECYCLE_NORM_FUNCS=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "lifecycle_sh_sources_in_normal_mode" "$EXIT_CODE"
assert_function_defined "bare_pm_start_work_defined_in_normal_mode" "pm_start_work" "$LIFECYCLE_NORM_FUNCS"
assert_function_defined "bare_pm_complete_work_defined_in_normal_mode" "pm_complete_work" "$LIFECYCLE_NORM_FUNCS"
assert_function_not_defined "_external_pm_start_work_NOT_defined_in_normal_mode" "_external_pm_start_work" "$LIFECYCLE_NORM_FUNCS"

echo ""

# --- Test Group 7: reconcile.sh prefix injection ---
echo "Test Group: reconcile.sh — external mode defines _external_pm_reconcile"

# reconcile.sh calls _board_log and pm_set_status internally; provide stubs
RECON_MOCK="_board_log() { true; }; pm_set_status() { true; }; _external_pm_set_status() { true; }"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  $RECON_MOCK
  export _PM_LOADING_EXTERNAL=1
  source \"$ADAPTERS_DIR/reconcile.sh\"
  declare -F | awk '{print \$3}' | grep -E '^(pm_|_external_pm_)' | sort
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
RECON_EXT_FUNCS=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "reconcile_sh_sources_in_external_mode" "$EXIT_CODE"
assert_function_defined "_external_pm_reconcile_defined_in_external_mode" "_external_pm_reconcile" "$RECON_EXT_FUNCS"
assert_function_not_defined "bare_pm_reconcile_NOT_defined_in_external_mode" "pm_reconcile" "$RECON_EXT_FUNCS"

echo ""
echo "Test Group: reconcile.sh — normal mode defines bare pm_reconcile"

RECON_MOCK_BARE="_board_log() { true; }; pm_set_status() { true; }"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  $RECON_MOCK_BARE
  unset _PM_LOADING_EXTERNAL
  source \"$ADAPTERS_DIR/reconcile.sh\"
  declare -F | awk '{print \$3}' | grep -E '^(pm_|_external_pm_)' | sort
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
RECON_NORM_FUNCS=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "reconcile_sh_sources_in_normal_mode" "$EXIT_CODE"
assert_function_defined "bare_pm_reconcile_defined_in_normal_mode" "pm_reconcile" "$RECON_NORM_FUNCS"
assert_function_not_defined "_external_pm_reconcile_NOT_defined_in_normal_mode" "_external_pm_reconcile" "$RECON_NORM_FUNCS"

echo ""

# --- Test Group 8: Private helpers are never prefixed ---
echo "Test Group: Private helpers are unprefixed in both modes"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_LOADING_EXTERNAL=1
  source \"$ADAPTERS_DIR/board.sh\"
  declare -F | awk '{print \$3}' | grep -E '^_gh_' | sort
" > "$TMPOUT" 2>&1
PRIVATE_FUNCS=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_function_defined "_gh_status_to_option_id_unprefixed_in_external_mode" "_gh_status_to_option_id" "$PRIVATE_FUNCS"
assert_function_defined "_gh_fetch_item_info_unprefixed_in_external_mode" "_gh_fetch_item_info" "$PRIVATE_FUNCS"
assert_function_defined "_gh_mutate_status_unprefixed_in_external_mode" "_gh_mutate_status" "$PRIVATE_FUNCS"
assert_function_defined "_gh_verify_status_unprefixed_in_external_mode" "_gh_verify_status" "$PRIVATE_FUNCS"
assert_function_defined "_gh_fetch_with_retry_unprefixed_in_external_mode" "_gh_fetch_with_retry" "$PRIVATE_FUNCS"

echo ""

# --- Test Group 9: All 15 public functions covered across all 7 modules ---
echo "Test Group: All 15 public functions defined in external mode"

# Source all 7 modules together with external mode enabled.
# Do NOT pre-define pm_* stubs — that would trigger idempotency guards and skip
# modules. Only provide _board_log (called at module init time, not a public function).
MOCK_STUBS="_board_log() { true; }"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  $MOCK_STUBS
  export _PM_LOADING_EXTERNAL=1
  source \"$ADAPTERS_DIR/board.sh\"
  source \"$ADAPTERS_DIR/comments.sh\"
  source \"$ADAPTERS_DIR/hierarchy.sh\"
  source \"$ADAPTERS_DIR/items.sh\"
  source \"$ADAPTERS_DIR/labels.sh\"
  source \"$ADAPTERS_DIR/lifecycle.sh\"
  source \"$ADAPTERS_DIR/reconcile.sh\"
  declare -F | awk '{print \$3}' | grep '^_external_pm_' | sort
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
ALL_EXT_FUNCS=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "all_7_modules_source_together_in_external_mode" "$EXIT_CODE"

# All 15 public functions must have _external_ prefix
EXPECTED_EXTERNAL_FUNCS=(
  _external_pm_add_comment
  _external_pm_add_label
  _external_pm_add_to_board
  _external_pm_batch_set_status
  _external_pm_complete_work
  _external_pm_create_item
  _external_pm_close_item
  _external_pm_get_item
  _external_pm_link_child
  _external_pm_list_items
  _external_pm_post_telemetry
  _external_pm_reconcile
  _external_pm_set_status
  _external_pm_start_work
  _external_pm_update_item
)

for fn in "${EXPECTED_EXTERNAL_FUNCS[@]}"; do
  assert_function_defined "all_modules_external_${fn}_defined" "$fn" "$ALL_EXT_FUNCS"
done

echo ""

# --- Test Group 10: All 15 public functions defined in normal mode ---
echo "Test Group: All 15 public functions defined in normal mode (zero behavioral change)"

# Same: do NOT pre-define pm_* stubs. Only provide _board_log.
MOCK_STUBS_NORM="_board_log() { true; }"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  $MOCK_STUBS_NORM
  unset _PM_LOADING_EXTERNAL
  source \"$ADAPTERS_DIR/board.sh\"
  source \"$ADAPTERS_DIR/comments.sh\"
  source \"$ADAPTERS_DIR/hierarchy.sh\"
  source \"$ADAPTERS_DIR/items.sh\"
  source \"$ADAPTERS_DIR/labels.sh\"
  source \"$ADAPTERS_DIR/lifecycle.sh\"
  source \"$ADAPTERS_DIR/reconcile.sh\"
  declare -F | awk '{print \$3}' | grep '^pm_' | sort
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
ALL_NORM_FUNCS=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "all_7_modules_source_together_in_normal_mode" "$EXIT_CODE"

EXPECTED_BARE_FUNCS=(
  pm_add_comment
  pm_add_label
  pm_add_to_board
  pm_batch_set_status
  pm_complete_work
  pm_create_item
  pm_close_item
  pm_get_item
  pm_link_child
  pm_list_items
  pm_post_telemetry
  pm_reconcile
  pm_set_status
  pm_start_work
  pm_update_item
)

for fn in "${EXPECTED_BARE_FUNCS[@]}"; do
  assert_function_defined "all_modules_normal_${fn}_defined" "$fn" "$ALL_NORM_FUNCS"
done

# No _external_ functions should exist in normal mode
EXT_COUNT=$(echo "$ALL_NORM_FUNCS" | grep -c '^_external_pm_' 2>/dev/null || true)
EXT_COUNT="${EXT_COUNT:-0}"
if [ "${EXT_COUNT}" -eq 0 ] 2>/dev/null || [ -z "$EXT_COUNT" ]; then
  echo "  PASS: no_external_pm_functions_in_normal_mode"
  PASS=$((PASS + 1))
else
  echo "  FAIL: no_external_pm_functions_in_normal_mode (found $EXT_COUNT _external_ functions)"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test Group 11: lifecycle.sh cross-function calls use prefix ---
echo "Test Group: lifecycle.sh cross-function calls use _PM_FN_PREFIX"

# When loaded as external, _external_pm_start_work must call _external_pm_add_comment,
# not bare pm_add_comment (which would be the dual-write wrapper).
COMMENT_LOG=$(mktemp)
STATUS_LOG=$(mktemp)

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  # Define both bare and external stubs — track which was called
  pm_add_comment() { echo 'BARE_COMMENT' >> \"$COMMENT_LOG\"; }
  pm_set_status() { echo 'BARE_STATUS' >> \"$STATUS_LOG\"; }
  _external_pm_add_comment() { echo 'EXT_COMMENT' >> \"$COMMENT_LOG\"; }
  _external_pm_set_status() { echo 'EXT_STATUS' >> \"$STATUS_LOG\"; }

  export _PM_LOADING_EXTERNAL=1
  source \"$ADAPTERS_DIR/lifecycle.sh\"

  # Call the external version directly
  _external_pm_start_work 42 --model test --agent test
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
COMMENT_CALLS=$(cat "$COMMENT_LOG")
STATUS_CALLS=$(cat "$STATUS_LOG")
rm -f "$TMPOUT" "$COMMENT_LOG" "$STATUS_LOG"

assert_exit_zero "external_start_work_exits_zero" "$EXIT_CODE"

# Should have called _external_pm_add_comment, NOT bare pm_add_comment
if echo "$COMMENT_CALLS" | grep -q "EXT_COMMENT"; then
  echo "  PASS: external_pm_start_work_calls_external_pm_add_comment"
  PASS=$((PASS + 1))
else
  echo "  FAIL: external_pm_start_work_calls_external_pm_add_comment"
  echo "    Comment log: $COMMENT_CALLS"
  FAIL=$((FAIL + 1))
fi

if ! echo "$COMMENT_CALLS" | grep -q "BARE_COMMENT"; then
  echo "  PASS: external_pm_start_work_does_NOT_call_bare_pm_add_comment"
  PASS=$((PASS + 1))
else
  echo "  FAIL: external_pm_start_work_does_NOT_call_bare_pm_add_comment"
  echo "    Comment log: $COMMENT_CALLS"
  FAIL=$((FAIL + 1))
fi

if echo "$STATUS_CALLS" | grep -q "EXT_STATUS"; then
  echo "  PASS: external_pm_start_work_calls_external_pm_set_status"
  PASS=$((PASS + 1))
else
  echo "  FAIL: external_pm_start_work_calls_external_pm_set_status"
  echo "    Status log: $STATUS_CALLS"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test Group 12: items.sh pm_close_item cross-function call uses prefix ---
echo "Test Group: items.sh pm_close_item cross-function call uses _PM_FN_PREFIX"

STATUS_LOG=$(mktemp)
GH_LOG=$(mktemp)

# Create a mock gh that accepts any arguments
MOCK_DIR=$(mktemp -d)
cat > "$MOCK_DIR/gh" <<'GHSTUB'
#!/usr/bin/env bash
# Stub gh: echo args to GH_LOG, succeed
echo "$@" >> "${GH_STUB_LOG:-/dev/null}"
exit 0
GHSTUB
chmod +x "$MOCK_DIR/gh"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export PATH=\"$MOCK_DIR:\$PATH\"
  export GH_STUB_LOG=\"$GH_LOG\"
  export CFG_REPO=\"test/repo\"

  pm_set_status() { echo 'BARE_STATUS' >> \"$STATUS_LOG\"; }
  _external_pm_set_status() { echo 'EXT_STATUS' >> \"$STATUS_LOG\"; }

  export _PM_LOADING_EXTERNAL=1
  source \"$ADAPTERS_DIR/items.sh\"

  _external_pm_close_item 99
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
STATUS_CALLS=$(cat "$STATUS_LOG")
rm -f "$TMPOUT" "$STATUS_LOG" "$GH_LOG"
rm -rf "$MOCK_DIR"

assert_exit_zero "external_pm_close_item_exits_zero" "$EXIT_CODE"

if echo "$STATUS_CALLS" | grep -q "EXT_STATUS"; then
  echo "  PASS: external_pm_close_item_calls_external_pm_set_status"
  PASS=$((PASS + 1))
else
  echo "  FAIL: external_pm_close_item_calls_external_pm_set_status"
  echo "    Status log: $STATUS_CALLS"
  FAIL=$((FAIL + 1))
fi

if ! echo "$STATUS_CALLS" | grep -q "BARE_STATUS"; then
  echo "  PASS: external_pm_close_item_does_NOT_call_bare_pm_set_status"
  PASS=$((PASS + 1))
else
  echo "  FAIL: external_pm_close_item_does_NOT_call_bare_pm_set_status"
  echo "    Status log: $STATUS_CALLS"
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
exit 0
