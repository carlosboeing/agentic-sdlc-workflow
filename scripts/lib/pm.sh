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
# Dual-source loader: always local, optionally external
# =============================================================================

# Source config to get CFG_PM_ADAPTER
# shellcheck source=scripts/lib/config.sh
source "$_PM_SCRIPT_DIR/config.sh"

# --- Step 1: Always source the local adapter ---
_PM_LOCAL_DIR="$_PM_SCRIPT_DIR/adapters/pm/local"
if [ ! -d "$_PM_LOCAL_DIR" ]; then
  echo "ERROR: Local PM adapter not found at $_PM_LOCAL_DIR" >&2
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

# --- Step 3: Determine external adapter ---
PM_EXTERNAL="${CFG_PM_ADAPTER:-}"
PM_ADAPTER="local"
PM_ADAPTER_DIR="$_PM_LOCAL_DIR"

# Handle pm.adapter = "local" (deprecated — local is now always-on)
if [ "$PM_EXTERNAL" = "local" ]; then
  echo "NOTE: pm.adapter='local' is deprecated. Local adapter is now always-on." >&2
  echo "  To run local-only, remove pm.adapter or set it to null." >&2
  echo "  To sync to GitHub, set pm.adapter to 'github'." >&2
  PM_EXTERNAL=""
fi

# Handle pm.adapter = "github" (default from config.sh) or other external adapter
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

  # --- Step 3b: Placeholder for dual-write wrapper generation (E02-S02) ---
  # E02-S02 will add _pm_generate_wrappers here. For now, when an external
  # adapter IS configured, pm_* functions alias directly to _local_pm_*
  # (same as no-external mode). The external functions are available as
  # _external_pm_* for explicit use but are not called by the wrappers yet.
  for _fn in "${_PM_LOCAL_FUNCTIONS[@]}"; do
    eval "${_fn}() { _local_${_fn} \"\$@\"; }"
  done
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

# Cleanup internal variables
unset _PM_SCRIPT_DIR _PM_LOCAL_DIR _PM_LOCAL_MODULES _PM_MODULE
unset _PM_LOCAL_FUNCTIONS _fn _PM_SH_COMPUTED_DIR _PM_SH_COMPUTED_EXT
unset _PM_EXTERNAL_DIR _PM_EXT_MODULES 2>/dev/null || true
