#!/usr/bin/env bash
# comments.sh -- Server adapter: pm_add_comment, pm_post_telemetry.
#
# Each function calls the HTTP API via curl using helpers from _common.sh.
# Supports prefix injection (_PM_LOADING_EXTERNAL) for dual-write mode.

_SERVER_COMMENTS_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${_SERVER_COMMON_LOADED:-}" ] && source "$_SERVER_COMMENTS_SH_DIR/_common.sh"

_PM_FN_PREFIX="${_PM_LOADING_EXTERNAL:+_external_}"

# pm_add_comment <item-id> <body>
eval "${_PM_FN_PREFIX}pm_add_comment() {
  if [ \$# -lt 2 ]; then
    echo \"Usage: pm_add_comment <item-id> <body>\" >&2
    return 1
  fi
  local item_id=\"\$1\"
  local body=\"\$2\"

  local escaped_body
  escaped_body=\$(_server_escape_json \"\$body\")

  _server_pm_curl_post \"/api/items/\$item_id/comments\" \
    \"{\\\"body\\\":\\\"\$escaped_body\\\",\\\"author\\\":\\\"shell-adapter\\\"}\" > /dev/null
}"

# pm_post_telemetry <item-id> [flags...]
# Delegates to scripts/item-telemetry.sh, passing all flags through unchanged.
eval "${_PM_FN_PREFIX}pm_post_telemetry() {
  local item_id=\"\$1\"
  shift
  \"\$REPO_ROOT/scripts/item-telemetry.sh\" \"\$item_id\" \"\$@\"
}"
