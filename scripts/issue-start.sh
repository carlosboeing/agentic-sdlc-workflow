#!/usr/bin/env bash
set -euo pipefail

# issue-start.sh — Mark a GitHub Issue as in-progress: post a "Work Started"
# comment and set the project board status to In Progress.
#
# Usage: ./scripts/issue-start.sh <issue-number> [--model <model>] [--agent <agent>]

REPO="gavinkilbride/NeuralNorris"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <issue-number> [--model <model>] [--agent <agent>]"
  exit 1
fi

ISSUE_NUMBER="$1"
shift

MODEL="unknown"
AGENT="unknown"

while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --agent) AGENT="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Post start comment
gh issue comment "$ISSUE_NUMBER" --repo "$REPO" --body "$(cat <<EOF
### 🚀 Work Started

| Field | Value |
|-------|-------|
| **Agent** | $AGENT |
| **Model** | $MODEL |
| **Started** | $TIMESTAMP |
EOF
)"

echo "Issue #$ISSUE_NUMBER marked as started (agent=$AGENT, model=$MODEL)"

# Set board status to In Progress (defense-in-depth — orchestrator also sets this)
"$SCRIPT_DIR/issue-set-status.sh" "$ISSUE_NUMBER" in-progress \
  || echo "Warning: Board status update failed for #$ISSUE_NUMBER" >&2
