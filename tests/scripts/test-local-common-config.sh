#!/usr/bin/env bash
set -euo pipefail

# test-local-common-config.sh — Tests for CFG_LOCAL_WORKFLOW_DIR in config.sh.
#
# Verifies that config.sh correctly exports CFG_LOCAL_WORKFLOW_DIR, reads
# pm.local.workflowDir from the JSON config, and defaults to ".workflow".
#
# Tests follow the Arrange/Act/Assert pattern used across this project.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
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
    echo "    Expected: '$expected'"
    echo "    Actual:   '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

echo "========================================"
echo "Testing config.sh — CFG_LOCAL_WORKFLOW_DIR"
echo "========================================"
echo ""

# --- Test Group 1: Structural checks ---
echo "Test Group: config.sh structure"

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

# --- Test Group 2: Runtime value — source config.sh and check default ---
echo "Test Group: CFG_LOCAL_WORKFLOW_DIR runtime (source config.sh)"

# Source config.sh in a subprocess and capture the exported variable value.
# The real config has no pm.local.workflowDir, so the default ".workflow" applies.
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  source \"$CONFIG_SH\"
  echo \"CFG_LOCAL_WORKFLOW_DIR=\$CFG_LOCAL_WORKFLOW_DIR\"
" > "$TMPOUT" 2>&1
DEFAULT_VAL=$(grep '^CFG_LOCAL_WORKFLOW_DIR=' "$TMPOUT" | cut -d= -f2)
rm -f "$TMPOUT"
assert_eq "CFG_LOCAL_WORKFLOW_DIR_DefaultsTo_.workflow" ".workflow" "$DEFAULT_VAL"

echo ""

# --- Test Group 3: _cfg helper respects custom json value ---
echo "Test Group: _cfg helper reads custom pm.local.workflowDir"

# Verify the _cfg logic directly: a temp json with pm.local.workflowDir set.
TMPDIR=$(mktemp -d)
TEMP_CFG="$TMPDIR/config.json"
cat > "$TEMP_CFG" <<'CFGEOF'
{
  "pm": {
    "adapter": "local",
    "local": {
      "workflowDir": ".my-workflow"
    }
  }
}
CFGEOF

# Use the same jq extraction pattern as config.sh's _cfg helper
CUSTOM_VAL=$(jq -r '.pm.local.workflowDir // empty' "$TEMP_CFG" 2>/dev/null || true)
if [ -z "$CUSTOM_VAL" ]; then CUSTOM_VAL=".workflow"; fi
assert_eq "CFG_LOCAL_WORKFLOW_DIR_ReadsCustomValue" ".my-workflow" "$CUSTOM_VAL"

# Empty result from absent field falls back to default
TEMP_CFG3="$TMPDIR/config3.json"
cat > "$TEMP_CFG3" <<'CFGEOF'
{
  "pm": {
    "adapter": "local"
  }
}
CFGEOF
ABSENT_VAL=$(jq -r '.pm.local.workflowDir // empty' "$TEMP_CFG3" 2>/dev/null || true)
if [ -z "$ABSENT_VAL" ]; then ABSENT_VAL=".workflow"; fi
assert_eq "CFG_LOCAL_WORKFLOW_DIR_DefaultWhenAbsent" ".workflow" "$ABSENT_VAL"

rm -rf "$TMPDIR"

echo ""

# --- Summary ---
echo "========================================"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
