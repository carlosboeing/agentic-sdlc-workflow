#!/usr/bin/env bash
set -euo pipefail

# test-validate-logs.sh — Validates validate-logs.sh behavior.
# Tests the new Board Drift Log section and existing sections.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_UNDER_TEST="$REPO_ROOT/scripts/validate-logs.sh"

# Create temporary test directory
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

PASS=0
FAIL=0

assert_contains() {
  local test_name="$1"
  local pattern="$2"
  local text="$3"
  if echo "$text" | grep -qF -- "$pattern"; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    Expected to contain: $pattern"
    echo "    Actual: $text"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local test_name="$1"
  local pattern="$2"
  local text="$3"
  if ! echo "$text" | grep -qF -- "$pattern"; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    Expected NOT to contain: $pattern"
    echo "    Actual: $text"
    FAIL=$((FAIL + 1))
  fi
}

assert_exit_code() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    Expected exit code: $expected"
    echo "    Actual exit code:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

# Create test logs directory
LOG_DIR="$TEST_DIR/.claude/logs"
mkdir -p "$LOG_DIR"

# Mock the BOARD_LOG, ORCH_LOG, and DRIFT_LOG paths by creating a wrapper script
VALIDATE_SCRIPT="$TEST_DIR/validate-logs-test.sh"
cp "$SCRIPT_UNDER_TEST" "$VALIDATE_SCRIPT"

# Replace the log paths in the wrapper to point to our test directory
sed -i.bak \
  -e "s|BOARD_LOG=\".*\"|BOARD_LOG=\"$LOG_DIR/board-status.log\"|" \
  -e "s|ORCH_LOG=\".*\"|ORCH_LOG=\"$LOG_DIR/orchestrator.log\"|" \
  -e "s|DRIFT_LOG=\".*\"|DRIFT_LOG=\"$LOG_DIR/board-drift.log\"|" \
  "$VALIDATE_SCRIPT"

echo "Test Suite: validate-logs.sh"
echo ""

# Test 1: No drift log exists
echo "Test Group 1: Missing drift log"
output=$("$VALIDATE_SCRIPT" 2>&1)
assert_exit_code "Exit code 0 when drift log missing" "0" "$?"
assert_contains "Drift log NOT FOUND message" "NOT FOUND -- no drift checks have been run" "$output"
echo ""

# Test 2: Empty drift log
echo "Test Group 2: Empty drift log"
touch "$LOG_DIR/board-drift.log"
output=$("$VALIDATE_SCRIPT" 2>&1)
assert_contains "Empty drift log section header" "Board Drift Log" "$output"
assert_contains "Total entries for empty log" "Total entries:" "$output"
echo ""

# Test 3: Drift log with only NO_DRIFT events
echo "Test Group 3: Drift log with NO_DRIFT events"
cat > "$LOG_DIR/board-drift.log" << 'EOF'
[2026-03-14T10:30:00Z] issue=46 target=in-progress set=OK verify_10s=OK verify_30s=OK result=NO_DRIFT
[2026-03-14T10:31:00Z] issue=47 target=in-review set=OK verify_10s=OK verify_30s=OK result=NO_DRIFT
[2026-03-14T10:32:00Z] issue=48 target=done set=OK verify_10s=OK verify_30s=OK result=NO_DRIFT
EOF
output=$("$VALIDATE_SCRIPT" 2>&1)
assert_contains "Board Drift Log section" "Board Drift Log" "$output"
assert_contains "Total entries count" "Total entries:" "$output"
assert_contains "NO_DRIFT count" "NO_DRIFT:" "$output"
assert_not_contains "No WARNING for NO_DRIFT only" "WARNING" "$output"
echo ""

# Test 4: Drift log with both NO_DRIFT and DRIFT events
echo "Test Group 4: Drift log with DRIFT events"
cat > "$LOG_DIR/board-drift.log" << 'EOF'
[2026-03-14T10:30:00Z] issue=46 target=in-progress set=OK verify_10s=OK verify_30s=OK result=NO_DRIFT
[2026-03-14T10:31:00Z] issue=47 target=in-review set=OK verify_10s=DRIFT(actual=todo) verify_30s=DRIFT(actual=todo) result=DRIFT
[2026-03-14T10:32:00Z] issue=48 target=done set=OK verify_10s=OK verify_30s=OK result=NO_DRIFT
[2026-03-14T10:33:00Z] issue=49 target=in-progress set=OK verify_10s=OK verify_30s=DRIFT(actual=todo) result=DRIFT
EOF
output=$("$VALIDATE_SCRIPT" 2>&1)
assert_contains "Board Drift Log section" "Board Drift Log" "$output"
assert_contains "NO_DRIFT count should be 2" "NO_DRIFT:" "$output"
assert_contains "DRIFT count should be 2" "DRIFT:" "$output"
assert_contains "WARNING header for DRIFT events" "WARNING: DRIFT EVENTS FOUND" "$output"
assert_contains "First DRIFT event in warning" "issue=47" "$output"
assert_contains "Second DRIFT event in warning" "issue=49" "$output"
echo ""

# Test 5: Section appears between Orchestrator and End Report
echo "Test Group 5: Section placement"
cat > "$LOG_DIR/orchestrator.log" << 'EOF'
[2026-03-14T10:00:00Z] tool=Bash duration=100 status=success
EOF
cat > "$LOG_DIR/board-drift.log" << 'EOF'
[2026-03-14T10:30:00Z] issue=46 target=in-progress set=OK verify_10s=OK verify_30s=OK result=NO_DRIFT
EOF
output=$("$VALIDATE_SCRIPT" 2>&1)
assert_contains "Orchestrator Log appears" "Orchestrator Log" "$output"
assert_contains "Board Drift Log appears" "Board Drift Log" "$output"
assert_contains "End Report appears" "=== End Report ===" "$output"
# Verify order: Orchestrator before Drift, Drift before End Report
line_orch=$(echo "$output" | grep -n "Orchestrator Log" | cut -d: -f1)
line_drift=$(echo "$output" | grep -n "Board Drift Log" | cut -d: -f1)
line_end=$(echo "$output" | grep -n "=== End Report ===" | cut -d: -f1)
if [ "$line_orch" -lt "$line_drift" ] && [ "$line_drift" -lt "$line_end" ]; then
  echo "  PASS: Section ordering is correct (Orch < Drift < End)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Section ordering is incorrect"
  echo "    Orchestrator line: $line_orch"
  echo "    Drift line: $line_drift"
  echo "    End Report line: $line_end"
  FAIL=$((FAIL + 1))
fi
echo ""

# Test 6: Existing Board Status Log still works
echo "Test Group 6: Existing sections (regressions)"
cat > "$LOG_DIR/board-status.log" << 'EOF'
[2026-03-14T10:00:00Z] issue=46 START in-progress
[2026-03-14T10:01:00Z] issue=46 MUTATION status=in-progress confirm=pending
[2026-03-14T10:02:00Z] issue=46 VERIFY_OK
EOF
output=$("$VALIDATE_SCRIPT" 2>&1)
assert_contains "Board Status Log header" "Board Status Log" "$output"
assert_contains "Board Status START count" "START:" "$output"
assert_contains "Board Status MUTATION count" "MUTATION:" "$output"
assert_contains "Board Status VERIFY_OK count" "VERIFY_OK:" "$output"
echo ""

# Test 7: DRIFT count excludes NO_DRIFT
echo "Test Group 7: DRIFT count accuracy"
cat > "$LOG_DIR/board-drift.log" << 'EOF'
[2026-03-14T10:30:00Z] issue=46 target=in-progress set=OK verify_10s=OK verify_30s=OK result=NO_DRIFT
[2026-03-14T10:31:00Z] issue=47 target=in-review set=OK verify_10s=DRIFT(actual=todo) verify_30s=DRIFT(actual=todo) result=DRIFT
[2026-03-14T10:32:00Z] issue=48 target=done set=OK verify_10s=OK verify_30s=DRIFT(actual=todo) result=DRIFT
EOF
output=$("$VALIDATE_SCRIPT" 2>&1)
# Count occurrences
drift_count=$(echo "$output" | grep "DRIFT:" | grep -oE '[0-9]+$' | tail -1)
no_drift_count=$(echo "$output" | grep "NO_DRIFT:" | grep -oE '[0-9]+$' | tail -1)
if [ "$drift_count" = "2" ]; then
  echo "  PASS: DRIFT count correctly reports 2"
  PASS=$((PASS + 1))
else
  echo "  FAIL: DRIFT count is $drift_count, expected 2"
  FAIL=$((FAIL + 1))
fi
if [ "$no_drift_count" = "1" ]; then
  echo "  PASS: NO_DRIFT count correctly reports 1"
  PASS=$((PASS + 1))
else
  echo "  FAIL: NO_DRIFT count is $no_drift_count, expected 1"
  FAIL=$((FAIL + 1))
fi
echo ""

# Print summary
echo "=== Test Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
if [ $FAIL -eq 0 ]; then
  exit 0
else
  exit 1
fi
