#!/usr/bin/env bash
set -euo pipefail

# item-get.sh — Read a work item's details.
#
# Thin wrapper: delegates to pm_get_item from the PM abstraction layer.
#
# Usage: ./scripts/item-get.sh <item-number> [--json <fields>]
#   fields: comma-separated list of: number, title, state, body, labels

if [ $# -lt 1 ]; then
  echo "Usage: $0 <item-number> [--json <fields>]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pm.sh"

pm_get_item "$@"
