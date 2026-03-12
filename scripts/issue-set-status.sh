#!/usr/bin/env bash
set -euo pipefail

# issue-set-status.sh — Reliably set a GitHub issue's status on the project board.
#
# Single source of truth for all board status updates. Handles control character
# cleanup, item ID validation, retry on race conditions, and non-zero exit on failure.
#
# Usage: ./scripts/issue-set-status.sh <issue-number> <status>
#
# Status values: backlog, planned, todo, in-progress, in-review, done
#
# Exit codes:
#   0 — status updated successfully
#   1 — failed (issue not found on board, invalid status, or API error)

PROJECT_NUMBER=7
PROJECT_OWNER="carlosboeing"
PROJECT_ID="PVT_kwHOADPMJc4BRg45"
STATUS_FIELD_ID="PVTSSF_lAHOADPMJc4BRg45zg_UfJc"
REPO="carlosboeing/agentic-sdlc-workflow"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <issue-number> <status>" >&2
  echo "  status: backlog | planned | todo | in-progress | in-review | done" >&2
  exit 1
fi

ISSUE_NUMBER="$1"
STATUS="$2"

# Map status name to option ID
case "$STATUS" in
  backlog)     OPTION_ID="17425ce6" ;;
  planned)     OPTION_ID="cf183d2a" ;;
  todo)        OPTION_ID="f75ad846" ;;
  in-progress) OPTION_ID="47fc9ee4" ;;
  in-review)   OPTION_ID="9bb97c15" ;;
  done)        OPTION_ID="98236657" ;;
  *)
    echo "ERROR: Unknown status '$STATUS'. Expected: backlog, planned, todo, in-progress, in-review, done" >&2
    exit 1
    ;;
esac

# Fetch the board item ID for this issue.
# Always pipe through tr -d to strip control characters that break jq parsing.
fetch_item_id() {
  gh project item-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" \
    --format json --limit 200 \
    | sed 's/[[:cntrl:]]//g' \
    | jq -r ".items[] | select(.content.number == $ISSUE_NUMBER and .content.repository == \"$REPO\") | .id" 2>/dev/null
}

ITEM_ID=$(fetch_item_id)

# Retry once after a short delay if not found (handles race condition after item-add)
if [ -z "$ITEM_ID" ] || [ "$ITEM_ID" = "null" ]; then
  sleep 3
  ITEM_ID=$(fetch_item_id)
fi

if [ -z "$ITEM_ID" ] || [ "$ITEM_ID" = "null" ]; then
  echo "ERROR: Could not find board item for issue #$ISSUE_NUMBER" >&2
  exit 1
fi

# Update the status
if gh project item-edit \
  --project-id "$PROJECT_ID" \
  --id "$ITEM_ID" \
  --field-id "$STATUS_FIELD_ID" \
  --single-select-option-id "$OPTION_ID"; then
  echo "✓ #$ISSUE_NUMBER → $STATUS"
else
  echo "ERROR: Failed to set #$ISSUE_NUMBER to $STATUS" >&2
  exit 1
fi
