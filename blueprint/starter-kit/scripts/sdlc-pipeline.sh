#!/bin/bash
# =============================================================================
# sdlc-pipeline.sh — Full SDLC pipeline with entry points, DAG execution,
#                     retry with model escalation, and cost-mode selection
#
# Usage:
#   ./sdlc-pipeline.sh <feature-description> [flags]
#
# Flags:
#   --entry <full|design|plan|build>   Pipeline entry point (default: full)
#   --cost-mode <standard|economy>     Model tier selection (default: standard)
#   --autonomy <supervised|autonomous> Checkpoint behavior (default: supervised)
#   --docs <manifest>                  Existing doc manifest (for --entry design/plan)
#   --resume-from <stage>              Resume from a specific stage
#   --task <spec-file>                 Single task spec (for --entry build)
#
# Examples:
#   ./sdlc-pipeline.sh "Add Stripe billing integration"
#   ./sdlc-pipeline.sh "Add dark mode" --cost-mode economy
#   ./sdlc-pipeline.sh "Fix timezone bug" --entry build --task ".claude/context/tasks/fix-tz.md"
# =============================================================================
set -euo pipefail

FEATURE="${1:?Usage: sdlc-pipeline.sh <feature> [--entry X] [--cost-mode X] [--autonomy X] [--docs X] [--resume-from X] [--task X]}"
ENTRY="full"
COST_MODE="standard"
AUTONOMY="supervised"
DOC_MANIFEST=""
RESUME_FROM=""
TASK_SPEC=""

# Parse flags
while [[ $# -gt 1 ]]; do
  case "$2" in
    --entry) ENTRY="$3"; shift 2;;
    --cost-mode) COST_MODE="$3"; shift 2;;
    --autonomy) AUTONOMY="$3"; shift 2;;
    --docs) DOC_MANIFEST="$3"; shift 2;;
    --resume-from) RESUME_FROM="$3"; shift 2;;
    --task) TASK_SPEC="$3"; shift 2;;
    *) shift;;
  esac
done

# ---------------------------------------------------------------------------
# Model selection based on cost mode
# ---------------------------------------------------------------------------
model_for() {
  local agent="$1"
  case "$COST_MODE" in
    economy)
      case "$agent" in
        visionary|planner) echo "sonnet";;
        *) echo "opus";;
      esac;;
    *) # standard
      case "$agent" in
        builder|tester) echo "sonnet";;
        *) echo "opus";;
      esac;;
  esac
}

# ---------------------------------------------------------------------------
# Retry with model escalation
# ---------------------------------------------------------------------------
run_with_retry() {
  local task_file="$1"
  local model="sonnet"
  local max_retries=3
  local error_context=""

  for attempt in $(seq 1 $((max_retries + 1))); do
    # Escalate to Opus on final attempt
    if [ $attempt -gt $max_retries ]; then
      model="opus"
      echo "Escalating to Opus for task $(basename "$task_file")"
    fi

    # Success = claude exits 0 and the JSON result is not flagged is_error.
    # (The JSON output has no `.success` field; stderr is kept out of the JSON.)
    if result=$(claude -p "Implement task from spec: $task_file. $error_context" \
      --model "$model" \
      --allowedTools "Read" "Write" "Edit" "Bash(npm run *)" "Bash(git add *)" "Bash(git commit *)" \
      --permission-mode acceptEdits \
      --max-turns 50 \
      --output-format json) \
      && ! echo "$result" | jq -e '.is_error == true' > /dev/null 2>&1; then
      return 0
    fi

    error_context="Previous attempt failed with: $(echo "$result" | jq -r '.error // .result' | tail -20). Fix the issues."
    echo "Attempt $attempt failed for $(basename "$task_file"). Retrying..."
  done

  echo "Task $(basename "$task_file") failed after $((max_retries + 1)) attempts including Opus escalation"
  return 1
}

# ---------------------------------------------------------------------------
# Checkpoint — pause for human approval unless autonomous
# ---------------------------------------------------------------------------
run_checkpoint() {
  local stage="$1" output="$2"
  [ "$AUTONOMY" = "autonomous" ] && return 0
  echo "$output" | jq . 2>/dev/null || echo "$output"
  echo ""
  echo "Options: [y] approve  [e] edit and re-run  [n] abort"
  read -p "Checkpoint $stage: " choice
  case "$choice" in
    e) echo "Edit docs, then: ./sdlc-pipeline.sh '$FEATURE' --resume-from $stage"; exit 0;;
    y) return 0;;
    *) echo "Aborted."; exit 1;;
  esac
}

# ---------------------------------------------------------------------------
# Initialize run manifest
# ---------------------------------------------------------------------------
RUN_ID="run_$(date +%s)"
RUN_MANIFEST=".claude/context/runs/${RUN_ID}.json"
mkdir -p .claude/context/runs .claude/context/tasks .claude/context/status
echo '{"run_id":"'"$RUN_ID"'","feature":"'"$FEATURE"'","started_at":"'"$(date -Iseconds)"'","stages":[]}' > "$RUN_MANIFEST"

# ---------------------------------------------------------------------------
# Resume support — skip stages until we reach the resume point
# ---------------------------------------------------------------------------
should_run() {
  local stage="$1"
  [ -n "$RESUME_FROM" ] && [ "$RESUME_FROM" != "$stage" ] && return 1
  [ -n "$RESUME_FROM" ] && RESUME_FROM="" # Clear after first match
  return 0
}

# ===========================================================================
# Stage 1: Visionary
# ===========================================================================
if [ "$ENTRY" = "full" ] && should_run "visionary"; then
  echo "Visionary: Producing product docs..."
  DOC_MANIFEST=$(claude -p "You are the Visionary agent. Goal: '$FEATURE'. \
    Load templates from .claude/templates/. Produce PRFAQ, PRD, Product Vision. \
    Write to doc tool. Output JSON manifest." \
    --model "$(model_for visionary)" \
    --output-format json \
    --allowedTools "Read" "Grep" "Glob" "WebFetch" "mcp__docs__create_page" "mcp__docs__search" \
    --max-turns 25 \
    | jq -r '.result')
  run_checkpoint "visionary" "$DOC_MANIFEST"
fi

# ===========================================================================
# Stage 2: Architect
# ===========================================================================
if [ "$ENTRY" = "full" ] || [ "$ENTRY" = "design" ]; then
  if should_run "architect"; then
    echo "Architect: Producing technical design..."
    TECH_MANIFEST=$(claude -p "You are the Architect agent. \
      Read product docs: $DOC_MANIFEST. Deep-dive codebase. Search past ADRs. \
      Load templates. Produce HLD, LLD, ADRs. Write to doc tool. Output JSON manifest." \
      --model "$(model_for architect)" \
      --output-format json \
      --allowedTools "Read" "Grep" "Glob" "Bash(find:*)" "Bash(tree:*)" "Bash(wc:*)" "WebFetch" \
        "mcp__docs__get_page" "mcp__docs__create_page" "mcp__docs__search" \
      --max-turns 40 \
      | jq -r '.result')
    DOC_MANIFEST=$(echo "[$DOC_MANIFEST,$TECH_MANIFEST]" | jq -s 'flatten')
    run_checkpoint "architect" "$TECH_MANIFEST"
  fi
fi

# ===========================================================================
# Stage 3: Planner
# ===========================================================================
if [ "$ENTRY" != "build" ]; then
  if should_run "planner"; then
    echo "Planner: Creating epics, stories, task specs..."
    PLAN=$(claude -p "You are the Planner agent. \
      Read docs: $DOC_MANIFEST. Create epic, stories, task specs with dependency DAG. \
      Write specs to .claude/context/tasks/. Output JSON task manifest with DAG." \
      --model "$(model_for planner)" \
      --output-format json \
      --allowedTools "Read" "Grep" "Glob" "Bash(find:*)" "Write" \
        "mcp__docs__get_page" "mcp__docs__search" \
        "mcp__pm__create_issue" "mcp__pm__search_issues" \
      --max-turns 40 \
      | jq -r '.result')
    run_checkpoint "planner" "$PLAN"
  fi
fi

# ===========================================================================
# Stage 4: Builder (DAG-aware with retry)
# ===========================================================================
echo "Builder: Implementing tasks (DAG-aware)..."
if [ -n "${TASK_SPEC:-}" ]; then
  run_with_retry "$TASK_SPEC"
else
  TASK_MANIFEST=".claude/context/task-manifest.json"
  echo "$PLAN" > "$TASK_MANIFEST"

  completed=()
  while true; do
    # Ready = not yet completed, and every dependency already completed.
    ready=$(jq -r --argjson done "$(printf '%s\n' "${completed[@]:-}" | jq -R . | jq -s .)" \
      '.dag | to_entries[] | select((.key as $k | $done | index($k) | not) and ((.value - $done) == [])) | .key' \
      "$TASK_MANIFEST" 2>/dev/null)
    [ -z "$ready" ] && break

    echo "Wave: $ready"
    pids=()
    for task_id in $ready; do
      task_file=".claude/context/tasks/${task_id}.md"
      git worktree add "../wt-$task_id" -b "feat/$task_id" main 2>/dev/null || true
      (cd "../wt-$task_id" && run_with_retry "$task_file") &
      pids+=($!)
    done
    # Halt the whole run if any task in the wave failed.
    wave_failed=0
    for pid in "${pids[@]}"; do
      wait "$pid" || wave_failed=1
    done
    if [ "$wave_failed" -ne 0 ]; then
      echo "A task in this wave failed. Halting before the next wave."
      exit 1
    fi
    completed+=($ready)
  done
fi

# ===========================================================================
# Stage 5: Tester
# ===========================================================================
echo "Tester: Writing and running tests..."
for task_file in .claude/context/tasks/*.md; do
  name=$(basename "$task_file" .md)
  [ -d "../wt-$name" ] || continue
  (
    cd "../wt-$name"
    claude -p "Write comprehensive tests. Run full suite. Fix failures." \
      --model sonnet \
      --allowedTools "Read" "Write" "Edit" "Bash(npm run test *)" "Bash(pytest *)" \
      --permission-mode acceptEdits \
      --max-turns 30
  ) &
done
wait

# ===========================================================================
# Stage 6: Reviewer (with integration test)
# ===========================================================================
echo "Reviewer: Code review plus integration test..."
claude -p "Review all feature branches. Read HLD/LLD/ADRs from docs. \
  Check quality, security, architecture alignment. \
  Merge all branches into temp integration branch, run full suite. \
  Output structured review." \
  --model opus \
  --allowedTools "Read" "Grep" "Glob" "Bash(git *)" \
    "mcp__docs__get_page" "mcp__docs__search" "mcp__pm__add_comment" \
  --output-format json \
  --max-turns 20

echo "Pipeline complete. Run manifest: $RUN_MANIFEST"
