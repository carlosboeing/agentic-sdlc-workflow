#!/usr/bin/env bash
# labels.sh -- Server adapter: pm_add_label.
#
# Calls the HTTP API via curl using helpers from _common.sh.
# Supports prefix injection (_PM_LOADING_EXTERNAL) for dual-write mode.
#
# NOTE: The server API currently adds labels to items at creation time
# (POST /api/items with labels[] in body). There is no dedicated
# POST /api/items/:id/labels endpoint yet. This adapter creates labels
# via POST /api/labels (ensuring they exist) and relies on item creation
# to attach them. A future API enhancement could add label-to-item
# association for existing items.

_SERVER_LABELS_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${_SERVER_COMMON_LOADED:-}" ] && source "$_SERVER_LABELS_SH_DIR/_common.sh"

_PM_FN_PREFIX="${_PM_LOADING_EXTERNAL:+_external_}"

# pm_add_label <id> <label> [--create-if-missing] [--color <hex>] [--description <text>]
eval "${_PM_FN_PREFIX}pm_add_label() {
  local item_id=\"\$1\"
  local label=\"\$2\"
  shift 2

  # Parse optional flags (accepted for compatibility with GitHub adapter)
  local color=\"\" description=\"\"
  while [ \"\$#\" -gt 0 ]; do
    case \"\$1\" in
      --create-if-missing) ;;
      --color)             color=\"\$2\"; shift ;;
      --description)       description=\"\$2\"; shift ;;
      *) echo \"ERROR: pm_add_label: unknown option: \$1\" >&2; return 1 ;;
    esac
    shift
  done

  # Ensure the label exists on the server (idempotent)
  local escaped_label
  escaped_label=\$(_server_escape_json \"\$label\")
  local label_json=\"{\\\"name\\\":\\\"\$escaped_label\\\"\"
  [ -n \"\$color\" ] && label_json=\"\${label_json},\\\"color\\\":\\\"\$color\\\"\"
  [ -n \"\$description\" ] && label_json=\"\${label_json},\\\"description\\\":\\\"\$description\\\"\"
  label_json=\"\${label_json}}\"

  # Create label (may fail with duplicate -- that is fine)
  _server_pm_curl_post \"/api/labels\" \"\$label_json\" > /dev/null 2>&1 || true
}"
