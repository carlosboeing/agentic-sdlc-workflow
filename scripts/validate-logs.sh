#!/usr/bin/env bash
# validate-logs.sh — Post-run diagnostic script for orchestrator logging.
#
# Reads both log files and reports whether expected events were captured.
# Surfaces VERIFY_MISMATCH events prominently with full log line details.
#
# Usage: ./scripts/validate-logs.sh
#
# Exit code: always 0 (diagnostic script — partial output is better than a crash)
#
# Note: intentionally omits -e so grep returning exit 1 (no matches) does not abort.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BOARD_LOG="$REPO_ROOT/.claude/logs/board-status.log"
ORCH_LOG="$REPO_ROOT/.claude/logs/orchestrator.log"

count_matching() {
  local file="$1"
  local pattern="$2"
  if [ ! -f "$file" ]; then
    echo 0
    return
  fi
  # grep -c exits 1 when no matches found (not an error), so capture the count
  # and treat exit 1 as 0 matches; exit 2+ is a real error (also treat as 0)
  local n
  n=$(grep -c "$pattern" "$file" 2>/dev/null) || n=0
  echo "$n"
}

echo "=== Log Validation Report ==="
echo ""

# --- Board Status Log ---
echo "Board Status Log ($BOARD_LOG)"
if [ ! -f "$BOARD_LOG" ]; then
  echo "  NOT FOUND — no board status events recorded"
else
  TOTAL=$(wc -l < "$BOARD_LOG" | tr -d ' ')
  COUNT_START=$(count_matching "$BOARD_LOG" " START ")
  COUNT_MUTATION=$(count_matching "$BOARD_LOG" " MUTATION ")
  COUNT_VERIFY_OK=$(count_matching "$BOARD_LOG" " VERIFY_OK ")
  COUNT_MISMATCH=$(count_matching "$BOARD_LOG" " VERIFY_MISMATCH ")
  COUNT_SKIP=$(count_matching "$BOARD_LOG" " SKIP ")

  printf "  %-22s %s\n" "Total entries:"     "$TOTAL"
  printf "  %-22s %s\n" "START:"             "$COUNT_START"
  printf "  %-22s %s\n" "MUTATION:"          "$COUNT_MUTATION"
  printf "  %-22s %s\n" "VERIFY_OK:"         "$COUNT_VERIFY_OK"
  printf "  %-22s %s\n" "VERIFY_MISMATCH:"   "$COUNT_MISMATCH"
  printf "  %-22s %s\n" "SKIP:"              "$COUNT_SKIP"

  if [ "$COUNT_MISMATCH" -gt 0 ]; then
    echo ""
    echo "  WARNING: MISMATCHES FOUND:"
    grep " VERIFY_MISMATCH " "$BOARD_LOG" | while IFS= read -r line; do
      echo "  $line"
    done
  fi
fi

echo ""

# --- Orchestrator Log ---
echo "Orchestrator Log ($ORCH_LOG)"
if [ ! -f "$ORCH_LOG" ]; then
  echo "  NOT FOUND — no orchestrator events recorded"
else
  TOTAL_ORCH=$(wc -l < "$ORCH_LOG" | tr -d ' ')
  COUNT_BASH=$(count_matching "$ORCH_LOG" " tool=Bash ")
  # Count both tool=Task and tool=Agent (hook logs either name depending on Claude Code version)
  COUNT_AGENT=$(grep -cE " tool=(Task|Agent) " "$ORCH_LOG" 2>/dev/null) || COUNT_AGENT=0

  printf "  %-22s %s\n" "Total entries:"     "$TOTAL_ORCH"
  printf "  %-22s %s\n" "Bash commands:"     "$COUNT_BASH"
  printf "  %-22s %s\n" "Agent dispatches:"  "$COUNT_AGENT"
fi

echo ""
echo "=== End Report ==="

exit 0
