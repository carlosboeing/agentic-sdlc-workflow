#!/usr/bin/env bash
set -euo pipefail

# issue-review.sh — Mark a story as ready for review: post a "Ready for Review"
# comment and set the project board status to In Review.
#
# Thin wrapper: delegates to pm_complete_work from the PM abstraction layer.
#
# Usage: ./scripts/issue-review.sh <issue-number> <commit-hash>

if [ $# -lt 2 ]; then
  echo "Usage: $0 <issue-number> <commit-hash>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pm.sh"

ISSUE_NUMBER="$1"
COMMIT_HASH="$2"
pm_complete_work "$@"
echo "Issue #$ISSUE_NUMBER moved to review (commit=$COMMIT_HASH)"
