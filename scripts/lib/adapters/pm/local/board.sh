#!/usr/bin/env bash
# board.sh — Local adapter: pm_set_status, pm_add_to_board,
# pm_batch_set_status, pm_get_status.
#
# Status is stored directly in item frontmatter. No API calls.
# Logs go to $_LOCAL_WORKFLOW_DIR/logs/board-status.log for
# compatibility with the GitHub adapter log readers.
#
# Usage: source this file; do not execute directly.

# Idempotency guard
[ -n "${_LOCAL_BOARD_LOADED:-}" ] && { return 0 2>/dev/null || exit 0; }
_LOCAL_BOARD_LOADED=1

# Auto-source _common.sh if not already loaded
_BOARD_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${_LOCAL_COMMON_LOADED:-}" ] && source "$_BOARD_SH_DIR/_common.sh"

# --- Private helpers ---

_board_log_file() {
  echo "$_LOCAL_WORKFLOW_DIR/logs/board-status.log"
}

_board_log() {
  local log_file
  log_file=$(_board_log_file)
  mkdir -p "$(dirname "$log_file")" 2>/dev/null || true
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$log_file" 2>/dev/null || true
}

# _local_validate_status <status> — returns 0 if valid, 1 otherwise.
_local_validate_status() {
  case "$1" in
    backlog|ready|in-progress|in-review|done) return 0 ;;
    *) return 1 ;;
  esac
}

# --- pm_set_status ---
# Usage: pm_set_status <item-id> <status>
# Updates the status: field in frontmatter. Skips if already at target.
# Logs to board-status.log. Prints skip or confirmation.
pm_set_status() {
  if [ $# -lt 2 ]; then
    echo "Usage: pm_set_status <item-id> <status>" >&2
    return 1
  fi
  local item_id="$1" status="$2"

  if ! _local_validate_status "$status"; then
    echo "ERROR: pm_set_status: invalid status '$status'. Expected: backlog, ready, in-progress, in-review, done" >&2
    return 1
  fi

  local item_path
  item_path=$(_local_item_path "$item_id")
  if [ ! -f "$item_path" ]; then
    echo "ERROR: pm_set_status: item $item_id not found" >&2
    return 1
  fi

  _board_log "issue=$item_id status=$status START"

  local current_status
  current_status=$(_local_fm_read "$item_path" status)

  if [ "$current_status" = "$status" ]; then
    _board_log "issue=$item_id status=$status SKIP already_at=$status"
    echo "#$item_id already at $status"
    return 0
  fi

  _local_fm_write "$item_path" status "$status"
  _board_log "issue=$item_id status=$status DONE prev=$current_status"
  echo "#$item_id -> $status"
}

# --- pm_add_to_board ---
# Usage: pm_add_to_board <item-id>
# No-op in the local adapter — items are always on the board.
pm_add_to_board() {
  if [ $# -lt 1 ]; then
    echo "Usage: pm_add_to_board <item-id>" >&2
    return 1
  fi
  local item_id="$1"
  echo "#$item_id added to board"
}

# --- pm_get_status ---
# Usage: pm_get_status <item-id>
# Prints the current status value from frontmatter.
pm_get_status() {
  if [ $# -lt 1 ]; then
    echo "Usage: pm_get_status <item-id>" >&2
    return 1
  fi
  local item_id="$1"
  local item_path
  item_path=$(_local_item_path "$item_id")
  if [ ! -f "$item_path" ]; then
    echo "ERROR: pm_get_status: item $item_id not found" >&2
    return 1
  fi
  _local_fm_read "$item_path" status
}

# --- pm_batch_set_status ---
# Usage: pm_batch_set_status <item>:<status> [...]
# Iterates pairs and calls pm_set_status for each.
pm_batch_set_status() {
  if [ $# -lt 1 ]; then
    echo "Usage: pm_batch_set_status <item>:<status> [...]" >&2
    return 1
  fi
  local pair issue status
  for pair in "$@"; do
    issue="${pair%%:*}"
    status="${pair##*:}"
    if [ -z "$issue" ] || [ -z "$status" ] || [ "$issue" = "$pair" ]; then
      echo "ERROR: pm_batch_set_status: Invalid pair '$pair'. Expected: <item>:<status>" >&2
      return 1
    fi
    pm_set_status "$issue" "$status" || return 1
  done
}
