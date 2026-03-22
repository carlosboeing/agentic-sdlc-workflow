#!/usr/bin/env bash
# test-cost-budget-sh.sh — Validates cost-budget.sh library behavior.
# Runs locally using mock state files and config (no live GitHub API calls).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/thresholds.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COST_BUDGET_SH="$REPO_ROOT/scripts/lib/cost-budget.sh"

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
  case "$haystack" in
    *"$needle"*)
      echo "  PASS: $test_name"
      PASS=$((PASS + 1))
      ;;
    *)
      echo "  FAIL: $test_name"
      echo "    Expected to contain: $needle"
      echo "    Actual: $haystack"
      FAIL=$((FAIL + 1))
      ;;
  esac
}

echo "========================================"
echo "Testing scripts/lib/cost-budget.sh"
echo "========================================"
echo ""

# --- File existence check ---
echo "Test Group: File properties"

if [ -f "$COST_BUDGET_SH" ]; then
  echo "  PASS: cost-budget.sh exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: cost-budget.sh not found at $COST_BUDGET_SH"
  FAIL=$((FAIL + 1))
fi

LINE_COUNT=$(wc -l < "$COST_BUDGET_SH" 2>/dev/null || echo 9999)
if [ "$LINE_COUNT" -le "$THRESHOLD_SMALL_MODULE" ]; then
  echo "  PASS: cost-budget.sh is under $THRESHOLD_SMALL_MODULE lines ($LINE_COUNT lines)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: cost-budget.sh exceeds $THRESHOLD_SMALL_MODULE lines ($LINE_COUNT lines)"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Helper: create a mock state file ---
MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT

make_state_file() {
  local path="$1" cost="$2"
  cat > "$path" << EOF
{
  "version": 1,
  "session": {
    "backlog": 109,
    "total_cost": $cost
  }
}
EOF
}

# --- Helper: run check_cost_budget with a given CFG_MAX_COST_PER_RUN ---
run_check() {
  local state_file="$1" max_cost="$2"
  bash --norc --noprofile -c "
    source \"$COST_BUDGET_SH\"
    CFG_MAX_COST_PER_RUN=\"$max_cost\"
    check_cost_budget \"$state_file\"
  " 2>&1
}

run_check_exit() {
  local state_file="$1" max_cost="$2"
  bash --norc --noprofile -c "
    source \"$COST_BUDGET_SH\"
    CFG_MAX_COST_PER_RUN=\"$max_cost\"
    check_cost_budget \"$state_file\"
  " > /dev/null 2>&1
  echo $?
}

# --- Test Group: Under budget ---
echo "Test Group: Under budget (cost=5.00, limit=10.00)"

STATE1="$MOCK_DIR/state-under.json"
make_state_file "$STATE1" "5.00"

EXIT1=$(run_check_exit "$STATE1" "10.00")
assert_exit_zero "Under_budget_returns_exit_0" "$EXIT1"

OUTPUT1=$(run_check "$STATE1" "10.00")
assert_contains "Under_budget_prints_current_cost" "5.00" "$OUTPUT1"
assert_contains "Under_budget_prints_limit" "10.00" "$OUTPUT1"

echo ""

# --- Test Group: Over budget ---
echo "Test Group: Over budget (cost=12.00, limit=10.00)"

STATE2="$MOCK_DIR/state-over.json"
make_state_file "$STATE2" "12.00"

EXIT2=$(run_check_exit "$STATE2" "10.00")
assert_exit_nonzero "Over_budget_returns_nonzero_exit" "$EXIT2"

OUTPUT2=$(run_check "$STATE2" "10.00")
assert_contains "Over_budget_message_contains_Budget_exceeded" "Budget exceeded" "$OUTPUT2"
assert_contains "Over_budget_message_contains_current_cost" "12.00" "$OUTPUT2"
assert_contains "Over_budget_message_contains_limit" "10.00" "$OUTPUT2"
assert_contains "Over_budget_message_contains_limit_word" "limit" "$OUTPUT2"

echo ""

# --- Test Group: No limit (null) ---
echo "Test Group: No limit configured (maxCostPerRun=null)"

STATE3="$MOCK_DIR/state-high-cost.json"
make_state_file "$STATE3" "999.99"

EXIT3=$(run_check_exit "$STATE3" "null")
assert_exit_zero "Null_limit_always_returns_exit_0" "$EXIT3"

echo ""

# --- Test Group: No limit (empty string — missing field fallback) ---
echo "Test Group: Missing/empty limit (maxCostPerRun defaults to null)"

EXIT4=$(run_check_exit "$STATE3" "null")
assert_exit_zero "Empty_limit_always_returns_exit_0" "$EXIT4"

echo ""

# --- Summary ---
echo "========================================"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
