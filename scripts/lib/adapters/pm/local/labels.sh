#!/usr/bin/env bash
# labels.sh — Local adapter: issue label management.
#
# Functions:
#   pm_add_label <id> <label> [--create-if-missing] [--color <hex>] [--description <text>]
#     Appends a label to the item's frontmatter labels array.
#     Idempotent: duplicate label is a no-op.
#     --create-if-missing, --color, --description are accepted as no-op flags
#     for GitHub adapter compatibility.
#
# Requires _common.sh (auto-sourced if not already loaded).

# Idempotency guard — prevents double-sourcing
if [ -n "${_LOCAL_LABELS_LOADED:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
_LOCAL_LABELS_LOADED=1

# Auto-source _common.sh if not already loaded
_LABELS_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${_LOCAL_COMMON_LOADED:-}" ] && source "$_LABELS_SH_DIR/_common.sh"

# pm_add_label <id> <label> [--create-if-missing] [--color <hex>] [--description <text>]
pm_add_label() {
  local item_id="$1"
  local label="$2"
  shift 2

  # Parse optional flags — all are no-ops for the local adapter
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --create-if-missing) ;;
      --color)             shift ;;
      --description)       shift ;;
      *) echo "ERROR: pm_add_label: unknown option: $1" >&2; return 1 ;;
    esac
    shift
  done

  local item_path
  item_path=$(_local_item_path "$item_id")
  if [ ! -f "$item_path" ]; then
    echo "ERROR: pm_add_label: item $item_id not found" >&2
    return 1
  fi

  _local_fm_append_label "$item_path" "$label"
}
