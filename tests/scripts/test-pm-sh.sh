#!/usr/bin/env bash
# test-pm-sh.sh — Validates pm.sh adapter loader behavior.
# Runs locally using mock adapter directories (no live GitHub API calls).

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
echo "Test Group: File properties"

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

# Verify github adapter directory exists (created by this story)
if [ -d "$ADAPTERS_DIR/github" ]; then
  echo "  PASS: adapters/pm/github/ directory exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: adapters/pm/github/ directory not found at $ADAPTERS_DIR/github"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test Group 2: Mock adapter sourcing ---
echo "Test Group: Mock adapter sourcing"

MOCK_ADAPTER_DIR=$(mktemp -d)
MOCK_ADAPTER_DIR="${MOCK_ADAPTER_DIR}/mock"
mkdir -p "$MOCK_ADAPTER_DIR"

# Create a mock adapter module with a test function
cat > "$MOCK_ADAPTER_DIR/test_module.sh" <<'MOCK_MODULE'
pm_mock_hello() {
  echo "hello from mock adapter"
}
MOCK_MODULE

# Override PM_ADAPTER via environment to point to our mock
# pm.sh reads CFG_PM_ADAPTER from config.sh, but we override with _PM_TEST_ADAPTER_DIR
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  # Override the adapter dir lookup by injecting _PM_TEST_ADAPTER_DIR
  export _PM_TEST_ADAPTER_DIR=\"$MOCK_ADAPTER_DIR\"
  source \"$PM_SH\"
  pm_mock_hello
" > "$TMPOUT" 2>&1
EXIT_CODE=$?

MOCK_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "Mock_adapter_sourcing_succeeds" "$EXIT_CODE"
assert_eq "Mock_function_callable_after_sourcing" "hello from mock adapter" "$MOCK_OUTPUT"

echo ""

# --- Test Group 3: Error on missing adapter directory ---
echo "Test Group: Error on missing adapter directory"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"/nonexistent/adapter/path\"
  source \"$PM_SH\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
ERROR_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_nonzero "Error_exit_when_adapter_dir_missing" "$EXIT_CODE"

# Verify error message mentions the adapter
if echo "$ERROR_OUTPUT" | grep -qi "error\|not found\|does not exist"; then
  echo "  PASS: Error_message_mentions_missing_adapter"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Error_message_mentions_missing_adapter (got: $ERROR_OUTPUT)"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test Group 4: Error on empty adapter directory ---
echo "Test Group: Error on empty adapter directory"

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
echo "Test Group: Idempotent sourcing (source twice, no errors or duplicate function warnings)"

MOCK_ADAPTER_DIR2=$(mktemp -d)
MOCK_ADAPTER_DIR2="${MOCK_ADAPTER_DIR2}/mock2"
mkdir -p "$MOCK_ADAPTER_DIR2"
cat > "$MOCK_ADAPTER_DIR2/idempotent_module.sh" <<'IDEMPOTENT'
pm_idempotent_test() {
  echo "idempotent"
}
IDEMPOTENT

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"$MOCK_ADAPTER_DIR2\"
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

# --- Test Group 6: Exported variables ---
echo "Test Group: Exported variables (SCRIPT_DIR, REPO_ROOT, PM_ADAPTER_DIR)"

MOCK_ADAPTER_DIR3=$(mktemp -d)
MOCK_ADAPTER_DIR3="${MOCK_ADAPTER_DIR3}/mock3"
mkdir -p "$MOCK_ADAPTER_DIR3"
cat > "$MOCK_ADAPTER_DIR3/vars_module.sh" <<'VARS_MODULE'
pm_print_vars() {
  echo "PM_ADAPTER_DIR=$PM_ADAPTER_DIR"
  echo "REPO_ROOT=$REPO_ROOT"
}
VARS_MODULE

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"$MOCK_ADAPTER_DIR3\"
  source \"$PM_SH\"
  pm_print_vars
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
VARS_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "Variables_exported_successfully" "$EXIT_CODE"

# PM_ADAPTER_DIR should point to the mock dir
if echo "$VARS_OUTPUT" | grep -q "PM_ADAPTER_DIR=$MOCK_ADAPTER_DIR3"; then
  echo "  PASS: PM_ADAPTER_DIR_exported_correctly"
  PASS=$((PASS + 1))
else
  echo "  FAIL: PM_ADAPTER_DIR_exported_correctly (got: $VARS_OUTPUT)"
  FAIL=$((FAIL + 1))
fi

# REPO_ROOT should point to the repo root
if echo "$VARS_OUTPUT" | grep -q "REPO_ROOT=$REPO_ROOT"; then
  echo "  PASS: REPO_ROOT_exported_correctly"
  PASS=$((PASS + 1))
else
  echo "  FAIL: REPO_ROOT_exported_correctly (got: $VARS_OUTPUT)"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test Group 7: Alphabetical module loading ---
echo "Test Group: Alphabetical module loading order"

MOCK_ADAPTER_DIR4=$(mktemp -d)
MOCK_ADAPTER_DIR4="${MOCK_ADAPTER_DIR4}/mock4"
mkdir -p "$MOCK_ADAPTER_DIR4"

# Create two modules in non-alphabetical-on-disk order
cat > "$MOCK_ADAPTER_DIR4/b_second.sh" <<'SECOND'
pm_alpha_order_second() {
  echo "second"
}
SECOND

cat > "$MOCK_ADAPTER_DIR4/a_first.sh" <<'FIRST'
pm_alpha_order_first() {
  echo "first"
}
FIRST

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export _PM_TEST_ADAPTER_DIR=\"$MOCK_ADAPTER_DIR4\"
  source \"$PM_SH\"
  pm_alpha_order_first
  pm_alpha_order_second
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
ALPHA_OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "Alphabetical_loading_both_modules_loaded" "$EXIT_CODE"
assert_eq "Alphabetical_loading_first_module_callable" "$(echo "$ALPHA_OUTPUT" | head -1)" "first"
assert_eq "Alphabetical_loading_second_module_callable" "$(echo "$ALPHA_OUTPUT" | tail -1)" "second"

echo ""

# --- Test Group 8: Real github adapter directory structure ---
echo "Test Group: Real adapter directory structure"

if [ -d "$ADAPTERS_DIR/github" ]; then
  echo "  PASS: adapters/pm/github/ exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: adapters/pm/github/ not found"
  FAIL=$((FAIL + 1))
fi

# pm.sh should source config.sh
if grep -q "config.sh" "$PM_SH" 2>/dev/null; then
  echo "  PASS: pm.sh references config.sh"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm.sh does not reference config.sh"
  FAIL=$((FAIL + 1))
fi

# pm.sh should reference CFG_PM_ADAPTER
if grep -q "CFG_PM_ADAPTER" "$PM_SH" 2>/dev/null; then
  echo "  PASS: pm.sh references CFG_PM_ADAPTER"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm.sh does not reference CFG_PM_ADAPTER"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Cleanup ---
rm -rf "$MOCK_ADAPTER_DIR" "$MOCK_ADAPTER_DIR2" "$MOCK_ADAPTER_DIR3" "$MOCK_ADAPTER_DIR4" 2>/dev/null || true

# --- Summary ---
echo "========================================"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
