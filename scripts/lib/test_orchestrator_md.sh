#!/usr/bin/env bash
# test_orchestrator_md.sh — Validates orchestrator.md rewrite acceptance criteria.
#
# Checks line count, deleted content, preserved content, and no inline Python
# for state operations.
#
# Usage: bash scripts/lib/test_orchestrator_md.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FILE="$REPO_ROOT/.claude/agents/orchestrator.md"

# ─── Helpers ──────────────────────────────────────────────────────────────────

PASS=0
FAIL=0
ERRORS=()

pass() { echo "  PASS: $1"; (( PASS++ )) || true; }
fail() { echo "  FAIL: $1"; ERRORS+=("$1"); (( FAIL++ )) || true; }

assert_range() {
  local desc="$1" min="$2" max="$3" actual="$4"
  if [ "$actual" -ge "$min" ] && [ "$actual" -le "$max" ]; then
    pass "$desc ($actual in [$min, $max])"
  else
    fail "$desc ($actual not in [$min, $max])"
  fi
}

assert_zero() {
  local desc="$1" count="$2"
  if [ "$count" -eq 0 ]; then
    pass "$desc (count=0)"
  else
    fail "$desc (expected 0, got $count)"
  fi
}

assert_gte() {
  local desc="$1" min="$2" actual="$3"
  if [ "$actual" -ge "$min" ]; then
    pass "$desc (count=$actual >= $min)"
  else
    fail "$desc (expected >= $min, got $actual)"
  fi
}

# ─── Tests ────────────────────────────────────────────────────────────────────

echo "=== orchestrator.md Rewrite Validation ==="
echo ""

# --- Line count ---
echo "--- Line Count ---"
LINE_COUNT=$(wc -l < "$FILE")
assert_range "Line count in [480, 580]" 480 580 "$LINE_COUNT"

# --- Deleted content (should NOT be present) ---
echo ""
echo "--- Deleted Content (must be absent) ---"

# Dead code: System Prompt Hardening / NeuralNorris references
COUNT=$(grep -c "SdlcWorkflowTool\|ClaudeDispatchTool" "$FILE" || true)
assert_zero "No SdlcWorkflowTool/ClaudeDispatchTool references" "$COUNT"

COUNT=$(grep -c "System Prompt Hardening" "$FILE" || true)
assert_zero "No System Prompt Hardening section" "$COUNT"

# Legacy manual telemetry method
COUNT=$(grep -c "Legacy method" "$FILE" || true)
assert_zero "No Legacy method references" "$COUNT"

# Gantt color tagging table
COUNT=$(grep -c "Gantt color tagging" "$FILE" || true)
assert_zero "No Gantt color tagging table" "$COUNT"

# Duration precision rules (the specific rule text)
COUNT=$(grep -c "Duration precision" "$FILE" || true)
assert_zero "No Duration precision section" "$COUNT"

# Value column convention rules
COUNT=$(grep -c "Value column convention" "$FILE" || true)
assert_zero "No Value column convention section" "$COUNT"

# --- Preserved content (MUST be present) ---
echo ""
echo "--- Preserved Content (must be present) ---"

# state.sh references
COUNT=$(grep -c "state\.sh init" "$FILE" || true)
assert_gte "state.sh init referenced" 1 "$COUNT"

COUNT=$(grep -c "state\.sh overhead" "$FILE" || true)
assert_gte "state.sh overhead referenced" 1 "$COUNT"

COUNT=$(grep -c "state\.sh lifecycle-duration" "$FILE" || true)
assert_gte "state.sh lifecycle-duration referenced" 1 "$COUNT"

COUNT=$(grep -c "state\.sh update --dispatch" "$FILE" || true)
assert_gte "state.sh update --dispatch referenced" 1 "$COUNT"

COUNT=$(grep -c "orchestrator-state\.v1\.json" "$FILE" || true)
assert_gte "Schema file referenced" 1 "$COUNT"

# Override Pattern preserved
COUNT=$(grep -c "Override Pattern\|When NOT to override" "$FILE" || true)
assert_gte "Override Pattern preserved" 1 "$COUNT"

# Idempotent Restart preserved
COUNT=$(grep -c "Idempotent Restart" "$FILE" || true)
assert_gte "Idempotent Restart preserved" 1 "$COUNT"

# Phase Boundary preserved
COUNT=$(grep -c "Phase Boundary" "$FILE" || true)
assert_gte "Phase Boundary preserved" 1 "$COUNT"

# Error Handling sections preserved
COUNT=$(grep -c "Designer/Planner Dispatch Failure\|Builder Dispatch Failure\|Review Rejection" "$FILE" || true)
assert_gte "Error Handling sections preserved" 2 "$COUNT"

# State Readers table preserved
COUNT=$(grep -c "State Readers" "$FILE" || true)
assert_gte "State Readers table preserved" 1 "$COUNT"

# state.sh reconstruct reference
COUNT=$(grep -c "state\.sh reconstruct" "$FILE" || true)
assert_gte "state.sh reconstruct referenced" 1 "$COUNT"

# --- YAML frontmatter unchanged ---
echo ""
echo "--- YAML Frontmatter ---"
FIRST_LINE=$(head -1 "$FILE")
if [ "$FIRST_LINE" = "---" ]; then
  pass "YAML frontmatter starts with ---"
else
  fail "YAML frontmatter starts with ---"
fi

# Check frontmatter fields preserved
COUNT=$(grep -c "^name: orchestrator$" "$FILE" || true)
assert_gte "name: orchestrator in frontmatter" 1 "$COUNT"

COUNT=$(grep -c "^model: inherit$" "$FILE" || true)
assert_gte "model: inherit in frontmatter" 1 "$COUNT"

# --- No inline Python for state operations ---
echo ""
echo "--- No Inline Python for State Operations ---"

# Check no python3 -c blocks for state file manipulation
# (Some python3 -c may remain for non-state operations like timestamp computation)
# We check specifically for the patterns that should have been extracted
COUNT=$(grep -c "json\.load\|json\.dump" "$FILE" || true)
assert_zero "No json.load/json.dump (state manipulation extracted)" "$COUNT"

COUNT=$(grep -c "state\['dispatches'\]" "$FILE" || true)
assert_zero "No state['dispatches'] manipulation" "$COUNT"

COUNT=$(grep -c "state\['epics'\]" "$FILE" || true)
assert_zero "No state['epics'] manipulation" "$COUNT"

COUNT=$(grep -c "state\['overhead'\]" "$FILE" || true)
assert_zero "No state['overhead'] manipulation" "$COUNT"

# --- CLI dispatch section trimmed ---
echo ""
echo "--- CLI Dispatch Section ---"

# The multi-line CLI dispatch bash examples should be deleted
COUNT=$(grep -c "dispatch-story.sh.*--model.*--agent.*&" "$FILE" || true)
assert_zero "No parallel CLI dispatch examples with &" "$COUNT"

# --- Cost Computation trimmed ---
echo ""
echo "--- Cost Computation ---"

# jq commands for rate extraction should be deleted
COUNT=$(grep -c "jq.*inputPerM\|jq.*outputPerM" "$FILE" || true)
assert_zero "No jq rate extraction commands" "$COUNT"

# But the "never hardcode rates" rule should remain
COUNT=$(grep -ci "never hardcode.*rate\|never.*memorize.*rate\|hardcode or memorize" "$FILE" || true)
assert_gte "Never hardcode rates rule preserved" 1 "$COUNT"

# ─── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "=== Results ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Failures:"
  for e in "${ERRORS[@]}"; do
    echo "  - $e"
  done
  exit 1
fi

echo ""
echo "All checks passed."
