#!/usr/bin/env bash
set -euo pipefail

# issue-start.sh — Mark a GitHub Issue as in-progress: post a "Work Started"
# comment and set the project board status to In Progress.
#
# Thin wrapper: delegates to pm_start_work from the PM abstraction layer.
#
# Usage: ./scripts/issue-start.sh <issue-number> [--model <model>] [--agent <agent>]

if [ $# -lt 1 ]; then
  echo "Usage: $0 <issue-number> [--model <model>] [--agent <agent>]"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pm.sh"

ISSUE_NUMBER="$1"
pm_start_work "$@"
echo "Issue #$ISSUE_NUMBER marked as started"
