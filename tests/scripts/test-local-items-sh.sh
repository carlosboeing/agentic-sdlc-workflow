#!/usr/bin/env bash
# test-local-items-sh.sh — Tests for scripts/lib/adapters/pm/local/items.sh
#
# Tests follow the Arrange/Act/Assert pattern. No mocking needed — all
# operations run against temporary directories.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
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

echo "========================================"
echo "Testing scripts/lib/adapters/pm/local/items.sh"
echo "========================================"
echo ""

# --- Test Group 0: File existence ---
echo "Test Group: File existence"

if [ -f "$ITEMS_SH" ]; then
  echo "  PASS: items.sh exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: items.sh not found at $ITEMS_SH"
  FAIL=$((FAIL + 1))
fi

LINE_COUNT=$(wc -l < "$ITEMS_SH" 2>/dev/null || echo 9999)
if [ "$LINE_COUNT" -le 200 ]; then
  echo "  PASS: items.sh is under 200 lines ($LINE_COUNT)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: items.sh exceeds 200 lines ($LINE_COUNT)"
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
    source '$ITEMS_SH'
    $snippet
  "
}

# read_body <file> — extract first non-blank line of body (below closing ---)
read_body() {
  local file="$1"
  local second_delim
  second_delim=$(grep -n '^---$' "$file" | awk -F: 'NR==2{print $1}')
  tail -n +"$((second_delim + 1))" "$file" | grep -v '^[[:space:]]*$' | head -1
}

# --- Test Group 1: pm_create_item creates file with correct frontmatter ---
echo "Test Group: pm_create_item creates file with correct frontmatter"

TMPDIR=$(mktemp -d)
OUT=$(run_snippet "$TMPDIR" "pm_create_item story 'My Story' --body 'Hello world'")
EXIT_CODE=$?

assert_exit_zero "pm_create_item_exits_zero" "$EXIT_CODE"
assert_eq "pm_create_item_returns_id_1" "1" "$OUT"

ITEM_FILE="$TMPDIR/.workflow/items/1.md"
if [ -f "$ITEM_FILE" ]; then
  echo "  PASS: pm_create_item_creates_item_file"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_create_item_creates_item_file (not found: $ITEM_FILE)"
  FAIL=$((FAIL + 1))
fi

assert_eq "pm_create_item_id_field" "1" "$(grep '^id:' "$ITEM_FILE" | sed 's/id: //')"
assert_eq "pm_create_item_title_field" "My Story" "$(grep '^title:' "$ITEM_FILE" | sed 's/title: //;s/^\"//;s/\"$//')"
assert_eq "pm_create_item_type_field" "story" "$(grep '^type:' "$ITEM_FILE" | sed 's/type: //')"
assert_eq "pm_create_item_status_field" "backlog" "$(grep '^status:' "$ITEM_FILE" | sed 's/status: //')"
assert_eq "pm_create_item_state_field" "open" "$(grep '^state:' "$ITEM_FILE" | sed 's/state: //')"

# Hierarchy label must be present
if grep -q "hierarchy/story" "$ITEM_FILE"; then
  echo "  PASS: pm_create_item_hierarchy_label_present"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_create_item_hierarchy_label_present"
  FAIL=$((FAIL + 1))
fi

# created and updated timestamps must be present
if grep -q '^created:' "$ITEM_FILE" && grep -q '^updated:' "$ITEM_FILE"; then
  echo "  PASS: pm_create_item_timestamps_present"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_create_item_timestamps_present"
  FAIL=$((FAIL + 1))
fi

# Body content must be below frontmatter
BODY_CONTENT=$(read_body "$ITEM_FILE")
assert_eq "pm_create_item_body_content" "Hello world" "$BODY_CONTENT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 2: pm_create_item sequential IDs ---
echo "Test Group: pm_create_item returns sequential IDs"

TMPDIR=$(mktemp -d)
ID1=$(run_snippet "$TMPDIR" "pm_create_item story 'Story 1'")
ID2=$(run_snippet "$TMPDIR" "pm_create_item epic 'Epic 1'")
ID3=$(run_snippet "$TMPDIR" "pm_create_item backlog 'Backlog 1'")

assert_eq "pm_create_item_id_sequence_1" "1" "$ID1"
assert_eq "pm_create_item_id_sequence_2" "2" "$ID2"
assert_eq "pm_create_item_id_sequence_3" "3" "$ID3"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 3: pm_create_item level -> type and hierarchy label mapping ---
echo "Test Group: pm_create_item level-to-type and hierarchy label mapping"

for LEVEL in backlog epic story docs; do
  TMPDIR=$(mktemp -d)
  run_snippet "$TMPDIR" "pm_create_item $LEVEL 'Test $LEVEL'" > /dev/null
  ITEM_FILE="$TMPDIR/.workflow/items/1.md"
  assert_eq "pm_create_item_type_for_$LEVEL" "$LEVEL" "$(grep '^type:' "$ITEM_FILE" | sed 's/type: //')"
  if grep -q "hierarchy/$LEVEL" "$ITEM_FILE"; then
    echo "  PASS: pm_create_item_hier_label_$LEVEL"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: pm_create_item_hier_label_$LEVEL (file: $(cat "$ITEM_FILE"))"
    FAIL=$((FAIL + 1))
  fi
  rm -rf "$TMPDIR"
done
echo ""

# --- Test Group 4: pm_create_item --body-file flag ---
echo "Test Group: pm_create_item with --body-file"

TMPDIR=$(mktemp -d)
BODY_FILE=$(mktemp)
echo "Body from file" > "$BODY_FILE"
run_snippet "$TMPDIR" "pm_create_item story 'File Story' --body-file '$BODY_FILE'" > /dev/null
EXIT_CODE=$?
BODY_CONTENT=$(read_body "$TMPDIR/.workflow/items/1.md")
assert_exit_zero "pm_create_item_body_file_exits_zero" "$EXIT_CODE"
assert_eq "pm_create_item_body_file_content" "Body from file" "$BODY_CONTENT"
rm -rf "$TMPDIR"
rm -f "$BODY_FILE"
echo ""

# --- Test Group 5: pm_create_item --labels appends to hierarchy label ---
echo "Test Group: pm_create_item with --labels flag"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Labelled Story' --labels 'type/feature,difficulty/easy'" > /dev/null
ITEM_FILE="$TMPDIR/.workflow/items/1.md"

if grep -q "hierarchy/story" "$ITEM_FILE"; then
  echo "  PASS: pm_create_item_labels_includes_hierarchy"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_create_item_labels_includes_hierarchy"
  FAIL=$((FAIL + 1))
fi
if grep -q "type/feature" "$ITEM_FILE"; then
  echo "  PASS: pm_create_item_labels_extra_label_1"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_create_item_labels_extra_label_1 (file: $(cat "$ITEM_FILE"))"
  FAIL=$((FAIL + 1))
fi
if grep -q "difficulty/easy" "$ITEM_FILE"; then
  echo "  PASS: pm_create_item_labels_extra_label_2"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_create_item_labels_extra_label_2 (file: $(cat "$ITEM_FILE"))"
  FAIL=$((FAIL + 1))
fi
rm -rf "$TMPDIR"
echo ""

# --- Test Group 6: pm_create_item error on invalid level ---
echo "Test Group: pm_create_item error on invalid level"

TMPDIR=$(mktemp -d)
OUT=$(run_snippet "$TMPDIR" "pm_create_item invalid 'Test'" 2>&1)
EXIT_CODE=$?
assert_exit_nonzero "pm_create_item_invalid_level_fails" "$EXIT_CODE"
assert_contains "pm_create_item_invalid_level_message" "level" "$OUT"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 7: pm_get_item human-readable format ---
echo "Test Group: pm_get_item human-readable format"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Human Story' --labels 'type/feature'" > /dev/null
OUT=$(run_snippet "$TMPDIR" "pm_get_item 1")
EXIT_CODE=$?

assert_exit_zero "pm_get_item_human_exits_zero" "$EXIT_CODE"
assert_contains "pm_get_item_human_has_title_field" "title:" "$OUT"
assert_contains "pm_get_item_human_shows_title" "Human Story" "$OUT"
assert_contains "pm_get_item_human_has_state_field" "state:" "$OUT"
assert_contains "pm_get_item_human_has_labels_field" "labels:" "$OUT"
# 2-space alignment: "title:  " (2 spaces after colon)
if echo "$OUT" | grep -q "^title:  "; then
  echo "  PASS: pm_get_item_human_two_space_alignment_title"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_get_item_human_two_space_alignment_title (got: $OUT)"
  FAIL=$((FAIL + 1))
fi
rm -rf "$TMPDIR"
echo ""

# --- Test Group 8: pm_get_item --json number,title,state ---
echo "Test Group: pm_get_item --json number,title,state"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'JSON Story'" > /dev/null
OUT=$(run_snippet "$TMPDIR" "pm_get_item 1 --json number,title,state")
EXIT_CODE=$?

assert_exit_zero "pm_get_item_json_exits_zero" "$EXIT_CODE"

# Must be valid JSON parseable by jq
if echo "$OUT" | jq . > /dev/null 2>&1; then
  echo "  PASS: pm_get_item_json_valid_json"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_get_item_json_valid_json (got: $OUT)"
  FAIL=$((FAIL + 1))
fi

assert_eq "pm_get_item_json_number_field" "1" "$(echo "$OUT" | jq -r '.number')"
assert_eq "pm_get_item_json_title_field" "JSON Story" "$(echo "$OUT" | jq -r '.title')"
# state must be uppercase (OPEN, not open)
assert_eq "pm_get_item_json_state_uppercase" "OPEN" "$(echo "$OUT" | jq -r '.state')"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 9: pm_get_item --json body ---
echo "Test Group: pm_get_item --json body"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Body Story' --body 'Body content here'" > /dev/null
OUT=$(run_snippet "$TMPDIR" "pm_get_item 1 --json body")
EXIT_CODE=$?

assert_exit_zero "pm_get_item_json_body_exits_zero" "$EXIT_CODE"
if echo "$OUT" | jq . > /dev/null 2>&1; then
  echo "  PASS: pm_get_item_json_body_valid_json"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_get_item_json_body_valid_json (got: $OUT)"
  FAIL=$((FAIL + 1))
fi
assert_contains "pm_get_item_json_body_content" "Body content here" "$(echo "$OUT" | jq -r '.body')"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 10: pm_get_item --json labels ---
echo "Test Group: pm_get_item --json labels"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Label Story' --labels 'type/feature'" > /dev/null
OUT=$(run_snippet "$TMPDIR" "pm_get_item 1 --json labels")
EXIT_CODE=$?

assert_exit_zero "pm_get_item_json_labels_exits_zero" "$EXIT_CODE"
if echo "$OUT" | jq . > /dev/null 2>&1; then
  echo "  PASS: pm_get_item_json_labels_valid_json"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_get_item_json_labels_valid_json (got: $OUT)"
  FAIL=$((FAIL + 1))
fi
# labels must be array of {name: "..."} objects
LABELS_TYPE=$(echo "$OUT" | jq -r '.labels | type')
assert_eq "pm_get_item_json_labels_is_array" "array" "$LABELS_TYPE"
# hierarchy/story must appear in labels array
if echo "$OUT" | jq -e '.labels[] | select(.name == "hierarchy/story")' > /dev/null 2>&1; then
  echo "  PASS: pm_get_item_json_labels_contains_hierarchy"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_get_item_json_labels_contains_hierarchy (got: $OUT)"
  FAIL=$((FAIL + 1))
fi
rm -rf "$TMPDIR"
echo ""

# --- Test Group 11: pm_list_items defaults ---
echo "Test Group: pm_list_items defaults (state=open, limit=30)"

TMPDIR=$(mktemp -d)
# Create 2 items
run_snippet "$TMPDIR" "pm_create_item story 'Alpha'" > /dev/null
run_snippet "$TMPDIR" "pm_create_item epic 'Beta'" > /dev/null
OUT=$(run_snippet "$TMPDIR" "pm_list_items")
EXIT_CODE=$?

assert_exit_zero "pm_list_items_exits_zero" "$EXIT_CODE"
assert_contains "pm_list_items_shows_alpha" "Alpha" "$OUT"
assert_contains "pm_list_items_shows_beta" "Beta" "$OUT"
# Tab-separated: ID, State (Title Case), Title, Date
if echo "$OUT" | grep -q "^1	"; then
  echo "  PASS: pm_list_items_tab_separated_id"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_list_items_tab_separated_id (got: $OUT)"
  FAIL=$((FAIL + 1))
fi
rm -rf "$TMPDIR"
echo ""

# --- Test Group 12: pm_list_items --label filter ---
echo "Test Group: pm_list_items with --label filter"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Story Item' --labels 'type/feature'" > /dev/null
run_snippet "$TMPDIR" "pm_create_item epic 'Epic Item' --labels 'type/refactor'" > /dev/null
OUT=$(run_snippet "$TMPDIR" "pm_list_items --label hierarchy/story")
EXIT_CODE=$?

assert_exit_zero "pm_list_items_label_exits_zero" "$EXIT_CODE"
assert_contains "pm_list_items_label_shows_story" "Story Item" "$OUT"
if echo "$OUT" | grep -q "Epic Item"; then
  echo "  FAIL: pm_list_items_label_excludes_epic"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: pm_list_items_label_excludes_epic"
  PASS=$((PASS + 1))
fi
rm -rf "$TMPDIR"
echo ""

# --- Test Group 13: pm_list_items --state filter ---
echo "Test Group: pm_list_items with --state filter"

TMPDIR=$(mktemp -d)
# Create item then close it manually by patching state in frontmatter
run_snippet "$TMPDIR" "pm_create_item story 'Open Story'" > /dev/null
run_snippet "$TMPDIR" "pm_create_item story 'Closed Story'" > /dev/null
# Close item 2 via _local_fm_write
run_snippet "$TMPDIR" "_local_fm_write '$TMPDIR/.workflow/items/2.md' state closed" > /dev/null

OUT_OPEN=$(run_snippet "$TMPDIR" "pm_list_items --state open")
OUT_CLOSED=$(run_snippet "$TMPDIR" "pm_list_items --state closed")

assert_contains "pm_list_items_state_open_shows_open" "Open Story" "$OUT_OPEN"
if echo "$OUT_OPEN" | grep -q "Closed Story"; then
  echo "  FAIL: pm_list_items_state_open_excludes_closed"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: pm_list_items_state_open_excludes_closed"
  PASS=$((PASS + 1))
fi
assert_contains "pm_list_items_state_closed_shows_closed" "Closed Story" "$OUT_CLOSED"
if echo "$OUT_CLOSED" | grep -q "Open Story"; then
  echo "  FAIL: pm_list_items_state_closed_excludes_open"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: pm_list_items_state_closed_excludes_open"
  PASS=$((PASS + 1))
fi
rm -rf "$TMPDIR"
echo ""

# --- Test Group 14: pm_list_items --limit filter ---
echo "Test Group: pm_list_items with --limit filter"

TMPDIR=$(mktemp -d)
for i in 1 2 3 4 5; do
  run_snippet "$TMPDIR" "pm_create_item story 'Story $i'" > /dev/null
done
OUT=$(run_snippet "$TMPDIR" "pm_list_items --limit 2")
LINE_COUNT=$(echo "$OUT" | grep -c .)

assert_eq "pm_list_items_limit_2_returns_2_lines" "2" "$LINE_COUNT"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 15: pm_update_item ---
echo "Test Group: pm_update_item"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Original Title' --body 'Original body'" > /dev/null

run_snippet "$TMPDIR" "pm_update_item 1 --title 'Updated Title'" > /dev/null
EXIT_CODE=$?
assert_exit_zero "pm_update_item_title_exits_zero" "$EXIT_CODE"
NEW_TITLE=$(grep '^title:' "$TMPDIR/.workflow/items/1.md" | sed 's/title: //;s/^\"//;s/\"$//')
assert_eq "pm_update_item_title_updated" "Updated Title" "$NEW_TITLE"

run_snippet "$TMPDIR" "pm_update_item 1 --body 'Updated body'" > /dev/null
EXIT_CODE=$?
assert_exit_zero "pm_update_item_body_exits_zero" "$EXIT_CODE"
BODY_CONTENT=$(read_body "$TMPDIR/.workflow/items/1.md")
assert_eq "pm_update_item_body_updated" "Updated body" "$BODY_CONTENT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 16: pm_done ---
echo "Test Group: pm_done sets state to closed and calls pm_set_status"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Done Story'" > /dev/null

# Provide a stub pm_set_status and verify pm_done calls it
STATUS_LOG="$TMPDIR/status_calls.log"
OUT=$(bash --norc --noprofile -c "
  _LOCAL_COMMON_LOADED=''
  _LOCAL_WORKFLOW_DIR='$TMPDIR/.workflow'
  source '$COMMON_SH'
  pm_set_status() {
    echo \"pm_set_status \$1 \$2\" >> '$STATUS_LOG'
  }
  source '$ITEMS_SH'
  pm_done 1
" 2>&1)
EXIT_CODE=$?

assert_exit_zero "pm_done_exits_zero" "$EXIT_CODE"

STATE_VAL=$(grep '^state:' "$TMPDIR/.workflow/items/1.md" | sed 's/state: //')
assert_eq "pm_done_sets_state_closed" "closed" "$STATE_VAL"

if [ -f "$STATUS_LOG" ] && grep -q "pm_set_status 1 done" "$STATUS_LOG"; then
  echo "  PASS: pm_done_calls_pm_set_status_done"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_done_calls_pm_set_status_done (log: $(cat "$STATUS_LOG" 2>/dev/null || echo 'missing'))"
  FAIL=$((FAIL + 1))
fi
rm -rf "$TMPDIR"
echo ""

# --- Test Group 17: pm_get_item error on missing item ---
echo "Test Group: pm_get_item error on nonexistent item"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "_local_ensure_dirs"
OUT=$(run_snippet "$TMPDIR" "pm_get_item 999" 2>&1)
EXIT_CODE=$?
assert_exit_nonzero "pm_get_item_missing_item_fails" "$EXIT_CODE"
assert_contains "pm_get_item_missing_item_message" "999" "$OUT"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 18: pm_update_item error on missing item ---
echo "Test Group: pm_update_item error on nonexistent item"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "_local_ensure_dirs"
OUT=$(run_snippet "$TMPDIR" "pm_update_item 999 --title 'New'" 2>&1)
EXIT_CODE=$?
assert_exit_nonzero "pm_update_item_missing_item_fails" "$EXIT_CODE"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 19: pm_list_items --state all ---
echo "Test Group: pm_list_items --state all"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Open One'" > /dev/null
run_snippet "$TMPDIR" "pm_create_item story 'Closed One'" > /dev/null
run_snippet "$TMPDIR" "_local_fm_write '$TMPDIR/.workflow/items/2.md' state closed" > /dev/null
OUT=$(run_snippet "$TMPDIR" "pm_list_items --state all")

assert_contains "pm_list_items_all_shows_open" "Open One" "$OUT"
assert_contains "pm_list_items_all_shows_closed" "Closed One" "$OUT"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 20: pm_get_item --json with multiple fields ---
echo "Test Group: pm_get_item --json with all key fields"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item backlog 'Full Test' --body 'Some body' --labels 'type/feature'" > /dev/null
OUT=$(run_snippet "$TMPDIR" "pm_get_item 1 --json number,title,state,body,labels")
EXIT_CODE=$?

assert_exit_zero "pm_get_item_json_all_fields_exits_zero" "$EXIT_CODE"
if echo "$OUT" | jq . > /dev/null 2>&1; then
  echo "  PASS: pm_get_item_json_all_fields_valid_json"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_get_item_json_all_fields_valid_json (got: $OUT)"
  FAIL=$((FAIL + 1))
fi
assert_eq "pm_get_item_json_all_number" "1" "$(echo "$OUT" | jq -r '.number')"
assert_eq "pm_get_item_json_all_title" "Full Test" "$(echo "$OUT" | jq -r '.title')"
assert_eq "pm_get_item_json_all_state" "OPEN" "$(echo "$OUT" | jq -r '.state')"
assert_contains "pm_get_item_json_all_body" "Some body" "$(echo "$OUT" | jq -r '.body')"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 21: C1 JSON title escaping (double quotes) ---
echo "Test Group: C1 JSON title escaping — double quotes in title"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" 'pm_create_item story "Title with \"quotes\" inside"' > /dev/null
OUT=$(run_snippet "$TMPDIR" "pm_get_item 1 --json title")
EXIT_CODE=$?

assert_exit_zero "pm_get_item_json_quoted_title_exits_zero" "$EXIT_CODE"
if echo "$OUT" | jq . > /dev/null 2>&1; then
  echo "  PASS: pm_get_item_json_quoted_title_valid_json"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_get_item_json_quoted_title_valid_json (got: $OUT)"
  FAIL=$((FAIL + 1))
fi
assert_contains "pm_get_item_json_quoted_title_value" 'quotes' "$(echo "$OUT" | jq -r '.title')"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 22: C1 JSON title escaping (backslashes) ---
echo "Test Group: C1 JSON title escaping — backslash in title"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" 'pm_create_item story "Path\\to\\thing"' > /dev/null
OUT=$(run_snippet "$TMPDIR" "pm_get_item 1 --json title")
EXIT_CODE=$?

assert_exit_zero "pm_get_item_json_backslash_title_exits_zero" "$EXIT_CODE"
if echo "$OUT" | jq . > /dev/null 2>&1; then
  echo "  PASS: pm_get_item_json_backslash_title_valid_json"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_get_item_json_backslash_title_valid_json (got: $OUT)"
  FAIL=$((FAIL + 1))
fi
rm -rf "$TMPDIR"
echo ""

# --- Test Group 23: W1 labels separator has space after comma ---
echo "Test Group: W1 labels separator — comma-space in human-readable output"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "pm_create_item story 'Sep Story' --labels 'type/feature'" > /dev/null
OUT=$(run_snippet "$TMPDIR" "pm_get_item 1")

# labels line must contain a comma-space (not just comma)
if echo "$OUT" | grep -q "^labels:.*,  *[^ ]"; then
  echo "  PASS: pm_get_item_human_labels_comma_space"
  PASS=$((PASS + 1))
else
  # Accept either "comma-space" or a single label (no comma at all) as passing
  LABEL_LINE=$(echo "$OUT" | grep "^labels:")
  if echo "$LABEL_LINE" | grep -q ","; then
    # There is a comma — it must be followed by a space
    if echo "$LABEL_LINE" | grep -q ", "; then
      echo "  PASS: pm_get_item_human_labels_comma_space"
      PASS=$((PASS + 1))
    else
      echo "  FAIL: pm_get_item_human_labels_comma_space (got: $LABEL_LINE)"
      FAIL=$((FAIL + 1))
    fi
  else
    # Single label, no comma — pass (separator only applies when >1 label)
    echo "  PASS: pm_get_item_human_labels_comma_space (single label, no comma)"
    PASS=$((PASS + 1))
  fi
fi

# Specifically: two labels must be separated with comma-space
TMPDIR2=$(mktemp -d)
run_snippet "$TMPDIR2" "pm_create_item story 'Multi Label' --labels 'type/feature,difficulty/easy'" > /dev/null
OUT2=$(run_snippet "$TMPDIR2" "pm_get_item 1")
LABEL_LINE2=$(echo "$OUT2" | grep "^labels:")
if echo "$LABEL_LINE2" | grep -qF ", "; then
  echo "  PASS: pm_get_item_human_labels_comma_space_multi"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_get_item_human_labels_comma_space_multi (got: $LABEL_LINE2)"
  FAIL=$((FAIL + 1))
fi
rm -rf "$TMPDIR" "$TMPDIR2"
echo ""

# --- Test Group 24: W2 pm_list_items safe glob (no ls pipe) ---
echo "Test Group: W2 pm_list_items works when items dir has no md files"

TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.workflow/items"
# No .md files — should return zero results without error
OUT=$(run_snippet "$TMPDIR" "pm_list_items" 2>&1)
EXIT_CODE=$?

assert_exit_zero "pm_list_items_empty_dir_exits_zero" "$EXIT_CODE"
if [ -z "$OUT" ]; then
  echo "  PASS: pm_list_items_empty_dir_no_output"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_list_items_empty_dir_no_output (got: $OUT)"
  FAIL=$((FAIL + 1))
fi
rm -rf "$TMPDIR"
echo ""

# --- Test Group 25: S4 _local_build_json naming ---
echo "Test Group: S4 _local_build_json naming consistency"

# Verify the old _pm_build_json name is gone and _local_build_json is present
if grep -q "_local_build_json" "$ITEMS_SH"; then
  echo "  PASS: items_sh_uses_local_build_json"
  PASS=$((PASS + 1))
else
  echo "  FAIL: items_sh_uses_local_build_json (function not found)"
  FAIL=$((FAIL + 1))
fi
if grep -q "_pm_build_json" "$ITEMS_SH"; then
  echo "  FAIL: items_sh_no_pm_build_json (old name still present)"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: items_sh_no_pm_build_json"
  PASS=$((PASS + 1))
fi
echo ""

# --- Test Group 26: C3 Multiline body preserved in JSON ---
echo "Test Group: C3 multiline body preserved in JSON output"

TMPDIR=$(mktemp -d)
# Write a real two-line body via a body file so newlines are literal
BODY_TMP=$(mktemp)
printf 'Line 1\nLine 2' > "$BODY_TMP"
run_snippet "$TMPDIR" "pm_create_item story 'Multi Story' --body-file '$BODY_TMP'" > /dev/null
OUT=$(run_snippet "$TMPDIR" "pm_get_item 1 --json body")
EXIT_CODE=$?

assert_exit_zero "pm_get_item_json_multiline_body_exits_zero" "$EXIT_CODE"
if echo "$OUT" | jq . > /dev/null 2>&1; then
  echo "  PASS: pm_get_item_json_multiline_body_valid_json"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_get_item_json_multiline_body_valid_json (got: $OUT)"
  FAIL=$((FAIL + 1))
fi
# Body must preserve line structure: jq -r output must contain a real newline
# (if tr flattened to spaces, jq -r gives "Line 1 Line 2" on one line)
BODY_VAL=$(echo "$OUT" | jq -r '.body' 2>/dev/null || echo "PARSE_ERROR")
LINE_COUNT=$(echo "$BODY_VAL" | grep -c .)
if [ "$LINE_COUNT" -ge 2 ]; then
  echo "  PASS: pm_get_item_json_multiline_body_newline_preserved ($LINE_COUNT lines)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_get_item_json_multiline_body_newline_preserved (body flattened — C3 bug; got 1 line: $BODY_VAL)"
  FAIL=$((FAIL + 1))
fi
rm -f "$BODY_TMP"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 27: W3 _local_item_path rejects non-numeric ID ---
echo "Test Group: W3 _local_item_path rejects non-numeric ID"

TMPDIR=$(mktemp -d)
OUT=$(run_snippet "$TMPDIR" "_local_ensure_dirs; pm_get_item 'abc'" 2>&1)
EXIT_CODE=$?
assert_exit_nonzero "pm_get_item_nonnumeric_id_fails" "$EXIT_CODE"
assert_contains "pm_get_item_nonnumeric_id_message" "abc" "$OUT"

OUT2=$(run_snippet "$TMPDIR" "_local_ensure_dirs; pm_get_item '../../etc/passwd'" 2>&1)
EXIT_CODE2=$?
assert_exit_nonzero "pm_get_item_path_traversal_fails" "$EXIT_CODE2"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 28: _local_pm_create_item_with_id creates file at explicit ID ---
echo "Test Group: _local_pm_create_item_with_id creates item at explicit ID"

TMPDIR=$(mktemp -d)
OUT=$(run_snippet "$TMPDIR" "_local_pm_create_item_with_id 42 story 'Explicit Story' --body 'Explicit body'")
EXIT_CODE=$?

assert_exit_zero "create_with_id_exits_zero" "$EXIT_CODE"
assert_eq "create_with_id_returns_id" "42" "$OUT"

ITEM_FILE="$TMPDIR/.workflow/items/42.md"
if [ -f "$ITEM_FILE" ]; then
  echo "  PASS: create_with_id_creates_file_at_correct_path"
  PASS=$((PASS + 1))
else
  echo "  FAIL: create_with_id_creates_file_at_correct_path (not found: $ITEM_FILE)"
  FAIL=$((FAIL + 1))
fi

assert_eq "create_with_id_id_field" "42" "$(grep '^id:' "$ITEM_FILE" | sed 's/id: //')"
assert_eq "create_with_id_title_field" "Explicit Story" "$(grep '^title:' "$ITEM_FILE" | sed 's/title: //;s/^\"//;s/\"$//')"
assert_eq "create_with_id_type_field" "story" "$(grep '^type:' "$ITEM_FILE" | sed 's/type: //')"
assert_eq "create_with_id_status_field" "backlog" "$(grep '^status:' "$ITEM_FILE" | sed 's/status: //')"
assert_eq "create_with_id_state_field" "open" "$(grep '^state:' "$ITEM_FILE" | sed 's/state: //')"

# Hierarchy label must be present
if grep -q "hierarchy/story" "$ITEM_FILE"; then
  echo "  PASS: create_with_id_hierarchy_label_present"
  PASS=$((PASS + 1))
else
  echo "  FAIL: create_with_id_hierarchy_label_present"
  FAIL=$((FAIL + 1))
fi

# Body content must be below frontmatter
BODY_CONTENT=$(read_body "$ITEM_FILE")
assert_eq "create_with_id_body_content" "Explicit body" "$BODY_CONTENT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 29: _local_pm_create_item_with_id bumps _next_id counter ---
echo "Test Group: _local_pm_create_item_with_id bumps _next_id counter to max(current, explicit+1)"

# Case 1: explicit ID (42) > current counter (1) — counter bumped to 43
TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "_local_pm_create_item_with_id 42 story 'Story'" > /dev/null
NEXT_ID=$(cat "$TMPDIR/.workflow/_next_id")
assert_eq "create_with_id_bumps_counter_above_explicit" "43" "$NEXT_ID"
rm -rf "$TMPDIR"

# Case 2: explicit ID (2) < current counter (10) — counter NOT regressed
TMPDIR=$(mktemp -d)
# Manually seed counter to 10
mkdir -p "$TMPDIR/.workflow"
echo "10" > "$TMPDIR/.workflow/_next_id"
# Need to also create the items/ dir
mkdir -p "$TMPDIR/.workflow/items"
run_snippet "$TMPDIR" "_local_pm_create_item_with_id 2 story 'Low ID Story'" > /dev/null
NEXT_ID=$(cat "$TMPDIR/.workflow/_next_id")
assert_eq "create_with_id_does_not_regress_counter" "10" "$NEXT_ID"
rm -rf "$TMPDIR"

echo ""

# --- Test Group 30: pm_create_item auto-increments from counter after explicit ID usage ---
echo "Test Group: pm_create_item auto-increments correctly after _local_pm_create_item_with_id"

TMPDIR=$(mktemp -d)
# Create with explicit ID 42 — counter should become 43
run_snippet "$TMPDIR" "_local_pm_create_item_with_id 42 story 'Explicit'" > /dev/null
# Now auto-increment should start from 43
NEXT=$(run_snippet "$TMPDIR" "pm_create_item story 'Auto One'")
assert_eq "create_with_id_auto_increment_starts_from_43" "43" "$NEXT"
# And subsequent auto-increment gives 44
NEXT2=$(run_snippet "$TMPDIR" "pm_create_item story 'Auto Two'")
assert_eq "create_with_id_auto_increment_second_is_44" "44" "$NEXT2"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 31: _local_pm_create_item_with_id --labels flag ---
echo "Test Group: _local_pm_create_item_with_id with --labels flag"

TMPDIR=$(mktemp -d)
run_snippet "$TMPDIR" "_local_pm_create_item_with_id 10 epic 'Labeled Epic' --labels 'type/feature,difficulty/medium'" > /dev/null
ITEM_FILE="$TMPDIR/.workflow/items/10.md"

if grep -q "hierarchy/epic" "$ITEM_FILE"; then
  echo "  PASS: create_with_id_labels_includes_hierarchy"
  PASS=$((PASS + 1))
else
  echo "  FAIL: create_with_id_labels_includes_hierarchy"
  FAIL=$((FAIL + 1))
fi
if grep -q "type/feature" "$ITEM_FILE"; then
  echo "  PASS: create_with_id_labels_extra_label_1"
  PASS=$((PASS + 1))
else
  echo "  FAIL: create_with_id_labels_extra_label_1 (file: $(cat "$ITEM_FILE"))"
  FAIL=$((FAIL + 1))
fi
if grep -q "difficulty/medium" "$ITEM_FILE"; then
  echo "  PASS: create_with_id_labels_extra_label_2"
  PASS=$((PASS + 1))
else
  echo "  FAIL: create_with_id_labels_extra_label_2 (file: $(cat "$ITEM_FILE"))"
  FAIL=$((FAIL + 1))
fi
rm -rf "$TMPDIR"
echo ""

# --- Test Group 32: _local_pm_create_item_with_id --body-file flag ---
echo "Test Group: _local_pm_create_item_with_id with --body-file flag"

TMPDIR=$(mktemp -d)
BODY_FILE=$(mktemp)
echo "Body from file for explicit ID" > "$BODY_FILE"
run_snippet "$TMPDIR" "_local_pm_create_item_with_id 7 backlog 'File Backlog' --body-file '$BODY_FILE'" > /dev/null
EXIT_CODE=$?
BODY_CONTENT=$(read_body "$TMPDIR/.workflow/items/7.md")
assert_exit_zero "create_with_id_body_file_exits_zero" "$EXIT_CODE"
assert_eq "create_with_id_body_file_content" "Body from file for explicit ID" "$BODY_CONTENT"
rm -rf "$TMPDIR"
rm -f "$BODY_FILE"
echo ""

# --- Test Group 33: _local_pm_create_item_with_id is not a pm_* exported function ---
echo "Test Group: _local_pm_create_item_with_id is a private helper (not pm_*)"

# Verify the function is defined with underscore prefix in items.sh
if grep -q "^_local_pm_create_item_with_id()" "$ITEMS_SH"; then
  echo "  PASS: create_with_id_has_underscore_prefix_definition"
  PASS=$((PASS + 1))
else
  echo "  FAIL: create_with_id_has_underscore_prefix_definition (not found in $ITEMS_SH)"
  FAIL=$((FAIL + 1))
fi

# Verify there is no pm_create_item_with_id (no public version)
if grep -q "^pm_create_item_with_id()" "$ITEMS_SH"; then
  echo "  FAIL: create_with_id_no_public_pm_version (public function found)"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: create_with_id_no_public_pm_version"
  PASS=$((PASS + 1))
fi
echo ""

# --- Test Group 34: _local_write_item shared helper exists ---
echo "Test Group: _local_write_item shared helper exists and is used by both create functions"

# Verify _local_write_item is defined in items.sh
if grep -q "^_local_write_item()" "$ITEMS_SH"; then
  echo "  PASS: local_write_item_helper_defined"
  PASS=$((PASS + 1))
else
  echo "  FAIL: local_write_item_helper_defined (not found in $ITEMS_SH)"
  FAIL=$((FAIL + 1))
fi

# Verify pm_create_item calls _local_write_item
if grep -A 30 "^pm_create_item()" "$ITEMS_SH" | grep -q "_local_write_item"; then
  echo "  PASS: pm_create_item_calls_write_item"
  PASS=$((PASS + 1))
else
  echo "  FAIL: pm_create_item_calls_write_item"
  FAIL=$((FAIL + 1))
fi

# Verify _local_pm_create_item_with_id calls _local_write_item
if grep -A 20 "^_local_pm_create_item_with_id()" "$ITEMS_SH" | grep -q "_local_write_item"; then
  echo "  PASS: create_with_id_calls_write_item"
  PASS=$((PASS + 1))
else
  echo "  FAIL: create_with_id_calls_write_item"
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
