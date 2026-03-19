#!/usr/bin/env bash
set -euo pipefail

# item-comment.sh — Add a comment to a work item.
#
# Thin wrapper: delegates to pm_add_comment from the PM abstraction layer.
# In the local adapter, appends to the item's Activity Log section.
# In the GitHub adapter, posts as an issue comment.
#
# Usage: ./scripts/item-comment.sh <item-number> <body>

if [ $# -lt 2 ]; then
  echo "Usage: $0 <item-number> <body>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pm.sh"

pm_add_comment "$@"
