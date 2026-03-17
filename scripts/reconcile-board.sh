#!/usr/bin/env bash
set -euo pipefail

# reconcile-board.sh — Reconcile GitHub project board statuses with orchestrator state.
#
# Computes the expected board status for every issue from the state file,
# queries the actual board status in a single batched GraphQL query, and
# fixes any discrepancies. This is the defense-in-depth layer that catches
# external automations, API failures, and board drift.
#
# Usage:
#   ./scripts/reconcile-board.sh --from-state <state-file> [--epic-issues <json>] [--dry-run]
#
# Examples:
#   ./scripts/reconcile-board.sh --from-state .agentic-workflow/runs/167/orchestrator.json
#   ./scripts/reconcile-board.sh --from-state ... --epic-issues '{"e01":172,"e02":173,"e03":174}'
#   ./scripts/reconcile-board.sh --from-state ... --dry-run
#
# Cost: 1 GraphQL query to read all statuses (~1 API point), plus 1 mutation
# per issue that needs fixing. A fully consistent board costs 1 API point total.
#
# The --epic-issues flag maps epic slugs to GitHub issue numbers (not stored in
# the state file). Without it, epic issues are not reconciled.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"

STATE_FILE=""
EPIC_ISSUES="{}"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-state)   STATE_FILE="$2"; shift 2 ;;
    --epic-issues)  EPIC_ISSUES="$2"; shift 2 ;;
    --dry-run)      DRY_RUN=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$STATE_FILE" ] || [ ! -f "$STATE_FILE" ]; then
  echo "Error: --from-state <file> required and must exist" >&2
  exit 1
fi

# --- Step 1: Compute expected statuses from state file ---
EXPECTED=$(STATE_FILE="$STATE_FILE" EPIC_ISSUES="$EPIC_ISSUES" python3 << 'PYEOF'
import json, os

with open(os.environ["STATE_FILE"]) as f:
    state = json.load(f)

epic_issues = json.loads(os.environ.get("EPIC_ISSUES", "{}"))
expected = {}
dispatches = state.get("dispatches", [])

# Backlog issue
backlog = state["session"]["backlog"]
has_pr_review = any(
    d.get("issue") == backlog and "reviewer" in d.get("agent", "")
    for d in dispatches
)
expected[str(backlog)] = "in-review" if has_pr_review else "in-progress"

# Doc issues (designer, planner, retro) → done if completed
for d in dispatches:
    if d.get("agent", "") in {"designer", "planner", "retro"}:
        issue = d.get("issue")
        if issue:
            expected[str(issue)] = "done" if d.get("result") == "success" else "in-progress"

# Story issues → derive from epic/story status
epic_story_statuses = {}
for epic_slug, epic_data in state.get("epics", {}).items():
    epic_story_statuses[epic_slug] = []
    for story_num, story_data in epic_data.get("stories", {}).items():
        status = story_data.get("status", "registered")
        if status in ("reviewed", "merged"):
            board = "in-review"
        elif status in ("building", "built", "reviewing"):
            board = "in-progress"
        else:
            board = "ready"
        expected[str(story_num)] = board
        epic_story_statuses[epic_slug].append(board)

# Epic issues → aggregate from story statuses
for epic_slug, issue_num in epic_issues.items():
    statuses = epic_story_statuses.get(epic_slug, [])
    if not statuses:
        continue
    if all(s == "in-review" for s in statuses):
        expected[str(issue_num)] = "in-review"
    elif any(s == "in-progress" for s in statuses):
        expected[str(issue_num)] = "in-progress"
    else:
        expected[str(issue_num)] = "in-review"

print(json.dumps(expected))
PYEOF
)

# --- Step 2: Build a single batched GraphQL query for all issues ---
ISSUES=$(echo "$EXPECTED" | python3 -c "import json,sys; print(' '.join(json.load(sys.stdin).keys()))")
ISSUE_COUNT=$(echo "$ISSUES" | wc -w | tr -d ' ')

# Build aliased query: i167: issue(number: 167) { ... }
QUERY_BODY=""
for NUM in $ISSUES; do
  QUERY_BODY="${QUERY_BODY}i${NUM}: issue(number: ${NUM}) { projectItems(first:1) { nodes { fieldValueByName(name:\"Status\") { ... on ProjectV2ItemFieldSingleSelectValue { name } } } } } "
done

BATCH_RESULT=$(gh api graphql -f query="query {
  repository(owner: \"$CFG_REPO_OWNER\", name: \"$CFG_REPO_NAME\") {
    ${QUERY_BODY}
  }
}" 2>/dev/null) || { echo "Error: batch query failed" >&2; exit 1; }

# --- Step 3: Compare and reconcile ---
STATUS_MAP='{"Ready":"ready","In Progress":"in-progress","In Review":"in-review","Done":"done"}'
DISPLAY_MAP='{"ready":"Ready","in-progress":"In Progress","in-review":"In Review","done":"Done"}'
FIXES_NEEDED=0
FIXES_APPLIED=0

for ISSUE_NUM in $ISSUES; do
  EXPECTED_STATUS=$(echo "$EXPECTED" | python3 -c "import json,sys; print(json.load(sys.stdin)['$ISSUE_NUM'])")
  DISPLAY_EXPECTED=$(echo "$DISPLAY_MAP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('$EXPECTED_STATUS','$EXPECTED_STATUS'))")

  ACTUAL_DISPLAY=$(echo "$BATCH_RESULT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
nodes = data.get('data',{}).get('repository',{}).get('i$ISSUE_NUM',{}).get('projectItems',{}).get('nodes',[])
if nodes and nodes[0].get('fieldValueByName'):
    print(nodes[0]['fieldValueByName'].get('name',''))
else:
    print('UNKNOWN')
")

  if [ "$ACTUAL_DISPLAY" = "$DISPLAY_EXPECTED" ]; then
    echo "✓ #$ISSUE_NUM: $DISPLAY_EXPECTED"
  else
    FIXES_NEEDED=$((FIXES_NEEDED + 1))
    echo "✗ #$ISSUE_NUM: expected=$DISPLAY_EXPECTED actual=${ACTUAL_DISPLAY:-null}"
    if [ "$DRY_RUN" = "false" ]; then
      "$SCRIPT_DIR/issue-set-status.sh" "$ISSUE_NUM" "$EXPECTED_STATUS" 2>/dev/null
      FIXES_APPLIED=$((FIXES_APPLIED + 1))
      echo "  → Fixed: #$ISSUE_NUM → $EXPECTED_STATUS"
    fi
  fi
done

echo ""
if [ "$FIXES_NEEDED" -eq 0 ]; then
  echo "Board reconciled: $ISSUE_COUNT issues consistent. (1 API query)"
else
  if [ "$DRY_RUN" = "true" ]; then
    echo "Dry run: $FIXES_NEEDED/$ISSUE_COUNT issues need fixing."
  else
    echo "Board reconciled: $FIXES_APPLIED fixes applied, $ISSUE_COUNT issues checked. (1 + $FIXES_APPLIED API queries)"
  fi
fi

exit 0
