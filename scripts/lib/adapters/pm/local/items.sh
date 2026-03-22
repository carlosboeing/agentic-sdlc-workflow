#!/usr/bin/env bash
# items.sh — Local adapter: pm_create_item, pm_get_item, pm_list_items,
# pm_update_item, pm_close_item, _local_pm_create_item_with_id. Requires _common.sh.

[ -n "${_LOCAL_ITEMS_LOADED:-}" ] && { return 0 2>/dev/null || exit 0; }
_LOCAL_ITEMS_LOADED=1
_ITEMS_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${_LOCAL_COMMON_LOADED:-}" ] && source "$_ITEMS_SH_DIR/_common.sh"

_local_escape_json_string() { printf '%s' "$1" | sed 's/\\/\\\\/g;s/"/\\"/g'; }

_local_build_json() {
  local item_id="$1" title="$2" state_upper="$3" body="$4" labels_json="$5" fields="$6"
  local json="{" first=1 part IFS=','
  for field in $fields; do
    field="${field#"${field%%[![:space:]]*}"}"; field="${field%"${field##*[![:space:]]}"}"
    case "$field" in
      number) part="\"number\":$item_id" ;;
      title)  part="$(printf '"title":"%s"' "$(_local_escape_json_string "$title")")" ;;
      state)  part="\"state\":\"$state_upper\"" ;;
      body)   part="$(printf '"body":"%s"' "$(printf '%s' "$body" | sed 's/\\/\\\\/g;s/"/\\"/g' | awk '{printf "%s%s",(NR>1?"\\n":""),$0}')")" ;;
      labels) part="\"labels\":$labels_json" ;;
      *)      part="\"$field\":null" ;;
    esac
    [ "$first" -eq 1 ] && json="${json}${part}" || json="${json},${part}"
    first=0
  done
  echo "${json}}"
}

# _local_hier_label <level> — print the hierarchy label; returns 1 on unknown level.
_local_hier_label() {
  case "$1" in
    backlog) echo "hierarchy/backlog" ;; epic) echo "hierarchy/epic" ;;
    story)   echo "hierarchy/story"  ;; docs) echo "hierarchy/docs" ;; *) return 1 ;;
  esac
}

# _local_write_item — write frontmatter + body to items/<id>.md.
# Usage: _local_write_item <id> <level> <hier_label> <title> <body> <body_file> <extra_labels> [<created_by>]
_local_write_item() {
  local item_id="$1" level="$2" hier_label="$3" title="$4" body="$5" body_file="$6" extra_labels="$7" created_by="${8:-}"
  local item_path now
  item_path=$(_local_item_path "$item_id"); now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  { echo "---"; echo "id: $item_id"; printf 'title: "%s"\n' "$title"
    echo "type: $level"; echo "status: backlog"; echo "labels:"; echo "  - $hier_label"
    if [ -n "$extra_labels" ]; then
      local IFS=','
      for lbl in $extra_labels; do
        lbl="${lbl#"${lbl%%[![:space:]]*}"}"; lbl="${lbl%"${lbl##*[![:space:]]}"}"
        [ -n "$lbl" ] && echo "  - $lbl"
      done
    fi
    echo "parent: null"; echo "state: open"; echo "created: $now"; echo "updated: $now"
    [ -n "$created_by" ] && echo "created_by: $created_by"
    echo "---"; echo ""
  } > "$item_path"
  if [ -n "$body_file" ]; then cat "$body_file" >> "$item_path"
  elif [ -n "$body" ]; then printf '%s\n' "$body" >> "$item_path"; fi
}

# pm_create_item <level> <title> [--body <t>] [--body-file <p>] [--labels <csv>]
pm_create_item() {
  local level="$1" title="$2"; shift 2
  local hier_label
  hier_label=$(_local_hier_label "$level") \
    || { echo "ERROR: pm_create_item: unknown level '$level'. Expected: backlog, epic, story, docs" >&2; return 1; }
  local body="" body_file="" extra_labels="" created_by=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --body) body="$2"; shift 2 ;; --body-file) body_file="$2"; shift 2 ;;
      --labels) extra_labels="$2"; shift 2 ;; --created-by) created_by="$2"; shift 2 ;;
      *) echo "ERROR: pm_create_item: unknown option '$1'" >&2; return 1 ;;
    esac
  done
  _local_ensure_dirs
  local item_id; item_id=$(_local_next_id)
  _local_write_item "$item_id" "$level" "$hier_label" "$title" "$body" "$body_file" "$extra_labels" "$created_by"
  echo "$item_id"
}

# _local_pm_create_item_with_id <id> <level> <title> [--body <t>] [--body-file <p>] [--labels <csv>]
# Creates item with explicit ID. Updates _next_id to max(current, id+1).
_local_pm_create_item_with_id() {
  local item_id="$1" level="$2" title="$3"; shift 3
  local hier_label
  hier_label=$(_local_hier_label "$level") \
    || { echo "ERROR: _local_pm_create_item_with_id: unknown level '$level'." >&2; return 1; }
  local body="" body_file="" extra_labels="" created_by=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --body) body="$2"; shift 2 ;; --body-file) body_file="$2"; shift 2 ;;
      --labels) extra_labels="$2"; shift 2 ;; --created-by) created_by="$2"; shift 2 ;;
      *) echo "ERROR: _local_pm_create_item_with_id: unknown option '$1'" >&2; return 1 ;;
    esac
  done
  _local_ensure_dirs
  local id_file="$_LOCAL_WORKFLOW_DIR/_next_id" current_next=1
  [ -f "$id_file" ] && current_next=$(cat "$id_file")
  local required_next=$(( item_id + 1 ))
  [ "$required_next" -gt "$current_next" ] && echo "$required_next" > "$id_file"
  _local_write_item "$item_id" "$level" "$hier_label" "$title" "$body" "$body_file" "$extra_labels" "$created_by"
  echo "$item_id"
}

# pm_get_item <id> [--json <fields>]
pm_get_item() {
  local item_id="$1"; shift
  local json_fields=""
  while [[ $# -gt 0 ]]; do
    case "$1" in --json) json_fields="$2"; shift 2 ;;
      *) echo "ERROR: pm_get_item: unknown option '$1'" >&2; return 1 ;;
    esac
  done
  local item_path; item_path=$(_local_item_path "$item_id")
  [ ! -f "$item_path" ] && { echo "ERROR: pm_get_item: item $item_id not found" >&2; return 1; }
  if [ -n "$json_fields" ]; then
    local title state body labels_json state_upper
    title=$(_local_fm_read "$item_path" title); state=$(_local_fm_read "$item_path" state)
    body=$(_local_read_body "$item_path")
    labels_json=$(_local_fm_read_labels "$item_path" \
      | awk '{printf "%s{\"name\":\"%s\"}",(NR>1?",":""),$0}' | awk '{print "["$0"]"}')
    state_upper=$(echo "$state" | tr '[:lower:]' '[:upper:]')
    _local_build_json "$item_id" "$title" "$state_upper" "$body" "$labels_json" "$json_fields"
  else
    local title state labels_csv
    title=$(_local_fm_read "$item_path" title); state=$(_local_fm_read "$item_path" state)
    labels_csv=$(_local_fm_read_labels "$item_path" | paste -sd ',' - | sed 's/,/, /g')
    printf "title:  %s\nstate:  %s\nlabels: %s\n" "$title" "$state" "$labels_csv"
  fi
}

# pm_list_items [--label <l>] [--state <open|closed|all>] [--limit <n>]
pm_list_items() {
  local label="" state="open" limit="30"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --label) label="$2"; shift 2 ;; --state) state="$2"; shift 2 ;;
      --limit) limit="$2"; shift 2 ;;
      *) echo "ERROR: pm_list_items: unknown option '$1'" >&2; return 1 ;;
    esac
  done
  local items_dir="$_LOCAL_WORKFLOW_DIR/items"
  [ ! -d "$items_dir" ] && return 0
  local count=0
  for item_path in "$items_dir"/*.md; do
    [ -f "$item_path" ] || continue
    local item_id item_state item_title item_created
    item_id=$(_local_fm_read "$item_path" id); item_state=$(_local_fm_read "$item_path" state)
    item_title=$(_local_fm_read "$item_path" title); item_created=$(_local_fm_read "$item_path" created)
    [ "$state" != "all" ] && [ "$item_state" != "$state" ] && continue
    [ -n "$label" ] && ! _local_fm_read_labels "$item_path" | grep -qxF "$label" && continue
    count=$((count + 1)); [ "$count" -gt "$limit" ] && break
    local state_display
    state_display=$(echo "$item_state" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
    printf "%s\t%s\t%s\t%s\n" "$item_id" "$state_display" "$item_title" "${item_created%%T*}"
  done
}

# pm_update_item <id> [--title <t>] [--body <b>] [--updated-by <agent>]
pm_update_item() {
  local item_id="$1"; shift
  local item_path; item_path=$(_local_item_path "$item_id")
  [ ! -f "$item_path" ] && { echo "ERROR: pm_update_item: item $item_id not found" >&2; return 1; }
  local new_title="" new_body="" updated_by=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title) new_title="$2"; shift 2 ;; --body) new_body="$2"; shift 2 ;;
      --updated-by) updated_by="$2"; shift 2 ;;
      *) echo "ERROR: pm_update_item: unknown option '$1'" >&2; return 1 ;;
    esac
  done
  if [ -n "$new_title" ]; then _local_fm_write "$item_path" title "\"$new_title\""; fi
  if [ -n "$new_body" ]; then _local_write_body "$item_path" "$new_body"; fi
  _local_fm_write "$item_path" updated "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  { [ -n "$updated_by" ] && _local_fm_write "$item_path" updated_by "$updated_by"; } || true
}

# pm_append_body <item-id> <content> [--updated-by <agent>]
# Appends content to the body section of an item file.
# If an Activity Log separator exists (─────────), inserts before it.
# Otherwise appends to end of file.
pm_append_body() {
  local item_id="$1" content="$2"; shift 2
  local updated_by=""
  while [[ $# -gt 0 ]]; do
    case "$1" in --updated-by) updated_by="$2"; shift 2 ;; *) shift ;; esac
  done
  local item_path; item_path=$(_local_item_path "$item_id")
  [ ! -f "$item_path" ] && { echo "ERROR: pm_append_body: item $item_id not found" >&2; return 1; }

  # Check if Activity Log separator exists
  if grep -q '─────────' "$item_path"; then
    # Insert content before the separator line
    local sep_line
    sep_line=$(grep -n '─────────' "$item_path" | head -1 | cut -d: -f1)
    {
      head -n "$((sep_line - 1))" "$item_path"
      printf '\n%s\n' "$content"
      tail -n +"$sep_line" "$item_path"
    } > "${item_path}.tmp" && mv "${item_path}.tmp" "$item_path"
  else
    # No Activity Log — append to end of file
    printf '\n%s\n' "$content" >> "$item_path"
  fi
  _local_fm_write "$item_path" updated "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  { [ -n "$updated_by" ] && _local_fm_write "$item_path" updated_by "$updated_by"; } || true
}

# pm_close_item <id> — sets state to closed, calls pm_set_status done.
pm_close_item() {
  local item_id="$1"
  local item_path; item_path=$(_local_item_path "$item_id")
  [ ! -f "$item_path" ] && { echo "ERROR: pm_close_item: item $item_id not found" >&2; return 1; }
  _local_fm_write "$item_path" state closed
  if declare -f pm_set_status > /dev/null 2>&1; then pm_set_status "$item_id" done || true; fi
}
