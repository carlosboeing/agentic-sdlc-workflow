#!/usr/bin/env bash
set -euo pipefail

# issue-close.sh — Close a GitHub Issue and set project board status to Done.
#
# Thin wrapper: delegates to pm_done from the PM abstraction layer.
#
# Usage: ./scripts/issue-close.sh <issue-number>

if [ $# -lt 1 ]; then
  echo "Usage: $0 <issue-number>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pm.sh"

pm_done "$@"
echo "Issue #$1 closed (or was already closed)."
