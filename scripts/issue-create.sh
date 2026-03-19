#!/usr/bin/env bash
set -euo pipefail

# issue-create.sh — Create a work item via the PM abstraction layer.
#
# Wraps pm_create_item with a CLI similar to gh issue create. Routes
# through the dual-write system: GitHub adapter creates the issue on
# GitHub (returns the ID), local adapter creates .workflow/items/<id>.md.
#
# Usage: ./scripts/issue-create.sh <level> --title "..." [--body "..."] [--label "..."] [--label "..."]
# Where <level> is: backlog, epic, story, docs
#
# Prints the issue number to stdout (just the number).
#
# Examples:
#   ./scripts/issue-create.sh story --title "[#242/E01-S01] Story title" --body "..." --label "backlog/242-slug" --label "difficulty/easy"
#   ./scripts/issue-create.sh docs --title "[#242] Write design doc" --body "..." --label "type/docs"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pm.sh"

# --- Argument parsing ---
if [ $# -lt 1 ]; then
  echo "Error: level argument required" >&2
  echo "Usage: $0 <level> --title <title> [--body <body>] [--label <label>] ..." >&2
  exit 1
fi

LEVEL="$1"
shift

TITLE=""
BODY=""
LABELS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)  TITLE="$2";           shift 2 ;;
    --body)   BODY="$2";            shift 2 ;;
    --label)  LABELS+=("$2");       shift 2 ;;
    *)
      echo "Error: unknown option '$1'" >&2
      echo "Usage: $0 <level> --title <title> [--body <body>] [--label <label>] ..." >&2
      exit 1
      ;;
  esac
done

if [ -z "$TITLE" ]; then
  echo "Error: --title is required" >&2
  echo "Usage: $0 <level> --title <title> [--body <body>] [--label <label>] ..." >&2
  exit 1
fi

# Join labels as CSV
LABELS_CSV=""
for lbl in "${LABELS[@]+"${LABELS[@]}"}"; do
  if [ -z "$LABELS_CSV" ]; then
    LABELS_CSV="$lbl"
  else
    LABELS_CSV="$LABELS_CSV,$lbl"
  fi
done

# --- Create the item via pm_create_item ---
CREATE_ARGS=("$LEVEL" "$TITLE")
if [ -n "$BODY" ]; then
  CREATE_ARGS+=(--body "$BODY")
fi
if [ -n "$LABELS_CSV" ]; then
  CREATE_ARGS+=(--labels "$LABELS_CSV")
fi

ISSUE_NUMBER=$(pm_create_item "${CREATE_ARGS[@]}")
echo "$ISSUE_NUMBER"
