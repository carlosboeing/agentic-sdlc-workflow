#!/usr/bin/env bash
set -euo pipefail

# issue-telemetry.sh — Post telemetry metrics to a GitHub Issue and optionally a PR.
# Renders from scripts/templates/telemetry.md — edit the template to change the output format.
#
# Usage: ./scripts/issue-telemetry.sh <issue-number> --model <model> --duration <ms> --commit <hash>
#        [--tokens <total>] [--tool-uses <n>] [--rate <cents-per-M>] [--cost <dollars>] [--breakdown <markdown>] [--pr <pr-number>]
#        [--wall-clock <ms>] [--gantt <mermaid-body>]
#
# --duration is the sequential sum of all story durations. --wall-clock is the actual elapsed
# time (accounting for parallel dispatch). When both are provided, parallelism metrics are shown.
#
# --rate overrides the hardcoded blended rate (in cents per million tokens). The orchestrator
# reads this from its state file (pricing fetched from Anthropic at session start). If omitted,
# the script falls back to hardcoded defaults.
#
# The --breakdown table should include a "Dispatch" column (parallel/sequential) between Wave
# and Story columns. The script adds the table header automatically.
#
# The --gantt parameter accepts the body of a Mermaid gantt chart (everything after the
# ```mermaid\ngantt header). The script wraps it in the code fence automatically.

REPO="carlosboeing/agentic-sdlc-workflow"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/templates/telemetry.md"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <issue-number> --model <model> --duration <ms> --commit <hash> [--tokens <n>] [--tool-uses <n>] [--rate <cents>] [--breakdown <markdown>] [--pr <n>] [--wall-clock <ms>] [--gantt <mermaid-body>]"
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
RATE_OVERRIDE=""
COST_OVERRIDE=""

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
    --rate) RATE_OVERRIDE="$2"; shift 2 ;;
    --cost) COST_OVERRIDE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ─── Compute derived values ───────────────────────────────────────────────────

# Format milliseconds into human-readable duration
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

DURATION_SECS=$((DURATION_MS / 1000))
DURATION_HUMAN=$(format_duration "$DURATION_MS")

# Calculate tokens/s (avoid division by zero)
if [ "$TOKENS" -gt 0 ] && [ "$DURATION_SECS" -gt 0 ]; then
  TOKENS_PER_SEC=$((TOKENS / DURATION_SECS))
else
  TOKENS_PER_SEC="—"
fi

# Estimate cost using blended rate per model ($/M tokens)
# Assumes ~75% input, ~25% output token split
# These defaults reflect pricing as of 2026-03. Use --rate to override with
# live rates from the orchestrator state file (fetched via fetch-pricing.sh).
# Opus 4.6: $5 in / $25 out → blended ~$10/M
# Sonnet 4.6: $3 in / $15 out → blended ~$6/M
# Haiku 4.5: $1 in / $5 out → blended ~$2/M
COST_EST="—"
if [ -n "$COST_OVERRIDE" ]; then
  # Pre-computed cost passed by orchestrator (e.g., for mixed-model epics)
  COST_EST="~\$${COST_OVERRIDE}"
elif [ "$TOKENS" -gt 0 ]; then
  if [ -n "$RATE_OVERRIDE" ]; then
    RATE_CENTS="$RATE_OVERRIDE"
  else
    case "$MODEL" in
      opus)   RATE_CENTS=1000 ;;
      sonnet) RATE_CENTS=600 ;;
      haiku)  RATE_CENTS=200 ;;
      *)      RATE_CENTS=0 ;;
    esac
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

# Format token count for display (e.g. 245000 → "245K", 1220000 → "1.22M")
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

# ─── Template rendering ──────────────────────────────────────────────────────

# Evaluate a named condition. Returns 0 (true) or 1 (false).
eval_condition() {
  case "$1" in
    TOKENS)                  [ "$TOKENS" -gt 0 ] ;;
    TOOL_USES)               [ "$TOOL_USES" -gt 0 ] ;;
    NO_PARALLELISM)          [ "$HAS_PARALLELISM" = false ] ;;
    PARALLELISM)             [ "$HAS_PARALLELISM" = true ] ;;
    TIME_SAVED)              [ -n "$TIME_SAVED_HUMAN" ] ;;
    BREAKDOWN)               [ -n "$BREAKDOWN" ] ;;
    PARALLELISM_BREAKDOWN)   [ "$HAS_PARALLELISM" = true ] && [ -n "$TIME_SAVED_HUMAN" ] ;;
    GANTT)                   [ -n "$GANTT" ] ;;
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
    # Strip HTML comments (<!-- ... -->) that aren't conditional blocks.
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
    if [[ "$line" == "{{BREAKDOWN}}" ]]; then
      [ -n "$BREAKDOWN" ] && printf '%s\n' "$BREAKDOWN"
      continue
    fi
    if [[ "$line" == "{{GANTT}}" ]]; then
      [ -n "$GANTT" ] && printf '%s\n' "$GANTT"
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

# ─── Post telemetry ──────────────────────────────────────────────────────────

ISSUE_BODY=$(render_template "$TEMPLATE_FILE" "📊 Telemetry")
gh issue comment "$ISSUE_NUMBER" --repo "$REPO" --body "$ISSUE_BODY"
echo "Telemetry posted to issue #$ISSUE_NUMBER (model=$MODEL, duration=$DURATION_HUMAN)"

if [ -n "$PR_NUMBER" ]; then
  PR_BODY=$(render_template "$TEMPLATE_FILE" "📊 Telemetry")
  gh pr comment "$PR_NUMBER" --repo "$REPO" --body "$PR_BODY"
  echo "Telemetry posted to PR #$PR_NUMBER"
fi
