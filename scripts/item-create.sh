#!/usr/bin/env bash
set -euo pipefail

# item-create.sh — Create a work item via the PM abstraction layer.
#
# Unified script for creating any work item level (backlog, epic, story, docs).
# Routes through the dual-write system: GitHub adapter creates the item on
# GitHub (returns the ID), local adapter creates .workflow/items/<id>.md.
#
# Usage:
#   ./scripts/item-create.sh <level> --title "..." [--body "..."] [--body-file <path>] [--label "..."] [--label "..."]
#   ./scripts/item-create.sh backlog --title "..." --slug <slug> [--body "..."] [--body-file <path>]
#
# Where <level> is: backlog, epic, story, docs
#
# For non-backlog levels: prints the item number to stdout (just the number).
# For backlog level with --slug: performs full Phase 0 setup and prints a summary.
#
# Behavior for ALL levels:
#   1. Create the item via pm_create_item (dual-write: GitHub + local)
#   2. Add item to project board via pm_add_to_board (if available)
#   3. Print the item number to stdout
#
# Additional behavior when level=backlog AND --slug is provided:
#   4. Replace #<this-issue> placeholders in body with actual number
#   5. Prefix title with [#N]
#   6. Set board status to backlog via pm_set_status
#   7. Create and apply the backlog/<N>-<slug> label via pm_add_label
#   8. Print the setup summary (URL, label, board status)
#
# Examples:
#   ./scripts/item-create.sh story --title "[#242/E01-S01] Story title" --body "..." --label "backlog/242-slug" --label "difficulty/easy"
#   ./scripts/item-create.sh backlog --title "My Feature" --slug my-feature --body "..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pm.sh"

# --- Argument parsing ---
if [ $# -lt 1 ]; then
  echo "Error: level argument required" >&2
  echo "Usage: $0 <level> --title <title> [--body <body>] [--body-file <path>] [--label <label>] ... [--slug <slug>]" >&2
  exit 1
fi

LEVEL="$1"
shift

TITLE=""
BODY=""
BODY_FILE=""
SLUG=""
LABELS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)     TITLE="$2";           shift 2 ;;
    --body)      BODY="$2";            shift 2 ;;
    --body-file) BODY_FILE="$2";       shift 2 ;;
    --label)     LABELS+=("$2");       shift 2 ;;
    --slug)      SLUG="$2";           shift 2 ;;
    *)
      echo "Error: unknown option '$1'" >&2
      echo "Usage: $0 <level> --title <title> [--body <body>] [--body-file <path>] [--label <label>] ... [--slug <slug>]" >&2
      exit 1
      ;;
  esac
done

if [ -z "$TITLE" ]; then
  echo "Error: --title is required" >&2
  echo "Usage: $0 <level> --title <title> [--body <body>] [--body-file <path>] [--label <label>] ... [--slug <slug>]" >&2
  exit 1
fi

# Determine if this is a backlog-with-slug flow
IS_BACKLOG_SETUP=false
if [ "$LEVEL" = "backlog" ] && [ -n "$SLUG" ]; then
  IS_BACKLOG_SETUP=true
fi

# --- Step 1: Create the item via pm_create_item ---
# Join labels as CSV
LABELS_CSV=""
for lbl in "${LABELS[@]+"${LABELS[@]}"}"; do
  if [ -z "$LABELS_CSV" ]; then
    LABELS_CSV="$lbl"
  else
    LABELS_CSV="$LABELS_CSV,$lbl"
  fi
done

CREATE_ARGS=("$LEVEL" "$TITLE")
if [ -n "$BODY_FILE" ]; then
  CREATE_ARGS+=(--body-file "$BODY_FILE")
elif [ -n "$BODY" ]; then
  CREATE_ARGS+=(--body "$BODY")
fi
if [ -n "$LABELS_CSV" ]; then
  CREATE_ARGS+=(--labels "$LABELS_CSV")
fi

if [ "$IS_BACKLOG_SETUP" = true ]; then
  echo "Creating item..." >&2
fi

ISSUE_NUMBER=$(pm_create_item "${CREATE_ARGS[@]}")

if [ "$IS_BACKLOG_SETUP" = true ]; then
  echo "Created item #$ISSUE_NUMBER" >&2
fi

# --- Step 2: Add to project board (graceful skip if pm_add_to_board not available) ---
if type pm_add_to_board &>/dev/null; then
  if [ "$IS_BACKLOG_SETUP" = true ]; then
    echo "Adding to project board..." >&2
  fi
  pm_add_to_board "$ISSUE_NUMBER" >&2 || true
fi

# --- Backlog-specific setup (only when --slug is provided) ---
if [ "$IS_BACKLOG_SETUP" = true ]; then
  # Step 4: Replace self-referential placeholders
  CURRENT_BODY=$(pm_get_item "$ISSUE_NUMBER" --json body | jq -r '.body // empty' 2>/dev/null || true)
  if echo "$CURRENT_BODY" | grep -q '<this-issue>'; then
    echo "Replacing #<this-issue> placeholders with #$ISSUE_NUMBER..." >&2
    PATCHED_BODY=$(echo "$CURRENT_BODY" | sed "s/#<this-issue>/#$ISSUE_NUMBER/g")
    pm_update_item "$ISSUE_NUMBER" --body "$PATCHED_BODY"
    echo "Placeholders replaced" >&2
  fi

  # Step 5: Prefix title with item number
  echo "Prefixing title with [#$ISSUE_NUMBER]..." >&2
  pm_update_item "$ISSUE_NUMBER" --title "[#$ISSUE_NUMBER] $TITLE"
  echo "Title prefixed" >&2

  # Step 6: Set board status to Backlog
  echo "Setting board status..." >&2
  pm_set_status "$ISSUE_NUMBER" backlog

  # Step 7: Create backlog label and apply it
  LABEL="backlog/${ISSUE_NUMBER}-${SLUG}"
  echo "Creating label '$LABEL'..." >&2
  pm_add_label "$ISSUE_NUMBER" "$LABEL" --create-if-missing --description "Backlog: $TITLE"
  echo "Label ready and applied" >&2

  # Step 8: Print summary
  ISSUE_URL="https://github.com/$CFG_REPO/issues/$ISSUE_NUMBER"
  echo "" >&2
  echo "=== Backlog item #$ISSUE_NUMBER ready ===" >&2
  echo "  Issue:  $ISSUE_URL" >&2
  echo "  Label:  $LABEL" >&2
  echo "  Board:  Backlog" >&2
  echo "" >&2
  echo "Next: create integration branch" >&2
  echo "  git checkout main && git pull" >&2
  echo "  git checkout -b backlog/${ISSUE_NUMBER}-${SLUG}" >&2
  echo "  git push -u origin backlog/${ISSUE_NUMBER}-${SLUG}" >&2
fi

# Print the item number to stdout (for scripting)
echo "$ISSUE_NUMBER"
