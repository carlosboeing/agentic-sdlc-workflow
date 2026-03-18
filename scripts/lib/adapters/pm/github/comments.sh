#!/usr/bin/env bash
# comments.sh — GitHub PM adapter: comment and telemetry functions.
#
# Provides:
#   pm_add_comment <item-id> <body>    — post a comment on a GitHub issue
#   pm_post_telemetry <item-id> [flags...] — delegate to issue-telemetry.sh
#
# Exported via pm.sh loader. Requires CFG_REPO and REPO_ROOT to be set.
#
# Prefix injection: when _PM_LOADING_EXTERNAL=1 is set before sourcing,
# public pm_* functions are defined as _external_pm_* instead.

# Set function name prefix: empty in normal mode, "_external_" when loading as external adapter
_PM_FN_PREFIX="${_PM_LOADING_EXTERNAL:+_external_}"

# Idempotency guard: check using the prefix-aware function name
if declare -f "${_PM_FN_PREFIX}pm_add_comment" > /dev/null 2>&1; then
  return 0 2>/dev/null || exit 0
fi

# pm_add_comment <item-id> <body>
# Posts a comment on the GitHub issue identified by <item-id>.
eval "${_PM_FN_PREFIX}pm_add_comment() {
  local item_id=\"\$1\"
  local body=\"\$2\"
  gh issue comment \"\$item_id\" --repo \"\$CFG_REPO\" --body \"\$body\"
}"

# pm_post_telemetry <item-id> [flags...]
# Delegates to scripts/issue-telemetry.sh, passing all flags through unchanged.
# Locates issue-telemetry.sh relative to REPO_ROOT.
eval "${_PM_FN_PREFIX}pm_post_telemetry() {
  local item_id=\"\$1\"
  shift
  \"\$REPO_ROOT/scripts/issue-telemetry.sh\" \"\$item_id\" \"\$@\"
}"
