#!/usr/bin/env bash
# items.sh — Local adapter: pm_create_item, pm_get_item, pm_list_items,
# pm_update_item, pm_done. Requires _common.sh. Sourced by pm.sh.

# Idempotency guard
[ -n "${_LOCAL_ITEMS_LOADED:-}" ] && { return 0 2>/dev/null || exit 0; }
_LOCAL_ITEMS_LOADED=1

# Auto-source _common.sh if not already loaded
_ITEMS_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${_LOCAL_COMMON_LOADED:-}" ] && source "$_ITEMS_SH_DIR/_common.sh"

# --- pm_create_item ---
# Usage: pm_create_item <level> <title> [--body <t>] [--body-file <p>] [--labels <csv>]
# Prints the new integer ID on stdout.
pm_create_item() {
  local level="$1" title="$2"; shift 2
  local hier_label
  case "$level" in
    backlog) hier_label="hierarchy/backlog" ;;
    epic)    hier_label="hierarchy/epic"    ;;
    story)   hier_label="hierarchy/story"   ;;
    docs)    hier_label="hierarchy/docs"    ;;
    *) echo "ERROR: pm_create_item: unknown level '$level'. Expected: backlog, epic, story, docs" >&2; return 1 ;;
  esac

  local body="" body_file="" extra_labels=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --body)      body="$2";         shift 2 ;;
      --body-file) body_file="$2";    shift 2 ;;
      --labels)    extra_labels="$2"; shift 2 ;;
      *) echo "ERROR: pm_create_item: unknown option '$1'" >&2; return 1 ;;
    esac
  done

  _local_ensure_dirs
  local item_id item_path now
  item_id=$(_local_next_id)
  item_path=$(_local_item_path "$item_id")
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  { echo "---"
    echo "id: $item_id"
    printf 'title: "%s"\n' "$title"
    echo "type: $level"
    echo "status: backlog"
    echo "labels:"
    echo "  - $hier_label"
    if [ -n "$extra_labels" ]; then
      local IFS=','
      for lbl in $extra_labels; do
        lbl="${lbl#"${lbl%%[![:space:]]*}"}"; lbl="${lbl%"${lbl##*[![:space:]]}"}"
        [ -n "$lbl" ] && echo "  - $lbl"
      done
    fi
    echo "parent: null"
    echo "state: open"
    echo "created: $now"
    echo "updated: $now"
    echo "---"
    echo ""
  } > "$item_path"

  [ -n "$body_file" ] && cat "$body_file" >> "$item_path"
  [ -z "$body_file" ] && [ -n "$body" ] && printf '%s\n' "$body" >> "$item_path"
  echo "$item_id"
}

# --- pm_get_item ---
# Usage: pm_get_item <id> [--json <fields>]
pm_get_item() {
  local item_id="$1"; shift
  local json_fields=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json_fields="$2"; shift 2 ;;
      *) echo "ERROR: pm_get_item: unknown option '$1'" >&2; return 1 ;;
    esac
  done
  local item_path
  item_path=$(_local_item_path "$item_id")
  [ ! -f "$item_path" ] && { echo "ERROR: pm_get_item: item $item_id not found" >&2; return 1; }

  if [ -n "$json_fields" ]; then
    local title state body labels_json state_upper
    title=$(_local_fm_read "$item_path" title)
    state=$(_local_fm_read "$item_path" state)
    body=$(_local_read_body "$item_path")
    labels_json=$(_local_fm_read_labels "$item_path" \
      | awk '{printf "%s{\"name\":\"%s\"}",(NR>1?",":""),$0}' \
      | awk '{print "["$0"]"}')
    state_upper=$(echo "$state" | tr '[:lower:]' '[:upper:]')
    _pm_build_json "$item_id" "$title" "$state_upper" "$body" "$labels_json" "$json_fields"
  else
    local title state labels_csv
    title=$(_local_fm_read "$item_path" title)
    state=$(_local_fm_read "$item_path" state)
    labels_csv=$(_local_fm_read_labels "$item_path" | paste -sd ',' -)
    printf "title:  %s\nstate:  %s\nlabels: %s\n" "$title" "$state" "$labels_csv"
  fi
}

# _pm_build_json — assemble JSON object for the requested fields.
_pm_build_json() {
  local item_id="$1" title="$2" state_upper="$3" body="$4" labels_json="$5" fields="$6"
  local json="{" first=1 part IFS=','
  for field in $fields; do
    field="${field#"${field%%[![:space:]]*}"}"; field="${field%"${field##*[![:space:]]}"}"
    case "$field" in
      number) part="\"number\":$item_id" ;;
      title)  part="$(printf '"title":"%s"' "$title")" ;;
      state)  part="\"state\":\"$state_upper\"" ;;
      body)   part="$(printf '"body":"%s"' "$(echo "$body" | sed 's/\\/\\\\/g;s/"/\\"/g' | tr '\n' ' ' | sed 's/ $//')")" ;;
      labels) part="\"labels\":$labels_json" ;;
      *)      part="\"$field\":null" ;;
    esac
    [ "$first" -eq 1 ] && json="${json}${part}" || json="${json},${part}"
    first=0
  done
  echo "${json}}"
}

# --- pm_list_items ---
# Usage: pm_list_items [--label <l>] [--state <open|closed|all>] [--limit <n>]
# Output: tab-separated ID, State (Title Case), Title, Date
pm_list_items() {
  local label="" state="open" limit="30"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --label) label="$2"; shift 2 ;;
      --state) state="$2"; shift 2 ;;
      --limit) limit="$2"; shift 2 ;;
      *) echo "ERROR: pm_list_items: unknown option '$1'" >&2; return 1 ;;
    esac
  done
  local items_dir="$_LOCAL_WORKFLOW_DIR/items"
  [ ! -d "$items_dir" ] && return 0
  local count=0
  for item_path in $(ls "$items_dir"/*.md 2>/dev/null | sort -V); do
    [ -f "$item_path" ] || continue
    local item_id item_state item_title item_created
    item_id=$(_local_fm_read "$item_path" id)
    item_state=$(_local_fm_read "$item_path" state)
    item_title=$(_local_fm_read "$item_path" title)
    item_created=$(_local_fm_read "$item_path" created)
    [ "$state" != "all" ] && [ "$item_state" != "$state" ] && continue
    [ -n "$label" ] && ! _local_fm_read_labels "$item_path" | grep -qxF "$label" && continue
    count=$((count + 1))
    [ "$count" -gt "$limit" ] && break
    local state_display
    state_display=$(echo "$item_state" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
    printf "%s\t%s\t%s\t%s\n" "$item_id" "$state_display" "$item_title" "${item_created%%T*}"
  done
}

# --- pm_update_item ---
# Usage: pm_update_item <id> [--title <t>] [--body <b>]
pm_update_item() {
  local item_id="$1"; shift
  local item_path
  item_path=$(_local_item_path "$item_id")
  [ ! -f "$item_path" ] && { echo "ERROR: pm_update_item: item $item_id not found" >&2; return 1; }
  local new_title="" new_body=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title) new_title="$2"; shift 2 ;;
      --body)  new_body="$2";  shift 2 ;;
      *) echo "ERROR: pm_update_item: unknown option '$1'" >&2; return 1 ;;
    esac
  done
  if [ -n "$new_title" ]; then
    _local_fm_write "$item_path" title "\"$new_title\""
  fi
  if [ -n "$new_body" ]; then
    _local_write_body "$item_path" "$new_body"
  fi
}

# --- pm_done ---
# Usage: pm_done <id> — sets state to closed, calls pm_set_status done.
pm_done() {
  local item_id="$1"
  local item_path
  item_path=$(_local_item_path "$item_id")
  [ ! -f "$item_path" ] && { echo "ERROR: pm_done: item $item_id not found" >&2; return 1; }
  _local_fm_write "$item_path" state closed
  if declare -f pm_set_status > /dev/null 2>&1; then
    pm_set_status "$item_id" done || true
  fi
}
