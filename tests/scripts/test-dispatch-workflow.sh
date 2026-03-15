#!/usr/bin/env bash
set -euo pipefail

# test-dispatch-workflow.sh — Validates dispatch-workflow.sh structure and behavior.
# Runs locally without invoking claude or making real GitHub API calls.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_UNDER_TEST="$REPO_ROOT/scripts/dispatch-workflow.sh"

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

echo "========================================"
echo "Testing dispatch-workflow.sh"
echo "========================================"
echo ""

# --- Test 1: Script exists and is executable ---
echo "Test Group: Script file properties"

if [ -f "$SCRIPT_UNDER_TEST" ]; then
  echo "  PASS: Script file exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Script file does not exist at $SCRIPT_UNDER_TEST"
  FAIL=$((FAIL + 1))
fi

if [ -x "$SCRIPT_UNDER_TEST" ]; then
  echo "  PASS: Script is executable"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Script is not executable"
  FAIL=$((FAIL + 1))
fi

# --- Test 2: Shebang line ---
FIRST_LINE=$(head -1 "$SCRIPT_UNDER_TEST")
assert_eq "Shebang is #!/usr/bin/env bash" "#!/usr/bin/env bash" "$FIRST_LINE"

# --- Test 3: Uses strict mode ---
if grep -q 'set -euo pipefail' "$SCRIPT_UNDER_TEST"; then
  echo "  PASS: Uses strict mode (set -euo pipefail)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Missing strict mode"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test 4: Usage message on no args ---
echo "Test Group: Argument parsing"

EXIT_CODE=0
OUTPUT=$("$SCRIPT_UNDER_TEST" 2>&1) || EXIT_CODE=$?
assert_exit_code "NoArgs_ExitCode_Is1" "1" "$EXIT_CODE"
assert_contains "NoArgs_ShowsUsage" "Usage:" "$OUTPUT"
assert_contains "NoArgs_ShowsBacklogIssueNumber" "<backlog-issue-number>" "$OUTPUT"
assert_contains "NoArgs_ShowsSkipDesign" "--skip-design" "$OUTPUT"
assert_contains "NoArgs_ShowsSkipPlan" "--skip-plan" "$OUTPUT"
assert_contains "NoArgs_ShowsEpic" "--epic" "$OUTPUT"

# --- Test 5: Unknown option ---
EXIT_CODE=0
OUTPUT=$("$SCRIPT_UNDER_TEST" 1 --unknown-flag 2>&1) || EXIT_CODE=$?
assert_exit_code "UnknownOption_ExitCode_Is1" "1" "$EXIT_CODE"
assert_contains "UnknownOption_ShowsError" "Unknown option" "$OUTPUT"

echo ""

# --- Test 6: Script structure - all five phases referenced ---
echo "Test Group: Phase structure"

for PHASE in "Phase 1" "Phase 2" "Phase 3" "Phase 4" "Phase 5"; do
  if grep -q "$PHASE" "$SCRIPT_UNDER_TEST"; then
    echo "  PASS: Contains $PHASE"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Missing $PHASE"
    FAIL=$((FAIL + 1))
  fi
done

echo ""

# --- Test 7: Script references key components ---
echo "Test Group: Key component references"

for COMPONENT in "designer" "planner" "builder" "reviewer" "retro"; do
  if grep -q "$COMPONENT" "$SCRIPT_UNDER_TEST"; then
    echo "  PASS: References agent: $COMPONENT"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Missing agent reference: $COMPONENT"
    FAIL=$((FAIL + 1))
  fi
done

if grep -q "dispatch-story.sh" "$SCRIPT_UNDER_TEST"; then
  echo "  PASS: Delegates to dispatch-story.sh"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Does not delegate to dispatch-story.sh"
  FAIL=$((FAIL + 1))
fi

if grep -q "issue-telemetry.sh" "$SCRIPT_UNDER_TEST"; then
  echo "  PASS: Posts telemetry via issue-telemetry.sh"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Does not reference issue-telemetry.sh"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test 8: Difficulty-to-model mapping ---
echo "Test Group: difficulty_to_model function"

# Extract complete function bodies using sed (from 'funcname()' to next closing brace at col 1)
extract_func() {
  local name="$1"
  sed -n "/^${name}()/,/^}/p" "$SCRIPT_UNDER_TEST"
}

# Source config lib so CFG_ROUTE_* variables are available
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/lib/config.sh"

eval "$(extract_func difficulty_to_model)"

assert_eq "DifficultyEasy_MapsToSonnet" "sonnet" "$(difficulty_to_model "difficulty/easy")"
assert_eq "DifficultyMedium_MapsToSonnet" "sonnet" "$(difficulty_to_model "difficulty/medium")"
assert_eq "DifficultyHard_MapsToOpus" "opus" "$(difficulty_to_model "difficulty/hard")"
assert_eq "DifficultyUnknown_DefaultsToSonnet" "sonnet" "$(difficulty_to_model "difficulty/unknown")"

echo ""

# --- Test 9: format_duration_human function ---
echo "Test Group: format_duration_human function"

eval "$(extract_func format_duration_human)"

assert_eq "Duration_0ms_Shows0s" "0s" "$(format_duration_human 0)"
assert_eq "Duration_5000ms_Shows5s" "5s" "$(format_duration_human 5000)"
assert_eq "Duration_60000ms_Shows1m" "1m" "$(format_duration_human 60000)"
assert_eq "Duration_90000ms_Shows1m30s" "1m 30s" "$(format_duration_human 90000)"
assert_eq "Duration_300000ms_Shows5m" "5m" "$(format_duration_human 300000)"

echo ""

# --- Test 10: title_to_slug function ---
echo "Test Group: title_to_slug function"

eval "$(extract_func title_to_slug)"

assert_eq "TitleSlug_StripsBracketPrefix" "create-dispatch-workflow-sh" "$(title_to_slug "[E01-S02] Create dispatch-workflow.sh")"
assert_eq "TitleSlug_LowercasesTitle" "simple-title" "$(title_to_slug "[E01-S01] Simple Title")"
assert_eq "TitleSlug_HandlesSpecialChars" "add-foo-bar" "$(title_to_slug "[E02-S03] Add foo & bar")"

echo ""

# --- Test 11: extract_story_tag function ---
echo "Test Group: extract_story_tag function"

eval "$(extract_func extract_story_tag)"

assert_eq "StoryTag_ExtractsTag" "e01-s02" "$(extract_story_tag "[E01-S02] Create dispatch-workflow.sh")"
assert_eq "StoryTag_HandlesUpperCase" "e02-s03" "$(extract_story_tag "[E02-S03] Add something")"

echo ""

# --- Test 12: skip flags ---
echo "Test Group: Skip flag handling"

if grep -q 'SKIP_DESIGN=true' "$SCRIPT_UNDER_TEST"; then
  echo "  PASS: Handles --skip-design flag"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Does not handle --skip-design"
  FAIL=$((FAIL + 1))
fi

if grep -q 'SKIP_PLAN=true' "$SCRIPT_UNDER_TEST"; then
  echo "  PASS: Handles --skip-plan flag"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Does not handle --skip-plan"
  FAIL=$((FAIL + 1))
fi

if grep -q 'SKIPPED via --skip-design' "$SCRIPT_UNDER_TEST"; then
  echo "  PASS: Logs skip message for design phase"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Does not log skip for design"
  FAIL=$((FAIL + 1))
fi

if grep -q 'SKIPPED via --skip-plan' "$SCRIPT_UNDER_TEST"; then
  echo "  PASS: Logs skip message for plan phase"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Does not log skip for plan"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test 13: Epic PR creation ---
echo "Test Group: Epic PR features"

if grep -q 'Closes #' "$SCRIPT_UNDER_TEST"; then
  echo "  PASS: Epic PR body includes Closes links"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Missing Closes links in PR body"
  FAIL=$((FAIL + 1))
fi

if grep -q 'gh pr create' "$SCRIPT_UNDER_TEST"; then
  echo "  PASS: Creates epic PR via gh pr create"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Does not create epic PR"
  FAIL=$((FAIL + 1))
fi

if grep -q 'gh pr list.*--state open' "$SCRIPT_UNDER_TEST"; then
  echo "  PASS: Checks for existing PRs before creating"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Does not check for existing PRs"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test 14: Board status management ---
echo "Test Group: Board status management"

if grep -q 'lib/config\.sh' "$SCRIPT_UNDER_TEST"; then
  echo "  PASS: Sources shared config library"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Missing shared config library source"
  FAIL=$((FAIL + 1))
fi

if grep -q 'CFG_REPO' "$SCRIPT_UNDER_TEST"; then
  echo "  PASS: Uses config variables for repo"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Missing config variable usage"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test 15: Idempotent restart support ---
echo "Test Group: Idempotent restart"

if grep -q 'CLOSED' "$SCRIPT_UNDER_TEST"; then
  echo "  PASS: Checks for already-closed stories (idempotent restart)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: No idempotent restart check"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Test 16: Pre-flight checks ---
echo "Test Group: Pre-flight checks"

for CMD in "claude" "gh" "jq"; do
  if grep -q "command -v $CMD" "$SCRIPT_UNDER_TEST"; then
    echo "  PASS: Checks for $CMD in PATH"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Does not check for $CMD"
    FAIL=$((FAIL + 1))
  fi
done

echo ""

# --- Summary ---
echo "========================================"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
