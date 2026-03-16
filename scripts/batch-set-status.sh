#!/usr/bin/env bash
set -euo pipefail

# batch-set-status.sh — Set board status for multiple issues in a single invocation.
#
# Accepts multiple <issue>:<status> pairs, fetches current status before mutations
# (skip already-correct), applies mutations sequentially (GitHub Projects API
# constraint), and runs a single shared verification pass after all mutations.
#
# Usage: ./scripts/batch-set-status.sh <issue>:<status> [<issue>:<status> ...]
#   ./scripts/batch-set-status.sh 112:in-progress 113:in-progress
#
# Status values: backlog, ready, in-progress, in-review, done
# Exit codes: 0 — all succeeded (or already correct); 1 — one or more failed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"
PROJECT_ID="$CFG_PROJECT_ID"
STATUS_FIELD_ID="$CFG_STATUS_FIELD_ID"
REPO_OWNER="$CFG_REPO_OWNER"
REPO_NAME="$CFG_REPO_NAME"
LOG_FILE="$(cd "$SCRIPT_DIR/.." && pwd)/.agentic-workflow/logs/board-status.log"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

log_board() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] batch $*" >> "$LOG_FILE" 2>/dev/null || true; }

if [ $# -lt 1 ]; then
  echo "Usage: $0 <issue>:<status> [<issue>:<status> ...]" >&2
  echo "  status: backlog | ready | in-progress | in-review | done" >&2
  exit 1
fi

map_status() {
  case "$1" in
    backlog)     echo "$CFG_STATUS_BACKLOG Backlog" ;;
    ready)       echo "$CFG_STATUS_READY Ready" ;;
    in-progress) echo "$CFG_STATUS_IN_PROGRESS In Progress" ;;
    in-review)   echo "$CFG_STATUS_IN_REVIEW In Review" ;;
    done)        echo "$CFG_STATUS_DONE Done" ;;
    *)           echo "" ;;
  esac
}

# Parse and validate all pairs upfront — exit immediately on any invalid input
declare -a ISSUES=() STATUSES=() OPTION_IDS=() DISPLAYS=()
for pair in "$@"; do
  issue="${pair%%:*}"; status="${pair##*:}"
  if [ -z "$issue" ] || [ -z "$status" ] || [ "$issue" = "$pair" ]; then
    echo "ERROR: Invalid pair '$pair'. Expected format: <issue>:<status>" >&2; exit 1
  fi
  mapped=$(map_status "$status")
  if [ -z "$mapped" ]; then
    echo "ERROR: Unknown status '$status'. Expected: backlog, ready, in-progress, in-review, done" >&2; exit 1
  fi
  ISSUES+=("$issue"); STATUSES+=("$status")
  OPTION_IDS+=("${mapped%% *}"); DISPLAYS+=("${mapped#* }")
done

TOTAL=${#ISSUES[@]}
log_board "START pairs=$TOTAL caller_pid=$$"

fetch_item_info() {
  gh api graphql -f query="
  query {
    repository(owner: \"$REPO_OWNER\", name: \"$REPO_NAME\") {
      issue(number: $1) {
        projectItems(first: 5) {
          nodes {
            id
            fieldValueByName(name: \"Status\") {
              ... on ProjectV2ItemFieldSingleSelectValue { name }
            }
          }
        }
      }
    }
  }" 2>/dev/null
}

parse_item_id()     { echo "$1" | jq -r '.data.repository.issue.projectItems.nodes[0].id // empty' 2>/dev/null || echo ""; }
parse_item_status() { echo "$1" | jq -r '.data.repository.issue.projectItems.nodes[0].fieldValueByName.name // "unknown"' 2>/dev/null || echo "unknown"; }

# Phase 1: Fetch current status for all issues before any mutations
declare -a ITEM_IDS=() CURRENT_STATUSES=()
for i in "${!ISSUES[@]}"; do
  issue="${ISSUES[$i]}"
  log_board "FETCH issue=$issue"
  result=$(fetch_item_info "$issue") || result=""
  item_id=$(parse_item_id "$result"); current=$(parse_item_status "$result")

  # Retry once on race condition (e.g., item just added to board)
  if [ -z "$item_id" ] || [ "$item_id" = "null" ]; then
    log_board "FETCH issue=$issue item_id=NOT_FOUND retrying_in_3s"
    sleep 3
    result=$(fetch_item_info "$issue") || result=""
    item_id=$(parse_item_id "$result"); current=$(parse_item_status "$result")
  fi

  ITEM_IDS+=("$item_id"); CURRENT_STATUSES+=("$current")
  log_board "FETCH issue=$issue item_id=$item_id current_status=$current"
done

# Phase 2: Apply mutations sequentially (skip already-correct issues)
FAILED=0
for i in "${!ISSUES[@]}"; do
  issue="${ISSUES[$i]}"; status="${STATUSES[$i]}"
  option_id="${OPTION_IDS[$i]}"; display="${DISPLAYS[$i]}"
  item_id="${ITEM_IDS[$i]}"; current="${CURRENT_STATUSES[$i]}"

  if [ -z "$item_id" ] || [ "$item_id" = "null" ]; then
    log_board "MUTATION issue=$issue NOT_ON_BOARD FAILED"
    echo "ERROR: Issue #$issue not found on project board" >&2
    FAILED=$((FAILED + 1)); continue
  fi

  if [ "$current" = "$display" ]; then
    log_board "SKIP issue=$issue already_at=$display"
    echo "✓ #$issue already at $status"; continue
  fi

  log_board "MUTATION issue=$issue target=$display option_id=$option_id"
  if mutation_out=$(gh project item-edit \
    --project-id "$PROJECT_ID" --id "$item_id" \
    --field-id "$STATUS_FIELD_ID" --single-select-option-id "$option_id" 2>&1); then
    log_board "MUTATION issue=$issue exit=0"
  else
    log_board "MUTATION issue=$issue exit=$? response=$(echo "$mutation_out" | head -c 200)"
    echo "ERROR: Failed to set #$issue to $status" >&2
    FAILED=$((FAILED + 1))
  fi
done

# Phase 3: Single shared verification pass after all mutations
sleep 1
VERIFY_FAILED=0
for i in "${!ISSUES[@]}"; do
  issue="${ISSUES[$i]}"; status="${STATUSES[$i]}"
  display="${DISPLAYS[$i]}"; item_id="${ITEM_IDS[$i]}"

  [ -z "$item_id" ] || [ "$item_id" = "null" ] && continue

  verify=$(fetch_item_info "$issue" 2>/dev/null) || verify=""
  actual=$(echo "$verify" | jq -r '.data.repository.issue.projectItems.nodes[0].fieldValueByName.name // empty' 2>/dev/null) || actual=""

  if [ -z "$actual" ]; then
    log_board "VERIFY issue=$issue UNAVAILABLE"; echo "✓ #$issue → $status"
  elif [ "$actual" = "$display" ]; then
    log_board "VERIFY issue=$issue OK actual=$actual"; echo "✓ #$issue → $status"
  else
    log_board "VERIFY issue=$issue MISMATCH expected=$display actual=$actual"
    echo "⚠ #$issue → $status (verify mismatch: actual=$actual)" >&2
    VERIFY_FAILED=$((VERIFY_FAILED + 1))
  fi
done

log_board "DONE pairs=$TOTAL failed=$FAILED verify_failed=$VERIFY_FAILED"
[ "$FAILED" -gt 0 ] && exit 1
exit 0
