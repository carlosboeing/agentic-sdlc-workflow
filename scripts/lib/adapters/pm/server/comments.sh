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

# pm_add_doc_comment <path> <body> [anchor]
# Add a comment to a design document, optionally anchored to a heading or paragraph.
# <path> is the document path relative to the docs/ directory (e.g. "2-design/overview.md")
# <anchor> is an optional anchor slug (e.g. "introduction" or "p-0")
eval "${_PM_FN_PREFIX}pm_add_doc_comment() {
  if [ \$# -lt 2 ]; then
    echo \"Usage: pm_add_doc_comment <path> <body> [anchor]\" >&2
    return 1
  fi
  local doc_path=\"\$1\"
  local body=\"\$2\"
  local anchor=\"\${3:-}\"

  local escaped_body escaped_anchor json_body
  escaped_body=\$(_server_escape_json \"\$body\")

  if [ -n \"\$anchor\" ]; then
    escaped_anchor=\$(_server_escape_json \"\$anchor\")
    json_body=\"{\\\"body\\\":\\\"\$escaped_body\\\",\\\"author\\\":\\\"shell-adapter\\\",\\\"anchor\\\":\\\"\$escaped_anchor\\\"}\"
  else
    json_body=\"{\\\"body\\\":\\\"\$escaped_body\\\",\\\"author\\\":\\\"shell-adapter\\\"}\"
  fi

  _server_pm_curl_post \"/api/documents/\$doc_path/comments\" \"\$json_body\" > /dev/null
}"

# pm_post_telemetry <item-id> [flags...]
# Delegates to scripts/item-telemetry.sh, passing all flags through unchanged.
eval "${_PM_FN_PREFIX}pm_post_telemetry() {
  local item_id=\"\$1\"
  shift
  \"\$REPO_ROOT/scripts/item-telemetry.sh\" \"\$item_id\" \"\$@\"
}"
