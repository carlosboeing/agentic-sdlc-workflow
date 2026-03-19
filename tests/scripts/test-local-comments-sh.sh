#!/usr/bin/env bash
# test-local-comments-sh.sh — Tests for scripts/lib/adapters/pm/local/comments.sh
#
# Tests follow the Arrange/Act/Assert pattern. All operations run against
# temporary directories — no mocking needed.
#
# The inline comment format appends comments to item .md files instead of
# creating separate files in .workflow/comments/.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMMENTS_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/comments.sh"
ITEMS_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/items.sh"
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

assert_not_contains() {
  local test_name="$1" needle="$2" haystack="$3"
  if ! echo "$haystack" | grep -qF -- "$needle"; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    Expected NOT to contain: $needle"
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

# --- Test Group 0: File existence ---
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
# Sources both _common.sh, items.sh, and comments.sh so item files can be created.
run_snippet() {
  local tmpdir="$1"
  local snippet="$2"
  bash --norc --noprofile -c "
    _LOCAL_COMMON_LOADED=''
    _LOCAL_ITEMS_LOADED=''
    _LOCAL_COMMENTS_LOADED=''
    _LOCAL_WORKFLOW_DIR='$tmpdir/.workflow'
    source '$COMMON_SH'
    source '$ITEMS_SH'
    source '$COMMENTS_SH'
    $snippet
  "
}

# --- Test Group 1: pm_add_comment appends to item file ---
echo "Test Group: pm_add_comment appends comment to item file"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'My Story' --body 'Story body'" > /dev/null
run_snippet "$TMPDIR" "pm_add_comment 1 '### Work Started

Some body text.'"
EXIT_CODE=$?

assert_exit_zero "pm_add_comment_exits_zero" "$EXIT_CODE"

ITEM_FILE="$TMPDIR/.workflow/items/1.md"
CONTENT=$(cat "$ITEM_FILE")
assert_contains "pm_add_comment_appended_to_item_file" "### Work Started" "$CONTENT"
assert_contains "pm_add_comment_body_text_present" "Some body text." "$CONTENT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 2: Activity Log separator added on first comment ---
echo "Test Group: Activity Log separator added on first comment"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Sep Story' --body 'Body here'" > /dev/null
run_snippet "$TMPDIR" "pm_add_comment 1 '### Work Started'" > /dev/null

CONTENT=$(cat "$TMPDIR/.workflow/items/1.md")
# Must have the box-drawing separator
assert_contains "pm_add_comment_has_separator" "─────────" "$CONTENT"
assert_contains "pm_add_comment_has_activity_log_heading" "## Activity Log" "$CONTENT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 3: Subsequent comments append below separator ---
echo "Test Group: Subsequent comments append below separator"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Multi Comment Story' --body 'Body'" > /dev/null
run_snippet "$TMPDIR" "pm_add_comment 1 '### Work Started'" > /dev/null
run_snippet "$TMPDIR" "pm_add_comment 1 '### Ready for Review'" > /dev/null
run_snippet "$TMPDIR" "pm_add_comment 1 '### Telemetry'" > /dev/null

CONTENT=$(cat "$TMPDIR/.workflow/items/1.md")
assert_contains "pm_add_comment_second_comment" "### Ready for Review" "$CONTENT"
assert_contains "pm_add_comment_third_comment" "### Telemetry" "$CONTENT"

# Activity Log heading should appear only once
ACTIVITY_LOG_COUNT=$(grep -c '## Activity Log' "$TMPDIR/.workflow/items/1.md" || true)
assert_eq "pm_add_comment_activity_log_heading_once" "1" "$ACTIVITY_LOG_COUNT"

# Separator line should appear only once
SEP_COUNT=$(grep -c '─────────' "$TMPDIR/.workflow/items/1.md" || true)
assert_eq "pm_add_comment_separator_once" "1" "$SEP_COUNT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 4: comment timestamp marker present ---
echo "Test Group: comment timestamp marker present"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Marker Story' --body 'Body'" > /dev/null
run_snippet "$TMPDIR" "pm_add_comment 1 '### Work Started'" > /dev/null

CONTENT=$(cat "$TMPDIR/.workflow/items/1.md")
# Must have <!-- comment: ISO-timestamp --> marker
if echo "$CONTENT" | grep -qE '<!-- comment: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z -->'; then
  echo "  PASS: pm_add_comment_timestamp_marker_present"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_add_comment_timestamp_marker_present (content: $(echo "$CONTENT" | head -20))"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 5: trailing --- separator between comments ---
echo "Test Group: trailing --- separator between comments"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Sep Between Story' --body 'Body'" > /dev/null
run_snippet "$TMPDIR" "pm_add_comment 1 '### Work Started'" > /dev/null
run_snippet "$TMPDIR" "pm_add_comment 1 '### Ready for Review'" > /dev/null

CONTENT=$(cat "$TMPDIR/.workflow/items/1.md")
# After activity log separator, there should be --- separators between comments
# The file format is: frontmatter (---), body, separator, activity log, comment, ---, comment
# Count --- lines after Activity Log heading
AFTER_ACTIVITY=$(awk '/## Activity Log/{found=1; next} found && /^---$/{c++} END{print c+0}' "$TMPDIR/.workflow/items/1.md")
# Should have at least 1 --- separator (between two comments)
if [ "$AFTER_ACTIVITY" -ge 1 ]; then
  echo "  PASS: pm_add_comment_trailing_separator_between_comments"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_add_comment_trailing_separator_between_comments (found $AFTER_ACTIVITY separators)"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 6: updated frontmatter timestamp refreshed ---
echo "Test Group: updated frontmatter field refreshed on comment"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Update TS Story' --body 'Body'" > /dev/null

BEFORE=$(grep '^updated:' "$TMPDIR/.workflow/items/1.md" | head -1 | sed 's/updated: //')

# Sleep 1 second to ensure timestamp difference
sleep 1
run_snippet "$TMPDIR" "pm_add_comment 1 '### Work Started'" > /dev/null

AFTER=$(grep '^updated:' "$TMPDIR/.workflow/items/1.md" | head -1 | sed 's/updated: //')

if [ "$BEFORE" != "$AFTER" ]; then
  echo "  PASS: pm_add_comment_updates_frontmatter_timestamp"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_add_comment_updates_frontmatter_timestamp (before=$BEFORE, after=$AFTER)"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 7: item file not found — skip silently ---
echo "Test Group: pm_add_comment skips silently when item file missing"

TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.workflow/items"
# Do NOT create item 999 — pm_add_comment should skip silently
OUT=$(run_snippet "$TMPDIR" "pm_add_comment 999 '### Work Started'" 2>&1)
EXIT_CODE=$?

assert_exit_zero "pm_add_comment_missing_item_exits_zero" "$EXIT_CODE"

# Should NOT create a comment file for missing item
if [ ! -d "$TMPDIR/.workflow/comments/999" ]; then
  echo "  PASS: pm_add_comment_missing_item_no_comment_dir"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_add_comment_missing_item_no_comment_dir (directory created)"
  FAIL=$((FAIL + 1))
fi

# Should NOT have created an item file
if [ ! -f "$TMPDIR/.workflow/items/999.md" ]; then
  echo "  PASS: pm_add_comment_missing_item_no_item_file"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_add_comment_missing_item_no_item_file (file created)"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 8: comment body content is preserved ---
echo "Test Group: comment body content preserved"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Content Story' --body 'Story body'" > /dev/null
BODY='### Work Started

| Field | Value |
|-------|-------|
| **Agent** | builder |'
run_snippet "$TMPDIR" "pm_add_comment 1 '$BODY'" > /dev/null

CONTENT=$(cat "$TMPDIR/.workflow/items/1.md")
assert_contains "pm_add_comment_body_preserved_heading" "### Work Started" "$CONTENT"
assert_contains "pm_add_comment_body_preserved_table" "Agent" "$CONTENT"
assert_contains "pm_add_comment_body_preserved_value" "builder" "$CONTENT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 9: original body preserved above activity log ---
echo "Test Group: original item body preserved above activity log"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Preserved Body Story' --body 'Original body content'" > /dev/null
run_snippet "$TMPDIR" "pm_add_comment 1 '### Work Started'" > /dev/null

CONTENT=$(cat "$TMPDIR/.workflow/items/1.md")
assert_contains "pm_add_comment_original_body_preserved" "Original body content" "$CONTENT"

# Body should appear before separator
BODY_LINE=$(grep -n 'Original body content' "$TMPDIR/.workflow/items/1.md" | head -1 | cut -d: -f1)
SEP_LINE=$(grep -n '─────────' "$TMPDIR/.workflow/items/1.md" | head -1 | cut -d: -f1)
if [ -n "$BODY_LINE" ] && [ -n "$SEP_LINE" ] && [ "$BODY_LINE" -lt "$SEP_LINE" ]; then
  echo "  PASS: pm_add_comment_body_before_separator"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_add_comment_body_before_separator (body line=$BODY_LINE, sep line=$SEP_LINE)"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 10: idempotency guard prevents double-sourcing ---
echo "Test Group: idempotency guard"

TMPDIR=$(mktemp -d)
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

# --- Test Group 11: pm_post_telemetry delegates to item-telemetry.sh ---
echo "Test Group: pm_post_telemetry delegates to item-telemetry.sh"

TMPDIR=$(mktemp -d)
STUB_BIN="$TMPDIR/bin"
mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/item-telemetry.sh" << 'STUB'
#!/usr/bin/env bash
echo "TELEMETRY_CALLED: $*"
STUB
chmod +x "$STUB_BIN/item-telemetry.sh"

RESULT=$(bash --norc --noprofile -c "
  _LOCAL_COMMON_LOADED=''
  _LOCAL_WORKFLOW_DIR='$TMPDIR/.workflow'
  REPO_ROOT='$TMPDIR'
  mkdir -p '$TMPDIR/scripts'
  cp '$STUB_BIN/item-telemetry.sh' '$TMPDIR/scripts/item-telemetry.sh'
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

# --- Test Group 12: backward-compat helpers still exist ---
echo "Test Group: backward-compat helpers still defined"

if grep -q "_local_comment_slug" "$COMMENTS_SH"; then
  echo "  PASS: _local_comment_slug_still_defined"
  PASS=$((PASS + 1))
else
  echo "  FAIL: _local_comment_slug_still_defined"
  FAIL=$((FAIL + 1))
fi

if grep -q "_local_next_comment_seq" "$COMMENTS_SH"; then
  echo "  PASS: _local_next_comment_seq_still_defined"
  PASS=$((PASS + 1))
else
  echo "  FAIL: _local_next_comment_seq_still_defined"
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
