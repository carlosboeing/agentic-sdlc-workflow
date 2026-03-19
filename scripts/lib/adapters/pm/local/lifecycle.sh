#!/usr/bin/env bash
# lifecycle.sh — Local PM adapter: work lifecycle functions.
#
# Provides:
#   pm_start_work <item-id> [--model <m>] [--agent <a>]
#     Posts a "Work Started" comment and sets status to In Progress.
#   pm_complete_work <item-id> <commit-hash>
#     Posts a "Ready for Review" comment and sets status to In Review.
#
# Both functions compose on pm_add_comment (comments.sh) and pm_set_status
# (board.sh) — no direct file writes.

# Idempotency guard
[ -n "${_LOCAL_LIFECYCLE_LOADED:-}" ] && { return 0 2>/dev/null || exit 0; }
_LOCAL_LIFECYCLE_LOADED=1

# Auto-source _common.sh if not already loaded
_LIFECYCLE_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${_LOCAL_COMMON_LOADED:-}" ] && source "$_LIFECYCLE_SH_DIR/_common.sh"

# pm_start_work <item-id> [--model <m>] [--agent <a>]
# Posts "Work Started" comment (byte-identical to item-start.sh) and sets
# board status to in-progress.
pm_start_work() {
  local item_id="$1"
  shift
  local model="unknown" agent="unknown"

  while [ $# -gt 0 ]; do
    case "$1" in
      --model) model="$2"; shift 2 ;;
      --agent) agent="$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
  done

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  pm_add_comment "$item_id" "$(cat <<EOF
### 🚀 Work Started

| Field | Value |
|-------|-------|
| **Agent** | $agent |
| **Model** | $model |
| **Started** | $timestamp |
EOF
)"

  pm_set_status "$item_id" in-progress \
    || echo "Warning: Board status update failed for #$item_id" >&2
}

# pm_complete_work <item-id> <commit-hash>
# Posts "Ready for Review" comment (byte-identical to item-review.sh) and
# sets board status to in-review.
pm_complete_work() {
  local item_id="$1"
  local commit_hash="$2"

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  pm_add_comment "$item_id" "$(cat <<EOF
### 👀 Ready for Review

| Field | Value |
|-------|-------|
| **Commit** | $commit_hash |
| **Completed** | $timestamp |
EOF
)"

  pm_set_status "$item_id" in-review \
    || echo "Warning: Board status update failed for #$item_id" >&2
}
