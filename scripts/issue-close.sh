#!/usr/bin/env bash
set -euo pipefail

# issue-close.sh — Close a GitHub Issue and set project board status to Done.
#
# Usage: ./scripts/issue-close.sh <issue-number>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"
REPO="$CFG_REPO"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <issue-number>"
  exit 1
fi

ISSUE_NUMBER="$1"

# Close the issue; suppress errors so already-closed issues are handled gracefully.
gh issue close "$ISSUE_NUMBER" --repo "$REPO" --reason completed 2>/dev/null || true

echo "Issue #$ISSUE_NUMBER closed (or was already closed)."

# Set board status to Done
"$SCRIPT_DIR/issue-set-status.sh" "$ISSUE_NUMBER" done \
  || echo "Warning: Board status update failed for #$ISSUE_NUMBER" >&2
