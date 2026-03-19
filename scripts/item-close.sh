#!/usr/bin/env bash
set -euo pipefail

# item-close.sh — Close a work item and set project board status to Done.
#
# Thin wrapper: delegates to pm_done from the PM abstraction layer.
#
# Usage: ./scripts/item-close.sh <item-number>

if [ $# -lt 1 ]; then
  echo "Usage: $0 <item-number>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pm.sh"

pm_done "$@"
echo "Item #$1 closed (or was already closed)."
