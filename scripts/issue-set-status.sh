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

PROJECT_NUMBER=1
PROJECT_OWNER="gavinkilbride"
PROJECT_ID="PVT_kwHOAAywgM4BRGeY"
STATUS_FIELD_ID="PVTSSF_lAHOAAywgM4BRGeYzg_By8o"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <issue-number> <status>" >&2
  echo "  status: backlog | planned | todo | in-progress | in-review | done" >&2
  exit 1
fi

ISSUE_NUMBER="$1"
STATUS="$2"

# Map status name to option ID
case "$STATUS" in
  backlog)     OPTION_ID="dd47bfb0" ;;
  planned)     OPTION_ID="61757ea9" ;;
  todo)        OPTION_ID="e37a4d28" ;;
  in-progress) OPTION_ID="308bbc1e" ;;
  in-review)   OPTION_ID="6f3c9037" ;;
  done)        OPTION_ID="9cfa70ca" ;;
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
    | tr -d '\x00-\x1f' \
    | jq -r ".items[] | select(.content.number == $ISSUE_NUMBER) | .id" 2>/dev/null
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
