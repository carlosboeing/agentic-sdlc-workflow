#!/usr/bin/env bash
# lifecycle.sh -- Server adapter: pm_start_work, pm_complete_work.
#
# Calls the HTTP API via curl using helpers from _common.sh.
# Supports prefix injection (_PM_LOADING_EXTERNAL) for dual-write mode.

_SERVER_LIFECYCLE_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${_SERVER_COMMON_LOADED:-}" ] && source "$_SERVER_LIFECYCLE_SH_DIR/_common.sh"

_PM_FN_PREFIX="${_PM_LOADING_EXTERNAL:+_external_}"

# pm_start_work <item-id> [--model <m>] [--agent <a>]
eval "${_PM_FN_PREFIX}pm_start_work() {
  local item_id=\"\$1\"
  shift
  local model=\"unknown\" agent=\"unknown\"

  while [ \$# -gt 0 ]; do
    case \"\$1\" in
      --model) model=\"\$2\"; shift 2 ;;
      --agent) agent=\"\$2\"; shift 2 ;;
      *) echo \"Unknown option: \$1\" >&2; return 1 ;;
    esac
  done

  local escaped_agent escaped_model
  escaped_agent=\$(_server_escape_json \"\$agent\")
  escaped_model=\$(_server_escape_json \"\$model\")

  _server_pm_curl_post \"/api/items/\$item_id/start\" \
    \"{\\\"agent\\\":\\\"\$escaped_agent\\\",\\\"model\\\":\\\"\$escaped_model\\\"}\" > /dev/null
}"

# pm_complete_work <item-id> <commit-hash>
eval "${_PM_FN_PREFIX}pm_complete_work() {
  local item_id=\"\$1\"
  local commit_hash=\"\$2\"

  local escaped_hash
  escaped_hash=\$(_server_escape_json \"\$commit_hash\")

  _server_pm_curl_post \"/api/items/\$item_id/complete\" \
    \"{\\\"commitHash\\\":\\\"\$escaped_hash\\\"}\" > /dev/null
}"
