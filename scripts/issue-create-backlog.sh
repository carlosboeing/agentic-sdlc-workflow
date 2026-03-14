#!/usr/bin/env bash
set -euo pipefail

# issue-create-backlog.sh — Create a backlog item with all required setup.
#
# Handles the full Phase 0 initialization for a new backlog item:
#   1. Creates the GitHub issue with hierarchy/backlog label
#   2. Adds the issue to the project board
#   3. Sets board status to Backlog
#   4. Creates the backlog/<N>-<slug> label
#   5. Adds the backlog label to the issue
#
# Usage: ./scripts/issue-create-backlog.sh --title <title> --slug <slug> --body-file <path>
#        ./scripts/issue-create-backlog.sh --title <title> --slug <slug> --body <text>
#
# Examples:
#   ./scripts/issue-create-backlog.sh --title "My Feature" --slug "my-feature" --body-file /tmp/body.md
#   ./scripts/issue-create-backlog.sh --title "Quick Fix" --slug "quick-fix" --body "One-liner description"

REPO="carlosboeing/agentic-sdlc-workflow"
PROJECT_NUMBER=7
PROJECT_OWNER="carlosboeing"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# --- Step 1: Create the issue ---
echo "Creating issue..."
CREATE_ARGS=(gh issue create --repo "$REPO" --title "$TITLE" --label "hierarchy/backlog")
if [ -n "$BODY_FILE" ]; then
  CREATE_ARGS+=(--body-file "$BODY_FILE")
elif [ -n "$BODY" ]; then
  CREATE_ARGS+=(--body "$BODY")
fi

ISSUE_URL=$("${CREATE_ARGS[@]}")
ISSUE_NUMBER=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')
echo "✓ Created issue #$ISSUE_NUMBER"

# --- Step 2: Add to project board ---
echo "Adding to project board..."
gh project item-add "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" \
  --url "$ISSUE_URL" --format json > /dev/null 2>&1
echo "✓ Added to project board"

# --- Step 3: Set board status to Backlog ---
echo "Setting board status..."
"$SCRIPT_DIR/issue-set-status.sh" "$ISSUE_NUMBER" backlog
# issue-set-status.sh prints its own ✓ message

# --- Step 4: Create backlog label ---
LABEL="backlog/${ISSUE_NUMBER}-${SLUG}"
echo "Creating label '$LABEL'..."
gh label create "$LABEL" --repo "$REPO" \
  --color "5319E7" --description "Backlog: $TITLE" 2>/dev/null \
  || echo "  (label already exists)"
echo "✓ Label ready"

# --- Step 5: Add backlog label to issue ---
echo "Adding label to issue..."
gh issue edit "$ISSUE_NUMBER" --repo "$REPO" --add-label "$LABEL" > /dev/null
echo "✓ Label applied"

# --- Done ---
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
