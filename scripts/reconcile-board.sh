#!/usr/bin/env bash
set -euo pipefail

# reconcile-board.sh — Reconcile GitHub project board statuses with orchestrator state.
#
# Thin wrapper: delegates to pm_reconcile from the PM abstraction layer.
#
# Usage: ./scripts/reconcile-board.sh --from-state <state-file> [--epic-issues <json>] [--dry-run]

if [ $# -lt 1 ]; then
  echo "Usage: $0 --from-state <state-file> [--epic-issues <json>] [--dry-run]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pm.sh"

pm_reconcile "$@"
