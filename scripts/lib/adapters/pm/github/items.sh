#!/usr/bin/env bash
# items.sh — GitHub adapter: item CRUD functions for the PM abstraction layer.
#
# Provides: pm_create_item, pm_get_item, pm_list_items, pm_done
#
# All functions use $CFG_REPO from the sourced config. Sourced by pm.sh;
# do not execute directly.
#
# Level → hierarchy label mapping:
#   backlog → hierarchy/backlog
#   epic    → hierarchy/epic
#   story   → hierarchy/story
#   docs    → hierarchy/docs

# --- pm_create_item ---
# Usage: pm_create_item <level> <title> [--body <text>] [--body-file <path>] [--labels <csv>]
# Prints the created issue number on stdout (just the number).
pm_create_item() {
  local level="$1"
  local title="$2"
  shift 2

  # Map level to hierarchy label
  local hier_label
  case "$level" in
    backlog) hier_label="hierarchy/backlog" ;;
    epic)    hier_label="hierarchy/epic"    ;;
    story)   hier_label="hierarchy/story"   ;;
    docs)    hier_label="hierarchy/docs"    ;;
    *)
      echo "ERROR: pm_create_item: unknown level '$level'. Expected: backlog, epic, story, docs" >&2
      return 1
      ;;
  esac

  local body="" body_file="" extra_labels=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --body)       body="$2";        shift 2 ;;
      --body-file)  body_file="$2";   shift 2 ;;
      --labels)     extra_labels="$2"; shift 2 ;;
      *)
        echo "ERROR: pm_create_item: unknown option '$1'" >&2
        return 1
        ;;
    esac
  done

  # Build label list: hierarchy label + any extra CSV labels
  local all_labels="$hier_label"
  if [ -n "$extra_labels" ]; then
    # Convert CSV to comma-separated, appending to hierarchy label
    all_labels="${hier_label},${extra_labels}"
  fi

  local create_args=(gh issue create --repo "$CFG_REPO" --title "$title" --label "$all_labels")

  if [ -n "$body_file" ]; then
    create_args+=(--body-file "$body_file")
  elif [ -n "$body" ]; then
    create_args+=(--body "$body")
  fi

  local issue_url
  issue_url=$("${create_args[@]}") || return 1

  # Extract and print just the issue number
  echo "$issue_url" | grep -oE '[0-9]+$'
}

# --- pm_get_item ---
# Usage: pm_get_item <item-id> [--json <fields>]
# Without --json: human-readable output (title, state, labels).
# With --json <fields>: raw JSON from gh issue view.
pm_get_item() {
  local item_id="$1"
  shift

  local json_fields=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json_fields="$2"; shift 2 ;;
      *)
        echo "ERROR: pm_get_item: unknown option '$1'" >&2
        return 1
        ;;
    esac
  done

  if [ -n "$json_fields" ]; then
    gh issue view "$item_id" --repo "$CFG_REPO" --json "$json_fields"
  else
    gh issue view "$item_id" --repo "$CFG_REPO"
  fi
}

# --- pm_list_items ---
# Usage: pm_list_items [--label <label>] [--state <open|closed|all>] [--limit <n>]
# Defaults: --state open, --limit 30
pm_list_items() {
  local label="" state="open" limit="30"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --label) label="$2";  shift 2 ;;
      --state) state="$2";  shift 2 ;;
      --limit) limit="$2";  shift 2 ;;
      *)
        echo "ERROR: pm_list_items: unknown option '$1'" >&2
        return 1
        ;;
    esac
  done

  local list_args=(gh issue list --repo "$CFG_REPO" --state "$state" --limit "$limit")

  if [ -n "$label" ]; then
    list_args+=(--label "$label")
  fi

  "${list_args[@]}"
}

# --- pm_update_item ---
# Usage: pm_update_item <item-id> [--title <text>] [--body <text>]
# Updates title and/or body of a GitHub issue.
pm_update_item() {
  local item_id="$1"
  shift

  local title="" body=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title) title="$2"; shift 2 ;;
      --body)  body="$2";  shift 2 ;;
      *)
        echo "ERROR: pm_update_item: unknown option '$1'" >&2
        return 1
        ;;
    esac
  done

  local edit_args=(gh issue edit "$item_id" --repo "$CFG_REPO")
  if [ -n "$title" ]; then
    edit_args+=(--title "$title")
  fi
  if [ -n "$body" ]; then
    edit_args+=(--body "$body")
  fi

  "${edit_args[@]}" > /dev/null
}

# --- pm_done ---
# Usage: pm_done <item-id>
# Closes the GitHub issue (with --reason completed) and sets board status to Done.
# Handles already-closed issues gracefully (no error).
# Calls pm_set_status for the board transition (available when modules sourced together).
pm_done() {
  local item_id="$1"

  # Close the issue; suppress errors for already-closed issues
  gh issue close "$item_id" --repo "$CFG_REPO" --reason completed 2>/dev/null || true

  # Update board status to Done via the sibling adapter function
  if declare -f pm_set_status > /dev/null 2>&1; then
    pm_set_status "$item_id" done || true
  fi
}
