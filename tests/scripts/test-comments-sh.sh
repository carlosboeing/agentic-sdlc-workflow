#!/usr/bin/env bash
# test-comments-sh.sh — Validates comments.sh adapter module behavior.
# Runs locally using mock adapters and stubs (no live GitHub API calls).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMMENTS_SH="$REPO_ROOT/scripts/lib/adapters/pm/github/comments.sh"

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

assert_contains() {
  local test_name="$1"
  local needle="$2"
  local haystack="$3"
  # Portable fixed-string substring check via case statement
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
echo "Testing scripts/lib/adapters/pm/github/comments.sh"
echo "========================================"
echo ""

# --- Shared stubs directory ---
MOCK_DIR=$(mktemp -d)

# gh stub: records all invocations to GH_STUB_LOG env var
GH_STUB="$MOCK_DIR/gh"
cat > "$GH_STUB" <<'STUB'
#!/usr/bin/env bash
echo "$@" >> "${GH_STUB_LOG:-/dev/null}"
exit 0
STUB
chmod +x "$GH_STUB"

# --- Test Group 1: File properties ---
echo "Test Group: File properties"

if [ -f "$COMMENTS_SH" ]; then
  echo "  PASS: comments.sh exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: comments.sh not found at $COMMENTS_SH"
  FAIL=$((FAIL + 1))
fi

if [ -x "$COMMENTS_SH" ]; then
  echo "  PASS: comments.sh is executable"
  PASS=$((PASS + 1))
else
  echo "  FAIL: comments.sh is not executable"
  FAIL=$((FAIL + 1))
fi

# File must be under 50 lines (thin wrapper acceptance criterion)
if [ -f "$COMMENTS_SH" ]; then
  LINE_COUNT=$(wc -l < "$COMMENTS_SH")
  if [ "$LINE_COUNT" -lt 50 ]; then
    echo "  PASS: comments.sh is under 50 lines ($LINE_COUNT lines)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: comments.sh exceeds 50 lines ($LINE_COUNT lines) — must be a thin wrapper"
    FAIL=$((FAIL + 1))
  fi
fi

echo ""

# --- Test Group 2: pm_add_comment function definition ---
echo "Test Group: pm_add_comment function definition"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export PATH=\"$MOCK_DIR:\$PATH\"
  export CFG_REPO=\"carlosboeing/agentic-sdlc-workflow\"
  export REPO_ROOT=\"$REPO_ROOT\"
  source \"$COMMENTS_SH\"
  declare -f pm_add_comment > /dev/null && echo 'function_defined'
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "pm_add_comment_sourcing_succeeds" "$EXIT_CODE"
assert_eq "pm_add_comment_function_is_defined" "function_defined" "$OUTPUT"

echo ""

# --- Test Group 3: pm_add_comment calls gh with correct args ---
echo "Test Group: pm_add_comment delegates to gh issue comment"

GH_LOG=$(mktemp)
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export PATH=\"$MOCK_DIR:\$PATH\"
  export GH_STUB_LOG=\"$GH_LOG\"
  export CFG_REPO=\"carlosboeing/agentic-sdlc-workflow\"
  export REPO_ROOT=\"$REPO_ROOT\"
  source \"$COMMENTS_SH\"
  pm_add_comment 42 'Hello world'
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
GH_CALLS=$(cat "$GH_LOG")
rm -f "$TMPOUT" "$GH_LOG"

assert_exit_zero "pm_add_comment_exits_zero_on_success" "$EXIT_CODE"
assert_contains "pm_add_comment_calls_gh_issue_comment" "issue comment" "$GH_CALLS"
assert_contains "pm_add_comment_passes_issue_number" "42" "$GH_CALLS"
assert_contains "pm_add_comment_passes_body" "Hello world" "$GH_CALLS"

echo ""

# --- Test Group 4: pm_add_comment passes --repo from CFG_REPO ---
echo "Test Group: pm_add_comment passes --repo from CFG_REPO"

GH_LOG2=$(mktemp)
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export PATH=\"$MOCK_DIR:\$PATH\"
  export GH_STUB_LOG=\"$GH_LOG2\"
  export CFG_REPO=\"myorg/myrepo\"
  export REPO_ROOT=\"$REPO_ROOT\"
  source \"$COMMENTS_SH\"
  pm_add_comment 55 'test body'
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
GH_CALLS2=$(cat "$GH_LOG2")
rm -f "$TMPOUT" "$GH_LOG2"

assert_exit_zero "pm_add_comment_with_custom_repo_exits_zero" "$EXIT_CODE"
assert_contains "pm_add_comment_passes_repo_flag" "--repo myorg/myrepo" "$GH_CALLS2"

echo ""

# --- Test Group 5: pm_post_telemetry function definition ---
echo "Test Group: pm_post_telemetry function definition"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export PATH=\"$MOCK_DIR:\$PATH\"
  export CFG_REPO=\"carlosboeing/agentic-sdlc-workflow\"
  export REPO_ROOT=\"$REPO_ROOT\"
  source \"$COMMENTS_SH\"
  declare -f pm_post_telemetry > /dev/null && echo 'function_defined'
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "pm_post_telemetry_sourcing_succeeds" "$EXIT_CODE"
assert_eq "pm_post_telemetry_function_is_defined" "function_defined" "$OUTPUT"

echo ""

# --- Test Group 6: pm_post_telemetry delegates to item-telemetry.sh ---
echo "Test Group: pm_post_telemetry delegates to item-telemetry.sh"

# Build a fake repo with a stub item-telemetry.sh that logs to a file
TELEMETRY_LOG=$(mktemp)
FAKE_REPO=$(mktemp -d)
mkdir -p "$FAKE_REPO/scripts"
# Write the stub with the log path baked in (using printf, not heredoc, for portability)
printf '#!/usr/bin/env bash\necho "$@" >> "%s"\nexit 0\n' "$TELEMETRY_LOG" > "$FAKE_REPO/scripts/item-telemetry.sh"
chmod +x "$FAKE_REPO/scripts/item-telemetry.sh"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export PATH=\"$MOCK_DIR:\$PATH\"
  export CFG_REPO=\"carlosboeing/agentic-sdlc-workflow\"
  export REPO_ROOT=\"$FAKE_REPO\"
  source \"$COMMENTS_SH\"
  pm_post_telemetry 197 --model sonnet --duration 1000 --commit abc123
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
TELEMETRY_CALLS=$(cat "$TELEMETRY_LOG")
rm -f "$TMPOUT" "$TELEMETRY_LOG"
rm -rf "$FAKE_REPO"

assert_exit_zero "pm_post_telemetry_exits_zero_on_success" "$EXIT_CODE"
assert_contains "pm_post_telemetry_passes_issue_number" "197" "$TELEMETRY_CALLS"
assert_contains "pm_post_telemetry_passes_model_flag" "--model sonnet" "$TELEMETRY_CALLS"
assert_contains "pm_post_telemetry_passes_duration_flag" "--duration 1000" "$TELEMETRY_CALLS"
assert_contains "pm_post_telemetry_passes_commit_flag" "--commit abc123" "$TELEMETRY_CALLS"

echo ""

# --- Test Group 7: pm_post_telemetry passes --pr flag through ---
echo "Test Group: pm_post_telemetry passes --pr flag through"

TELEMETRY_LOG2=$(mktemp)
FAKE_REPO2=$(mktemp -d)
mkdir -p "$FAKE_REPO2/scripts"
printf '#!/usr/bin/env bash\necho "$@" >> "%s"\nexit 0\n' "$TELEMETRY_LOG2" > "$FAKE_REPO2/scripts/item-telemetry.sh"
chmod +x "$FAKE_REPO2/scripts/item-telemetry.sh"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export PATH=\"$MOCK_DIR:\$PATH\"
  export CFG_REPO=\"carlosboeing/agentic-sdlc-workflow\"
  export REPO_ROOT=\"$FAKE_REPO2\"
  source \"$COMMENTS_SH\"
  pm_post_telemetry 197 --model sonnet --duration 1000 --commit abc123 --pr 99
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
PR_CALLS=$(cat "$TELEMETRY_LOG2")
rm -f "$TMPOUT" "$TELEMETRY_LOG2"
rm -rf "$FAKE_REPO2"

assert_exit_zero "pm_post_telemetry_with_pr_flag_exits_zero" "$EXIT_CODE"
assert_contains "pm_post_telemetry_passes_pr_flag" "--pr 99" "$PR_CALLS"

echo ""

# --- Cleanup ---
rm -rf "$MOCK_DIR" 2>/dev/null || true

# --- Summary ---
echo "========================================"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
