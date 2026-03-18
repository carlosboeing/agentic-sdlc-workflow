#!/usr/bin/env bash
set -euo pipefail

# issue-set-status.sh — Set a GitHub issue's status on the project board.
#
# Thin wrapper: delegates to pm_set_status from the PM abstraction layer.
#
# Usage: ./scripts/issue-set-status.sh <issue-number> <status>
# Status values: backlog, ready, in-progress, in-review, done

if [ $# -lt 2 ]; then
  echo "Usage: $0 <issue-number> <status>" >&2
  echo "  status: backlog | ready | in-progress | in-review | done" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pm.sh"

pm_set_status "$@"
