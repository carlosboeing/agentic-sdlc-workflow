#!/usr/bin/env bash
set -euo pipefail

# issue-set-status.sh — Reliably set a GitHub issue's status on the project board.
#
# Single source of truth for all board status updates. Handles control character
# cleanup, item ID validation, retry on race conditions, diagnostic logging,
# and post-mutation verification.
#
# Usage: ./scripts/issue-set-status.sh <issue-number> <status>
#
# Status values: backlog, planned, todo, in-progress, in-review, done
#
# Exit codes:
#   0 — status updated successfully (or already at desired status, or verify mismatch)
#   1 — failed (issue not found on board, invalid status, or API error)

PROJECT_NUMBER=7
PROJECT_OWNER="carlosboeing"
PROJECT_ID="PVT_kwHOADPMJc4BRg45"
STATUS_FIELD_ID="PVTSSF_lAHOADPMJc4BRg45zg_UfJc"
REPO="carlosboeing/agentic-sdlc-workflow"

# --- Logging ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
  backlog)     OPTION_ID="17425ce6"; STATUS_DISPLAY="Backlog" ;;
  planned)     OPTION_ID="cf183d2a"; STATUS_DISPLAY="Planned" ;;
  todo)        OPTION_ID="f75ad846"; STATUS_DISPLAY="Todo" ;;
  in-progress) OPTION_ID="47fc9ee4"; STATUS_DISPLAY="In Progress" ;;
  in-review)   OPTION_ID="9bb97c15"; STATUS_DISPLAY="In Review" ;;
  done)        OPTION_ID="98236657"; STATUS_DISPLAY="Done" ;;
  *)
    echo "ERROR: Unknown status '$STATUS'. Expected: backlog, planned, todo, in-progress, in-review, done" >&2
    exit 1
    ;;
esac

log_board "START caller_pid=$$"
log_board "option_id=$OPTION_ID"

# --- Fetch board data ---
# Returns the full project item-list JSON. Used to extract both item ID and
# current status from a single API call.
fetch_board_data() {
  gh project item-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" \
    --format json --limit 200 \
    | sed 's/[[:cntrl:]]//g'
}

# Extract item ID and current status from board data JSON.
# Sets ITEM_ID and CURRENT_STATUS variables.
extract_item_info() {
  local data="$1"
  ITEM_ID=$(echo "$data" | jq -r ".items[] | select(.content.number == $ISSUE_NUMBER and .content.repository == \"$REPO\") | .id" 2>/dev/null) || ITEM_ID=""
  CURRENT_STATUS=$(echo "$data" | jq -r ".items[] | select(.content.number == $ISSUE_NUMBER and .content.repository == \"$REPO\") | .status // .Status // \"unknown\"" 2>/dev/null) || CURRENT_STATUS="unknown"
}

BOARD_DATA=$(fetch_board_data)
extract_item_info "$BOARD_DATA"

# Retry once after a short delay if not found (handles race condition after item-add)
if [ -z "$ITEM_ID" ] || [ "$ITEM_ID" = "null" ]; then
  log_board "item_id=NOT_FOUND retrying_in_3s"
  sleep 3
  BOARD_DATA=$(fetch_board_data)
  extract_item_info "$BOARD_DATA"
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

if VERIFY_DATA=$(fetch_board_data 2>/dev/null); then
  ACTUAL_STATUS=$(echo "$VERIFY_DATA" | jq -r ".items[] | select(.content.number == $ISSUE_NUMBER and .content.repository == \"$REPO\") | .status // .Status // \"unknown\"" 2>/dev/null) || ACTUAL_STATUS=""
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
