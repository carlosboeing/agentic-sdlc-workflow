#!/usr/bin/env bash
set -euo pipefail

# item-link-child.sh — Link a child item to a parent item (sub-item relationship).
#
# Thin wrapper: delegates to pm_link_child from the PM abstraction layer.
#
# Usage: ./scripts/item-link-child.sh <parent-number> <child-number>

if [ $# -lt 2 ]; then
  echo "Usage: $0 <parent-number> <child-number>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pm.sh"

pm_link_child "$@"
