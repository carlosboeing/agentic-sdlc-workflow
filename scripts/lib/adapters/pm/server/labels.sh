#!/usr/bin/env bash
# labels.sh -- Server adapter: pm_add_label.
#
# Calls the HTTP API via curl using helpers from _common.sh.
# Supports prefix injection (_PM_LOADING_EXTERNAL) for dual-write mode.
#
# The adapter calls POST /api/items/:id/labels to associate a label with an
# item. The server's LabelService.addLabelToItem() handles upsert semantics:
# creates the label if it does not exist and idempotently associates it.

_SERVER_LABELS_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${_SERVER_COMMON_LOADED:-}" ] && source "$_SERVER_LABELS_SH_DIR/_common.sh"

_PM_FN_PREFIX="${_PM_LOADING_EXTERNAL:+_external_}"

# pm_add_label <id> <label> [--create-if-missing] [--color <hex>] [--description <text>]
eval "${_PM_FN_PREFIX}pm_add_label() {
  if [ \$# -lt 2 ]; then
    echo \"Usage: pm_add_label <item-id> <label> [--create-if-missing] [--color <hex>] [--description <text>]\" >&2
    return 1
  fi
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

  # Associate the label with the item via the server API.
  # POST /api/items/:id/labels handles upsert: creates the label if it does
  # not exist, then creates the item-label association (idempotent).
  local escaped_label
  escaped_label=\$(_server_escape_json \"\$label\")
  _server_pm_curl_post \"/api/items/\$item_id/labels\" \
    \"{\\\"name\\\":\\\"\$escaped_label\\\"}\" > /dev/null 2>&1 || true
}"
