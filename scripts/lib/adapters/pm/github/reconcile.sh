#!/usr/bin/env bash
# reconcile.sh — GitHub adapter: board reconciliation.
#
# Provides pm_reconcile, split from board.sh to stay within the
# 200-line module limit. Ported from reconcile-board.sh.
#
# Computes expected statuses from the orchestrator state file,
# queries actual statuses via a single batched GraphQL query,
# and fixes discrepancies.

# pm_reconcile --from-state <file> [--epic-issues <json>] [--dry-run]
# Full port of reconcile-board.sh logic.
pm_reconcile() {
  local state_file="" epic_issues="{}" dry_run=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from-state)   state_file="$2"; shift 2 ;;
      --epic-issues)  epic_issues="$2"; shift 2 ;;
      --dry-run)      dry_run=true; shift ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
  done

  if [ -z "$state_file" ] || [ ! -f "$state_file" ]; then
    echo "Error: --from-state <file> required and must exist" >&2
    return 1
  fi

  _board_log "reconcile START state_file=$state_file dry_run=$dry_run"

  # Step 1: Compute expected statuses from state file (Python)
  local expected
  expected=$(STATE_FILE="$state_file" EPIC_ISSUES="$epic_issues" python3 << 'PYEOF'
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

# Doc issues (designer, planner, retro) -> done if completed
for d in dispatches:
    if d.get("agent", "") in {"designer", "planner", "retro"}:
        issue = d.get("issue")
        if issue:
            expected[str(issue)] = "done" if d.get("result") == "success" else "in-progress"

# Story issues -> derive from epic/story status
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

# Epic issues -> aggregate from story statuses
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
  ) || { echo "Error: failed to compute expected statuses" >&2; return 1; }

  # Step 2: Build batched GraphQL query for all issues
  local issues issue_count query_body num
  issues=$(echo "$expected" | python3 -c "import json,sys; print(' '.join(json.load(sys.stdin).keys()))")
  issue_count=$(echo "$issues" | wc -w | tr -d ' ')

  query_body=""
  for num in $issues; do
    query_body="${query_body}i${num}: issue(number: ${num}) { projectItems(first:1) { nodes { fieldValueByName(name:\"Status\") { ... on ProjectV2ItemFieldSingleSelectValue { name } } } } } "
  done

  local batch_result
  batch_result=$(gh api graphql -f query="query {
    repository(owner: \"$CFG_REPO_OWNER\", name: \"$CFG_REPO_NAME\") {
      ${query_body}
    }
  }" 2>/dev/null) || { echo "Error: batch query failed" >&2; return 1; }

  # Step 3: Compare and reconcile
  local display_map='{"backlog":"Backlog","ready":"Ready","in-progress":"In Progress","in-review":"In Review","done":"Done"}'
  local fixes_needed=0 fixes_applied=0
  local issue_num expected_status display_expected actual_display script_dir

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

  for issue_num in $issues; do
    expected_status=$(echo "$expected" | python3 -c "import json,sys; print(json.load(sys.stdin)['$issue_num'])")
    display_expected=$(echo "$display_map" | python3 -c "import json,sys; print(json.load(sys.stdin).get('$expected_status','$expected_status'))")

    actual_display=$(echo "$batch_result" | python3 -c "
import json, sys
data = json.load(sys.stdin)
nodes = data.get('data',{}).get('repository',{}).get('i$issue_num',{}).get('projectItems',{}).get('nodes',[])
if nodes and nodes[0].get('fieldValueByName'):
    print(nodes[0]['fieldValueByName'].get('name',''))
else:
    print('UNKNOWN')
")

    if [ "$actual_display" = "$display_expected" ]; then
      echo "✓ #$issue_num: $display_expected"
    else
      fixes_needed=$((fixes_needed + 1))
      echo "✗ #$issue_num: expected=$display_expected actual=${actual_display:-null}"
      if [ "$dry_run" = "false" ]; then
        pm_set_status "$issue_num" "$expected_status" 2>/dev/null
        fixes_applied=$((fixes_applied + 1))
        echo "  → Fixed: #$issue_num → $expected_status"
      fi
    fi
  done

  echo ""
  if [ "$fixes_needed" -eq 0 ]; then
    echo "Board reconciled: $issue_count issues consistent. (1 API query)"
  else
    if [ "$dry_run" = "true" ]; then
      echo "Dry run: $fixes_needed/$issue_count issues need fixing."
    else
      echo "Board reconciled: $fixes_applied fixes applied, $issue_count issues checked. (1 + $fixes_applied API queries)"
    fi
  fi

  _board_log "reconcile DONE issues=$issue_count fixes_needed=$fixes_needed fixes_applied=$fixes_applied"
  return 0
}
