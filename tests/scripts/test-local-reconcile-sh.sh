#!/usr/bin/env bash
# test-local-reconcile-sh.sh — Tests for scripts/lib/adapters/pm/local/reconcile.sh
#
# Tests follow the Arrange/Act/Assert pattern. All operations run against
# temporary directories — no GitHub API calls, no mocking needed.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RECONCILE_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/reconcile.sh"
COMMON_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/_common.sh"
ITEMS_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/items.sh"
BOARD_SH="$REPO_ROOT/scripts/lib/adapters/pm/local/board.sh"

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
    echo "    Got: $(echo "$haystack" | head -10)"
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
    echo "    Got: $(echo "$haystack" | head -10)"
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
echo "Testing scripts/lib/adapters/pm/local/reconcile.sh"
echo "========================================"
echo ""

# --- Test Group 0: File existence and line count ---
echo "Test Group: File existence and size"

if [ -f "$RECONCILE_SH" ]; then
  echo "  PASS: reconcile.sh exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL: reconcile.sh not found at $RECONCILE_SH"
  FAIL=$((FAIL + 1))
fi

LINE_COUNT=$(wc -l < "$RECONCILE_SH" 2>/dev/null || echo 9999)
if [ "$LINE_COUNT" -le 200 ]; then
  echo "  PASS: reconcile.sh is under 200 lines ($LINE_COUNT)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: reconcile.sh exceeds 200 lines ($LINE_COUNT)"
  FAIL=$((FAIL + 1))
fi
echo ""

# --- Helper: run snippet in an isolated workflow dir ---
# Sources _common.sh, items.sh, board.sh, and reconcile.sh into a fresh shell.
run_snippet() {
  local tmpdir="$1"
  local snippet="$2"
  bash --norc --noprofile -c "
    _LOCAL_COMMON_LOADED=''
    _LOCAL_ITEMS_LOADED=''
    _LOCAL_BOARD_LOADED=''
    _LOCAL_RECONCILE_LOADED=''
    _LOCAL_WORKFLOW_DIR='$tmpdir/.workflow'
    source '$COMMON_SH'
    source '$ITEMS_SH'
    source '$BOARD_SH'
    source '$RECONCILE_SH'
    $snippet
  "
}

# Helper: write a minimal orchestrator state file with story statuses.
# Usage: write_state_file <output_path> <backlog_id> <epic_slug> <story_id> <story_status>
write_state_file() {
  local state_path="$1" backlog_id="$2" epic_slug="$3" story_id="$4" story_status="$5"
  cat > "$state_path" << EOF
{
  "session": {
    "backlog": $backlog_id,
    "mode": "autonomous"
  },
  "dispatches": [],
  "epics": {
    "$epic_slug": {
      "stories": {
        "$story_id": {
          "status": "$story_status"
        }
      }
    }
  }
}
EOF
}

# Helper: write a state file with multiple stories across epics.
write_multi_story_state() {
  local state_path="$1" backlog_id="$2"
  cat > "$state_path" << EOF
{
  "session": {
    "backlog": $backlog_id,
    "mode": "autonomous"
  },
  "dispatches": [],
  "epics": {
    "e01": {
      "stories": {
        "10": { "status": "merged" },
        "11": { "status": "building" }
      }
    },
    "e02": {
      "stories": {
        "20": { "status": "reviewed" }
      }
    }
  }
}
EOF
}

# Helper: write a state file with a completed doc dispatch.
write_state_with_doc() {
  local state_path="$1" backlog_id="$2" doc_issue="$3"
  cat > "$state_path" << EOF
{
  "session": {
    "backlog": $backlog_id,
    "mode": "autonomous"
  },
  "dispatches": [
    {
      "agent": "planner",
      "issue": $doc_issue,
      "result": "success"
    }
  ],
  "epics": {}
}
EOF
}

# read_fm_field <file> <field> — extract a frontmatter scalar value.
read_fm_field() {
  local file="$1" field="$2"
  grep "^${field}:" "$file" | head -1 | sed "s/^${field}: *//"
}

# --- Test Group 1: File existence and --from-state required ---
echo "Test Group: pm_reconcile argument validation"

TMPDIR=$(mktemp -d)
STATE_FILE="$TMPDIR/state.json"
write_state_file "$STATE_FILE" 99 "e01" "1" "merged"

# Missing --from-state
OUT=$(run_snippet "$TMPDIR" "pm_reconcile" 2>&1)
EXIT_CODE=$?
assert_exit_nonzero "reconcile_no_args_fails" "$EXIT_CODE"

# Nonexistent state file
OUT=$(run_snippet "$TMPDIR" "pm_reconcile --from-state /nonexistent/state.json" 2>&1)
EXIT_CODE=$?
assert_exit_nonzero "reconcile_nonexistent_state_fails" "$EXIT_CODE"
assert_contains "reconcile_nonexistent_state_error_msg" "required" "$OUT"

# Unknown option
OUT=$(run_snippet "$TMPDIR" "pm_reconcile --unknown-flag value --from-state $STATE_FILE" 2>&1)
EXIT_CODE=$?
assert_exit_nonzero "reconcile_unknown_option_fails" "$EXIT_CODE"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 2: All statuses consistent (no fixes needed) ---
echo "Test Group: pm_reconcile all statuses consistent"

TMPDIR=$(mktemp -d)
STATE_FILE="$TMPDIR/state.json"

# Create the backlog item (id=99) and a story item (id=1)
run_snippet "$TMPDIR" "pm_create_item backlog 'Backlog Item'" > /dev/null
run_snippet "$TMPDIR" "pm_create_item story 'Story Item'" > /dev/null
# Set backlog to in-progress (expected from state since no pr-review dispatch)
run_snippet "$TMPDIR" "pm_set_status 1 in-progress" > /dev/null  # backlog=1 in this test
run_snippet "$TMPDIR" "pm_set_status 2 in-review" > /dev/null    # merged story = in-review

# State file: backlog=1, story=2, story_status=merged (maps to in-review)
cat > "$STATE_FILE" << EOF
{
  "session": { "backlog": 1, "mode": "autonomous" },
  "dispatches": [],
  "epics": {
    "e01": {
      "stories": {
        "2": { "status": "merged" }
      }
    }
  }
}
EOF

OUT=$(run_snippet "$TMPDIR" "pm_reconcile --from-state $STATE_FILE")
EXIT_CODE=$?
assert_exit_zero "reconcile_consistent_exits_zero" "$EXIT_CODE"
assert_contains "reconcile_consistent_checkmark_backlog" "#1:" "$OUT"
assert_contains "reconcile_consistent_checkmark_story" "#2:" "$OUT"
assert_contains "reconcile_consistent_summary_zero_fixes" "consistent" "$OUT"
assert_not_contains "reconcile_consistent_no_discrepancy_word" "expected=" "$OUT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 3: Discrepancy detected and fixed ---
echo "Test Group: pm_reconcile detects and fixes discrepancy"

TMPDIR=$(mktemp -d)
STATE_FILE="$TMPDIR/state.json"

# Create backlog (id=1) and story (id=2)
run_snippet "$TMPDIR" "pm_create_item backlog 'Backlog Item'" > /dev/null
run_snippet "$TMPDIR" "pm_create_item story 'Story A'" > /dev/null
# Set backlog correctly but leave story at backlog (wrong status)
run_snippet "$TMPDIR" "pm_set_status 1 in-progress" > /dev/null
# story stays at 'backlog' (default) but state says it should be 'in-review'

cat > "$STATE_FILE" << EOF
{
  "session": { "backlog": 1, "mode": "autonomous" },
  "dispatches": [],
  "epics": {
    "e01": {
      "stories": {
        "2": { "status": "merged" }
      }
    }
  }
}
EOF

OUT=$(run_snippet "$TMPDIR" "pm_reconcile --from-state $STATE_FILE")
EXIT_CODE=$?
assert_exit_zero "reconcile_fix_exits_zero" "$EXIT_CODE"
assert_contains "reconcile_fix_shows_discrepancy" "expected=" "$OUT"
assert_contains "reconcile_fix_shows_actual" "actual=" "$OUT"
assert_contains "reconcile_fix_summary_has_fixes" "fix" "$OUT"

# Verify the fix was actually applied to the frontmatter
STORY_STATUS=$(read_fm_field "$TMPDIR/.workflow/items/2.md" status)
assert_eq "reconcile_fix_applies_to_frontmatter" "in-review" "$STORY_STATUS"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 4: Dry-run mode reports but does not fix ---
echo "Test Group: pm_reconcile dry-run does not modify frontmatter"

TMPDIR=$(mktemp -d)
STATE_FILE="$TMPDIR/state.json"

# Create backlog (id=1) and story (id=2)
run_snippet "$TMPDIR" "pm_create_item backlog 'Backlog Item'" > /dev/null
run_snippet "$TMPDIR" "pm_create_item story 'Story Dry'" > /dev/null
run_snippet "$TMPDIR" "pm_set_status 1 in-progress" > /dev/null
# story is 'backlog', expected is 'in-review' from state

cat > "$STATE_FILE" << EOF
{
  "session": { "backlog": 1, "mode": "autonomous" },
  "dispatches": [],
  "epics": {
    "e01": {
      "stories": {
        "2": { "status": "merged" }
      }
    }
  }
}
EOF

OUT=$(run_snippet "$TMPDIR" "pm_reconcile --from-state $STATE_FILE --dry-run")
EXIT_CODE=$?
assert_exit_zero "reconcile_dryrun_exits_zero" "$EXIT_CODE"
assert_contains "reconcile_dryrun_reports_discrepancy" "expected=" "$OUT"
assert_contains "reconcile_dryrun_summary_mentions_dry" "ry" "$OUT"  # "Dry run" or "dry-run"

# Frontmatter must NOT be modified
STORY_STATUS_AFTER=$(read_fm_field "$TMPDIR/.workflow/items/2.md" status)
assert_eq "reconcile_dryrun_does_not_fix" "backlog" "$STORY_STATUS_AFTER"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 5: Mock state file with dispatches, stories, epic-issues ---
echo "Test Group: pm_reconcile with epic-issues JSON"

TMPDIR=$(mktemp -d)
STATE_FILE="$TMPDIR/state.json"

# Create backlog=1, epic item=2, two stories=3,4
run_snippet "$TMPDIR" "pm_create_item backlog 'Backlog'" > /dev/null
run_snippet "$TMPDIR" "pm_create_item epic 'Epic 1'" > /dev/null
run_snippet "$TMPDIR" "pm_create_item story 'Story A'" > /dev/null
run_snippet "$TMPDIR" "pm_create_item story 'Story B'" > /dev/null

# Set all to expected statuses: backlog=in-progress, epic=in-review, both stories=in-review
run_snippet "$TMPDIR" "pm_set_status 1 in-progress" > /dev/null
run_snippet "$TMPDIR" "pm_set_status 2 in-review" > /dev/null
run_snippet "$TMPDIR" "pm_set_status 3 in-review" > /dev/null
run_snippet "$TMPDIR" "pm_set_status 4 in-review" > /dev/null

cat > "$STATE_FILE" << EOF
{
  "session": { "backlog": 1, "mode": "autonomous" },
  "dispatches": [],
  "epics": {
    "e01": {
      "stories": {
        "3": { "status": "merged" },
        "4": { "status": "reviewed" }
      }
    }
  }
}
EOF

OUT=$(run_snippet "$TMPDIR" "pm_reconcile --from-state $STATE_FILE --epic-issues '{\"e01\":2}'")
EXIT_CODE=$?
assert_exit_zero "reconcile_epic_issues_exits_zero" "$EXIT_CODE"
assert_contains "reconcile_epic_issues_checks_backlog" "#1:" "$OUT"
assert_contains "reconcile_epic_issues_checks_epic" "#2:" "$OUT"
assert_contains "reconcile_epic_issues_checks_story3" "#3:" "$OUT"
assert_contains "reconcile_epic_issues_checks_story4" "#4:" "$OUT"
assert_contains "reconcile_epic_issues_consistent_summary" "consistent" "$OUT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 6: Summary line format ---
echo "Test Group: pm_reconcile summary line format"

TMPDIR=$(mktemp -d)
STATE_FILE="$TMPDIR/state.json"

# Two items: backlog=1 correct, story=2 needs fix
run_snippet "$TMPDIR" "pm_create_item backlog 'Backlog'" > /dev/null
run_snippet "$TMPDIR" "pm_create_item story 'Story'" > /dev/null
run_snippet "$TMPDIR" "pm_set_status 1 in-progress" > /dev/null
# story stays at default 'backlog'; state says it should be in-review (status=merged)

cat > "$STATE_FILE" << EOF
{
  "session": { "backlog": 1, "mode": "autonomous" },
  "dispatches": [],
  "epics": {
    "e01": {
      "stories": {
        "2": { "status": "merged" }
      }
    }
  }
}
EOF

OUT=$(run_snippet "$TMPDIR" "pm_reconcile --from-state $STATE_FILE")
# Summary should contain counts
assert_contains "reconcile_summary_has_count" "2" "$OUT"
assert_contains "reconcile_summary_mentions_issues" "issue" "$OUT"

# Check dry-run summary separately
OUT_DRY=$(run_snippet "$TMPDIR" "pm_reconcile --from-state $STATE_FILE --dry-run")
assert_contains "reconcile_dryrun_summary_has_fix_count" "1" "$OUT_DRY"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 7: Logging to board-status.log ---
echo "Test Group: pm_reconcile logs reconcile events"

TMPDIR=$(mktemp -d)
STATE_FILE="$TMPDIR/state.json"

run_snippet "$TMPDIR" "pm_create_item backlog 'Backlog'" > /dev/null
run_snippet "$TMPDIR" "pm_set_status 1 in-progress" > /dev/null

cat > "$STATE_FILE" << EOF
{
  "session": { "backlog": 1, "mode": "autonomous" },
  "dispatches": [],
  "epics": {}
}
EOF

run_snippet "$TMPDIR" "pm_reconcile --from-state $STATE_FILE" > /dev/null

LOG_FILE="$TMPDIR/.workflow/logs/board-status.log"
if [ -f "$LOG_FILE" ]; then
  echo "  PASS: reconcile_log_file_created"
  PASS=$((PASS + 1))
else
  echo "  FAIL: reconcile_log_file_created (not found at $LOG_FILE)"
  FAIL=$((FAIL + 1))
fi

if [ -f "$LOG_FILE" ] && grep -q "reconcile" "$LOG_FILE"; then
  echo "  PASS: reconcile_log_contains_reconcile_event"
  PASS=$((PASS + 1))
else
  echo "  FAIL: reconcile_log_contains_reconcile_event (log: $(cat "$LOG_FILE" 2>/dev/null))"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"
echo ""

# --- Test Group 8: Story status mapping (all status values) ---
echo "Test Group: Story status maps to correct board status"

# Mapping: reviewed/merged -> in-review, building/built/reviewing -> in-progress, other -> ready
for STORY_STATUS in "merged" "reviewed"; do
  TMPDIR=$(mktemp -d)
  STATE_FILE="$TMPDIR/state.json"
  run_snippet "$TMPDIR" "pm_create_item backlog 'Backlog'" > /dev/null
  run_snippet "$TMPDIR" "pm_create_item story 'Story'" > /dev/null
  run_snippet "$TMPDIR" "pm_set_status 1 in-progress" > /dev/null
  run_snippet "$TMPDIR" "pm_set_status 2 in-review" > /dev/null  # pre-set to expected

  cat > "$STATE_FILE" << EOF
{
  "session": { "backlog": 1, "mode": "autonomous" },
  "dispatches": [],
  "epics": { "e01": { "stories": { "2": { "status": "$STORY_STATUS" } } } }
}
EOF

  OUT=$(run_snippet "$TMPDIR" "pm_reconcile --from-state $STATE_FILE")
  assert_contains "reconcile_${STORY_STATUS}_maps_to_in_review" "consistent" "$OUT"
  rm -rf "$TMPDIR"
done

for STORY_STATUS in "building" "built" "reviewing"; do
  TMPDIR=$(mktemp -d)
  STATE_FILE="$TMPDIR/state.json"
  run_snippet "$TMPDIR" "pm_create_item backlog 'Backlog'" > /dev/null
  run_snippet "$TMPDIR" "pm_create_item story 'Story'" > /dev/null
  run_snippet "$TMPDIR" "pm_set_status 1 in-progress" > /dev/null
  run_snippet "$TMPDIR" "pm_set_status 2 in-progress" > /dev/null  # pre-set to expected

  cat > "$STATE_FILE" << EOF
{
  "session": { "backlog": 1, "mode": "autonomous" },
  "dispatches": [],
  "epics": { "e01": { "stories": { "2": { "status": "$STORY_STATUS" } } } }
}
EOF

  OUT=$(run_snippet "$TMPDIR" "pm_reconcile --from-state $STATE_FILE")
  assert_contains "reconcile_${STORY_STATUS}_maps_to_in_progress" "consistent" "$OUT"
  rm -rf "$TMPDIR"
done

# 'registered' maps to ready
TMPDIR=$(mktemp -d)
STATE_FILE="$TMPDIR/state.json"
run_snippet "$TMPDIR" "pm_create_item backlog 'Backlog'" > /dev/null
run_snippet "$TMPDIR" "pm_create_item story 'Story'" > /dev/null
run_snippet "$TMPDIR" "pm_set_status 1 in-progress" > /dev/null
run_snippet "$TMPDIR" "pm_set_status 2 ready" > /dev/null

cat > "$STATE_FILE" << EOF
{
  "session": { "backlog": 1, "mode": "autonomous" },
  "dispatches": [],
  "epics": { "e01": { "stories": { "2": { "status": "registered" } } } }
}
EOF

OUT=$(run_snippet "$TMPDIR" "pm_reconcile --from-state $STATE_FILE")
assert_contains "reconcile_registered_maps_to_ready" "consistent" "$OUT"
rm -rf "$TMPDIR"
echo ""

# --- Test Group 9: Backlog status with reviewer dispatch ---
echo "Test Group: Backlog status respects pr-review dispatch"

TMPDIR=$(mktemp -d)
STATE_FILE="$TMPDIR/state.json"

run_snippet "$TMPDIR" "pm_create_item backlog 'Backlog'" > /dev/null
run_snippet "$TMPDIR" "pm_set_status 1 in-review" > /dev/null

cat > "$STATE_FILE" << EOF
{
  "session": { "backlog": 1, "mode": "autonomous" },
  "dispatches": [
    { "agent": "reviewer-opus", "issue": 1, "result": "success" }
  ],
  "epics": {}
}
EOF

OUT=$(run_snippet "$TMPDIR" "pm_reconcile --from-state $STATE_FILE")
EXIT_CODE=$?
assert_exit_zero "reconcile_backlog_with_reviewer_exits_zero" "$EXIT_CODE"
assert_contains "reconcile_backlog_reviewer_consistent" "consistent" "$OUT"

rm -rf "$TMPDIR"
echo ""

# --- Test Group 10: Doc issue (planner dispatch) maps to done ---
echo "Test Group: Doc issue dispatch maps to done"

TMPDIR=$(mktemp -d)
STATE_FILE="$TMPDIR/state.json"

# Create backlog=1, doc issue=2
run_snippet "$TMPDIR" "pm_create_item backlog 'Backlog'" > /dev/null
run_snippet "$TMPDIR" "pm_create_item docs 'Plan Doc'" > /dev/null
run_snippet "$TMPDIR" "pm_set_status 1 in-progress" > /dev/null
run_snippet "$TMPDIR" "pm_set_status 2 done" > /dev/null

cat > "$STATE_FILE" << EOF
{
  "session": { "backlog": 1, "mode": "autonomous" },
  "dispatches": [
    { "agent": "planner", "issue": 2, "result": "success" }
  ],
  "epics": {}
}
EOF

OUT=$(run_snippet "$TMPDIR" "pm_reconcile --from-state $STATE_FILE")
EXIT_CODE=$?
assert_exit_zero "reconcile_doc_done_exits_zero" "$EXIT_CODE"
assert_contains "reconcile_doc_done_consistent" "consistent" "$OUT"

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
