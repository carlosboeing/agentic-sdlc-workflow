#!/usr/bin/env bash
# test-local-integration.sh — Integration tests: local adapter via pm.sh loader.
# Exercises the full item lifecycle end-to-end in a temp directory.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOCAL_ADAPTER_DIR="$REPO_ROOT/scripts/lib/adapters/pm/local"
PM_SH="$REPO_ROOT/scripts/lib/pm.sh"
PASS=0; FAIL=0

assert_eq() {
  if [ "$2" = "$3" ]; then echo "  PASS: $1"; PASS=$((PASS+1))
  else echo "  FAIL: $1"; echo "    Expected: $2"; echo "    Actual:   $3"; FAIL=$((FAIL+1)); fi
}
assert_contains() {
  if echo "$3" | grep -qF -- "$2"; then echo "  PASS: $1"; PASS=$((PASS+1))
  else echo "  FAIL: $1 (expected: $2)"; FAIL=$((FAIL+1)); fi
}

# run_in_env <tmpdir> <snippet> — source local adapter via pm.sh and run snippet
run_in_env() {
  bash --norc --noprofile -c "
    export _PM_TEST_ADAPTER_DIR='$LOCAL_ADAPTER_DIR'
    export _LOCAL_WORKFLOW_DIR='$1/.workflow'
    export _LOCAL_COMMON_LOADED='' _LOCAL_ITEMS_LOADED='' _LOCAL_BOARD_LOADED=''
    export _LOCAL_COMMENTS_LOADED='' _LOCAL_HIERARCHY_LOADED='' _LOCAL_LABELS_LOADED=''
    export _LOCAL_LIFECYCLE_LOADED='' _LOCAL_RECONCILE_LOADED=''
    export _PM_SH_LOADED='' _PM_SH_LOADED_DIR=''
    source '$PM_SH'
    $2
  "
}

echo "========================================"
echo "Integration: local adapter via pm.sh"
echo "========================================"
echo ""

# ─── Group 1: File checks ─────────────────────────────────────────────────────
echo "Test Group: File checks"
if [ -f "$SCRIPT_DIR/test-local-integration.sh" ]; then echo "  PASS: test file exists"; PASS=$((PASS+1))
else echo "  FAIL: test file not found"; FAIL=$((FAIL+1)); fi
LC=$(wc -l < "$SCRIPT_DIR/test-local-integration.sh")
if [ "$LC" -le 200 ]; then echo "  PASS: under 200 lines ($LC)"; PASS=$((PASS+1))
else echo "  FAIL: exceeds 200 lines ($LC)"; FAIL=$((FAIL+1)); fi
echo ""

# ─── Group 2: Full lifecycle ──────────────────────────────────────────────────
echo "Test Group: Full item lifecycle (create -> link -> status transitions -> done)"
T=$(mktemp -d)

IDS=$(run_in_env "$T" "
  BID=\$(pm_create_item backlog 'My Backlog' --labels 'backlog/111-test')
  EID=\$(pm_create_item epic   '[E01] My Epic')
  SID=\$(pm_create_item story  '[E01-S01] My Story' --labels 'difficulty/easy')
  pm_link_child \"\$BID\" \"\$EID\" >/dev/null
  pm_link_child \"\$EID\" \"\$SID\" >/dev/null
  echo \"\$BID \$EID \$SID\"
")
BID=$(echo "$IDS"|awk '{print $1}'); EID=$(echo "$IDS"|awk '{print $2}'); SID=$(echo "$IDS"|awk '{print $3}')
assert_eq "ids_assigned_sequentially" "1 2 3" "$BID $EID $SID"

EPIC_PARENT=$(grep "^parent:" "$T/.workflow/items/2.md" | sed 's/parent: //')
STORY_PARENT=$(grep "^parent:" "$T/.workflow/items/3.md" | sed 's/parent: //')
assert_eq "epic_parent_links_to_backlog" "1" "$EPIC_PARENT"
assert_eq "story_parent_links_to_epic"   "2" "$STORY_PARENT"

# Transition: ready -> start_work (in-progress) -> complete_work (in-review) -> done
run_in_env "$T" "pm_set_status $SID ready; pm_start_work $SID --model sonnet --agent builder; pm_complete_work $SID abc123; pm_done $SID" >/dev/null
FINAL_STATUS=$(grep "^status:" "$T/.workflow/items/3.md"|sed 's/status: //')
FINAL_STATE=$(grep  "^state:"  "$T/.workflow/items/3.md"|sed 's/state: //')
assert_eq "story_final_status_done"   "done"   "$FINAL_STATUS"
assert_eq "story_final_state_closed"  "closed" "$FINAL_STATE"
rm -rf "$T"
echo ""

# ─── Group 3: Comment structure ───────────────────────────────────────────────
echo "Test Group: Comment files created with correct structure"
T=$(mktemp -d)
run_in_env "$T" "
  pm_create_item story 'Comment Story' >/dev/null
  pm_start_work 1 --model sonnet --agent builder >/dev/null
  pm_complete_work 1 deadbeef0000 >/dev/null
" >/dev/null

CDIR="$T/.workflow/comments/1"
assert_eq "two_comment_files_created" "2" "$(ls "$CDIR/" | wc -l | tr -d ' ')"
STARTED=$(cat "$CDIR/001-work-started.md")
REVIEW=$(cat "$CDIR/002-ready-for-review.md")
assert_contains "work_started_posted_header"  "<!-- posted:"        "$STARTED"
assert_contains "work_started_emoji_heading"  "### 🚀 Work Started"  "$STARTED"
assert_contains "work_started_model_field"    "**Model**"           "$STARTED"
assert_contains "review_posted_header"        "<!-- posted:"        "$REVIEW"
assert_contains "review_emoji_heading"        "### 👀 Ready for Review" "$REVIEW"
assert_contains "review_commit_hash"          "deadbeef0000"        "$REVIEW"
rm -rf "$T"
echo ""

# ─── Group 4: pm_get_item --json compatibility ────────────────────────────────
echo "Test Group: pm_get_item --json parseable by jq (GitHub adapter compat)"
T=$(mktemp -d)
run_in_env "$T" "pm_create_item story 'JSON Story' --labels 'difficulty/medium' >/dev/null" >/dev/null
JSON=$(run_in_env "$T" "pm_get_item 1 --json 'number,title,state,labels'")

NUM=$(echo "$JSON"  | jq -r '.number'        2>/dev/null || echo "PARSE_ERROR")
TITLE=$(echo "$JSON"| jq -r '.title'         2>/dev/null || echo "PARSE_ERROR")
STATE=$(echo "$JSON"| jq -r '.state'         2>/dev/null || echo "PARSE_ERROR")
LBL=$(echo "$JSON"  | jq -r '.labels[0].name' 2>/dev/null || echo "PARSE_ERROR")

assert_eq "json_number_field"      "1"          "$NUM"
assert_eq "json_title_field"       "JSON Story" "$TITLE"
assert_eq "json_state_upper"       "OPEN"       "$STATE"
assert_eq "json_label_name_schema" "hierarchy/story" "$LBL"
rm -rf "$T"
echo ""

# ─── Group 5: pm_list_items filtering ────────────────────────────────────────
echo "Test Group: pm_list_items filtering by label, state, and limit"
T=$(mktemp -d)
run_in_env "$T" "
  pm_create_item backlog 'B' --labels 'backlog/111-test' >/dev/null
  pm_create_item epic   'E' --labels 'backlog/111-test' >/dev/null
  pm_create_item story  'S' --labels 'backlog/111-test' >/dev/null
  pm_create_item story  'Done' --labels 'backlog/111-test' >/dev/null
  pm_done 4 >/dev/null
" >/dev/null

assert_eq "list_label_open"   "3" "$(run_in_env "$T" "pm_list_items --label 'backlog/111-test' --state open"  | grep -c . || true)"
assert_eq "list_state_closed" "1" "$(run_in_env "$T" "pm_list_items --state closed" | grep -c . || true)"
assert_eq "list_state_all"    "4" "$(run_in_env "$T" "pm_list_items --state all"    | grep -c . || true)"
assert_eq "list_limit"        "2" "$(run_in_env "$T" "pm_list_items --state all --limit 2" | grep -c . || true)"
rm -rf "$T"
echo ""

# ─── Group 6: Frontmatter integrity after multiple operations ─────────────────
echo "Test Group: Frontmatter integrity after multiple operations"
T=$(mktemp -d)
run_in_env "$T" "
  pm_create_item story 'FM Story' --labels 'hierarchy/story' >/dev/null
  pm_add_label 1 'difficulty/hard' >/dev/null
  pm_set_status 1 ready >/dev/null
  pm_set_status 1 in-progress >/dev/null
" >/dev/null

ITEM="$T/.workflow/items/1.md"
assert_eq "frontmatter_fence_count" "2" "$(grep -c '^---$' "$ITEM" || true)"
for field in id title type status state labels parent created updated; do
  if grep -q "^${field}:" "$ITEM"; then echo "  PASS: field_${field}_present"; PASS=$((PASS+1))
  else echo "  FAIL: field_${field}_present"; FAIL=$((FAIL+1)); fi
done
LBLS=$(awk '/^---$/{b++; if(b==2)exit; next} b==1 && /^  - /{print}' "$ITEM")
assert_contains "hierarchy_label_preserved" "hierarchy/story" "$LBLS"
assert_contains "added_label_present"       "difficulty/hard" "$LBLS"
rm -rf "$T"
echo ""

# ─── Group 7: Idempotency ────────────────────────────────────────────────────
echo "Test Group: Idempotency — double status set and double label add"
T=$(mktemp -d)
run_in_env "$T" "pm_create_item story 'Idempotent Story'" >/dev/null
OUT=$(run_in_env "$T" "pm_set_status 1 ready; pm_set_status 1 ready")
assert_contains "double_status_set_skips" "already at" "$OUT"
run_in_env "$T" "pm_add_label 1 'my-label'; pm_add_label 1 'my-label'" >/dev/null
CNT=$(awk '/^---$/{b++; if(b==2)exit; next} b==1 && /my-label/{c++} END{print c+0}' "$T/.workflow/items/1.md")
assert_eq "double_label_add_idempotent" "1" "$CNT"
rm -rf "$T"
echo ""

# ─── Summary ──────────────────────────────────────────────────────────────────
echo "========================================"
echo "Results: $PASS/$((PASS+FAIL)) passed, $FAIL failed"
echo "========================================"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
