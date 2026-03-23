#!/usr/bin/env bash
# pm.sh — Dual-write PM adapter loader.
#
# Always sources the local adapter (adapters/pm/local/) first. Optionally
# overlays an external adapter (e.g., adapters/pm/github/) with fire-and-forget
# dual-write wrappers. The local adapter is the foundation; the external
# adapter is an optional sync target.
#
# After sourcing:
#   pm_*        — public API (either direct alias to _local_pm_* or dual-write
#                 wrapper when external adapter is configured)
#   _local_pm_* — local adapter functions (always available)
#   _external_pm_* — external adapter functions (when configured)
#
# Exported variables:
#   PM_ADAPTER      — always "local" (local is the primary adapter)
#   PM_ADAPTER_DIR  — absolute path to the local adapter directory
#   PM_EXTERNAL     — external adapter name (e.g., "github"), or "" if none
#   REPO_ROOT       — absolute path to the repository root
#
# Idempotency: sourcing pm.sh multiple times is safe. The guard tracks
# the loaded adapter directory and external adapter name to prevent re-sourcing.
#
# Test override: set _PM_TEST_ADAPTER_DIR to bypass the dual-source loader
# and point directly at a mock adapter directory (preserves existing test
# infrastructure). When set, functions load as bare pm_* — no _local_pm_*
# renaming occurs.

# --- Idempotency guard ---
# When _PM_TEST_ADAPTER_DIR is set, use its value for idempotency tracking.
# Otherwise, track local adapter dir + external adapter name. If the external
# adapter config changes between sourcing calls, the guard detects it and
# re-sources.
_PM_SH_COMPUTED_DIR="${_PM_TEST_ADAPTER_DIR:-}"
_PM_SH_COMPUTED_EXT="${CFG_PM_ADAPTER:-}"

if [ -n "${_PM_SH_LOADED:-}" ] \
   && [ "${_PM_SH_LOADED_DIR:-}" = "$_PM_SH_COMPUTED_DIR" ] \
   && [ "${_PM_SH_LOADED_EXTERNAL:-}" = "$_PM_SH_COMPUTED_EXT" ]; then
  return 0 2>/dev/null || exit 0
fi

# Locate this file and the repo root
_PM_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT
REPO_ROOT="$(cd "$_PM_SCRIPT_DIR/../.." && pwd)"

# =============================================================================
# Test override path: _PM_TEST_ADAPTER_DIR bypasses the dual-source loader
# =============================================================================
if [ -n "${_PM_TEST_ADAPTER_DIR:-}" ]; then
  PM_ADAPTER="test"
  PM_ADAPTER_DIR="$_PM_TEST_ADAPTER_DIR"
  PM_EXTERNAL=""

  export PM_ADAPTER PM_ADAPTER_DIR PM_EXTERNAL

  # Validate test adapter directory exists
  if [ ! -d "$PM_ADAPTER_DIR" ]; then
    echo "ERROR: PM test adapter directory not found: $PM_ADAPTER_DIR" >&2
    return 1 2>/dev/null || exit 1
  fi

  # Validate it contains at least one .sh file
  _PM_MODULES=()
  while IFS= read -r -d '' _f; do
    _PM_MODULES+=("$_f")
  done < <(find -L "$PM_ADAPTER_DIR" -maxdepth 1 -name "*.sh" -print0 | sort -z)

  if [ "${#_PM_MODULES[@]}" -eq 0 ]; then
    echo "ERROR: PM test adapter directory contains no .sh modules: $PM_ADAPTER_DIR" >&2
    return 1 2>/dev/null || exit 1
  fi

  for _PM_MODULE in "${_PM_MODULES[@]}"; do
    # shellcheck disable=SC1090
    source "$_PM_MODULE"
  done

  _PM_SH_LOADED=1
  _PM_SH_LOADED_DIR="$_PM_SH_COMPUTED_DIR"
  _PM_SH_LOADED_EXTERNAL="$_PM_SH_COMPUTED_EXT"
  unset _PM_SCRIPT_DIR _PM_MODULES _PM_MODULE _PM_SH_COMPUTED_DIR _PM_SH_COMPUTED_EXT
  return 0 2>/dev/null || exit 0
fi

# =============================================================================
# Dual-source loader: primary adapter + optional external sync target
# =============================================================================

# Source config to get CFG_PM_ADAPTER
# shellcheck source=scripts/lib/config.sh
source "$_PM_SCRIPT_DIR/config.sh"

# --- Step 1: Source the local adapter ---
# The local PM is the workflow server (SQLite via HTTP API).
# The old file-based adapter (adapters/pm/local/) is retained for tests.
_PM_LOCAL_DIR="$_PM_SCRIPT_DIR/adapters/pm/server"
if [ ! -d "$_PM_LOCAL_DIR" ]; then
  echo "ERROR: Primary PM adapter not found at $_PM_LOCAL_DIR" >&2
  return 1 2>/dev/null || exit 1
fi

_PM_LOCAL_MODULES=()
while IFS= read -r -d '' _f; do
  _PM_LOCAL_MODULES+=("$_f")
done < <(find -L "$_PM_LOCAL_DIR" -maxdepth 1 -name "*.sh" -print0 | sort -z)

if [ "${#_PM_LOCAL_MODULES[@]}" -eq 0 ]; then
  echo "ERROR: Local PM adapter directory contains no .sh modules: $_PM_LOCAL_DIR" >&2
  return 1 2>/dev/null || exit 1
fi

for _PM_MODULE in "${_PM_LOCAL_MODULES[@]}"; do
  # shellcheck disable=SC1090
  source "$_PM_MODULE"
done

# --- Step 2: Capture and rename local pm_* functions to _local_pm_* ---
# Discover all pm_* functions defined by the local adapter, create _local_pm_*
# copies using declare -f + eval, then unset the originals to free the
# namespace for wrappers.
_PM_LOCAL_FUNCTIONS=()
while IFS= read -r _fn; do
  _PM_LOCAL_FUNCTIONS+=("$_fn")
done < <(declare -F | awk '{print $3}' | grep '^pm_')

for _fn in "${_PM_LOCAL_FUNCTIONS[@]}"; do
  # Create _local_pm_* copy: capture function body via declare -f, rename
  # the function name in the first line, and eval the result.
  eval "$(declare -f "$_fn" | sed "1s/^${_fn} /_local_${_fn} /")"
  unset -f "$_fn"
done

# =============================================================================
# Function classification and dual-write wrapper definitions
# =============================================================================

# Functions that are read-only — always local, never dual-written.
_PM_LOCAL_ONLY_FUNCTIONS=(pm_get_item pm_list_items pm_get_status)

# Functions that compose on dual-write primitives — aliased to local only.
# Their local implementations call pm_add_comment / pm_set_status (which ARE
# dual-write wrappers), so the external effects happen through those primitives.
_PM_COMPOSED_FUNCTIONS=(pm_start_work pm_complete_work pm_post_telemetry pm_reconcile)

# _pm_is_local_only <fn_name> — returns 0 if the function should skip external.
_pm_is_local_only() {
  local fn="$1"
  local candidate
  for candidate in "${_PM_LOCAL_ONLY_FUNCTIONS[@]}"; do
    [ "$fn" = "$candidate" ] && return 0
  done
  for candidate in "${_PM_COMPOSED_FUNCTIONS[@]}"; do
    [ "$fn" = "$candidate" ] && return 0
  done
  return 1
}

# _pm_external_fire_and_forget <fn> [args...]
# Runs the external function in the background with stderr redirected to the
# external sync log. The caller does not wait for this to complete.
_pm_external_fire_and_forget() {
  local fn="$1"; shift
  local _sync_log="${REPO_ROOT:-.}/.agentic-workflow/logs/external-sync.log"
  mkdir -p "$(dirname "$_sync_log")" 2>/dev/null || true
  (
    "$fn" "$@" 2>> "$_sync_log"
  ) &
  disown 2>/dev/null || true
}

# _pm_generate_wrapper <fn_name>
# Creates a dual-write wrapper for a single pm_* function. The wrapper calls
# _local_pm_* synchronously, captures the return code, then calls
# _external_pm_* fire-and-forget if it exists. Returns the local return code.
_pm_generate_wrapper() {
  local fn_name="$1"
  eval "${fn_name}() {
    _local_${fn_name} \"\$@\"
    local _local_rc=\$?
    if declare -f _external_${fn_name} > /dev/null 2>&1; then
      _pm_external_fire_and_forget _external_${fn_name} \"\$@\"
    fi
    return \$_local_rc
  }"
}

# _pm_generate_wrappers
# Iterates all local pm_* functions and generates appropriate wrappers:
#   - Local-only / composed functions: alias to _local_pm_*
#   - pm_create_item: special synchronous wrapper (see below)
#   - All other functions: standard dual-write wrapper
_pm_generate_wrappers() {
  local _fn
  for _fn in "${_PM_LOCAL_FUNCTIONS[@]}"; do
    if [ "$_fn" = "pm_create_item" ]; then
      _pm_generate_create_item_wrapper
    elif _pm_is_local_only "$_fn"; then
      eval "${_fn}() { _local_${_fn} \"\$@\"; }"
    else
      _pm_generate_wrapper "$_fn"
    fi
  done
}

# _pm_generate_create_item_wrapper
# Special wrapper for pm_create_item. Unlike other dual-write functions,
# pm_create_item calls the external adapter SYNCHRONOUSLY to obtain the
# external ID (e.g., GitHub issue number), then creates the local item with
# that same ID via _local_pm_create_item_with_id. Returns the external ID.
#
# Fallback: if the external adapter fails, falls back to local-only creation
# with auto-incremented ID and prints a warning.
_pm_generate_create_item_wrapper() {
  eval 'pm_create_item() {
    if [ -n "$PM_EXTERNAL" ] && declare -f _external_pm_create_item > /dev/null 2>&1; then
      local _external_id
      local _sync_log="${REPO_ROOT:-.}/.agentic-workflow/logs/external-sync.log"
      mkdir -p "$(dirname "$_sync_log")" 2>/dev/null || true
      if _external_id=$(_external_pm_create_item "$@" 2>>"$_sync_log"); then
        _local_pm_create_item_with_id "$_external_id" "$@" > /dev/null
        echo "$_external_id"
      else
        echo "WARNING: External pm_create_item failed. Falling back to local-only." >&2
        _local_pm_create_item "$@"
      fi
    else
      _local_pm_create_item "$@"
    fi
  }'
}

# --- Step 3: Determine sync target ---
# pm.adapter names the remote to sync to (e.g., "github").
PM_EXTERNAL="${CFG_PM_ADAPTER:-}"
PM_ADAPTER="local"
PM_ADAPTER_DIR="$_PM_LOCAL_DIR"

# Handle external adapter directory lookup
if [ -n "$PM_EXTERNAL" ]; then
  _PM_EXTERNAL_DIR="$_PM_SCRIPT_DIR/adapters/pm/$PM_EXTERNAL"
  if [ ! -d "$_PM_EXTERNAL_DIR" ]; then
    echo "WARNING: External PM adapter '$PM_EXTERNAL' not found at $_PM_EXTERNAL_DIR. Running local-only." >&2
    PM_EXTERNAL=""
  fi
fi

if [ -n "$PM_EXTERNAL" ]; then
  # --- Step 3a: Source external adapter with _PM_LOADING_EXTERNAL=1 ---
  # External adapter modules use prefix injection: when _PM_LOADING_EXTERNAL
  # is set, they define functions as _external_pm_* instead of pm_*.
  _PM_LOADING_EXTERNAL=1
  export _PM_LOADING_EXTERNAL

  _PM_EXT_MODULES=()
  while IFS= read -r -d '' _f; do
    _PM_EXT_MODULES+=("$_f")
  done < <(find -L "$_PM_EXTERNAL_DIR" -maxdepth 1 -name "*.sh" -print0 | sort -z)

  for _PM_MODULE in "${_PM_EXT_MODULES[@]}"; do
    # shellcheck disable=SC1090
    source "$_PM_MODULE"
  done

  unset _PM_LOADING_EXTERNAL

  # --- Step 3b: Generate dual-write wrappers ---
  _pm_generate_wrappers
else
  # --- No external adapter: pm_* aliases directly to _local_pm_* ---
  for _fn in "${_PM_LOCAL_FUNCTIONS[@]}"; do
    eval "${_fn}() { _local_${_fn} \"\$@\"; }"
  done
fi

export PM_ADAPTER PM_ADAPTER_DIR PM_EXTERNAL

# Mark as loaded (tracks both adapter dir and external adapter name)
_PM_SH_LOADED=1
_PM_SH_LOADED_DIR="$_PM_SH_COMPUTED_DIR"
_PM_SH_LOADED_EXTERNAL="$_PM_SH_COMPUTED_EXT"

# Cleanup internal variables (classification arrays and helpers are kept)
unset _PM_SCRIPT_DIR _PM_LOCAL_DIR _PM_LOCAL_MODULES _PM_MODULE
unset _fn _PM_SH_COMPUTED_DIR _PM_SH_COMPUTED_EXT
unset _PM_EXTERNAL_DIR _PM_EXT_MODULES 2>/dev/null || true
