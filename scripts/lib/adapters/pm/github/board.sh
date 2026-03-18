#!/usr/bin/env bash
# board.sh — GitHub adapter: board management functions.
#
# Provides pm_set_status, pm_add_to_board, pm_batch_set_status and internal
# helpers for GitHub Projects v2. Ported from issue-set-status.sh and
# batch-set-status.sh. Reconciliation (pm_reconcile) is in reconcile.sh.
# All logging goes to .agentic-workflow/logs/board-status.log.
#
# Prefix injection: when _PM_LOADING_EXTERNAL=1 is set before sourcing,
# public pm_* functions are defined as _external_pm_* instead.

_BOARD_LOG_DIR="${REPO_ROOT:-.}/.agentic-workflow/logs"
_BOARD_LOG_FILE="$_BOARD_LOG_DIR/board-status.log"
mkdir -p "$_BOARD_LOG_DIR" 2>/dev/null || true

# Set function name prefix: empty in normal mode, "_external_" when loading as external adapter
_PM_FN_PREFIX="${_PM_LOADING_EXTERNAL:+_external_}"

# Idempotency guard: check using the prefix-aware function name
if declare -f "${_PM_FN_PREFIX}pm_set_status" > /dev/null 2>&1; then
  return 0 2>/dev/null || exit 0
fi

_board_log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$_BOARD_LOG_FILE" 2>/dev/null || true
}

# Maps status name to GitHub project option ID from CFG_STATUS_* config vars.
_gh_status_to_option_id() {
  case "$1" in
    backlog)     echo "$CFG_STATUS_BACKLOG" ;;
    ready)       echo "$CFG_STATUS_READY" ;;
    in-progress) echo "$CFG_STATUS_IN_PROGRESS" ;;
    in-review)   echo "$CFG_STATUS_IN_REVIEW" ;;
    done)        echo "$CFG_STATUS_DONE" ;;
    *) echo "ERROR: Unknown status '$1'" >&2; return 1 ;;
  esac
}

# Maps status name to display name (e.g., "in-progress" -> "In Progress").
_gh_status_to_display() {
  case "$1" in
    backlog)     echo "Backlog" ;;
    ready)       echo "Ready" ;;
    in-progress) echo "In Progress" ;;
    in-review)   echo "In Review" ;;
    done)        echo "Done" ;;
    *) echo "ERROR: Unknown status '$1'" >&2; return 1 ;;
  esac
}

# Lightweight per-issue GraphQL query (~1 point). Returns JSON.
_gh_fetch_item_info() {
  local n="$1"
  gh api graphql -f query="query {
    repository(owner: \"$CFG_REPO_OWNER\", name: \"$CFG_REPO_NAME\") {
      issue(number: $n) {
        projectItems(first: 5) { nodes { id
          fieldValueByName(name: \"Status\") {
            ... on ProjectV2ItemFieldSingleSelectValue { name }
          }
        } }
      }
    }
  }" 2>/dev/null
}

# Parses GraphQL response. Sets ITEM_ID and CURRENT_STATUS in caller scope.
_gh_extract_item_info() {
  local data="$1"
  ITEM_ID=$(echo "$data" | jq -r '.data.repository.issue.projectItems.nodes[0].id // empty' 2>/dev/null) || ITEM_ID=""
  CURRENT_STATUS=$(echo "$data" | jq -r '.data.repository.issue.projectItems.nodes[0].fieldValueByName.name // "unknown"' 2>/dev/null) || CURRENT_STATUS="unknown"
}

# Performs gh project item-edit mutation.
_gh_mutate_status() {
  gh project item-edit --project-id "$CFG_PROJECT_ID" --id "$1" \
    --field-id "$CFG_STATUS_FIELD_ID" --single-select-option-id "$2" 2>&1
}

# Re-fetches status after mutation and logs discrepancies.
_gh_verify_status() {
  local issue_number="$1" expected_display="$2" verify_result actual_status
  verify_result=$(_gh_fetch_item_info "$issue_number" 2>/dev/null) || verify_result=""
  if [ -n "$verify_result" ]; then
    actual_status=$(echo "$verify_result" | jq -r '.data.repository.issue.projectItems.nodes[0].fieldValueByName.name // empty' 2>/dev/null) || actual_status=""
  else
    actual_status=""
  fi
  if [ -z "$actual_status" ]; then
    _board_log "VERIFY issue=$issue_number UNAVAILABLE"
    echo "✓ #$issue_number → status set"
  elif [ "$actual_status" = "$expected_display" ]; then
    _board_log "VERIFY issue=$issue_number OK actual=$actual_status"
    echo "✓ #$issue_number → $(echo "$expected_display" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
  else
    _board_log "VERIFY issue=$issue_number MISMATCH expected=$expected_display actual=$actual_status"
    echo "⚠ #$issue_number → status set (verify mismatch: actual=$actual_status)" >&2
  fi
}

# Fetches item info with 3-second retry on not-found. Sets ITEM_ID/CURRENT_STATUS.
_gh_fetch_with_retry() {
  local issue_number="$1" query_result
  query_result=$(_gh_fetch_item_info "$issue_number") || query_result=""
  _gh_extract_item_info "$query_result"
  if [ -z "$ITEM_ID" ] || [ "$ITEM_ID" = "null" ]; then
    _board_log "issue=$issue_number item_id=NOT_FOUND retrying_in_3s"
    sleep 3
    query_result=$(_gh_fetch_item_info "$issue_number") || query_result=""
    _gh_extract_item_info "$query_result"
  fi
}

# pm_set_status <issue-number> <status> — Sets board status with retry,
# verification, and logging. Full port of issue-set-status.sh.
eval "${_PM_FN_PREFIX}pm_set_status() {
  if [ \$# -lt 2 ]; then
    echo \"Usage: ${_PM_FN_PREFIX}pm_set_status <issue-number> <status>\" >&2
    return 1
  fi
  local issue_number=\"\$1\" status=\"\$2\" option_id status_display
  option_id=\$(_gh_status_to_option_id \"\$status\") || return 1
  status_display=\$(_gh_status_to_display \"\$status\") || return 1
  _board_log \"issue=\$issue_number status=\$status START caller_pid=\$\$\"

  _gh_fetch_with_retry \"\$issue_number\"
  if [ -z \"\$ITEM_ID\" ] || [ \"\$ITEM_ID\" = \"null\" ]; then
    _board_log \"issue=\$issue_number status=\$status item_id=NOT_FOUND FAILED\"
    echo \"ERROR: Could not find board item for issue #\$issue_number\" >&2
    return 1
  fi
  _board_log \"issue=\$issue_number status=\$status item_id=\$ITEM_ID current=\$CURRENT_STATUS\"

  if [ \"\$CURRENT_STATUS\" = \"\$status_display\" ]; then
    _board_log \"issue=\$issue_number status=\$status SKIP already_at=\$status_display\"
    echo \"✓ #\$issue_number already at \$status\"; return 0
  fi

  local mutation_output mutation_exit=0
  mutation_output=\$(_gh_mutate_status \"\$ITEM_ID\" \"\$option_id\") || mutation_exit=\$?
  _board_log \"issue=\$issue_number status=\$status MUTATION exit=\$mutation_exit\"
  if [ \"\$mutation_exit\" -ne 0 ]; then
    echo \"ERROR: Failed to set #\$issue_number to \$status\" >&2; return 1
  fi
  sleep 1
  _gh_verify_status \"\$issue_number\" \"\$status_display\"
}"

# pm_add_to_board <issue-number> — Adds issue to project board.
eval "${_PM_FN_PREFIX}pm_add_to_board() {
  if [ \$# -lt 1 ]; then
    echo \"Usage: ${_PM_FN_PREFIX}pm_add_to_board <issue-number>\" >&2; return 1
  fi
  local issue_number=\"\$1\"
  local url=\"https://github.com/\$CFG_REPO_OWNER/\$CFG_REPO_NAME/issues/\$issue_number\"
  _board_log \"issue=\$issue_number ADD_TO_BOARD START\"
  local out
  if out=\$(gh project item-add \"\$CFG_PROJECT_NUMBER\" --owner \"\$CFG_PROJECT_OWNER\" \
    --url \"\$url\" --format json 2>&1); then
    _board_log \"issue=\$issue_number ADD_TO_BOARD OK\"
    echo \"✓ #\$issue_number added to board\"
  else
    _board_log \"issue=\$issue_number ADD_TO_BOARD FAILED response=\$(echo \"\$out\" | head -c 200)\"
    echo \"ERROR: Failed to add #\$issue_number to board\" >&2; return 1
  fi
}"

# pm_batch_set_status <issue>:<status> [...] — Full port of batch-set-status.sh.
# Fetch-all, mutate-sequentially, verify-once.
eval "${_PM_FN_PREFIX}pm_batch_set_status() {
  if [ \$# -lt 1 ]; then
    echo \"Usage: ${_PM_FN_PREFIX}pm_batch_set_status <issue>:<status> [...]\" >&2; return 1
  fi
  local -a issues=() statuses=() option_ids=() displays=()
  local pair issue status oid disp
  for pair in \"\$@\"; do
    issue=\"\${pair%%:*}\"; status=\"\${pair##*:}\"
    if [ -z \"\$issue\" ] || [ -z \"\$status\" ] || [ \"\$issue\" = \"\$pair\" ]; then
      echo \"ERROR: Invalid pair '\$pair'. Expected: <issue>:<status>\" >&2; return 1
    fi
    oid=\$(_gh_status_to_option_id \"\$status\") || return 1
    disp=\$(_gh_status_to_display \"\$status\") || return 1
    issues+=(\"\$issue\"); statuses+=(\"\$status\"); option_ids+=(\"\$oid\"); displays+=(\"\$disp\")
  done
  local total=\${#issues[@]}
  _board_log \"batch START pairs=\$total caller_pid=\$\$\"

  # Phase 1: Fetch current status for all issues
  local -a item_ids=() currents=()
  local i result
  for i in \"\${!issues[@]}\"; do
    _board_log \"batch FETCH issue=\${issues[\$i]}\"
    _gh_fetch_with_retry \"\${issues[\$i]}\"
    item_ids+=(\"\$ITEM_ID\"); currents+=(\"\$CURRENT_STATUS\")
    _board_log \"batch FETCH issue=\${issues[\$i]} item_id=\$ITEM_ID current=\$CURRENT_STATUS\"
  done

  # Phase 2: Mutate sequentially (skip already-correct)
  local failed=0 mout
  for i in \"\${!issues[@]}\"; do
    if [ -z \"\${item_ids[\$i]}\" ] || [ \"\${item_ids[\$i]}\" = \"null\" ]; then
      _board_log \"batch MUTATION issue=\${issues[\$i]} NOT_ON_BOARD FAILED\"
      echo \"ERROR: Issue #\${issues[\$i]} not found on project board\" >&2
      failed=\$((failed + 1)); continue
    fi
    if [ \"\${currents[\$i]}\" = \"\${displays[\$i]}\" ]; then
      _board_log \"batch SKIP issue=\${issues[\$i]} already_at=\${displays[\$i]}\"
      echo \"✓ #\${issues[\$i]} already at \${statuses[\$i]}\"; continue
    fi
    _board_log \"batch MUTATION issue=\${issues[\$i]} target=\${displays[\$i]}\"
    if mout=\$(_gh_mutate_status \"\${item_ids[\$i]}\" \"\${option_ids[\$i]}\"); then
      _board_log \"batch MUTATION issue=\${issues[\$i]} exit=0\"
    else
      _board_log \"batch MUTATION issue=\${issues[\$i]} exit=\$?\"
      echo \"ERROR: Failed to set #\${issues[\$i]} to \${statuses[\$i]}\" >&2
      failed=\$((failed + 1))
    fi
  done

  # Phase 3: Single verification pass
  sleep 1
  local vfail=0 vresult actual
  for i in \"\${!issues[@]}\"; do
    [ -z \"\${item_ids[\$i]}\" ] || [ \"\${item_ids[\$i]}\" = \"null\" ] && continue
    vresult=\$(_gh_fetch_item_info \"\${issues[\$i]}\" 2>/dev/null) || vresult=\"\"
    actual=\$(echo \"\$vresult\" | jq -r '.data.repository.issue.projectItems.nodes[0].fieldValueByName.name // empty' 2>/dev/null) || actual=\"\"
    if [ -z \"\$actual\" ]; then
      _board_log \"batch VERIFY issue=\${issues[\$i]} UNAVAILABLE\"
      echo \"✓ #\${issues[\$i]} → \${statuses[\$i]}\"
    elif [ \"\$actual\" = \"\${displays[\$i]}\" ]; then
      _board_log \"batch VERIFY issue=\${issues[\$i]} OK actual=\$actual\"
      echo \"✓ #\${issues[\$i]} → \${statuses[\$i]}\"
    else
      _board_log \"batch VERIFY issue=\${issues[\$i]} MISMATCH expected=\${displays[\$i]} actual=\$actual\"
      echo \"⚠ #\${issues[\$i]} → \${statuses[\$i]} (verify mismatch: actual=\$actual)\" >&2
      vfail=\$((vfail + 1))
    fi
  done
  _board_log \"batch DONE pairs=\$total failed=\$failed verify_failed=\$vfail\"
  [ \"\$failed\" -gt 0 ] && return 1
  return 0
}"
