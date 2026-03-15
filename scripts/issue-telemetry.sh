#!/usr/bin/env bash
set -euo pipefail

# issue-telemetry.sh — Post telemetry metrics to a GitHub Issue and optionally a PR.
# Renders from scripts/templates/telemetry.md — edit the template to change the output format.
#
# Usage: ./scripts/issue-telemetry.sh <issue-number> --model <model> --duration <ms> --commit <hash>
#        [--tokens <total>] [--tool-uses <n>] [--rate <cents-per-M>] [--cost <dollars>]
#        [--dispatches <json-file>] [--dispatches-from-state <state-file>]
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
# --dispatches-from-state reads the orchestrator state file (.claude/state/<N>/orchestrator.json)
# and converts its dispatches[] array into the structured format above. This is the preferred
# method for backlog-level telemetry — the orchestrator passes its state file and the script
# does all the math, eliminating manual cost/duration computation errors.
#
# --footer provides trailing text (e.g., notes, PR link) rendered before the disclaimer.
#
# --gantt provides the body of a Mermaid gantt chart (everything after the gantt keyword).
# The script wraps it in the code fence and init block automatically.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"
REPO="$CFG_REPO"
TEMPLATE_FILE="$SCRIPT_DIR/templates/telemetry.md"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <issue-number> --model <model> --duration <ms> --commit <hash> [--tokens <n>] [--tool-uses <n>] [--rate <cents>] [--breakdown <markdown>] [--pr <n>] [--wall-clock <ms>] [--gantt <mermaid-body>] [--summary <markdown>] [--footer <markdown>]"
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
SUMMARY=""
FOOTER=""
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
    --rate) RATE_OVERRIDE="$2"; shift 2 ;;
    --cost) COST_OVERRIDE="$2"; shift 2 ;;
    --summary) SUMMARY="$2"; shift 2 ;;
    --footer) FOOTER="$2"; shift 2 ;;
    --dispatches) DISPATCHES_FILE="$2"; shift 2 ;;
    --dispatches-from-state) DISPATCHES_FROM_STATE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done


# ─── Process --dispatches (structured data → computed breakdown/summary/cost) ──

_run_dispatches_computation() {
  local dispatches_file="$1"

  _dispatches_result=$(python3 << DISPEOF
import json, sys

cfg_file = "$_CFG_FILE"

# Read config rates
try:
    with open(cfg_file) as f:
        cfg = json.load(f)
    pricing = cfg.get("pricing", {})
    split_in = pricing.get("tokenSplit", {}).get("input", 0.75)
    split_out = pricing.get("tokenSplit", {}).get("output", 0.25)
except Exception:
    pricing = {}
    split_in, split_out = 0.75, 0.25

defaults = {"opus": (15.0, 75.0), "sonnet": (3.0, 15.0), "haiku": (1.0, 5.0)}

def blended_rate(model):
    m = pricing.get(model, {})
    inp = m.get("inputPerM", defaults.get(model, (0,0))[0])
    out = m.get("outputPerM", defaults.get(model, (0,0))[1])
    return inp * split_in + out * split_out

def fmt_duration(ms):
    secs = ms // 1000
    mins = secs // 60
    rem = secs % 60
    if mins > 0 and rem > 0: return f"{mins}m {rem:02d}s"
    elif mins > 0: return f"{mins}m"
    else: return f"{rem}s"

def fmt_tokens(t):
    if t >= 1_000_000: return f"{t/1_000_000:.2f}M"
    elif t >= 1000: return f"{t//1000}K"
    else: return str(t)

def fmt_cost(dollars):
    return f"~\${dollars:.2f}"

with open("$dispatches_file") as f:
    dispatches = json.load(f)

# Compute per-row values
total_duration = 0
total_tokens = 0
total_cost = 0.0
breakdown_rows = []
phase_agg = {}

# Preserve phase insertion order
phase_order = []

for d in dispatches:
    model = d["model"]
    dur_ms = d["duration_ms"]
    tokens = d["tokens"]
    rate = blended_rate(model)
    cost = tokens / 1_000_000 * rate

    total_duration += dur_ms
    total_tokens += tokens
    total_cost += cost

    agent_label = d.get("agent", model.capitalize())
    task_label = d.get("task", f"Issue #{d.get('issue', '?')}")
    phase = d.get("phase", "Other")

    breakdown_rows.append(
        f"| {agent_label} | {task_label} | {fmt_duration(dur_ms)} | {fmt_tokens(tokens)} | {fmt_cost(cost)} |"
    )

    if phase not in phase_agg:
        phase_agg[phase] = {"duration_ms": 0, "tokens": 0, "cost": 0.0, "count": 0}
        phase_order.append(phase)
    phase_agg[phase]["duration_ms"] += dur_ms
    phase_agg[phase]["tokens"] += tokens
    phase_agg[phase]["cost"] += cost
    phase_agg[phase]["count"] += 1

# Build breakdown total row
breakdown_rows.append(
    f"| | **Total ({len(dispatches)} dispatches)** | **{fmt_duration(total_duration)}** | **{fmt_tokens(total_tokens)}** | **{fmt_cost(total_cost)}** |"
)

# Build summary rows
summary_rows = []
for phase in phase_order:
    a = phase_agg[phase]
    count_suffix = ""
    if a["count"] > 1:
        if phase == "Build":
            count_suffix = f" ({a['count']} stories)"
        else:
            count_suffix = f" ({a['count']} dispatches)"
    # Collect unique models in this phase from dispatches
    phase_models = list(dict.fromkeys(d["model"] for d in dispatches if d.get("phase") == phase))
    if len(phase_models) == 1:
        agent_desc = f"{phase_models[0]}{count_suffix}"
    else:
        agent_desc = f"mixed ({', '.join(phase_models)}){count_suffix}"
    summary_rows.append(
        f"| {phase} | {agent_desc} | {fmt_duration(a['duration_ms'])} | {fmt_tokens(a['tokens'])} | {fmt_cost(a['cost'])} |"
    )
summary_rows.append(
    f"| **Total** | | **{fmt_duration(total_duration)}** | **{fmt_tokens(total_tokens)}** | **{fmt_cost(total_cost)}** |"
)

result = {
    "breakdown": "\n".join(breakdown_rows),
    "summary": "\n".join(summary_rows),
    "cost": f"{total_cost:.2f}",
    "duration_ms": str(total_duration),
    "tokens": str(total_tokens),
}
json.dump(result, sys.stdout)
DISPEOF
  )

  # Parse the result and set variables
  BREAKDOWN=$(echo "$_dispatches_result" | jq -r '.breakdown')
  SUMMARY=$(echo "$_dispatches_result" | jq -r '.summary')
  COST_OVERRIDE=$(echo "$_dispatches_result" | jq -r '.cost')
  DURATION_MS=$(echo "$_dispatches_result" | jq -r '.duration_ms')
  TOKENS=$(echo "$_dispatches_result" | jq -r '.tokens')
}

if [ -n "$DISPATCHES_FILE" ] && [ -f "$DISPATCHES_FILE" ]; then
  _run_dispatches_computation "$DISPATCHES_FILE"
elif [ -n "$DISPATCHES_FROM_STATE" ] && [ -f "$DISPATCHES_FROM_STATE" ]; then
  # Convert orchestrator state file dispatches[] to the dispatches format.
  # Maps agent types to phases and generates human-readable task labels.
  _state_tmp=$(mktemp)
  trap "rm -f $_state_tmp" EXIT
  python3 << STATEEOF > "$_state_tmp"
import json, sys

with open("$DISPATCHES_FROM_STATE") as f:
    state = json.load(f)

agent_to_phase = {
    "designer": "Design",
    "planner": "Plan",
    "builder-haiku": "Build", "builder-sonnet": "Build", "builder-opus": "Build",
    "reviewer": "Review",
    "retro": "Retro",
}

# Build issue-to-title map from epics
issue_titles = {}
for epic_key, epic in state.get("epics", {}).items():
    for issue_num, story in epic.get("stories", {}).items():
        branch = story.get("branch", "")
        # Derive a short label from the branch name
        label = branch.replace(f"{epic_key}-", "").replace("/", " ").replace("-", " ").title()
        issue_titles[int(issue_num)] = label

dispatches = []
for d in state.get("dispatches", []):
    agent = d.get("agent", "unknown")
    model = d.get("model", "unknown")
    issue = d.get("issue")
    phase = agent_to_phase.get(agent, "Other")

    # Build human-readable agent label: "Builder (sonnet)" or "Reviewer (opus)"
    agent_base = agent.split("-")[0].capitalize()
    if agent_base == "Builder":
        agent_label = f"Builder ({model})"
    elif agent_base == "Reviewer":
        agent_label = f"Reviewer ({model})"
    else:
        agent_label = f"{agent_base.capitalize()} ({model})"

    # Build task label from issue titles or agent type
    if phase == "Design":
        task = f"Design Doc (#{issue})" if issue else "Design Doc"
    elif phase == "Plan":
        task = f"Plan Doc (#{issue})" if issue else "Plan Doc"
    elif phase == "Retro":
        task = f"Retrospective (#{issue})" if issue else "Retrospective"
    elif phase == "Review" and issue:
        if issue in issue_titles:
            title = issue_titles[issue]
            task = f"Review {title} (#{issue})"
        else:
            task = f"PR Review (#{issue})"
    elif issue and issue in issue_titles:
        task = f"{issue_titles[issue]} (#{issue})"
    elif issue:
        task = f"Issue #{issue}"
    else:
        task = agent

    dispatches.append({
        "agent": agent_label,
        "model": model,
        "task": task,
        "duration_ms": d.get("duration_ms", 0),
        "tokens": d.get("tokens", 0),
        "phase": phase,
    })

json.dump(dispatches, sys.stdout, indent=2)
STATEEOF
  _run_dispatches_computation "$_state_tmp"
  rm -f "$_state_tmp"
fi

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
# Reads pricing from .claude/agentic-sdlc-config.json via lib/config.sh.
# Use --rate to override with live rates from the orchestrator state file.
_cfg_blended_rate() {
  local model="$1"
  if [ -f "$_CFG_FILE" ]; then
    local inp out split_in split_out
    inp=$(jq -r ".pricing.${model}.inputPerM // empty" "$_CFG_FILE" 2>/dev/null) || inp=""
    out=$(jq -r ".pricing.${model}.outputPerM // empty" "$_CFG_FILE" 2>/dev/null) || out=""
    split_in=$(jq -r '.pricing.tokenSplit.input // empty' "$_CFG_FILE" 2>/dev/null) || split_in=""
    split_out=$(jq -r '.pricing.tokenSplit.output // empty' "$_CFG_FILE" 2>/dev/null) || split_out=""
    if [ -n "$inp" ] && [ -n "$out" ]; then
      # Compute blended rate in cents/M: (input * split_in + output * split_out) * 100
      echo "$inp $out ${split_in:-0.75} ${split_out:-0.25}" | awk '{printf "%d", ($1 * $3 + $2 * $4) * 100}'
      return
    fi
  fi
  # Fallback defaults
  case "$model" in
    opus)   echo "3000" ;;
    sonnet) echo "600" ;;
    haiku)  echo "200" ;;
    *)      echo "0" ;;
  esac
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

# Detect mode: backlog (--summary provided) vs story/epic (default)
IS_BACKLOG=false
if [ -n "$SUMMARY" ]; then
  IS_BACKLOG=true
fi

# ─── Template rendering ──────────────────────────────────────────────────────

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

RENDERED=$(render_template "$TEMPLATE_FILE" "📊 Telemetry")
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
