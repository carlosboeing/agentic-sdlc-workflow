#!/usr/bin/env bash
# _common.sh — Shared helpers for the local PM adapter.
#
# Provides path resolution, frontmatter parsing, ID generation, and
# directory initialization. Sourced by all other local adapter modules.
#
# Usage: source this file; do not execute directly.
# All helpers use $_LOCAL_WORKFLOW_DIR which must be set before sourcing,
# or defaults to "${CFG_LOCAL_WORKFLOW_DIR:-.workflow}" at source time.

# Idempotency guard — prevents double-sourcing
if [ -n "${_LOCAL_COMMON_LOADED:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
_LOCAL_COMMON_LOADED=1

# Resolve the workflow directory. Callers may override via _LOCAL_WORKFLOW_DIR
# (for tests) or CFG_LOCAL_WORKFLOW_DIR (from config.sh).
_LOCAL_WORKFLOW_DIR="${_LOCAL_WORKFLOW_DIR:-${CFG_LOCAL_WORKFLOW_DIR:-.workflow}}"

# --- Directory helpers ---

# _local_ensure_dirs — create items/ and comments/ subdirectories.
_local_ensure_dirs() {
  mkdir -p "$_LOCAL_WORKFLOW_DIR/items" "$_LOCAL_WORKFLOW_DIR/comments"
}

# --- Path helpers ---

# _local_item_path <id> — return the full path to an item file.
_local_item_path() {
  echo "$_LOCAL_WORKFLOW_DIR/items/$1.md"
}

# --- ID generation ---

# _local_next_id — read/increment the _next_id counter file. Returns the
# current ID (before increment) on stdout. Starts at 1 when file is absent.
_local_next_id() {
  local id_file="$_LOCAL_WORKFLOW_DIR/_next_id"
  _local_ensure_dirs
  local current_id=1
  if [ -f "$id_file" ]; then
    current_id=$(cat "$id_file")
  fi
  echo "$((current_id + 1))" > "$id_file"
  echo "$current_id"
}

# --- Frontmatter read helpers ---

# _local_fm_read <file> <field> — extract a scalar frontmatter value.
# Returns the raw value string (strips surrounding double quotes if present).
_local_fm_read() {
  local file="$1" field="$2"
  # Extract only from the YAML block between first and second ---
  awk '/^---$/{block++; if(block==2) exit; next} block==1 && /^'"$field"':/' "$file" \
    | head -1 \
    | sed "s/^${field}: *//" \
    | sed 's/^"\(.*\)"$/\1/'
}

# _local_fm_read_labels <file> — return the labels array, one label per line.
_local_fm_read_labels() {
  local file="$1"
  # Find the labels: block within frontmatter, collect indented "- value" lines
  awk '
    /^---$/ { block++; if (block == 2) exit; next }
    block != 1 { next }
    /^labels:/ { in_labels=1; next }
    in_labels && /^  - / { print substr($0, 5) }
    in_labels && /^[^ -]/ { in_labels=0 }
  ' "$file"
}

# --- Frontmatter write helpers ---

# _local_fm_write <file> <field> <value> — update a scalar frontmatter field
# and automatically refresh the `updated` timestamp.
# Uses ENVIRON to pass field/value so that backslashes and other metacharacters
# (|, &, \, /) are never interpreted (C1 fix). awk -v processes \-escapes in
# its argument strings; ENVIRON["VAR"] does not.
_local_fm_write() {
  local file="$1" field="$2" value="$3"
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  _FM_FIELD="$field" _FM_VALUE="$value" _FM_TS="$now" \
  awk '
    BEGIN { fld=ENVIRON["_FM_FIELD"]; val=ENVIRON["_FM_VALUE"]; ts=ENVIRON["_FM_TS"] }
    $0 ~ ("^" fld ":") { print fld ": " val; next }
    /^updated:/         { print "updated: " ts; next }
    { print }
  ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

# _local_fm_append_label <file> <label> — append a label to the labels array.
# Idempotent: no-op if label already present.
# Handles the edge case where labels: is the last field before closing ---
# by detecting in_labels when block transitions to 2 (C2 fix).
_local_fm_append_label() {
  local file="$1" label="$2"
  # Check for duplicate
  if _local_fm_read_labels "$file" | grep -qxF "$label"; then
    return 0
  fi
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  awk -v lbl="$label" -v ts="$now" '
    /^---$/ {
      block++
      if (block == 2 && in_labels) {
        # labels: block was last field — emit new label before closing ---
        print "  - " lbl
        in_labels=0
      }
      in_front=(block == 1)
      print
      next
    }
    in_front && /^labels:/ { in_labels=1; print; next }
    in_front && in_labels && /^  - / { print; next }
    in_front && in_labels {
      # First non-label-entry line while still in labels block
      print "  - " lbl
      in_labels=0
      print
      next
    }
    /^updated:/ { print "updated: " ts; next }
    { print }
  ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

# --- Body helpers ---

# _local_read_body <file> — return content below the closing --- delimiter.
_local_read_body() {
  local file="$1"
  # Skip everything up to and including the second ---
  awk '/^---$/{count++; if(count==2){found=1; next}} found{print}' "$file"
}

# _local_write_body <file> <body> — replace content below closing --- delimiter.
_local_write_body() {
  local file="$1" body="$2"
  # Extract frontmatter (lines up to and including second ---)
  local frontmatter
  frontmatter=$(awk '/^---$/{count++; print; if(count==2) exit; next} count>=1{print}' "$file")
  # Write frontmatter + blank line + new body
  printf '%s\n\n%s\n' "$frontmatter" "$body" > "$file"
}
