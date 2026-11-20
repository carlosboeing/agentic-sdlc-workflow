#!/usr/bin/env bash
set -euo pipefail

# test-config-sh.sh — Validates config.sh variable exports and defaults.
# Runs locally without invoking claude or making real GitHub API calls.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_SH="$REPO_ROOT/scripts/lib/config.sh"
# Fully configured fixture board, not the (empty) repository config.
CONFIG_JSON="$REPO_ROOT/tests/fixtures/config/github-board.json"
export _CFG_FILE_OVERRIDE="$CONFIG_JSON"

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

assert_file_contains() {
  local test_name="$1"
  local pattern="$2"
  local file="$3"
  if grep -q "$pattern" "$file" 2>/dev/null; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (pattern '$pattern' not found in $file)"
    FAIL=$((FAIL + 1))
  fi
}

echo "========================================"
echo "Testing scripts/lib/config.sh"
echo "========================================"
echo ""

# --- Test Group 1: File properties ---
echo "Test Group: File properties"

if [ -f "$CONFIG_SH" ]; then
  echo "  PASS: config.sh exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: config.sh not found at $CONFIG_SH"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test Group 2: New PM adapter variables (sourcing real config) ---
echo "Test Group: New PM adapter variables from real config"

# Source config.sh in a temp file and capture exported values
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  source \"$CONFIG_SH\"
  echo \"CFG_PM_ADAPTER=\$CFG_PM_ADAPTER\"
  echo \"CFG_MAX_COST_PER_RUN=\$CFG_MAX_COST_PER_RUN\"
" > "$TMPOUT" 2>&1

CFG_PM_ADAPTER_VAL=$(grep '^CFG_PM_ADAPTER=' "$TMPOUT" | cut -d= -f2)
CFG_MAX_COST_VAL=$(grep '^CFG_MAX_COST_PER_RUN=' "$TMPOUT" | cut -d= -f2)
rm -f "$TMPOUT"

assert_eq "CFG_PM_ADAPTER_From_Config_Is_github" "github" "$CFG_PM_ADAPTER_VAL"
assert_eq "CFG_MAX_COST_PER_RUN_From_Config_Is_null" "null" "$CFG_MAX_COST_VAL"

echo ""

# --- Test Group 3: Existing variables unchanged ---
echo "Test Group: Existing variables unchanged"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  source \"$CONFIG_SH\"
  echo \"CFG_REPO=\$CFG_REPO\"
  echo \"CFG_PROJECT_NUMBER=\$CFG_PROJECT_NUMBER\"
  echo \"CFG_PROJECT_OWNER=\$CFG_PROJECT_OWNER\"
  echo \"CFG_STATUS_BACKLOG=\$CFG_STATUS_BACKLOG\"
  echo \"CFG_STATUS_IN_PROGRESS=\$CFG_STATUS_IN_PROGRESS\"
  echo \"CFG_STATUS_IN_REVIEW=\$CFG_STATUS_IN_REVIEW\"
  echo \"CFG_STATUS_DONE=\$CFG_STATUS_DONE\"
  echo \"CFG_ROUTE_EASY=\$CFG_ROUTE_EASY\"
  echo \"CFG_ROUTE_MEDIUM=\$CFG_ROUTE_MEDIUM\"
  echo \"CFG_ROUTE_HARD=\$CFG_ROUTE_HARD\"
" > "$TMPOUT" 2>&1

get_val() { grep "^$1=" "$TMPOUT" | cut -d= -f2; }

assert_eq "CFG_REPO_IsSet" "example-org/example-repo" "$(get_val CFG_REPO)"
assert_eq "CFG_PROJECT_NUMBER_IsSet" "7" "$(get_val CFG_PROJECT_NUMBER)"
assert_eq "CFG_PROJECT_OWNER_IsSet" "example-org" "$(get_val CFG_PROJECT_OWNER)"
assert_eq "CFG_STATUS_BACKLOG_IsSet" "opt-backlog" "$(get_val CFG_STATUS_BACKLOG)"
assert_eq "CFG_STATUS_IN_PROGRESS_IsSet" "opt-in-progress" "$(get_val CFG_STATUS_IN_PROGRESS)"
assert_eq "CFG_STATUS_IN_REVIEW_IsSet" "opt-in-review" "$(get_val CFG_STATUS_IN_REVIEW)"
assert_eq "CFG_STATUS_DONE_IsSet" "opt-done" "$(get_val CFG_STATUS_DONE)"
assert_eq "CFG_ROUTE_EASY_IsSet" "sonnet" "$(get_val CFG_ROUTE_EASY)"
assert_eq "CFG_ROUTE_MEDIUM_IsSet" "sonnet" "$(get_val CFG_ROUTE_MEDIUM)"
assert_eq "CFG_ROUTE_HARD_IsSet" "opus" "$(get_val CFG_ROUTE_HARD)"
rm -f "$TMPOUT"

echo ""

# --- Test Group 4: Defaults when pm section absent from config ---
echo "Test Group: Defaults when pm section absent"

TEMP_CFG=$(mktemp)
cat > "$TEMP_CFG" <<'CFGEOF'
{
  "github": {
    "repo": "test/repo",
    "projectNumber": 99,
    "owner": "test",
    "projectId": "PVT_test",
    "statusFieldId": "PVTSSF_test"
  },
  "workflow": {
    "autoMergePlanPR": true,
    "autoMergeDesignPR": true,
    "skipRetro": false,
    "maxParallelBuilders": 3
  }
}
CFGEOF

# Test .pm.adapter default via jq (same logic as _cfg helper)
val=$(jq -r '.pm.adapter // empty' "$TEMP_CFG" 2>/dev/null || true)
if [ -z "$val" ]; then val="github"; fi
assert_eq "CFG_PM_ADAPTER_DefaultsTo_github_WhenAbsent" "github" "$val"

# Test .workflow.maxCostPerRun default via jq
val=$(jq -r '.workflow.maxCostPerRun // empty' "$TEMP_CFG" 2>/dev/null || true)
if [ -z "$val" ]; then val="null"; fi
assert_eq "CFG_MAX_COST_PER_RUN_DefaultsTo_null_WhenAbsent" "null" "$val"

rm -f "$TEMP_CFG"

echo ""

# --- Test Group 5: Custom pm.adapter value ---
echo "Test Group: Custom pm.adapter value"

TEMP_CFG2=$(mktemp)
cat > "$TEMP_CFG2" <<'CFGEOF'
{
  "github": {
    "repo": "test/repo",
    "projectNumber": 99,
    "owner": "test",
    "projectId": "PVT_test",
    "statusFieldId": "PVTSSF_test"
  },
  "pm": {
    "adapter": "local"
  },
  "workflow": {
    "autoMergePlanPR": true,
    "autoMergeDesignPR": true,
    "skipRetro": false,
    "maxParallelBuilders": 3,
    "maxCostPerRun": 5
  }
}
CFGEOF

val=$(jq -r '.pm.adapter // empty' "$TEMP_CFG2" 2>/dev/null || true)
if [ -z "$val" ]; then val="github"; fi
assert_eq "CFG_PM_ADAPTER_ReadsCustomValue_local" "local" "$val"

val=$(jq -r '.workflow.maxCostPerRun // empty' "$TEMP_CFG2" 2>/dev/null || true)
if [ -z "$val" ]; then val="null"; fi
assert_eq "CFG_MAX_COST_PER_RUN_ReadsCustomValue_5" "5" "$val"

rm -f "$TEMP_CFG2"

echo ""

# --- Test Group 6: Config JSON structure ---
echo "Test Group: Config JSON structure"

if [ -f "$CONFIG_JSON" ]; then
  PM_ADAPTER=$(jq -r '.pm.adapter // empty' "$CONFIG_JSON" 2>/dev/null || true)
  assert_eq "ConfigJSON_Has_pm_adapter_github" "github" "$PM_ADAPTER"

  MAX_COST=$(jq -r '.workflow.maxCostPerRun' "$CONFIG_JSON" 2>/dev/null || true)
  assert_eq "ConfigJSON_Has_workflow_maxCostPerRun_null" "null" "$MAX_COST"

  AUTO_MERGE_PLAN=$(jq -r '.workflow.autoMergePlanPR' "$CONFIG_JSON" 2>/dev/null || true)
  assert_eq "ConfigJSON_workflow_autoMergePlanPR_Unchanged" "true" "$AUTO_MERGE_PLAN"

  MAX_PARALLEL=$(jq -r '.workflow.maxParallelBuilders' "$CONFIG_JSON" 2>/dev/null || true)
  assert_eq "ConfigJSON_workflow_maxParallelBuilders_Unchanged" "3" "$MAX_PARALLEL"

  # New: workflowDir at top level
  WORKFLOW_DIR=$(jq -r '.workflowDir // empty' "$CONFIG_JSON" 2>/dev/null || true)
  assert_eq "ConfigJSON_Has_toplevel_workflowDir_dotworkflow" ".workflow" "$WORKFLOW_DIR"
else
  echo "  SKIP: Config JSON not found at $CONFIG_JSON"
fi

echo ""

# --- Test Group 7: config.sh exports new variables ---
echo "Test Group: config.sh exports CFG_PM_ADAPTER and CFG_MAX_COST_PER_RUN"

assert_file_contains "config.sh_defines_CFG_PM_ADAPTER" "CFG_PM_ADAPTER" "$CONFIG_SH"
assert_file_contains "config.sh_defines_CFG_MAX_COST_PER_RUN" "CFG_MAX_COST_PER_RUN" "$CONFIG_SH"
assert_file_contains "config.sh_reads_pm_adapter_from_JSON" "\.pm\.adapter" "$CONFIG_SH"
assert_file_contains "config.sh_reads_workflow_maxCostPerRun_from_JSON" "\.workflow\.maxCostPerRun" "$CONFIG_SH"

echo ""

# --- Test Group 8: CFG_WORKFLOW_DIR top-level read ---
echo "Test Group: CFG_WORKFLOW_DIR reads top-level workflowDir"

# Config with top-level workflowDir
TEMP_CFG_WD=$(mktemp)
cat > "$TEMP_CFG_WD" <<'CFGEOF'
{
  "workflowDir": ".my-workflow",
  "github": {
    "repo": "test/repo",
    "projectNumber": 99,
    "owner": "test",
    "projectId": "PVT_test",
    "statusFieldId": "PVTSSF_test"
  }
}
CFGEOF

TMPOUT=$(mktemp)
_CFG_FILE_OVERRIDE="$TEMP_CFG_WD" bash --norc --noprofile -c "
  source \"$CONFIG_SH\"
  echo \"CFG_WORKFLOW_DIR=\$CFG_WORKFLOW_DIR\"
  echo \"CFG_LOCAL_WORKFLOW_DIR=\$CFG_LOCAL_WORKFLOW_DIR\"
" > "$TMPOUT" 2>&1

WD_VAL=$(grep '^CFG_WORKFLOW_DIR=' "$TMPOUT" | cut -d= -f2)
LWD_VAL=$(grep '^CFG_LOCAL_WORKFLOW_DIR=' "$TMPOUT" | cut -d= -f2)
rm -f "$TMPOUT" "$TEMP_CFG_WD"

assert_eq "CFG_WORKFLOW_DIR_ReadsTopLevel_workflowDir" ".my-workflow" "$WD_VAL"
assert_eq "CFG_LOCAL_WORKFLOW_DIR_AliasMatchesCFG_WORKFLOW_DIR" ".my-workflow" "$LWD_VAL"

echo ""

# --- Test Group 9: CFG_WORKFLOW_DIR default ---
echo "Test Group: CFG_WORKFLOW_DIR default when workflowDir absent"

TEMP_CFG_WD2=$(mktemp)
cat > "$TEMP_CFG_WD2" <<'CFGEOF'
{
  "github": {
    "repo": "test/repo",
    "projectNumber": 99,
    "owner": "test",
    "projectId": "PVT_test",
    "statusFieldId": "PVTSSF_test"
  }
}
CFGEOF

TMPOUT=$(mktemp)
_CFG_FILE_OVERRIDE="$TEMP_CFG_WD2" bash --norc --noprofile -c "
  source \"$CONFIG_SH\"
  echo \"CFG_WORKFLOW_DIR=\$CFG_WORKFLOW_DIR\"
" > "$TMPOUT" 2>&1

WD_VAL=$(grep '^CFG_WORKFLOW_DIR=' "$TMPOUT" | cut -d= -f2)
rm -f "$TMPOUT" "$TEMP_CFG_WD2"

assert_eq "CFG_WORKFLOW_DIR_DefaultsTo_dotworkflow_WhenAbsent" ".workflow" "$WD_VAL"

echo ""

# --- Test Group 10: CFG_WORKFLOW_DIR backward compat from pm.local.workflowDir ---
echo "Test Group: CFG_WORKFLOW_DIR backward compat (pm.local.workflowDir fallback)"

TEMP_CFG_WD3=$(mktemp)
cat > "$TEMP_CFG_WD3" <<'CFGEOF'
{
  "github": {
    "repo": "test/repo",
    "projectNumber": 99,
    "owner": "test",
    "projectId": "PVT_test",
    "statusFieldId": "PVTSSF_test"
  },
  "pm": {
    "adapter": "github",
    "local": {
      "workflowDir": ".old-workflow"
    }
  }
}
CFGEOF

TMPOUT=$(mktemp)
_CFG_FILE_OVERRIDE="$TEMP_CFG_WD3" bash --norc --noprofile -c "
  source \"$CONFIG_SH\"
  echo \"CFG_WORKFLOW_DIR=\$CFG_WORKFLOW_DIR\"
  echo \"CFG_LOCAL_WORKFLOW_DIR=\$CFG_LOCAL_WORKFLOW_DIR\"
" > "$TMPOUT" 2>&1

WD_VAL=$(grep '^CFG_WORKFLOW_DIR=' "$TMPOUT" | cut -d= -f2)
LWD_VAL=$(grep '^CFG_LOCAL_WORKFLOW_DIR=' "$TMPOUT" | cut -d= -f2)
rm -f "$TMPOUT" "$TEMP_CFG_WD3"

assert_eq "CFG_WORKFLOW_DIR_BackwardCompat_UsesOldPmLocalWorkflowDir" ".old-workflow" "$WD_VAL"
assert_eq "CFG_LOCAL_WORKFLOW_DIR_BackwardCompat_AliasMatchesCFG_WORKFLOW_DIR" ".old-workflow" "$LWD_VAL"

echo ""

# --- Test Group 11: CFG_WORKFLOW_DIR top-level wins over pm.local.workflowDir ---
echo "Test Group: CFG_WORKFLOW_DIR top-level takes precedence over pm.local.workflowDir"

TEMP_CFG_WD4=$(mktemp)
cat > "$TEMP_CFG_WD4" <<'CFGEOF'
{
  "workflowDir": ".top-level-wins",
  "github": {
    "repo": "test/repo",
    "projectNumber": 99,
    "owner": "test",
    "projectId": "PVT_test",
    "statusFieldId": "PVTSSF_test"
  },
  "pm": {
    "adapter": "github",
    "local": {
      "workflowDir": ".old-should-be-ignored"
    }
  }
}
CFGEOF

TMPOUT=$(mktemp)
_CFG_FILE_OVERRIDE="$TEMP_CFG_WD4" bash --norc --noprofile -c "
  source \"$CONFIG_SH\"
  echo \"CFG_WORKFLOW_DIR=\$CFG_WORKFLOW_DIR\"
" > "$TMPOUT" 2>&1

WD_VAL=$(grep '^CFG_WORKFLOW_DIR=' "$TMPOUT" | cut -d= -f2)
rm -f "$TMPOUT" "$TEMP_CFG_WD4"

assert_eq "CFG_WORKFLOW_DIR_TopLevel_WinsOverPmLocal" ".top-level-wins" "$WD_VAL"

echo ""

# --- Test Group 12: config.sh defines CFG_WORKFLOW_DIR ---
echo "Test Group: config.sh defines CFG_WORKFLOW_DIR and alias"

assert_file_contains "config.sh_defines_CFG_WORKFLOW_DIR" "CFG_WORKFLOW_DIR" "$CONFIG_SH"
assert_file_contains "config.sh_defines_CFG_LOCAL_WORKFLOW_DIR" "CFG_LOCAL_WORKFLOW_DIR" "$CONFIG_SH"
assert_file_contains "config.sh_reads_toplevel_workflowDir_from_JSON" "\.workflowDir" "$CONFIG_SH"

echo ""

# --- Test Group 13: CFG_SKIP_REVIEW_* reads from real config ---
echo "Test Group: CFG_SKIP_REVIEW_* variables from real config"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  source \"$CONFIG_SH\"
  echo \"CFG_SKIP_REVIEW_ENABLED=\$CFG_SKIP_REVIEW_ENABLED\"
  echo \"CFG_SKIP_REVIEW_MAX_DIFFICULTY=\$CFG_SKIP_REVIEW_MAX_DIFFICULTY\"
  echo \"CFG_SKIP_REVIEW_REQUIRE_LABEL=\$CFG_SKIP_REVIEW_REQUIRE_LABEL\"
" > "$TMPOUT" 2>&1

get_val2() { grep "^$1=" "$TMPOUT" | cut -d= -f2; }

assert_eq "CFG_SKIP_REVIEW_ENABLED_From_Config_Is_true" "true" "$(get_val2 CFG_SKIP_REVIEW_ENABLED)"
assert_eq "CFG_SKIP_REVIEW_MAX_DIFFICULTY_From_Config_Is_easy" "easy" "$(get_val2 CFG_SKIP_REVIEW_MAX_DIFFICULTY)"
assert_eq "CFG_SKIP_REVIEW_REQUIRE_LABEL_From_Config_Is_test-agentic-sdlc" "test-agentic-sdlc" "$(get_val2 CFG_SKIP_REVIEW_REQUIRE_LABEL)"
rm -f "$TMPOUT"

echo ""

# --- Test Group 14: CFG_SKIP_REVIEW_* defaults when reviewStrategy absent ---
echo "Test Group: CFG_SKIP_REVIEW_* defaults when reviewStrategy section absent"

TEMP_CFG_RS=$(mktemp)
cat > "$TEMP_CFG_RS" <<'CFGEOF'
{
  "github": {
    "repo": "test/repo",
    "projectNumber": 99,
    "owner": "test",
    "projectId": "PVT_test",
    "statusFieldId": "PVTSSF_test"
  }
}
CFGEOF

TMPOUT=$(mktemp)
_CFG_FILE_OVERRIDE="$TEMP_CFG_RS" bash --norc --noprofile -c "
  source \"$CONFIG_SH\"
  echo \"CFG_SKIP_REVIEW_ENABLED=\$CFG_SKIP_REVIEW_ENABLED\"
  echo \"CFG_SKIP_REVIEW_MAX_DIFFICULTY=\$CFG_SKIP_REVIEW_MAX_DIFFICULTY\"
  echo \"CFG_SKIP_REVIEW_REQUIRE_LABEL=\$CFG_SKIP_REVIEW_REQUIRE_LABEL\"
" > "$TMPOUT" 2>&1

assert_eq "CFG_SKIP_REVIEW_ENABLED_DefaultsTo_false" "false" "$(grep '^CFG_SKIP_REVIEW_ENABLED=' "$TMPOUT" | cut -d= -f2)"
assert_eq "CFG_SKIP_REVIEW_MAX_DIFFICULTY_DefaultsTo_easy" "easy" "$(grep '^CFG_SKIP_REVIEW_MAX_DIFFICULTY=' "$TMPOUT" | cut -d= -f2)"
assert_eq "CFG_SKIP_REVIEW_REQUIRE_LABEL_DefaultsTo_empty" "" "$(grep '^CFG_SKIP_REVIEW_REQUIRE_LABEL=' "$TMPOUT" | cut -d= -f2)"
rm -f "$TMPOUT" "$TEMP_CFG_RS"

echo ""

# --- Test Group 15: CFG_SKIP_REVIEW_* with empty config file ---
echo "Test Group: CFG_SKIP_REVIEW_* defaults with empty JSON config"

TEMP_CFG_EMPTY=$(mktemp)
echo '{}' > "$TEMP_CFG_EMPTY"

TMPOUT=$(mktemp)
_CFG_FILE_OVERRIDE="$TEMP_CFG_EMPTY" bash --norc --noprofile -c "
  source \"$CONFIG_SH\"
  echo \"CFG_SKIP_REVIEW_ENABLED=\$CFG_SKIP_REVIEW_ENABLED\"
  echo \"CFG_SKIP_REVIEW_MAX_DIFFICULTY=\$CFG_SKIP_REVIEW_MAX_DIFFICULTY\"
  echo \"CFG_SKIP_REVIEW_REQUIRE_LABEL=\$CFG_SKIP_REVIEW_REQUIRE_LABEL\"
" > "$TMPOUT" 2>&1

assert_eq "CFG_SKIP_REVIEW_ENABLED_DefaultsTo_false_EmptyConfig" "false" "$(grep '^CFG_SKIP_REVIEW_ENABLED=' "$TMPOUT" | cut -d= -f2)"
assert_eq "CFG_SKIP_REVIEW_MAX_DIFFICULTY_DefaultsTo_easy_EmptyConfig" "easy" "$(grep '^CFG_SKIP_REVIEW_MAX_DIFFICULTY=' "$TMPOUT" | cut -d= -f2)"
assert_eq "CFG_SKIP_REVIEW_REQUIRE_LABEL_DefaultsTo_empty_EmptyConfig" "" "$(grep '^CFG_SKIP_REVIEW_REQUIRE_LABEL=' "$TMPOUT" | cut -d= -f2)"
rm -f "$TMPOUT" "$TEMP_CFG_EMPTY"

echo ""

# --- Test Group 16: config.sh file content checks for review strategy ---
echo "Test Group: config.sh defines CFG_SKIP_REVIEW_* variables"

assert_file_contains "config.sh_defines_CFG_SKIP_REVIEW_ENABLED" "CFG_SKIP_REVIEW_ENABLED" "$CONFIG_SH"
assert_file_contains "config.sh_defines_CFG_SKIP_REVIEW_MAX_DIFFICULTY" "CFG_SKIP_REVIEW_MAX_DIFFICULTY" "$CONFIG_SH"
assert_file_contains "config.sh_defines_CFG_SKIP_REVIEW_REQUIRE_LABEL" "CFG_SKIP_REVIEW_REQUIRE_LABEL" "$CONFIG_SH"
assert_file_contains "config.sh_reads_skipPerStoryReview_enabled" "skipPerStoryReview.enabled" "$CONFIG_SH"
assert_file_contains "config.sh_reads_skipPerStoryReview_maxDifficulty" "maxDifficulty" "$CONFIG_SH"
assert_file_contains "config.sh_reads_skipPerStoryReview_requireLabel" "requireLabel" "$CONFIG_SH"
assert_file_contains "config.sh_header_mentions_CFG_SKIP_REVIEW_ENABLED" "CFG_SKIP_REVIEW_ENABLED" "$CONFIG_SH"

echo ""

# --- Summary ---
echo "========================================"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
