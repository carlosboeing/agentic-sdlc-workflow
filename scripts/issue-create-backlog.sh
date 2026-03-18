#!/usr/bin/env bash
set -euo pipefail

# issue-create-backlog.sh — Create a backlog item with all required setup.
#
# Handles the full Phase 0 initialization for a new backlog item:
#   1. Creates the GitHub issue with hierarchy/backlog label (pm_create_item)
#   2. Replaces #<this-issue> placeholders in the issue body (orchestrator concern)
#   3. Prefixes the title with [#N] (orchestrator concern)
#   4. Adds the issue to the project board (pm_add_to_board)
#   5. Sets board status to Backlog (pm_set_status)
#   6. Creates and applies the backlog/<N>-<slug> label (pm_add_label)
#
# Usage: ./scripts/issue-create-backlog.sh --title <title> --slug <slug> [--body <text> | --body-file <path>]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pm.sh"

# --- Argument parsing ---
TITLE=""
SLUG=""
BODY=""
BODY_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)   TITLE="$2";     shift 2 ;;
    --slug)    SLUG="$2";      shift 2 ;;
    --body)    BODY="$2";      shift 2 ;;
    --body-file) BODY_FILE="$2"; shift 2 ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 --title <title> --slug <slug> [--body <text> | --body-file <path>]" >&2
      exit 1
      ;;
  esac
done

if [ -z "$TITLE" ] || [ -z "$SLUG" ]; then
  echo "Error: --title and --slug are required" >&2
  echo "Usage: $0 --title <title> --slug <slug> [--body <text> | --body-file <path>]" >&2
  exit 1
fi

# --- Step 1: Create the issue via pm_create_item ---
echo "Creating issue..."
CREATE_ARGS=(backlog "$TITLE")
if [ -n "$BODY_FILE" ]; then
  CREATE_ARGS+=(--body-file "$BODY_FILE")
elif [ -n "$BODY" ]; then
  CREATE_ARGS+=(--body "$BODY")
fi
ISSUE_NUMBER=$(pm_create_item "${CREATE_ARGS[@]}")
echo "Created issue #$ISSUE_NUMBER"

# --- Step 1b: Replace self-referential placeholders (orchestrator concern) ---
# The issue body may contain #<this-issue> that references the issue's own number.
CURRENT_BODY=$(pm_get_item "$ISSUE_NUMBER" --json body | jq -r '.body // empty' 2>/dev/null || true)
if echo "$CURRENT_BODY" | grep -q '<this-issue>'; then
  echo "Replacing #<this-issue> placeholders with #$ISSUE_NUMBER..."
  PATCHED_BODY=$(echo "$CURRENT_BODY" | sed "s/#<this-issue>/#$ISSUE_NUMBER/g")
  pm_update_item "$ISSUE_NUMBER" --body "$PATCHED_BODY"
  echo "Placeholders replaced"
fi

# --- Step 1c: Prefix title with issue number (orchestrator concern) ---
echo "Prefixing title with [#$ISSUE_NUMBER]..."
pm_update_item "$ISSUE_NUMBER" --title "[#$ISSUE_NUMBER] $TITLE"
echo "Title prefixed"

# --- Step 2: Add to project board ---
echo "Adding to project board..."
pm_add_to_board "$ISSUE_NUMBER"

# --- Step 3: Set board status to Backlog ---
echo "Setting board status..."
pm_set_status "$ISSUE_NUMBER" backlog

# --- Step 4: Create backlog label and apply it ---
LABEL="backlog/${ISSUE_NUMBER}-${SLUG}"
echo "Creating label '$LABEL'..."
pm_add_label "$ISSUE_NUMBER" "$LABEL" --create-if-missing --description "Backlog: $TITLE"
echo "Label ready and applied"

# --- Done ---
ISSUE_URL="https://github.com/$CFG_REPO/issues/$ISSUE_NUMBER"
echo ""
echo "=== Backlog item #$ISSUE_NUMBER ready ==="
echo "  Issue:  $ISSUE_URL"
echo "  Label:  $LABEL"
echo "  Board:  Backlog"
echo ""
echo "Next: create integration branch"
echo "  git checkout main && git pull"
echo "  git checkout -b backlog/${ISSUE_NUMBER}-${SLUG}"
echo "  git push -u origin backlog/${ISSUE_NUMBER}-${SLUG}"
