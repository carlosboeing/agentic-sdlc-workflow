#!/usr/bin/env bash
set -euo pipefail

# issue-review.sh — Mark a story as ready for review: post a "Ready for Review"
# comment and set the project board status to In Review.
#
# Usage: ./scripts/issue-review.sh <issue-number> <commit-hash>

REPO="gavinkilbride/NeuralNorris"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <issue-number> <commit-hash>"
  exit 1
fi

ISSUE_NUMBER="$1"
COMMIT_HASH="$2"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Post review-ready comment
gh issue comment "$ISSUE_NUMBER" --repo "$REPO" --body "$(cat <<EOF
### 👀 Ready for Review

| Field | Value |
|-------|-------|
| **Commit** | $COMMIT_HASH |
| **Completed** | $TIMESTAMP |
EOF
)"

echo "Issue #$ISSUE_NUMBER moved to review (commit=$COMMIT_HASH)"

# Set board status to In Review (defense-in-depth — orchestrator also sets this)
"$SCRIPT_DIR/issue-set-status.sh" "$ISSUE_NUMBER" in-review \
  || echo "Warning: Board status update failed for #$ISSUE_NUMBER" >&2
