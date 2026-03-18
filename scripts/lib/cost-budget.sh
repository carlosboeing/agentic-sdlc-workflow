#!/usr/bin/env bash
# cost-budget.sh — Cost budget enforcement for the agentic SDLC workflow.
#
# Standalone sourced library. Source this file to get check_cost_budget.
#
# Usage (from orchestrator or any script in scripts/):
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/lib/cost-budget.sh"
#   check_cost_budget "$STATE_FILE"
#
# Reads CFG_MAX_COST_PER_RUN from config.sh (caller must have sourced it, or
# the variable must already be set in the environment).

# check_cost_budget <state-file>
#   Returns 0 if under budget or no limit configured (maxCostPerRun: null).
#   Returns 1 if cumulative cost exceeds the configured limit.
#   Prints current cost and limit on stdout in all cases.
check_cost_budget() {
  local state_file="$1"
  local max_cost="${CFG_MAX_COST_PER_RUN:-null}"

  if [ "$max_cost" = "null" ] || [ -z "$max_cost" ]; then
    echo "Budget: no limit configured"
    return 0
  fi

  local current_cost
  current_cost=$(jq -r '.session.total_cost // 0' "$state_file" 2>/dev/null || echo "0")

  if (( $(echo "$current_cost > $max_cost" | bc -l) )); then
    echo "Budget exceeded: \$$current_cost > \$$max_cost limit"
    return 1
  fi

  echo "Budget: \$$current_cost of \$$max_cost limit"
  return 0
}
