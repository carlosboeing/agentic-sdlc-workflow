#!/usr/bin/env bash
# items.sh -- Server adapter: pm_create_item, pm_get_item, pm_list_items,
# pm_update_item, pm_close_item, pm_append_body.
#
# Each function calls the HTTP API via curl using helpers from _common.sh.
# Supports prefix injection (_PM_LOADING_EXTERNAL) for dual-write mode.

_SERVER_ITEMS_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${_SERVER_COMMON_LOADED:-}" ] && source "$_SERVER_ITEMS_SH_DIR/_common.sh"

_PM_FN_PREFIX="${_PM_LOADING_EXTERNAL:+_external_}"

# pm_create_item <level> <title> [--body <t>] [--body-file <p>] [--labels <csv>] [--created-by <agent>]
eval "${_PM_FN_PREFIX}pm_create_item() {
  local level=\"\$1\" title=\"\$2\"; shift 2
  local body=\"\" body_file=\"\" labels=\"\" created_by=\"\"
  while [[ \$# -gt 0 ]]; do
    case \"\$1\" in
      --body) body=\"\$2\"; shift 2 ;;
      --body-file) body_file=\"\$2\"; shift 2 ;;
      --labels) labels=\"\$2\"; shift 2 ;;
      --created-by) created_by=\"\$2\"; shift 2 ;;
      *) echo \"ERROR: pm_create_item: unknown option '\$1'\" >&2; return 1 ;;
    esac
  done

  # Read body from file if specified
  if [ -n \"\$body_file\" ] && [ -f \"\$body_file\" ]; then
    body=\$(cat \"\$body_file\")
  fi

  # Build labels JSON array
  local labels_json=\"[]\"
  if [ -n \"\$labels\" ]; then
    labels_json=\$(printf '%s' \"\$labels\" | awk -F',' '{
      printf \"[\"
      for(i=1;i<=NF;i++) {
        gsub(/^[[:space:]]+|[[:space:]]+\$/, \"\", \$i)
        if(i>1) printf \",\"
        printf \"\\\"%s\\\"\", \$i
      }
      printf \"]\"
    }')
  fi

  local escaped_title escaped_body
  escaped_title=\$(_server_escape_json \"\$title\")
  escaped_body=\$(_server_escape_json \"\$body\")

  local json_payload
  json_payload=\"{\\\"type\\\":\\\"\$level\\\",\\\"title\\\":\\\"\$escaped_title\\\"\"
  [ -n \"\$body\" ] && json_payload=\"\${json_payload},\\\"body\\\":\\\"\$escaped_body\\\"\"
  [ -n \"\$created_by\" ] && json_payload=\"\${json_payload},\\\"createdBy\\\":\\\"\$created_by\\\"\"
  json_payload=\"\${json_payload},\\\"labels\\\":\$labels_json}\"

  local response
  response=\$(_server_pm_curl_post \"/api/items\" \"\$json_payload\") || return 1

  # Extract and return the item ID
  echo \"\$response\" | jq -r '.id'
}"

# pm_get_item <id> [--json <fields>]
eval "${_PM_FN_PREFIX}pm_get_item() {
  local item_id=\"\$1\"; shift
  local json_fields=\"\"
  while [[ \$# -gt 0 ]]; do
    case \"\$1\" in --json) json_fields=\"\$2\"; shift 2 ;;
      *) echo \"ERROR: pm_get_item: unknown option '\$1'\" >&2; return 1 ;;
    esac
  done

  local response
  response=\$(_server_pm_curl_get \"/api/items/\$item_id\") || return 1

  if [ -n \"\$json_fields\" ]; then
    # Build a jq filter from the comma-separated field list
    local jq_filter=\"{\"
    local first=1
    local IFS=','
    for field in \$json_fields; do
      field=\$(echo \"\$field\" | tr -d ' ')
      [ \"\$first\" -eq 1 ] && first=0 || jq_filter=\"\${jq_filter},\"
      case \"\$field\" in
        number) jq_filter=\"\${jq_filter}number:.id\" ;;
        title)  jq_filter=\"\${jq_filter}title:.title\" ;;
        state)  jq_filter=\"\${jq_filter}state:.state\" ;;
        body)   jq_filter=\"\${jq_filter}body:(.body // \\\"\\\")\" ;;
        labels) jq_filter=\"\${jq_filter}labels:(.labels // [])\" ;;
        *)      jq_filter=\"\${jq_filter}\$field:.\$field\" ;;
      esac
    done
    jq_filter=\"\${jq_filter}}\"
    echo \"\$response\" | jq -c \"\$jq_filter\"
  else
    # Plain text format matching local adapter output
    local title state labels_csv
    title=\$(echo \"\$response\" | jq -r '.title // \"\"')
    state=\$(echo \"\$response\" | jq -r '.state // \"open\"')
    labels_csv=\$(echo \"\$response\" | jq -r '(.labels // []) | map(.name // .) | join(\", \")')
    printf \"title:  %s\nstate:  %s\nlabels: %s\n\" \"\$title\" \"\$state\" \"\$labels_csv\"
  fi
}"

# pm_list_items [--label <l>] [--state <open|closed|all>] [--limit <n>]
eval "${_PM_FN_PREFIX}pm_list_items() {
  local label=\"\" state=\"open\" limit=\"30\"
  while [[ \$# -gt 0 ]]; do
    case \"\$1\" in
      --label) label=\"\$2\"; shift 2 ;;
      --state) state=\"\$2\"; shift 2 ;;
      --limit) limit=\"\$2\"; shift 2 ;;
      *) echo \"ERROR: pm_list_items: unknown option '\$1'\" >&2; return 1 ;;
    esac
  done

  local query_params=\"?limit=\$limit\"
  [ \"\$state\" != \"all\" ] && query_params=\"\${query_params}&state=\$state\"
  [ -n \"\$label\" ] && query_params=\"\${query_params}&label=\$label\"

  local response
  response=\$(_server_pm_curl_get \"/api/items\$query_params\") || return 1

  # Format output to match local adapter: id<tab>State<tab>title<tab>date
  echo \"\$response\" | jq -r '.[] | [
    (.id | tostring),
    (.state // \"open\" | if . == \"open\" then \"Open\" elif . == \"closed\" then \"Closed\" else . end),
    (.title // \"\"),
    (.createdAt // \"\" | split(\"T\")[0] // \"\")
  ] | @tsv'
}"

# pm_update_item <id> [--title <t>] [--body <b>] [--updated-by <agent>]
eval "${_PM_FN_PREFIX}pm_update_item() {
  local item_id=\"\$1\"; shift
  local new_title=\"\" new_body=\"\" updated_by=\"\"
  while [[ \$# -gt 0 ]]; do
    case \"\$1\" in
      --title) new_title=\"\$2\"; shift 2 ;;
      --body) new_body=\"\$2\"; shift 2 ;;
      --updated-by) updated_by=\"\$2\"; shift 2 ;;
      *) echo \"ERROR: pm_update_item: unknown option '\$1'\" >&2; return 1 ;;
    esac
  done

  local json_payload=\"{\"
  local first=1
  if [ -n \"\$new_title\" ]; then
    local escaped_title
    escaped_title=\$(_server_escape_json \"\$new_title\")
    [ \"\$first\" -eq 1 ] && first=0 || json_payload=\"\${json_payload},\"
    json_payload=\"\${json_payload}\\\"title\\\":\\\"\$escaped_title\\\"\"
  fi
  if [ -n \"\$new_body\" ]; then
    local escaped_body
    escaped_body=\$(_server_escape_json \"\$new_body\")
    [ \"\$first\" -eq 1 ] && first=0 || json_payload=\"\${json_payload},\"
    json_payload=\"\${json_payload}\\\"body\\\":\\\"\$escaped_body\\\"\"
  fi
  json_payload=\"\${json_payload}}\"

  _server_pm_curl_patch \"/api/items/\$item_id\" \"\$json_payload\" > /dev/null
}"

# pm_close_item <id>
eval "${_PM_FN_PREFIX}pm_close_item() {
  local item_id=\"\$1\"
  _server_pm_curl_delete \"/api/items/\$item_id\" > /dev/null
}"

# pm_append_body <item-id> <content> [--updated-by <agent>]
eval "${_PM_FN_PREFIX}pm_append_body() {
  local item_id=\"\$1\" content=\"\$2\"; shift 2
  local updated_by=\"\"
  while [[ \$# -gt 0 ]]; do
    case \"\$1\" in --updated-by) updated_by=\"\$2\"; shift 2 ;; *) shift ;; esac
  done

  # Get current body, append content, then update
  local current_body escaped_content
  current_body=\$(_server_pm_curl_get \"/api/items/\$item_id\" | jq -r '.body // \"\"') || return 1
  local new_body=\"\${current_body}
\${content}\"
  local escaped_body
  escaped_body=\$(_server_escape_json \"\$new_body\")
  _server_pm_curl_patch \"/api/items/\$item_id\" \"{\\\"body\\\":\\\"\$escaped_body\\\"}\" > /dev/null
}"
