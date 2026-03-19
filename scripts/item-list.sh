#!/usr/bin/env bash
set -euo pipefail

# item-list.sh — List work items.
#
# Thin wrapper: delegates to pm_list_items from the PM abstraction layer.
#
# Usage: ./scripts/item-list.sh [--label <label>] [--state <open|closed|all>] [--limit <n>]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pm.sh"

pm_list_items "$@"
