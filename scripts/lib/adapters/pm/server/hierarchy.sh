#!/usr/bin/env bash
# hierarchy.sh -- Server adapter: pm_link_child.
#
# Calls the HTTP API via curl using helpers from _common.sh.
# Supports prefix injection (_PM_LOADING_EXTERNAL) for dual-write mode.

_SERVER_HIERARCHY_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${_SERVER_COMMON_LOADED:-}" ] && source "$_SERVER_HIERARCHY_SH_DIR/_common.sh"

_PM_FN_PREFIX="${_PM_LOADING_EXTERNAL:+_external_}"

# pm_link_child <parent-id> <child-id>
eval "${_PM_FN_PREFIX}pm_link_child() {
  if [ \$# -lt 2 ]; then
    echo \"Usage: pm_link_child <parent-id> <child-id>\" >&2
    return 1
  fi
  local parent_id=\"\$1\"
  local child_id=\"\$2\"

  local response
  response=\$(_server_pm_curl_post \"/api/items/\$parent_id/children\" \
    \"{\\\"childId\\\":\$child_id}\") || return 1

  echo \"Linked #\$child_id as sub-issue of #\$parent_id\"
}"
