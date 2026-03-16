#!/usr/bin/env bash
set -euo pipefail

# issue-telemetry.sh — Post telemetry metrics to a GitHub Issue and optionally a PR.
# Renders from scripts/templates/telemetry.md — edit the template to change the output format.
#
# Usage: ./scripts/issue-telemetry.sh <issue-number> --model <model> --duration <ms> --commit <hash>
#        [--tokens <total>] [--tool-uses <n>] [--rate <cents-per-M>] [--cost <dollars>]
#        [--dispatches <json-file>] [--dispatches-from-state <state-file>]
#        [--gantt-from-state <state-file>]
#        [--breakdown <markdown>] [--pr <pr-number>] [--wall-clock <ms>] [--gantt <mermaid-body>]
#        [--summary <markdown>] [--footer <markdown>]
#
# Modes:
#   Story/epic (default): Renders a Metric/Value summary table with model, commit, tokens, cost.
#   Backlog (--summary):  Renders a phase Summary table + full lifecycle sections.
#
# --duration is the sequential sum of all story durations. --wall-clock is the actual elapsed
# time (accounting for parallel dispatch). When both are provided, parallelism metrics are shown.
#
# --rate overrides the hardcoded blended rate (in cents per million tokens). The orchestrator
# reads this from its state file (pricing fetched from Anthropic at session start). If omitted,
# the script falls back to hardcoded defaults.
#
# --summary provides the phase-level summary table rows (backlog-level telemetry).
# Columns: Phase | Agent | Duration | Tokens | Est. Cost. The script adds the header.
# When --summary is provided, --pr appends to the PR description instead of commenting.
#
# --breakdown provides per-dispatch detail rows.
# Columns: Agent | Task | Duration | Tokens | Est. Cost. The script adds the header.
#
# --dispatches accepts a JSON file with structured dispatch data. The script computes
# breakdown rows, summary rows, total cost, total duration, and total tokens from the data
# using config rates. This replaces manual --breakdown, --summary, and --cost computation.
# Format: [{"agent":"Builder (sonnet)","model":"sonnet","task":"E01-S01 (#61)",
#           "duration_ms":146479,"tokens":49691,"phase":"Build"}, ...]
# Phases are grouped in the summary table. The script adds total rows automatically.
#
# --dispatches-from-state reads the orchestrator state file (.agentic-workflow/runs/<N>/orchestrator.json)
# and converts its dispatches[] array into the structured format above. This is the preferred
# method for backlog-level telemetry — the orchestrator passes its state file and the script
# does all the math, eliminating manual cost/duration computation errors.
#
# Wall-clock auto-computation: When --dispatches-from-state is used, the script automatically
# computes wall-clock duration from the started_at timestamps in the dispatch log. Dispatches
# with the same started_at are treated as parallel (take max duration); different timestamps
# are sequential (sum durations). If --wall-clock is not provided, the computed value is used.
# If --wall-clock is provided but equals --duration (suspicious when parallel dispatches exist),
# the script overrides with the computed value and emits a warning.
#
# --gantt-from-state reads the orchestrator state file and generates a Mermaid Gantt chart
# body via compute-dispatches.py --gantt. Also processes dispatches from state (combines
# --dispatches-from-state + Gantt generation in a single Python call). Takes precedence over
# --gantt when both are provided.
#
# --footer provides trailing text (e.g., notes, PR link) rendered before the disclaimer.
#
# --gantt provides the body of a Mermaid gantt chart (everything after the gantt keyword).
# The script wraps it in the code fence and init block automatically.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"
REPO="$CFG_REPO"
_PRICING_CACHE="$_CFG_REPO_ROOT/.agentic-workflow/pricing.json"
TEMPLATE_FILE="$SCRIPT_DIR/templates/telemetry.md"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <issue-number> --model <model> --duration <ms> --commit <hash> [--tokens <n>] [--tool-uses <n>] [--rate <cents>] [--breakdown <markdown>] [--pr <n>] [--wall-clock <ms>] [--gantt <mermaid-body>] [--gantt-from-state <state-file>] [--summary <markdown>] [--footer <markdown>]"
  exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Error: Template file not found: $TEMPLATE_FILE" >&2
  exit 1
fi

ISSUE_NUMBER="$1"
shift

MODEL="unknown"
DURATION_MS="0"
COMMIT="unknown"
TOKENS="0"
TOOL_USES="0"
BREAKDOWN=""
PR_NUMBER=""
WALL_CLOCK_MS=""
GANTT=""
GANTT_FROM_STATE=""
RATE_OVERRIDE=""
COST_OVERRIDE=""
SUMMARY=""
FOOTER=""
FIX_FOOTER=""
DISPATCHES_FILE=""
DISPATCHES_FROM_STATE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --duration) DURATION_MS="$2"; shift 2 ;;
    --commit) COMMIT="$2"; shift 2 ;;
    --tokens) TOKENS="$2"; shift 2 ;;
    --tool-uses) TOOL_USES="$2"; shift 2 ;;
    --breakdown) BREAKDOWN="$2"; shift 2 ;;
    --pr) PR_NUMBER="$2"; shift 2 ;;
    --wall-clock) WALL_CLOCK_MS="$2"; shift 2 ;;
    --gantt) GANTT="$2"; shift 2 ;;
    --gantt-from-state) GANTT_FROM_STATE="$2"; shift 2 ;;
    --rate) RATE_OVERRIDE="$2"; shift 2 ;;
    --cost) COST_OVERRIDE="$2"; shift 2 ;;
    --summary) SUMMARY="$2"; shift 2 ;;
    --footer) FOOTER="$2"; shift 2 ;;
    --dispatches) DISPATCHES_FILE="$2"; shift 2 ;;
    --dispatches-from-state) DISPATCHES_FROM_STATE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# --- Shared helpers ---

# Format milliseconds into human-readable duration (defined here so it is available
# during dispatch processing below -- e.g. for wall-clock warning messages)
format_duration() {
  local ms=$1
  local secs=$((ms / 1000))
  local mins=$((secs / 60))
  local rem=$((secs % 60))
  if [ "$mins" -gt 0 ] && [ "$rem" -gt 0 ]; then
    echo "${mins}m ${rem}s"
  elif [ "$mins" -gt 0 ]; then
    echo "${mins}m"
  else
    echo "${rem}s"
  fi
}

# --- Process --dispatches (structured data to computed breakdown/summary/cost) ---

_run_dispatches_computation() {
  local dispatches_file="$1"

  _dispatches_result=$(python3 "$SCRIPT_DIR/lib/compute-dispatches.py" \
    --dispatches "$dispatches_file" \
    --pricing "$_PRICING_CACHE" \
    --config "$_CFG_FILE")

  BREAKDOWN=$(echo "$_dispatches_result" | jq -r '.breakdown')
  SUMMARY=$(echo "$_dispatches_result" | jq -r '.summary')
  COST_OVERRIDE=$(echo "$_dispatches_result" | jq -r '.cost')
  DURATION_MS=$(echo "$_dispatches_result" | jq -r '.duration_ms')
  TOKENS=$(echo "$_dispatches_result" | jq -r '.tokens')
}

_process_state_result() {
  # Parse shared fields from a --from-state Python result (JSON string in $1).
  # Sets: BREAKDOWN, SUMMARY, COST_OVERRIDE, DURATION_MS, TOKENS,
  #       FIX_FOOTER, WALL_CLOCK_MS (after wall-clock override logic).
  local result="$1"

  BREAKDOWN=$(echo "$result" | jq -r '.breakdown')
  SUMMARY=$(echo "$result" | jq -r '.summary')
  COST_OVERRIDE=$(echo "$result" | jq -r '.cost')
  DURATION_MS=$(echo "$result" | jq -r '.duration_ms')
  TOKENS=$(echo "$result" | jq -r '.tokens')
  FIX_FOOTER=$(echo "$result" | jq -r '.fix_footer // empty')

  # Wall-clock auto-computation from state file started_at grouping
  local computed_wc has_parallel
  computed_wc=$(echo "$result" | jq -r '.wall_clock_ms')
  has_parallel=$(echo "$result" | jq -r '.has_parallel')

  if [ -z "$WALL_CLOCK_MS" ] || [ "$WALL_CLOCK_MS" = "0" ]; then
    # No wall-clock provided -- use computed value
    WALL_CLOCK_MS="$computed_wc"
    if [ "$has_parallel" = "true" ]; then
      echo "Wall-clock auto-computed from state file: $(format_duration "$computed_wc") (parallel dispatches detected)" >&2
    fi
  elif [ "$WALL_CLOCK_MS" = "$DURATION_MS" ] && [ "$has_parallel" = "true" ]; then
    # User passed wall-clock == duration but parallel dispatches exist -- override with computed
    echo "Warning: --wall-clock ($WALL_CLOCK_MS ms) equals --duration but parallel dispatches detected." >&2
    echo "  Overriding with computed critical path: $(format_duration "$computed_wc")" >&2
    WALL_CLOCK_MS="$computed_wc"
  fi
}

if [ -n "$DISPATCHES_FILE" ] && [ -f "$DISPATCHES_FILE" ]; then
  _run_dispatches_computation "$DISPATCHES_FILE"
elif [ -n "$GANTT_FROM_STATE" ] && [ -f "$GANTT_FROM_STATE" ]; then
  # --gantt-from-state: processes dispatches AND generates Gantt in one call.
  # Takes precedence over --gantt when both are provided.
  if [ -n "$GANTT" ]; then
    echo "Warning: --gantt-from-state and --gantt both provided; --gantt-from-state takes precedence." >&2
  fi
  _state_result=$(python3 "$SCRIPT_DIR/lib/compute-dispatches.py" \
    --from-state "$GANTT_FROM_STATE" \
    --gantt \
    --pricing "$_PRICING_CACHE" --config "$_CFG_FILE")
  _process_state_result "$_state_result"
  GANTT=$(echo "$_state_result" | jq -r '.gantt // empty')
elif [ -n "$DISPATCHES_FROM_STATE" ] && [ -f "$DISPATCHES_FROM_STATE" ]; then
  # Use compute-dispatches.py to convert the state file and compute all metrics:
  # breakdown, summary (with fix cycles row), cost, duration_ms, tokens,
  # wall_clock_ms, has_parallel, fix_cycles, fix_footer.
  _state_result=$(python3 "$SCRIPT_DIR/lib/compute-dispatches.py" \
    --from-state "$DISPATCHES_FROM_STATE" \
    --pricing "$_PRICING_CACHE" --config "$_CFG_FILE")
  _process_state_result "$_state_result"
fi

# --- Compute derived values ---

DURATION_SECS=$((DURATION_MS / 1000))
DURATION_HUMAN=$(format_duration "$DURATION_MS")

# Calculate tokens/s (avoid division by zero)
if [ "$TOKENS" -gt 0 ] && [ "$DURATION_SECS" -gt 0 ]; then
  TOKENS_PER_SEC=$((TOKENS / DURATION_SECS))
else
  TOKENS_PER_SEC="—"
fi

# Estimate cost using blended rate per model ($/M tokens)
# Resolution order:
#   1. Config pricing override (if pricing section exists in config)
#   2. Cached pricing (.agentic-workflow/pricing.json from fetch-pricing.sh)
#   3. Returns 0 (cost will show "—")
#
# Token split (75% input / 25% output) is a fixed constant based on
# observed patterns across 12 test runs. Not user-configurable.
_TOKEN_SPLIT_INPUT=0.75
_TOKEN_SPLIT_OUTPUT=0.25

_cfg_blended_rate() {
  local model="$1"
  local inp="" out=""

  # Priority 1: Config pricing override
  if [ -f "$_CFG_FILE" ]; then
    inp=$(jq -r ".pricing.${model}.inputPerM // empty" "$_CFG_FILE" 2>/dev/null) || inp=""
    out=$(jq -r ".pricing.${model}.outputPerM // empty" "$_CFG_FILE" 2>/dev/null) || out=""
  fi

  # Priority 2: Cached pricing from fetch-pricing.sh
  if [ -z "$inp" ] || [ -z "$out" ]; then
    if [ -f "$_PRICING_CACHE" ]; then
      inp=$(jq -r ".rates.${model}.inputPerM // empty" "$_PRICING_CACHE" 2>/dev/null) || inp=""
      out=$(jq -r ".rates.${model}.outputPerM // empty" "$_PRICING_CACHE" 2>/dev/null) || out=""
    fi
  fi

  # Compute blended rate in cents/M
  if [ -n "$inp" ] && [ -n "$out" ]; then
    echo "$inp $out $_TOKEN_SPLIT_INPUT $_TOKEN_SPLIT_OUTPUT" | awk '{printf "%d", ($1 * $3 + $2 * $4) * 100}'
    return
  fi

  # No pricing data available
  echo "0"
}
COST_EST="—"
if [ -n "$COST_OVERRIDE" ]; then
  # Pre-computed cost passed by orchestrator (e.g., for mixed-model epics)
  COST_EST="~\$${COST_OVERRIDE}"
elif [ "$TOKENS" -gt 0 ]; then
  if [ -n "$RATE_OVERRIDE" ]; then
    RATE_CENTS="$RATE_OVERRIDE"
  else
    RATE_CENTS=$(_cfg_blended_rate "$MODEL")
  fi
  if [ "$RATE_CENTS" -gt 0 ]; then
    COST_CENTS=$(( (TOKENS * RATE_CENTS + 500000) / 1000000 ))
    if [ "$COST_CENTS" -ge 100 ]; then
      COST_DOLLARS=$((COST_CENTS / 100))
      COST_REMAINDER=$((COST_CENTS % 100))
      COST_EST=$(printf "~\$%d.%02d" "$COST_DOLLARS" "$COST_REMAINDER")
    else
      COST_EST=$(printf "~\$0.%02d" "$COST_CENTS")
    fi
  fi
fi

# Format token count for display (e.g. 245000 -> "245K", 1220000 -> "1.22M")
format_tokens() {
  local t=$1
  if [ "$t" -ge 1000000 ]; then
    local m=$((t / 1000000))
    local r=$(( (t % 1000000) / 10000 ))
    if [ "$r" -gt 0 ]; then
      printf "%d.%02dM" "$m" "$r"
    else
      printf "%dM" "$m"
    fi
  elif [ "$t" -ge 1000 ]; then
    printf "%dK" "$((t / 1000))"
  else
    printf "%d" "$t"
  fi
}

if [ "$TOKENS" -gt 0 ]; then
  TOKENS_FMT=$(format_tokens "$TOKENS")
else
  TOKENS_FMT="—"
fi

# Calculate parallelism metrics when wall-clock time is provided
WALL_CLOCK_HUMAN=""
TIME_SAVED_HUMAN=""
SPEEDUP=""
HAS_PARALLELISM=false
if [ -n "$WALL_CLOCK_MS" ] && [ "$WALL_CLOCK_MS" -gt 0 ] 2>/dev/null; then
  HAS_PARALLELISM=true
  WALL_CLOCK_HUMAN=$(format_duration "$WALL_CLOCK_MS")
  WC_SECS=$((WALL_CLOCK_MS / 1000))

  SAVED_MS=$((DURATION_MS - WALL_CLOCK_MS))
  if [ "$SAVED_MS" -gt 0 ]; then
    TIME_SAVED_HUMAN=$(format_duration "$SAVED_MS")
  fi

  # Speedup factor: sequential / wall-clock (e.g. "2.3x")
  if [ "$WC_SECS" -gt 0 ]; then
    SPEEDUP_X10=$(( (DURATION_SECS * 10 + WC_SECS / 2) / WC_SECS ))
    SPEEDUP_WHOLE=$((SPEEDUP_X10 / 10))
    SPEEDUP_FRAC=$((SPEEDUP_X10 % 10))
    SPEEDUP="${SPEEDUP_WHOLE}.${SPEEDUP_FRAC}x"
  fi
fi

# Shortened commit hash for display
COMMIT_SHORT="${COMMIT:0:7}"

# Detect mode: backlog (--summary provided) vs story/epic (default)
IS_BACKLOG=false
if [ -n "$SUMMARY" ]; then
  IS_BACKLOG=true
fi

# --- Template rendering ---

# Evaluate a named condition. Returns 0 (true) or 1 (false).
eval_condition() {
  case "$1" in
    BACKLOG)                 [ "$IS_BACKLOG" = true ] ;;
    STORY)                   [ "$IS_BACKLOG" = false ] ;;
    TOKENS)                  [ "$TOKENS" -gt 0 ] ;;
    TOOL_USES)               [ "$TOOL_USES" -gt 0 ] ;;
    NO_PARALLELISM)          [ "$HAS_PARALLELISM" = false ] ;;
    PARALLELISM)             [ "$HAS_PARALLELISM" = true ] ;;
    TIME_SAVED)              [ -n "$TIME_SAVED_HUMAN" ] ;;
    BREAKDOWN)               [ -n "$BREAKDOWN" ] ;;
    GANTT)                   [ -n "$GANTT" ] ;;
    FOOTER)                  [ -n "$FOOTER" ] ;;
    FIX_CYCLES)              [ -n "$FIX_FOOTER" ] ;;
    DISCLAIMER)              [ "$COST_EST" != "—" ] || [ -n "$BREAKDOWN" ] ;;
    *)                       return 1 ;;
  esac
}

# Render the template file with variable substitution and conditional blocks.
# Usage: render_template <template-file> <heading>
render_template() {
  local template_file="$1"
  local heading="$2"
  local skip_depth=0
  local in_html_comment=false

  while IFS= read -r line || [ -n "$line" ]; do
    # Strip HTML comments (<!-- ... -->) that are not conditional blocks.
    # Handles both single-line and multi-line comments.
    if [ "$in_html_comment" = true ]; then
      if [[ "$line" =~ ^[[:space:]]*'-->'[[:space:]]*$ ]]; then
        in_html_comment=false
      fi
      continue
    fi
    if [[ "$line" =~ ^'<!--' ]] && [[ ! "$line" =~ ^'<!-- IF_' ]] && [[ ! "$line" =~ ^'<!-- END_' ]]; then
      if [[ "$line" != *'-->'* ]]; then
        in_html_comment=true
      fi
      continue
    fi

    # Conditional block start
    if [[ "$line" =~ ^'<!-- IF_'([A-Z_]+)' -->'$ ]]; then
      if [ "$skip_depth" -gt 0 ]; then
        skip_depth=$((skip_depth + 1))
      else
        if ! eval_condition "${BASH_REMATCH[1]}"; then
          skip_depth=1
        fi
      fi
      continue
    fi

    # Conditional block end
    if [[ "$line" =~ ^'<!-- END_'([A-Z_]+)' -->'$ ]]; then
      if [ "$skip_depth" -gt 0 ]; then
        skip_depth=$((skip_depth - 1))
      fi
      continue
    fi

    # Skip lines inside false conditionals
    if [ "$skip_depth" -gt 0 ]; then
      continue
    fi

    # Multi-line content injection (marker on its own line)
    if [[ "$line" == "{{SUMMARY}}" ]]; then
      [ -n "$SUMMARY" ] && printf '%s\n' "$SUMMARY"
      continue
    fi
    if [[ "$line" == "{{BREAKDOWN}}" ]]; then
      [ -n "$BREAKDOWN" ] && printf '%s\n' "$BREAKDOWN"
      continue
    fi
    if [[ "$line" == "{{GANTT}}" ]]; then
      [ -n "$GANTT" ] && printf '%s\n' "$GANTT"
      continue
    fi
    if [[ "$line" == "{{FOOTER}}" ]]; then
      [ -n "$FOOTER" ] && printf '%s\n' "$FOOTER"
      continue
    fi
    if [[ "$line" == "{{FIX_FOOTER}}" ]]; then
      [ -n "$FIX_FOOTER" ] && printf '%s\n' "$FIX_FOOTER"
      continue
    fi

    # Simple variable substitution
    line="${line//\{\{HEADING\}\}/$heading}"
    line="${line//\{\{MODEL\}\}/$MODEL}"
    line="${line//\{\{COMMIT_SHORT\}\}/$COMMIT_SHORT}"
    line="${line//\{\{TOKENS_FMT\}\}/$TOKENS_FMT}"
    line="${line//\{\{TOKENS_PER_SEC\}\}/$TOKENS_PER_SEC}"
    line="${line//\{\{COST_EST\}\}/$COST_EST}"
    line="${line//\{\{TOOL_USES\}\}/$TOOL_USES}"
    line="${line//\{\{DURATION_HUMAN\}\}/$DURATION_HUMAN}"
    line="${line//\{\{WALL_CLOCK_HUMAN\}\}/$WALL_CLOCK_HUMAN}"
    line="${line//\{\{TIME_SAVED_HUMAN\}\}/$TIME_SAVED_HUMAN}"
    line="${line//\{\{SPEEDUP\}\}/$SPEEDUP}"

    printf '%s\n' "$line"
  done < "$template_file"
}

# --- Post telemetry ---

RENDERED=$(render_template "$TEMPLATE_FILE" "Telemetry")
gh issue comment "$ISSUE_NUMBER" --repo "$REPO" --body "$RENDERED"
echo "Telemetry posted to issue #$ISSUE_NUMBER (model=$MODEL, duration=$DURATION_HUMAN)"

if [ -n "$PR_NUMBER" ]; then
  if [ "$IS_BACKLOG" = true ]; then
    # Backlog mode: append telemetry to PR description
    EXISTING_BODY=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json body -q .body)
    UPDATED_BODY="${EXISTING_BODY}

${RENDERED}"
    gh pr edit "$PR_NUMBER" --repo "$REPO" --body "$UPDATED_BODY"
    echo "Telemetry appended to PR #$PR_NUMBER description"
  else
    # Story/epic mode: post as PR comment
    gh pr comment "$PR_NUMBER" --repo "$REPO" --body "$RENDERED"
    echo "Telemetry posted to PR #$PR_NUMBER as comment"
  fi
fi
