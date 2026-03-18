#!/usr/bin/env bash
# labels.sh — GitHub adapter: issue label management.
#
# Functions:
#   pm_add_label <issue-number> <label> [--create-if-missing] [--color <hex>] [--description <text>]
#     Applies a label to a GitHub issue.
#
#     Without --create-if-missing: adds the label (fails if label does not exist).
#     With --create-if-missing: creates the label first (idempotent via --force),
#       then adds it to the issue.
#
#     --color defaults to "5319E7" (deep purple, used for backlog/* labels).
#     Requires CFG_REPO (e.g., "owner/repo") to be set.
#
# Prefix injection: when _PM_LOADING_EXTERNAL=1 is set before sourcing,
# public pm_* functions are defined as _external_pm_* instead.

# Set function name prefix: empty in normal mode, "_external_" when loading as external adapter
_PM_FN_PREFIX="${_PM_LOADING_EXTERNAL:+_external_}"

# Idempotency guard: check using the prefix-aware function name
if declare -f "${_PM_FN_PREFIX}pm_add_label" > /dev/null 2>&1; then
  return 0 2>/dev/null || exit 0
fi

eval "${_PM_FN_PREFIX}pm_add_label() {
  local item_id=\"\$1\"
  local label=\"\$2\"
  shift 2

  local create_if_missing=0
  local color=\"5319E7\"
  local description=\"\"

  while [ \"\$#\" -gt 0 ]; do
    case \"\$1\" in
      --create-if-missing) create_if_missing=1 ;;
      --color)             color=\"\$2\"; shift ;;
      --description)       description=\"\$2\"; shift ;;
      *) echo \"ERROR: Unknown option: \$1\" >&2; return 1 ;;
    esac
    shift
  done

  if [ \"\$create_if_missing\" -eq 1 ]; then
    gh label create \"\$label\" \
      --repo \"\$CFG_REPO\" \
      --color \"\$color\" \
      --description \"\$description\" \
      --force
  fi

  gh issue edit \"\$item_id\" \
    --repo \"\$CFG_REPO\" \
    --add-label \"\$label\"
}"
