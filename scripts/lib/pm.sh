#!/usr/bin/env bash
# pm.sh — PM Abstraction Layer adapter loader.
#
# Sources the configured PM adapter modules from scripts/lib/adapters/pm/<adapter>/.
# All *.sh files in the adapter directory are sourced in alphabetical order.
# After sourcing, all pm_* functions from the adapter are available to the caller.
#
# Usage (from any script):
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/lib/pm.sh"
#   pm_start_work 123 --model sonnet --agent builder
#
# Exported variables available to adapter modules:
#   PM_ADAPTER      — active adapter name (e.g., "github")
#   PM_ADAPTER_DIR  — absolute path to active adapter directory
#   REPO_ROOT       — absolute path to the repository root
#
# Idempotency: sourcing pm.sh multiple times is safe. The guard variable
# _PM_SH_LOADED prevents double-sourcing of this loader. Individual adapter
# modules may implement their own guards (e.g., using declare -f checks).
#
# Test override: set _PM_TEST_ADAPTER_DIR to bypass config-based adapter
# resolution and point directly at a mock adapter directory.

# Idempotency guard — skip if already loaded with same adapter dir
_PM_SH_COMPUTED_DIR="${_PM_TEST_ADAPTER_DIR:-}"

if [ -n "${_PM_SH_LOADED:-}" ] && [ "${_PM_SH_LOADED_DIR:-}" = "$_PM_SH_COMPUTED_DIR" ]; then
  return 0 2>/dev/null || exit 0
fi

# Locate this file and the repo root
_PM_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT
REPO_ROOT="$(cd "$_PM_SCRIPT_DIR/../.." && pwd)"

# Source config to get CFG_PM_ADAPTER (unless test override is active)
if [ -z "${_PM_TEST_ADAPTER_DIR:-}" ]; then
  # shellcheck source=scripts/lib/config.sh
  source "$_PM_SCRIPT_DIR/config.sh"
  PM_ADAPTER="${CFG_PM_ADAPTER:-github}"
  PM_ADAPTER_DIR="$_PM_SCRIPT_DIR/adapters/pm/$PM_ADAPTER"
else
  # Test mode: use the injected directory directly
  PM_ADAPTER="test"
  PM_ADAPTER_DIR="$_PM_TEST_ADAPTER_DIR"
fi

export PM_ADAPTER
export PM_ADAPTER_DIR

# Validate adapter directory exists
if [ ! -d "$PM_ADAPTER_DIR" ]; then
  echo "ERROR: PM adapter directory not found: $PM_ADAPTER_DIR" >&2
  echo "  Adapter: $PM_ADAPTER" >&2
  echo "  Expected at: $PM_ADAPTER_DIR" >&2
  return 1 2>/dev/null || exit 1
fi

# Validate adapter directory contains at least one .sh file
_PM_MODULES=()
while IFS= read -r -d '' _f; do
  _PM_MODULES+=("$_f")
done < <(find "$PM_ADAPTER_DIR" -maxdepth 1 -name "*.sh" -print0 | sort -z)

if [ "${#_PM_MODULES[@]}" -eq 0 ]; then
  echo "ERROR: PM adapter directory contains no .sh modules: $PM_ADAPTER_DIR" >&2
  return 1 2>/dev/null || exit 1
fi

# Source all adapter modules in alphabetical order
for _PM_MODULE in "${_PM_MODULES[@]}"; do
  # shellcheck disable=SC1090
  source "$_PM_MODULE"
done

# Mark as loaded (store the resolved adapter dir for idempotency check)
_PM_SH_LOADED=1
_PM_SH_LOADED_DIR="$_PM_SH_COMPUTED_DIR"

unset _PM_SCRIPT_DIR _PM_MODULES _PM_MODULE _PM_SH_COMPUTED_DIR
