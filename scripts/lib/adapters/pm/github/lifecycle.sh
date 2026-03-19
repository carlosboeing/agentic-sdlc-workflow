#!/usr/bin/env bash
# lifecycle.sh — GitHub PM adapter: work lifecycle functions.
#
# Provides:
#   pm_start_work <item-id> [--model <m>] [--agent <a>]
#     Posts a "Work Started" comment and sets board to In Progress.
#   pm_complete_work <item-id> <commit-hash>
#     Posts a "Ready for Review" comment and sets board to In Review.
#
# Both functions compose pm_add_comment and pm_set_status — no direct gh calls.
# Prefix injection: when _PM_LOADING_EXTERNAL=1 is set before sourcing, public
# pm_* functions are defined as _external_pm_*; cross-function calls also use the
# prefix so _external_pm_start_work calls _external_pm_add_comment (not wrapper).

# Set function name prefix: empty in normal mode, "_external_" as external adapter
_PM_FN_PREFIX="${_PM_LOADING_EXTERNAL:+_external_}"

# Idempotency guard: check using the prefix-aware function name
if declare -f "${_PM_FN_PREFIX}pm_start_work" > /dev/null 2>&1; then
  return 0 2>/dev/null || exit 0
fi

# pm_start_work <item-id> [--model <m>] [--agent <a>]
# Posts "Work Started" comment (byte-identical to item-start.sh) and sets
# board status to in-progress.
eval "${_PM_FN_PREFIX}pm_start_work() {
  local item_id=\"\$1\"
  shift
  local model=\"unknown\" agent=\"unknown\"

  while [ \$# -gt 0 ]; do
    case \"\$1\" in
      --model) model=\"\$2\"; shift 2 ;;
      --agent) agent=\"\$2\"; shift 2 ;;
      *) echo \"Unknown option: \$1\" >&2; return 1 ;;
    esac
  done

  local timestamp
  timestamp=\$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")

  ${_PM_FN_PREFIX}pm_add_comment \"\$item_id\" \"\$(cat <<EOF
### 🚀 Work Started

| Field | Value |
|-------|-------|
| **Agent** | \$agent |
| **Model** | \$model |
| **Started** | \$timestamp |
EOF
)\"

  ${_PM_FN_PREFIX}pm_set_status \"\$item_id\" in-progress \
    || echo \"Warning: Board status update failed for #\$item_id\" >&2
}"

# pm_complete_work <item-id> <commit-hash>
# Posts "Ready for Review" comment (byte-identical to item-review.sh) and
# sets board status to in-review.
eval "${_PM_FN_PREFIX}pm_complete_work() {
  local item_id=\"\$1\"
  local commit_hash=\"\$2\"

  local timestamp
  timestamp=\$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")

  ${_PM_FN_PREFIX}pm_add_comment \"\$item_id\" \"\$(cat <<EOF
### 👀 Ready for Review

| Field | Value |
|-------|-------|
| **Commit** | \$commit_hash |
| **Completed** | \$timestamp |
EOF
)\"

  ${_PM_FN_PREFIX}pm_set_status \"\$item_id\" in-review \
    || echo \"Warning: Board status update failed for #\$item_id\" >&2
}"
