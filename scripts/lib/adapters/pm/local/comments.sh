#!/usr/bin/env bash
# comments.sh — Local PM adapter: pm_add_comment, pm_post_telemetry.
#
# Provides:
#   pm_add_comment <item-id> <body>       — write a comment file under
#                                           .workflow/comments/<id>/
#   pm_post_telemetry <item-id> [flags..] — delegate to issue-telemetry.sh
#
# Comment files are named <NNN>-<slug>.md with a <!-- posted: ISO --> header.
# Requires _common.sh (sourced automatically if not already loaded).

# Idempotency guard — prevents double-sourcing
[ -n "${_LOCAL_COMMENTS_LOADED:-}" ] && { return 0 2>/dev/null || exit 0; }
_LOCAL_COMMENTS_LOADED=1

# Auto-source _common.sh if not already loaded
_COMMENTS_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${_LOCAL_COMMON_LOADED:-}" ] && source "$_COMMENTS_SH_DIR/_common.sh"

# --- Private helpers ---

# _local_comment_slug <body>
# Derive a lowercase hyphenated slug from the first ### or ## heading in body.
# Falls back to "comment" if no heading is found.
_local_comment_slug() {
  local body="$1"
  local heading
  heading=$(printf '%s' "$body" \
    | grep -m1 '^##\{0,1\}# ' \
    | sed 's/^#* //; s/[^a-zA-Z0-9 ]//g' \
    | tr '[:upper:]' '[:lower:]' \
    | tr ' ' '-')
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

# --- pm_add_comment ---
# Usage: pm_add_comment <item-id> <body>
# Creates .workflow/comments/<item-id>/<NNN>-<slug>.md with:
#   Line 1: <!-- posted: <ISO 8601> -->
#   Remaining lines: raw body content
pm_add_comment() {
  local item_id="$1"
  local body="$2"
  _local_ensure_dirs

  local seq slug comment_path now
  seq=$(_local_next_comment_seq "$item_id")
  slug=$(_local_comment_slug "$body")
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  comment_path="$_LOCAL_WORKFLOW_DIR/comments/$item_id/${seq}-${slug}.md"

  printf '<!-- posted: %s -->\n\n%s\n' "$now" "$body" > "$comment_path"
}

# --- pm_post_telemetry ---
# Usage: pm_post_telemetry <item-id> [flags...]
# Delegates to scripts/issue-telemetry.sh, passing all flags through unchanged.
# Locates issue-telemetry.sh relative to REPO_ROOT.
pm_post_telemetry() {
  local item_id="$1"
  shift
  "$REPO_ROOT/scripts/issue-telemetry.sh" "$item_id" "$@"
}
