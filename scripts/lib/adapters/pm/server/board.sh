#!/usr/bin/env bash
# board.sh -- Server adapter: pm_set_status, pm_add_to_board,
# pm_batch_set_status, pm_get_status.
#
# Each function calls the HTTP API via curl using helpers from _common.sh.
# Supports prefix injection (_PM_LOADING_EXTERNAL) for dual-write mode.

_SERVER_BOARD_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${_SERVER_COMMON_LOADED:-}" ] && source "$_SERVER_BOARD_SH_DIR/_common.sh"

_PM_FN_PREFIX="${_PM_LOADING_EXTERNAL:+_external_}"

# pm_set_status <item-id> <status>
eval "${_PM_FN_PREFIX}pm_set_status() {
  if [ \$# -lt 2 ]; then
    echo \"Usage: pm_set_status <item-id> <status>\" >&2
    return 1
  fi
  local item_id=\"\$1\" status=\"\$2\"

  case \"\$status\" in
    backlog|ready|in-progress|in-review|done) ;;
    *) echo \"ERROR: pm_set_status: invalid status '\$status'. Expected: backlog, ready, in-progress, in-review, done\" >&2; return 1 ;;
  esac

  local response
  response=\$(_server_pm_curl_post \"/api/items/\$item_id/status\" \"{\\\"status\\\":\\\"\$status\\\"}\") || return 1
  echo \"#\$item_id -> \$status\"
}"

# pm_add_to_board <item-id>
# No-op for server adapter (items are always on the board).
eval "${_PM_FN_PREFIX}pm_add_to_board() {
  if [ \$# -lt 1 ]; then
    echo \"Usage: pm_add_to_board <item-id>\" >&2
    return 1
  fi
  echo \"#\$1 added to board\"
}"

# pm_get_status <item-id>
eval "${_PM_FN_PREFIX}pm_get_status() {
  if [ \$# -lt 1 ]; then
    echo \"Usage: pm_get_status <item-id>\" >&2
    return 1
  fi
  local item_id=\"\$1\"

  local response
  response=\$(_server_pm_curl_get \"/api/items/\$item_id\") || return 1
  echo \"\$response\" | jq -r '.status // \"backlog\"'
}"

# pm_batch_set_status <item>:<status> [...]
eval "${_PM_FN_PREFIX}pm_batch_set_status() {
  if [ \$# -lt 1 ]; then
    echo \"Usage: pm_batch_set_status <item>:<status> [...]\" >&2
    return 1
  fi
  local pair issue status
  for pair in \"\$@\"; do
    issue=\"\${pair%%:*}\"
    status=\"\${pair##*:}\"
    if [ -z \"\$issue\" ] || [ -z \"\$status\" ] || [ \"\$issue\" = \"\$pair\" ]; then
      echo \"ERROR: pm_batch_set_status: Invalid pair '\$pair'. Expected: <item>:<status>\" >&2
      return 1
    fi
    ${_PM_FN_PREFIX}pm_set_status \"\$issue\" \"\$status\" || return 1
  done
}"
