#!/usr/bin/env bash
# test-local-comments-sh.sh — Tests for scripts/lib/adapters/pm/local/comments.sh
#
# Tests follow the Arrange/Act/Assert pattern. All operations run against
# temporary directories — no mocking needed.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMMENTS_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/comments.sh"
COMMON_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/_common.sh"

PASS=0
FAIL=0

assert_eq() {
  local test_name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    Expected: $(echo "$expected" | head -5)"
    echo "    Actual:   $(echo "$actual" | head -5)"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local test_name="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF -- "$needle"; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    Expected to contain: $needle"
    echo "    Got: $(echo "$haystack" | head -5)"
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

echo "========================================"
echo "Testing scripts/lib/adapters/pm/local/comments.sh"
echo "========================================"
echo ""

# --- Test Group 0: File existence and size ---
echo "Test Group: File existence"

if [ -f "$COMMENTS_SH" ]; then
  echo "  PASS: comments.sh exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: comments.sh not found at $COMMENTS_SH"
  FAIL=$((FAIL + 1))
fi

LINE_COUNT=$(wc -l < "$COMMENTS_SH" 2>/dev/null || echo 9999)
if [ "$LINE_COUNT" -le 200 ]; then
  echo "  PASS: comments.sh is under 200 lines ($LINE_COUNT)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: comments.sh exceeds 200 lines ($LINE_COUNT)"
  FAIL=$((FAIL + 1))
fi
echo ""

# --- Helper: run a snippet inside an isolated workflow dir ---
run_snippet() {
  local tmpdir="$1"
  local snippet="$2"
  bash --norc --noprofile -c "
    _LOCAL_COMMON_LOADED=''
    _LOCAL_WORKFLOW_DIR='$tmpdir/.workflow'
    source '$COMMON_SH'
    source '$COMMENTS_SH'
    $snippet
  "
}

# --- Test Group 1: pm_add_comment creates file in correct directory ---
echo "Test Group: pm_add_comment creates file in correct directory"

TMPDIR=$(mktemp -d)
BODY="### Work Started

Some body text."
run_snippet "$TMPDIR" "pm_add_comment 42 '### Work Started

Some body text.'"
EXIT_CODE=$?

assert_exit_zero "pm_add_comment_exits_zero" "$EXIT_CODE"

COMMENT_DIR="$TMPDIR/.workflow/comments/42"
if [ -d "$COMMENT_DIR" ]; then
  echo "  PASS: pm_add_comment_creates_comment_dir"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_add_comment_creates_comment_dir (not found: $COMMENT_DIR)"
  FAIL=$((FAIL + 1))
fi

COMMENT_FILES=("$COMMENT_DIR"/*.md)
if [ -f "${COMMENT_FILES[0]:-}" ]; then
  echo "  PASS: pm_add_comment_creates_comment_file"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_add_comment_creates_comment_file (no .md in $COMMENT_DIR)"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 2: comment filename format (sequence + slug) ---
echo "Test Group: comment filename format"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_add_comment 5 '### Work Started

body'" > /dev/null

COMMENT_FILE=$(ls "$TMPDIR/.workflow/comments/5/" 2>/dev/null | head -1)
assert_eq "pm_add_comment_filename_001_work_started" "001-work-started.md" "$COMMENT_FILE"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 3: sequential comments get incrementing sequence numbers ---
echo "Test Group: sequential sequence numbers"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_add_comment 7 '### Work Started'" > /dev/null
run_snippet "$TMPDIR" "pm_add_comment 7 '### Ready for Review'" > /dev/null
run_snippet "$TMPDIR" "pm_add_comment 7 '### Telemetry'" > /dev/null

COMMENT_FILES_LIST=$(ls "$TMPDIR/.workflow/comments/7/" 2>/dev/null | sort)
assert_contains "pm_add_comment_seq_001" "001-work-started.md" "$COMMENT_FILES_LIST"
assert_contains "pm_add_comment_seq_002" "002-ready-for-review.md" "$COMMENT_FILES_LIST"
assert_contains "pm_add_comment_seq_003" "003-telemetry.md" "$COMMENT_FILES_LIST"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 4: slug derivation from various headings ---
echo "Test Group: slug derivation from headings"

TMPDIR=$(mktemp -d)

# ### heading
run_snippet "$TMPDIR" "pm_add_comment 10 '### Work Started

body content'" > /dev/null
FILE=$(ls "$TMPDIR/.workflow/comments/10/" | head -1)
assert_eq "slug_from_h3_work_started" "001-work-started.md" "$FILE"
rm -rf "$TMPDIR"

# ## heading (two hashes)
TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_add_comment 10 '## Ready for Review

body'" > /dev/null
FILE=$(ls "$TMPDIR/.workflow/comments/10/" | head -1)
assert_eq "slug_from_h2_ready_for_review" "001-ready-for-review.md" "$FILE"
rm -rf "$TMPDIR"

# Single word heading
TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_add_comment 10 '### Telemetry'" > /dev/null
FILE=$(ls "$TMPDIR/.workflow/comments/10/" | head -1)
assert_eq "slug_from_h3_single_word" "001-telemetry.md" "$FILE"
rm -rf "$TMPDIR"

echo ""

# --- Test Group 5: slug fallback to "comment" when no heading ---
echo "Test Group: slug fallback"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_add_comment 20 'No heading here, just plain text.'" > /dev/null
FILE=$(ls "$TMPDIR/.workflow/comments/20/" | head -1)
assert_eq "slug_fallback_to_comment" "001-comment.md" "$FILE"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 6: timestamp HTML comment on first line ---
echo "Test Group: timestamp HTML comment on first line"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_add_comment 30 '### Work Started

body text'" > /dev/null
COMMENT_FILE=$(ls "$TMPDIR/.workflow/comments/30/" | head -1)
FIRST_LINE=$(head -1 "$TMPDIR/.workflow/comments/30/$COMMENT_FILE")

# Must start with <!-- posted: and end with -->
if echo "$FIRST_LINE" | grep -qE '^<!-- posted: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z -->$'; then
  echo "  PASS: pm_add_comment_timestamp_html_comment_first_line"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_add_comment_timestamp_html_comment_first_line (got: $FIRST_LINE)"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 7: comment body content is preserved ---
echo "Test Group: comment body content preserved"

TMPDIR=$(mktemp -d)
BODY='### Work Started

| Field | Value |
|-------|-------|
| **Agent** | builder |'
run_snippet "$TMPDIR" "pm_add_comment 40 '$BODY'" > /dev/null
COMMENT_FILE=$(ls "$TMPDIR/.workflow/comments/40/" | head -1)
CONTENT=$(cat "$TMPDIR/.workflow/comments/40/$COMMENT_FILE")

assert_contains "pm_add_comment_body_preserved_heading" "### Work Started" "$CONTENT"
assert_contains "pm_add_comment_body_preserved_table" "Agent" "$CONTENT"
assert_contains "pm_add_comment_body_preserved_value" "builder" "$CONTENT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 8: comments for different item IDs are isolated ---
echo "Test Group: comment isolation per item ID"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_add_comment 1 '### Work Started'" > /dev/null
run_snippet "$TMPDIR" "pm_add_comment 2 '### Work Started'" > /dev/null
run_snippet "$TMPDIR" "pm_add_comment 1 '### Ready for Review'" > /dev/null

COUNT_1=$(ls "$TMPDIR/.workflow/comments/1/" | wc -l | tr -d ' ')
COUNT_2=$(ls "$TMPDIR/.workflow/comments/2/" | wc -l | tr -d ' ')

assert_eq "pm_add_comment_isolation_item1_has_2" "2" "$COUNT_1"
assert_eq "pm_add_comment_isolation_item2_has_1" "1" "$COUNT_2"

# Sequence for item 1 should be 001 and 002
FILES_1=$(ls "$TMPDIR/.workflow/comments/1/" | sort)
assert_contains "pm_add_comment_isolation_item1_seq_001" "001-work-started.md" "$FILES_1"
assert_contains "pm_add_comment_isolation_item1_seq_002" "002-ready-for-review.md" "$FILES_1"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 9: idempotency guard prevents double-sourcing ---
echo "Test Group: idempotency guard"

TMPDIR=$(mktemp -d)
# Source twice — second source must be a no-op
RESULT=$(bash --norc --noprofile -c "
  _LOCAL_COMMON_LOADED=''
  _LOCAL_WORKFLOW_DIR='$TMPDIR/.workflow'
  source '$COMMON_SH'
  source '$COMMENTS_SH'
  source '$COMMENTS_SH'
  echo 'sourced_ok'
" 2>&1)
EXIT_CODE=$?

assert_exit_zero "idempotency_guard_double_source_ok" "$EXIT_CODE"
assert_contains "idempotency_guard_no_error" "sourced_ok" "$RESULT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 10: pm_post_telemetry delegates to issue-telemetry.sh ---
echo "Test Group: pm_post_telemetry delegates to issue-telemetry.sh"

TMPDIR=$(mktemp -d)
# Create a stub issue-telemetry.sh in a temp bin dir
STUB_BIN="$TMPDIR/bin"
mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/issue-telemetry.sh" << 'STUB'
#!/usr/bin/env bash
echo "TELEMETRY_CALLED: $*"
STUB
chmod +x "$STUB_BIN/issue-telemetry.sh"

RESULT=$(bash --norc --noprofile -c "
  _LOCAL_COMMON_LOADED=''
  _LOCAL_WORKFLOW_DIR='$TMPDIR/.workflow'
  REPO_ROOT='$TMPDIR'
  mkdir -p '$TMPDIR/scripts'
  cp '$STUB_BIN/issue-telemetry.sh' '$TMPDIR/scripts/issue-telemetry.sh'
  source '$COMMON_SH'
  source '$COMMENTS_SH'
  pm_post_telemetry 42 --model sonnet --duration 1000 --commit abc123
" 2>&1)
EXIT_CODE=$?

assert_exit_zero "pm_post_telemetry_exits_zero" "$EXIT_CODE"
assert_contains "pm_post_telemetry_passes_id" "42" "$RESULT"
assert_contains "pm_post_telemetry_passes_flags" "--model" "$RESULT"
assert_contains "pm_post_telemetry_passes_model_value" "sonnet" "$RESULT"
assert_contains "pm_post_telemetry_passes_commit" "--commit" "$RESULT"

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
