#!/usr/bin/env bash
set -uo pipefail

# check-board-drift.sh — Diagnostic script that sets a board status and re-verifies
# at timed intervals (+10s, +30s) to detect delayed drift.
#
# Uses the lightweight per-issue GraphQL query pattern from issue-set-status.sh
# for timed re-verifications. Calls issue-set-status.sh as a subprocess for the
# initial set (does not reimplement the mutation).
#
# Usage: ./scripts/check-board-drift.sh <issue-number> <status>
#
# Status values: backlog, planned, todo, in-progress, in-review, done
#
# Exit codes:
#   0 — no drift detected
#   1 — drift detected
#   2 — usage error or API failure

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REPO_OWNER="carlosboeing"
REPO_NAME="agentic-sdlc-workflow"

LOG_DIR="$REPO_ROOT/.claude/logs"
DRIFT_LOG="$LOG_DIR/board-drift.log"
mkdir -p "$LOG_DIR" 2>/dev/null || true

# --- Argument parsing ---
if [ $# -lt 2 ]; then
  echo "Usage: $0 <issue-number> <status>" >&2
  echo "  status: backlog | planned | todo | in-progress | in-review | done" >&2
  exit 2
fi

ISSUE_NUMBER="$1"
STATUS="$2"

# Map status CLI argument to display name (same mapping as issue-set-status.sh)
case "$STATUS" in
  backlog)     STATUS_DISPLAY="Backlog" ;;
  planned)     STATUS_DISPLAY="Planned" ;;
  todo)        STATUS_DISPLAY="Todo" ;;
  in-progress) STATUS_DISPLAY="In Progress" ;;
  in-review)   STATUS_DISPLAY="In Review" ;;
  done)        STATUS_DISPLAY="Done" ;;
  *)
    echo "ERROR: Unknown status '$STATUS'. Expected: backlog, planned, todo, in-progress, in-review, done" >&2
    exit 2
    ;;
esac

# --- Lightweight per-issue GraphQL query (same pattern as issue-set-status.sh) ---
# Costs ~1 GraphQL point vs ~200+ for gh project item-list.
fetch_item_status() {
  local result
  result=$(gh api graphql -f query="
  query {
    repository(owner: \"$REPO_OWNER\", name: \"$REPO_NAME\") {
      issue(number: $ISSUE_NUMBER) {
        projectItems(first: 5) {
          nodes {
            id
            fieldValueByName(name: \"Status\") {
              ... on ProjectV2ItemFieldSingleSelectValue {
                name
              }
            }
          }
        }
      }
    }
  }" 2>/dev/null) || result=""
  echo "$result"
}

extract_status_name() {
  local data="$1"
  local name
  name=$(echo "$data" | jq -r '.data.repository.issue.projectItems.nodes[0].fieldValueByName.name // empty' 2>/dev/null) || name=""
  echo "$name"
}

# --- Structured log append ---
# Format: [ISO-timestamp] issue=N target=status set=OK verify_10s=OK|DRIFT(actual=X) verify_30s=OK|DRIFT(actual=X) result=NO_DRIFT|DRIFT
append_drift_log() {
  local ts set_result verify_10s verify_30s final_result
  ts="$1"
  set_result="$2"
  verify_10s="$3"
  verify_30s="$4"
  final_result="$5"

  echo "[$ts] issue=$ISSUE_NUMBER target=$STATUS set=$set_result verify_10s=$verify_10s verify_30s=$verify_30s result=$final_result" >> "$DRIFT_LOG" 2>/dev/null || true
}

# --- Human-readable output helper ---
ts_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

print_header() {
  echo ""
  echo "=== Board Drift Detection Check ==="
  echo "  Issue:    #$ISSUE_NUMBER"
  echo "  Target:   $STATUS ($STATUS_DISPLAY)"
  echo "  Started:  $(ts_now)"
  echo ""
}

print_header

RUN_TIMESTAMP=$(ts_now)

# --- Step 1: Call issue-set-status.sh for the initial status set ---
echo "[$(ts_now)] Setting status to '$STATUS'..."

SET_OUTPUT=$("$SCRIPT_DIR/issue-set-status.sh" "$ISSUE_NUMBER" "$STATUS" 2>&1)
SET_EXIT=$?

if [ "$SET_EXIT" -ne 0 ]; then
  echo "[$(ts_now)] ERROR: issue-set-status.sh failed (exit $SET_EXIT): $SET_OUTPUT" >&2
  append_drift_log "$RUN_TIMESTAMP" "FAIL" "N/A" "N/A" "API_FAILURE"
  exit 2
fi

echo "[$(ts_now)] Set complete: $SET_OUTPUT"
SET_RESULT="OK"

# --- Step 2: Re-verify at +10s ---
echo "[$(ts_now)] Waiting 10 seconds before first re-verification..."
sleep 10

echo "[$(ts_now)] Re-verifying (10s check)..."
QUERY_10=$(fetch_item_status)
ACTUAL_10=$(extract_status_name "$QUERY_10")

if [ -z "$ACTUAL_10" ]; then
  echo "[$(ts_now)] WARNING: Could not read board status at +10s (API unavailable)"
  VERIFY_10S="UNAVAILABLE"
elif [ "$ACTUAL_10" = "$STATUS_DISPLAY" ]; then
  echo "[$(ts_now)] +10s check: OK (status=$ACTUAL_10)"
  VERIFY_10S="OK"
else
  echo "[$(ts_now)] +10s check: DRIFT (expected=$STATUS_DISPLAY, actual=$ACTUAL_10)"
  VERIFY_10S="DRIFT(actual=$ACTUAL_10)"
fi

# --- Step 3: Re-verify at +30s (sleep 20 more seconds — 30s total from initial set) ---
echo "[$(ts_now)] Waiting 20 more seconds before second re-verification..."
sleep 20

echo "[$(ts_now)] Re-verifying (30s check)..."
QUERY_30=$(fetch_item_status)
ACTUAL_30=$(extract_status_name "$QUERY_30")

if [ -z "$ACTUAL_30" ]; then
  echo "[$(ts_now)] WARNING: Could not read board status at +30s (API unavailable)"
  VERIFY_30S="UNAVAILABLE"
elif [ "$ACTUAL_30" = "$STATUS_DISPLAY" ]; then
  echo "[$(ts_now)] +30s check: OK (status=$ACTUAL_30)"
  VERIFY_30S="OK"
else
  echo "[$(ts_now)] +30s check: DRIFT (expected=$STATUS_DISPLAY, actual=$ACTUAL_30)"
  VERIFY_30S="DRIFT(actual=$ACTUAL_30)"
fi

# --- Step 4: Determine result ---
DRIFT_DETECTED=false

if echo "$VERIFY_10S" | grep -q "^DRIFT"; then
  DRIFT_DETECTED=true
fi
if echo "$VERIFY_30S" | grep -q "^DRIFT"; then
  DRIFT_DETECTED=true
fi

if [ "$DRIFT_DETECTED" = true ]; then
  FINAL_RESULT="DRIFT"
else
  FINAL_RESULT="NO_DRIFT"
fi

# --- Step 5: Print summary and append to drift log ---
echo ""
echo "=== Drift Check Summary ==="
printf "  %-18s %s\n" "Issue:"       "#$ISSUE_NUMBER"
printf "  %-18s %s\n" "Target:"      "$STATUS_DISPLAY"
printf "  %-18s %s\n" "Initial set:" "$SET_RESULT"
printf "  %-18s %s\n" "+10s check:"  "$VERIFY_10S"
printf "  %-18s %s\n" "+30s check:"  "$VERIFY_30S"
printf "  %-18s %s\n" "Result:"      "$FINAL_RESULT"
echo ""

append_drift_log "$RUN_TIMESTAMP" "$SET_RESULT" "$VERIFY_10S" "$VERIFY_30S" "$FINAL_RESULT"

if [ "$DRIFT_DETECTED" = true ]; then
  echo "DRIFT DETECTED: Board status drifted away from '$STATUS_DISPLAY' after mutation." >&2
  exit 1
else
  echo "No drift detected. Board status held at '$STATUS_DISPLAY' across all checks."
  exit 0
fi
