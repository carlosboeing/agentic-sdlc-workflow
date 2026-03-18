#!/usr/bin/env bash
set -euo pipefail

# batch-set-status.sh — Set board status for multiple issues in one invocation.
#
# Thin wrapper: delegates to pm_batch_set_status from the PM abstraction layer.
#
# Usage: ./scripts/batch-set-status.sh <issue>:<status> [<issue>:<status> ...]
# Status values: backlog, ready, in-progress, in-review, done

if [ $# -lt 1 ]; then
  echo "Usage: $0 <issue>:<status> [<issue>:<status> ...]" >&2
  echo "  status: backlog | ready | in-progress | in-review | done" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pm.sh"

pm_batch_set_status "$@"
