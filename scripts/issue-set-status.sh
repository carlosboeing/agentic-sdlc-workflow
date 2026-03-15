#!/usr/bin/env bash
set -euo pipefail

# issue-set-status.sh — Reliably set a GitHub issue's status on the project board.
#
# Single source of truth for all board status updates. Handles control character
# cleanup, item ID validation, retry on race conditions, diagnostic logging,
# and post-mutation verification.
#
# Uses lightweight per-issue GraphQL queries (~1 point each) instead of
# gh project item-list (~200+ points). See Run 10 lesson:
# docs/4-reviews/lessons/2026-03-13-test-agentic-sdlc-run10-orchestrator-logging/e00-setup/2026-03-13-s00-rate-limit-item-list.md
#
# Usage: ./scripts/issue-set-status.sh <issue-number> <status>
#
# Status values: backlog, planned, todo, in-progress, in-review, done
#
# Exit codes:
#   0 — status updated successfully (or already at desired status, or verify mismatch)
#   1 — failed (issue not found on board, invalid status, or API error)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"
PROJECT_ID="$CFG_PROJECT_ID"
STATUS_FIELD_ID="$CFG_STATUS_FIELD_ID"
REPO_OWNER="$CFG_REPO_OWNER"
REPO_NAME="$CFG_REPO_NAME"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$REPO_ROOT/.claude/logs"
LOG_FILE="$LOG_DIR/board-status.log"
mkdir -p "$LOG_DIR" 2>/dev/null || true

log_board() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] issue=$ISSUE_NUMBER status=$STATUS $*" >> "$LOG_FILE" 2>/dev/null || true
}

# --- Argument parsing ---
if [ $# -lt 2 ]; then
  echo "Usage: $0 <issue-number> <status>" >&2
  echo "  status: backlog | planned | todo | in-progress | in-review | done" >&2
  exit 1
fi

ISSUE_NUMBER="$1"
STATUS="$2"

# Map status name to option ID and display name (as shown on the board)
case "$STATUS" in
  backlog)     OPTION_ID="$CFG_STATUS_BACKLOG";      STATUS_DISPLAY="Backlog" ;;
  planned)     OPTION_ID="$CFG_STATUS_PLANNED";      STATUS_DISPLAY="Planned" ;;
  todo)        OPTION_ID="$CFG_STATUS_TODO";          STATUS_DISPLAY="Todo" ;;
  in-progress) OPTION_ID="$CFG_STATUS_IN_PROGRESS";  STATUS_DISPLAY="In Progress" ;;
  in-review)   OPTION_ID="$CFG_STATUS_IN_REVIEW";    STATUS_DISPLAY="In Review" ;;
  done)        OPTION_ID="$CFG_STATUS_DONE";          STATUS_DISPLAY="Done" ;;
  *)
    echo "ERROR: Unknown status '$STATUS'. Expected: backlog, planned, todo, in-progress, in-review, done" >&2
    exit 1
    ;;
esac

log_board "START caller_pid=$$"
log_board "option_id=$OPTION_ID"

# --- Fetch item ID and current status via lightweight per-issue GraphQL query ---
# Costs ~1 GraphQL point vs ~200+ for gh project item-list.
fetch_item_info() {
  gh api graphql -f query="
  query {
    repository(owner: \"$REPO_OWNER\", name: \"$REPO_NAME\") {
      issue(number: $ISSUE_NUMBER) {
        projectItems(first: 5) {
          nodes {
            id
            fieldValueByName(name: \"Status\") {
              ... on ProjectV2ItemFieldSingleSelectValue {
                name
              }
            }
          }
        }
      }
    }
  }" 2>/dev/null
}

# Extract item ID and current status from the GraphQL response.
# Sets ITEM_ID and CURRENT_STATUS variables.
extract_item_info() {
  local data="$1"
  ITEM_ID=$(echo "$data" | jq -r '.data.repository.issue.projectItems.nodes[0].id // empty' 2>/dev/null) || ITEM_ID=""
  CURRENT_STATUS=$(echo "$data" | jq -r '.data.repository.issue.projectItems.nodes[0].fieldValueByName.name // "unknown"' 2>/dev/null) || CURRENT_STATUS="unknown"
}

QUERY_RESULT=$(fetch_item_info) || QUERY_RESULT=""
extract_item_info "$QUERY_RESULT"

# Retry once after a short delay if not found (handles race condition after item-add)
if [ -z "$ITEM_ID" ] || [ "$ITEM_ID" = "null" ]; then
  log_board "item_id=NOT_FOUND retrying_in_3s"
  sleep 3
  QUERY_RESULT=$(fetch_item_info) || QUERY_RESULT=""
  extract_item_info "$QUERY_RESULT"
fi

if [ -z "$ITEM_ID" ] || [ "$ITEM_ID" = "null" ]; then
  log_board "item_id=NOT_FOUND FAILED"
  echo "ERROR: Could not find board item for issue #$ISSUE_NUMBER" >&2
  exit 1
fi

log_board "item_id=$ITEM_ID current_status=$CURRENT_STATUS"

# --- Skip if already at desired status ---
if [ "$CURRENT_STATUS" = "$STATUS_DISPLAY" ]; then
  log_board "SKIP already_at=$STATUS_DISPLAY"
  echo "✓ #$ISSUE_NUMBER already at $STATUS"
  exit 0
fi

# --- Perform mutation ---
if MUTATION_OUTPUT=$(gh project item-edit \
  --project-id "$PROJECT_ID" \
  --id "$ITEM_ID" \
  --field-id "$STATUS_FIELD_ID" \
  --single-select-option-id "$OPTION_ID" 2>&1); then
  MUTATION_EXIT=0
else
  MUTATION_EXIT=$?
fi

log_board "MUTATION exit=$MUTATION_EXIT response=$(echo "$MUTATION_OUTPUT" | head -c 200)"

if [ "$MUTATION_EXIT" -ne 0 ]; then
  echo "ERROR: Failed to set #$ISSUE_NUMBER to $STATUS" >&2
  exit 1
fi

# --- Post-mutation verification ---
# Wait for eventual consistency, then re-fetch and compare.
sleep 1

VERIFY_RESULT=$(fetch_item_info 2>/dev/null) || VERIFY_RESULT=""
if [ -n "$VERIFY_RESULT" ]; then
  ACTUAL_STATUS=$(echo "$VERIFY_RESULT" | jq -r '.data.repository.issue.projectItems.nodes[0].fieldValueByName.name // empty' 2>/dev/null) || ACTUAL_STATUS=""
else
  ACTUAL_STATUS=""
fi

if [ -z "$ACTUAL_STATUS" ]; then
  # Could not verify — log but treat as success (mutation itself succeeded)
  log_board "VERIFY_UNAVAILABLE"
  echo "✓ #$ISSUE_NUMBER → $STATUS"
elif [ "$ACTUAL_STATUS" = "$STATUS_DISPLAY" ]; then
  log_board "VERIFY_OK actual_status=$ACTUAL_STATUS"
  echo "✓ #$ISSUE_NUMBER → $STATUS"
else
  log_board "VERIFY_MISMATCH expected=$STATUS_DISPLAY actual=$ACTUAL_STATUS"
  echo "⚠ #$ISSUE_NUMBER → $STATUS (verify mismatch: actual=$ACTUAL_STATUS)" >&2
fi
