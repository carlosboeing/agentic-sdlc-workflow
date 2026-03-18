#!/usr/bin/env bash
# test-items-sh.sh — Validates pm_create_item, pm_get_item, pm_list_items, pm_done.
# Runs locally; all GitHub API calls are mocked via a fake gh stub.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ITEMS_SH="$REPO_ROOT/scripts/lib/adapters/pm/github/items.sh"

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
    echo "    Expected: $(echo "$expected" | head -3)"
    echo "    Actual:   $(echo "$actual" | head -3)"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local test_name="$1"
  local needle="$2"
  local haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    echo "    Expected to contain: $needle"
    echo "    Got: $haystack"
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
echo "Testing scripts/lib/adapters/pm/github/items.sh"
echo "========================================"
echo ""

# --- Test Group 1: File properties ---
echo "Test Group: File properties"

if [ -f "$ITEMS_SH" ]; then
  echo "  PASS: items.sh exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: items.sh not found at $ITEMS_SH"
  FAIL=$((FAIL + 1))
fi

if [ -x "$ITEMS_SH" ]; then
  echo "  PASS: items.sh is executable"
  PASS=$((PASS + 1))
else
  echo "  FAIL: items.sh is not executable"
  FAIL=$((FAIL + 1))
fi

# Line count under 200
LINE_COUNT=$(wc -l < "$ITEMS_SH" 2>/dev/null || echo 9999)
if [ "$LINE_COUNT" -le 200 ]; then
  echo "  PASS: items.sh is under 200 lines ($LINE_COUNT)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: items.sh exceeds 200 lines ($LINE_COUNT)"
  FAIL=$((FAIL + 1))
fi

echo ""

# --- Helper: build a mock environment ---
# Creates a temporary directory with a fake 'gh' stub so tests never hit the API.
build_mock_env() {
  local mock_dir
  mock_dir=$(mktemp -d)

  # Fake gh stub: record last call args; respond to issue create / view / list / close
  cat > "$mock_dir/gh" <<'STUB'
#!/usr/bin/env bash
# Fake gh stub — records invocations and returns canned responses.

# Route based on subcommand
case "$1 $2" in
  "issue create")
    # Return a fake issue URL ending with the issue number 999
    echo "https://github.com/test-owner/test-repo/issues/999"
    ;;
  "issue view")
    ISSUE_NUM="$3"
    # If --json flag is present return raw JSON
    if [[ "$*" == *"--json"* ]]; then
      echo '{"number":'"$ISSUE_NUM"',"title":"Test Issue","state":"OPEN","labels":[{"name":"hierarchy/story"}]}'
    else
      echo "title:  Test Issue"
      echo "state:  OPEN"
      echo "labels: hierarchy/story"
    fi
    ;;
  "issue list")
    echo "123  Open  First Issue   2026-01-01"
    echo "124  Open  Second Issue  2026-01-02"
    ;;
  "issue close")
    # succeed silently
    ;;
  "issue edit")
    # succeed silently
    ;;
  *)
    # Any other gh call — succeed silently
    ;;
esac
STUB
  chmod +x "$mock_dir/gh"

  echo "$mock_dir"
}

# --- Test Group 2: pm_create_item ---
echo "Test Group: pm_create_item"

MOCK_DIR=$(build_mock_env)
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export PATH=\"$MOCK_DIR:\$PATH\"
  export CFG_REPO=\"test-owner/test-repo\"
  source \"$ITEMS_SH\"
  pm_create_item story \"My Test Story\" --body \"test body\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "pm_create_item_exits_zero" "$EXIT_CODE"
assert_eq "pm_create_item_returns_number" "999" "$OUTPUT"

rm -rf "$MOCK_DIR"
echo ""

# --- Test Group 3: pm_create_item with --body-file ---
echo "Test Group: pm_create_item with --body-file"

MOCK_DIR=$(build_mock_env)
BODY_FILE=$(mktemp)
echo "Body from file" > "$BODY_FILE"
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export PATH=\"$MOCK_DIR:\$PATH\"
  export CFG_REPO=\"test-owner/test-repo\"
  source \"$ITEMS_SH\"
  pm_create_item epic \"My Epic\" --body-file \"$BODY_FILE\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT" "$BODY_FILE"

assert_exit_zero "pm_create_item_body_file_exits_zero" "$EXIT_CODE"
assert_eq "pm_create_item_body_file_returns_number" "999" "$OUTPUT"

rm -rf "$MOCK_DIR"
echo ""

# --- Test Group 4: pm_create_item hierarchy label mapping ---
echo "Test Group: pm_create_item hierarchy label mapping"

# We capture what gh is called with to verify the hierarchy label.
# Use double-quoted heredoc so CALL_LOG path is baked into the stub.
MOCK_DIR=$(mktemp -d)
CALL_LOG="/tmp/gh_calls_hier_$$.log"
rm -f "$CALL_LOG"

# Write stub with real CALL_LOG path expanded (double-quoted heredoc)
cat > "$MOCK_DIR/gh" <<STUB
#!/usr/bin/env bash
echo "\$@" >> "$CALL_LOG"
case "\$1 \$2" in
  "issue create")
    echo "https://github.com/test-owner/test-repo/issues/42"
    ;;
  *)
    ;;
esac
STUB
chmod +x "$MOCK_DIR/gh"

for LEVEL in backlog epic story docs; do
  TMPOUT=$(mktemp)
  bash --norc --noprofile -c "
    export PATH=\"$MOCK_DIR:\$PATH\"
    export CFG_REPO=\"test-owner/test-repo\"
    source \"$ITEMS_SH\"
    pm_create_item $LEVEL \"Test $LEVEL\" --body \"body\"
  " > "$TMPOUT" 2>&1
  rm -f "$TMPOUT"
done

# Verify hierarchy labels were applied for each level
for LEVEL_LABEL in "hierarchy/backlog" "hierarchy/epic" "hierarchy/story" "hierarchy/docs"; do
  if grep -q "$LEVEL_LABEL" "$CALL_LOG" 2>/dev/null; then
    echo "  PASS: pm_create_item applies $LEVEL_LABEL"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: pm_create_item does not apply $LEVEL_LABEL (gh calls: $(cat "$CALL_LOG" 2>/dev/null))"
    FAIL=$((FAIL + 1))
  fi
done

rm -f "$CALL_LOG"
rm -rf "$MOCK_DIR"
echo ""

# --- Test Group 5: pm_create_item with --labels CSV ---
echo "Test Group: pm_create_item with extra --labels"

MOCK_DIR=$(mktemp -d)
CALL_LOG2="/tmp/gh_calls2_$$.log"
rm -f "$CALL_LOG2"
cat > "$MOCK_DIR/gh" <<STUB
#!/usr/bin/env bash
echo "\$@" >> "$CALL_LOG2"
case "\$1 \$2" in
  "issue create")
    echo "https://github.com/test-owner/test-repo/issues/77"
    ;;
  *)
    ;;
esac
STUB
chmod +x "$MOCK_DIR/gh"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export PATH=\"$MOCK_DIR:\$PATH\"
  export CFG_REPO=\"test-owner/test-repo\"
  source \"$ITEMS_SH\"
  pm_create_item backlog \"Test Backlog\" --body \"body\" --labels \"type/feature,difficulty/easy\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"

assert_exit_zero "pm_create_item_labels_exits_zero" "$EXIT_CODE"
assert_eq "pm_create_item_labels_returns_number" "77" "$OUTPUT"

# Both extra labels and hierarchy label should appear in the gh call
if grep -q "type/feature" "$CALL_LOG2" 2>/dev/null; then
  echo "  PASS: pm_create_item_applies_extra_labels"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_create_item_applies_extra_labels (gh calls: $(cat "$CALL_LOG2"))"
  FAIL=$((FAIL + 1))
fi

if grep -q "hierarchy/backlog" "$CALL_LOG2" 2>/dev/null; then
  echo "  PASS: pm_create_item_applies_hierarchy_with_extra_labels"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_create_item_applies_hierarchy_with_extra_labels (gh calls: $(cat "$CALL_LOG2"))"
  FAIL=$((FAIL + 1))
fi

rm -f "$CALL_LOG2"
rm -rf "$MOCK_DIR"
echo ""

# --- Test Group 6: pm_create_item error on invalid level ---
echo "Test Group: pm_create_item error on invalid level"

MOCK_DIR=$(build_mock_env)
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export PATH=\"$MOCK_DIR:\$PATH\"
  export CFG_REPO=\"test-owner/test-repo\"
  source \"$ITEMS_SH\"
  pm_create_item invalid_level \"Test\" --body \"body\"
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"
rm -rf "$MOCK_DIR"

assert_exit_nonzero "pm_create_item_invalid_level_fails" "$EXIT_CODE"
assert_contains "pm_create_item_invalid_level_error_message" "level" "$OUTPUT"

echo ""

# --- Test Group 7: pm_get_item human-readable ---
echo "Test Group: pm_get_item human-readable"

MOCK_DIR=$(build_mock_env)
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export PATH=\"$MOCK_DIR:\$PATH\"
  export CFG_REPO=\"test-owner/test-repo\"
  source \"$ITEMS_SH\"
  pm_get_item 42
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"
rm -rf "$MOCK_DIR"

assert_exit_zero "pm_get_item_human_exits_zero" "$EXIT_CODE"
assert_contains "pm_get_item_human_shows_title" "Test Issue" "$OUTPUT"

echo ""

# --- Test Group 8: pm_get_item with --json ---
echo "Test Group: pm_get_item with --json"

MOCK_DIR=$(build_mock_env)
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export PATH=\"$MOCK_DIR:\$PATH\"
  export CFG_REPO=\"test-owner/test-repo\"
  source \"$ITEMS_SH\"
  pm_get_item 42 --json number,title,state
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
OUTPUT=$(cat "$TMPOUT")
rm -f "$TMPOUT"
rm -rf "$MOCK_DIR"

assert_exit_zero "pm_get_item_json_exits_zero" "$EXIT_CODE"
assert_contains "pm_get_item_json_is_json" "{" "$OUTPUT"

echo ""

# --- Test Group 9: pm_list_items defaults ---
echo "Test Group: pm_list_items defaults (state=open, limit=30)"

MOCK_DIR=$(mktemp -d)
CALL_LOG3="/tmp/gh_list_$$.log"
rm -f "$CALL_LOG3"
cat > "$MOCK_DIR/gh" <<STUB
#!/usr/bin/env bash
echo "\$@" >> "$CALL_LOG3"
echo "1  Open  First  2026-01-01"
STUB
chmod +x "$MOCK_DIR/gh"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export PATH=\"$MOCK_DIR:\$PATH\"
  export CFG_REPO=\"test-owner/test-repo\"
  source \"$ITEMS_SH\"
  pm_list_items
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
rm -f "$TMPOUT"

assert_exit_zero "pm_list_items_exits_zero" "$EXIT_CODE"

# Default state=open should appear
if grep -q -- "--state open" "$CALL_LOG3" 2>/dev/null; then
  echo "  PASS: pm_list_items_default_state_open"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_list_items_default_state_open (gh calls: $(cat "$CALL_LOG3"))"
  FAIL=$((FAIL + 1))
fi

# Default limit=30 should appear
if grep -q -- "--limit 30" "$CALL_LOG3" 2>/dev/null; then
  echo "  PASS: pm_list_items_default_limit_30"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_list_items_default_limit_30 (gh calls: $(cat "$CALL_LOG3"))"
  FAIL=$((FAIL + 1))
fi

rm -f "$CALL_LOG3"
rm -rf "$MOCK_DIR"
echo ""

# --- Test Group 10: pm_list_items with filters ---
echo "Test Group: pm_list_items with --label, --state, --limit"

MOCK_DIR=$(mktemp -d)
CALL_LOG4="/tmp/gh_list2_$$.log"
rm -f "$CALL_LOG4"
cat > "$MOCK_DIR/gh" <<STUB
#!/usr/bin/env bash
echo "\$@" >> "$CALL_LOG4"
echo "1  Closed  Old Issue  2025-01-01"
STUB
chmod +x "$MOCK_DIR/gh"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export PATH=\"$MOCK_DIR:\$PATH\"
  export CFG_REPO=\"test-owner/test-repo\"
  source \"$ITEMS_SH\"
  pm_list_items --label hierarchy/epic --state closed --limit 5
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
rm -f "$TMPOUT"

assert_exit_zero "pm_list_items_filtered_exits_zero" "$EXIT_CODE"

if grep -q "hierarchy/epic" "$CALL_LOG4" 2>/dev/null; then
  echo "  PASS: pm_list_items_passes_label_filter"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_list_items_passes_label_filter (got: $(cat "$CALL_LOG4"))"
  FAIL=$((FAIL + 1))
fi

if grep -q -- "--state closed" "$CALL_LOG4" 2>/dev/null; then
  echo "  PASS: pm_list_items_passes_state_filter"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_list_items_passes_state_filter (got: $(cat "$CALL_LOG4"))"
  FAIL=$((FAIL + 1))
fi

if grep -q -- "--limit 5" "$CALL_LOG4" 2>/dev/null; then
  echo "  PASS: pm_list_items_passes_limit_filter"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_list_items_passes_limit_filter (got: $(cat "$CALL_LOG4"))"
  FAIL=$((FAIL + 1))
fi

rm -f "$CALL_LOG4"
rm -rf "$MOCK_DIR"
echo ""

# --- Test Group 11: pm_done closes and sets status ---
echo "Test Group: pm_done closes issue and sets board Done"

MOCK_DIR=$(mktemp -d)
CALL_LOG5="/tmp/gh_done_$$.log"
rm -f "$CALL_LOG5"
cat > "$MOCK_DIR/gh" <<STUB
#!/usr/bin/env bash
echo "\$@" >> "$CALL_LOG5"
STUB
chmod +x "$MOCK_DIR/gh"

# Provide a fake pm_set_status so we don't need the full set-status script
TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export PATH=\"$MOCK_DIR:\$PATH\"
  export CFG_REPO=\"test-owner/test-repo\"
  # Mock pm_set_status so pm_done can call it
  pm_set_status() { echo \"pm_set_status \$1 \$2\" >> \"$CALL_LOG5\"; }
  source \"$ITEMS_SH\"
  pm_done 88
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
rm -f "$TMPOUT"

assert_exit_zero "pm_done_exits_zero" "$EXIT_CODE"

# gh issue close should be invoked
if grep -q "issue close 88" "$CALL_LOG5" 2>/dev/null; then
  echo "  PASS: pm_done_calls_gh_issue_close"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_done_calls_gh_issue_close (calls: $(cat "$CALL_LOG5"))"
  FAIL=$((FAIL + 1))
fi

# Should close with --reason completed
if grep -q -- "--reason completed" "$CALL_LOG5" 2>/dev/null; then
  echo "  PASS: pm_done_uses_reason_completed"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_done_uses_reason_completed (calls: $(cat "$CALL_LOG5"))"
  FAIL=$((FAIL + 1))
fi

# pm_set_status done should be called
if grep -q "pm_set_status 88 done" "$CALL_LOG5" 2>/dev/null; then
  echo "  PASS: pm_done_calls_pm_set_status_done"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_done_calls_pm_set_status_done (calls: $(cat "$CALL_LOG5"))"
  FAIL=$((FAIL + 1))
fi

rm -f "$CALL_LOG5"
rm -rf "$MOCK_DIR"
echo ""

# --- Test Group 12: pm_done handles already-closed issue gracefully ---
echo "Test Group: pm_done handles already-closed issue gracefully"

MOCK_DIR=$(mktemp -d)
# gh stub that returns non-zero for 'issue close' to simulate already-closed
cat > "$MOCK_DIR/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "issue close")
    echo "Issue is already closed" >&2
    exit 1
    ;;
  *)
    ;;
esac
STUB
chmod +x "$MOCK_DIR/gh"

TMPOUT=$(mktemp)
bash --norc --noprofile -c "
  export PATH=\"$MOCK_DIR:\$PATH\"
  export CFG_REPO=\"test-owner/test-repo\"
  pm_set_status() { return 0; }
  source \"$ITEMS_SH\"
  pm_done 99
" > "$TMPOUT" 2>&1
EXIT_CODE=$?
rm -f "$TMPOUT"
rm -rf "$MOCK_DIR"

assert_exit_zero "pm_done_already_closed_exits_zero" "$EXIT_CODE"

echo ""

# --- Test Group 13: CFG_REPO usage ---
echo "Test Group: CFG_REPO usage"

# items.sh should reference CFG_REPO
if grep -q "CFG_REPO" "$ITEMS_SH" 2>/dev/null; then
  echo "  PASS: items.sh references CFG_REPO"
  PASS=$((PASS + 1))
else
  echo "  FAIL: items.sh does not reference CFG_REPO"
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
