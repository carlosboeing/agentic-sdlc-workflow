#!/usr/bin/env bash
# comments.sh — Local PM adapter: pm_add_comment, pm_post_telemetry.
#
# Provides:
#   pm_add_comment <item-id> <body>       — append comment to item file's
#                                           Activity Log section
#   pm_post_telemetry <item-id> [flags..] — delegate to item-telemetry.sh
#
# Comments are appended inline to .workflow/items/<id>.md with a separator
# line and Activity Log heading. Each comment has a <!-- comment: ISO -->
# marker and a trailing --- separator.
#
# If the item file does not exist, the comment is silently skipped (backward
# compatibility — the item may not have been created locally).
#
# Requires _common.sh (sourced automatically if not already loaded).

# Idempotency guard — prevents double-sourcing
[ -n "${_LOCAL_COMMENTS_LOADED:-}" ] && { return 0 2>/dev/null || exit 0; }
_LOCAL_COMMENTS_LOADED=1

# Auto-source _common.sh if not already loaded
_COMMENTS_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${_LOCAL_COMMON_LOADED:-}" ] && source "$_COMMENTS_SH_DIR/_common.sh"

# --- Private helpers (kept for backward compatibility) ---

# _local_comment_slug <body>
# Derive a lowercase hyphenated slug from the first ### or ## heading in body.
# Falls back to "comment" if no heading is found.
_local_comment_slug() {
  local body="$1"
  local heading
  heading=$(printf '%s' "$body" \
    | grep -m1 '^##\{0,1\}# ' \
    | sed 's/^#* //; s/[^a-zA-Z0-9 ]//g; s/^ *//; s/ *$//' \
    | tr '[:upper:]' '[:lower:]' \
    | tr -s ' ' '-')
  if [ -z "$heading" ]; then
    heading="comment"
  fi
  echo "$heading"
}

# _local_next_comment_seq <item-id>
# Return the next zero-padded three-digit sequence number for item <item-id>.
# Counts existing .md files in the comment directory.
_local_next_comment_seq() {
  local item_id="$1"
  local comment_dir="$_LOCAL_WORKFLOW_DIR/comments/$item_id"
  mkdir -p "$comment_dir"
  local count
  count=$(find "$comment_dir" -maxdepth 1 -name "*.md" | wc -l | tr -d ' ')
  printf "%03d" "$((count + 1))"
}

# --- Activity Log separator ---
# Unicode box-drawing character U+2500, repeated for a visible thick line.
_LOCAL_ACTIVITY_SEPARATOR="─────────────────────────────────────────────────────────────────────────"

# --- pm_add_comment ---
# Usage: pm_add_comment <item-id> <body>
# Appends the comment to the item's .md file under an Activity Log section.
# If the item file does not exist, silently returns 0 (backward compat).
pm_add_comment() {
  local item_id="$1"
  local body="$2"
  _local_ensure_dirs

  local item_path
  item_path=$(_local_item_path "$item_id") || return 0

  # If item file doesn't exist, skip silently
  [ ! -f "$item_path" ] && return 0

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Check if Activity Log separator already exists (at least 10 box-drawing chars)
  if ! grep -q '─────────' "$item_path"; then
    # Append separator + Activity Log heading
    printf '\n%s\n## Activity Log\n' "$_LOCAL_ACTIVITY_SEPARATOR" >> "$item_path"
  fi

  # Append comment with marker and trailing separator
  printf '\n<!-- comment: %s -->\n%s\n\n---\n' "$now" "$body" >> "$item_path"

  # Update the frontmatter `updated:` timestamp
  _local_fm_write "$item_path" updated "$now"
}

# --- pm_post_telemetry ---
# Usage: pm_post_telemetry <item-id> [flags...]
# Delegates to scripts/item-telemetry.sh, passing all flags through unchanged.
# Locates item-telemetry.sh relative to REPO_ROOT.
pm_post_telemetry() {
  local item_id="$1"
  shift
  "$REPO_ROOT/scripts/item-telemetry.sh" "$item_id" "$@"
}
