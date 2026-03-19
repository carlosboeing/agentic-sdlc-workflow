#!/usr/bin/env bash
set -euo pipefail

# item-append-body.sh — Append content to a work item's body.
#
# Thin wrapper: delegates to pm_append_body from the PM abstraction layer.
# Appends content to the body section of a work item. In the local adapter,
# inserts before the Activity Log separator if it exists. In the GitHub
# adapter, fetches the current body and appends via gh issue edit.
#
# Usage: ./scripts/item-append-body.sh <item-number> <content>

if [ $# -lt 2 ]; then
  echo "Usage: $0 <item-number> <content>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pm.sh"

pm_append_body "$@"
