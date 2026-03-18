#!/usr/bin/env bash
# hierarchy.sh — Local adapter: parent-child item linking.
#
# Functions:
#   pm_link_child <parent-id> <child-id>
#     Sets parent: <parent-id> in the child item's frontmatter.
#     Validates that both item files exist before making changes.
#     Prints "Linked #<child-id> as sub-issue of #<parent-id>" on success.
#
# Requires _common.sh (auto-sourced if not already loaded).

# Idempotency guard — prevents double-sourcing
if [ -n "${_LOCAL_HIERARCHY_LOADED:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
_LOCAL_HIERARCHY_LOADED=1

# Auto-source _common.sh if not already loaded
_HIERARCHY_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${_LOCAL_COMMON_LOADED:-}" ] && source "$_HIERARCHY_SH_DIR/_common.sh"

# pm_link_child <parent-id> <child-id>
# Sets parent: <parent-id> in the child item's frontmatter.
pm_link_child() {
  local parent_id="$1"
  local child_id="$2"

  local parent_path child_path
  parent_path=$(_local_item_path "$parent_id")
  child_path=$(_local_item_path "$child_id")

  if [ ! -f "$parent_path" ]; then
    echo "ERROR: pm_link_child: parent item $parent_id not found" >&2
    return 1
  fi

  if [ ! -f "$child_path" ]; then
    echo "ERROR: pm_link_child: child item $child_id not found" >&2
    return 1
  fi

  _local_fm_write "$child_path" parent "$parent_id"
  echo "Linked #$child_id as sub-issue of #$parent_id"
}
