#!/usr/bin/env bash
set -euo pipefail

# dispatch-workflow.sh — Orchestrate a full backlog item lifecycle:
#   design → plan → build → review → epic PR → retro.
#
# Usage: ./scripts/dispatch-workflow.sh <backlog-issue-number> [--skip-design] [--skip-plan] [--autonomous] [--epic <eNN-slug>]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"
REPO="$CFG_REPO"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
if [ $# -lt 1 ]; then
  echo "Usage: $0 <backlog-issue-number> [--skip-design] [--skip-plan] [--autonomous] [--epic <eNN-slug>]"
  exit 1
fi

BACKLOG_ISSUE="$1"
shift

SKIP_DESIGN=false
SKIP_PLAN=false
AUTONOMOUS=false
EPIC_SLUG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-design) SKIP_DESIGN=true;  shift ;;
    --skip-plan)   SKIP_PLAN=true;    shift ;;
    --autonomous)  AUTONOMOUS=true;   shift ;;
    --epic)        EPIC_SLUG="$2";    shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers (must be defined before first use)
# ---------------------------------------------------------------------------
log_phase() {
  local phase="$1"
  local message="$2"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo ""
  echo "========================================================================"
  echo "  [$timestamp] Phase $phase: $message"
  echo "========================================================================"
  echo ""
}

log_step() {
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "  [$timestamp] $1"
}

difficulty_to_model() {
  local label="$1"
  case "$label" in
    difficulty/easy)   echo "$CFG_ROUTE_EASY"   ;;
    difficulty/medium) echo "$CFG_ROUTE_MEDIUM" ;;
    difficulty/hard)   echo "$CFG_ROUTE_HARD"   ;;
    *)                 echo "$CFG_ROUTE_MEDIUM" ;;
  esac
}

set_board_status() {
  local issue_number="$1"
  local status_name="$2"
  if "$SCRIPT_DIR/item-set-status.sh" "$issue_number" "$status_name"; then
    log_step "Board status updated for issue #$issue_number → $status_name"
  else
    log_step "Warning: Board status update failed for issue #$issue_number"
  fi
}

format_duration_human() {
  local ms="$1"
  local secs=$(( ms / 1000 ))
  local mins=$(( secs / 60 ))
  local remaining_secs=$(( secs % 60 ))
  if [ "$mins" -gt 0 ] && [ "$remaining_secs" -gt 0 ]; then
    echo "${mins}m ${remaining_secs}s"
  elif [ "$mins" -gt 0 ]; then
    echo "${mins}m"
  else
    echo "${remaining_secs}s"
  fi
}

# Derive a branch-safe slug from an issue title, stripping the [ENN-SNN] prefix
title_to_slug() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/\[#[0-9]*\/e[0-9]*-s[0-9]*\] *//;s/\[e[0-9]*-s[0-9]*\] *//' \
    | sed 's/[^a-z0-9]/-/g' \
    | sed 's/-\{2,\}/-/g' \
    | sed 's/^-//;s/-$//'
}

# Extract the epic/story tag (e.g. "e01-s02") from a title like "[E01-S02] Create foo"
extract_story_tag() {
  echo "$1" | grep -oiE 'E[0-9]+-S[0-9]+' | head -1 | tr '[:upper:]' '[:lower:]' || echo ""
}

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
if ! command -v claude &>/dev/null; then
  echo "Error: 'claude' CLI not found in PATH."
  exit 1
fi

# Detect nested Claude Code session. The CC CLI sets CLAUDECODE to prevent
# recursive launches, but we intentionally spawn independent builder/reviewer
# processes on separate branches — no shared state with the parent session.
run_claude() {
  if [ -n "${CLAUDECODE:-}" ]; then
    env -u CLAUDECODE claude "$@"
  else
    claude "$@"
  fi
}

if [ -n "${CLAUDECODE:-}" ]; then
  log_step "Note: running inside a Claude Code session — child processes will bypass nested session check."
fi

if ! command -v gh &>/dev/null; then
  echo "Error: 'gh' CLI not found in PATH."
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: 'jq' not found in PATH."
  exit 1
fi

# ---------------------------------------------------------------------------
# Fetch backlog issue metadata
# ---------------------------------------------------------------------------
log_phase "0" "Preparing workflow for backlog item #$BACKLOG_ISSUE"

BACKLOG_JSON=$(gh issue view "$BACKLOG_ISSUE" --repo "$REPO" --json title,body,labels)
BACKLOG_TITLE=$(echo "$BACKLOG_JSON" | jq -r '.title')
log_step "Backlog item: $BACKLOG_TITLE"

# Global telemetry accumulators (initialized early so Phase 4 can reference them
# even if the build phase was skipped or had no stories)
TOTAL_DURATION_MS=0
HIGHEST_MODEL="haiku"
BREAKDOWN=""
COMPLETED_ISSUES=""
EPIC_ISSUE=""

# ---------------------------------------------------------------------------
# Phase 1: Design
# ---------------------------------------------------------------------------
if [ "$SKIP_DESIGN" = true ]; then
  log_phase "1" "Design (SKIPPED via --skip-design)"
else
  log_phase "1" "Design"
  log_step "Dispatching designer agent for backlog item #$BACKLOG_ISSUE..."

  DESIGN_PROMPT="Design a feature for backlog item #$BACKLOG_ISSUE ($BACKLOG_TITLE). Read the backlog issue on GitHub for full context."
  if [ "$AUTONOMOUS" = true ]; then
    DESIGN_PROMPT="autonomous — $DESIGN_PROMPT"
  fi

  DESIGN_EXIT=0
  run_claude -p "$DESIGN_PROMPT" \
    --agent designer \
    --model sonnet \
    --output-format json \
    || DESIGN_EXIT=$?

  if [ "$DESIGN_EXIT" -ne 0 ]; then
    log_step "ERROR: Designer agent exited with code $DESIGN_EXIT"
    exit "$DESIGN_EXIT"
  fi

  log_step "Designer complete."

  if [ "$AUTONOMOUS" = true ]; then
    # Auto-merge the design doc PR
    log_step "Autonomous mode: auto-merging design doc PR..."
    OPEN_DESIGN_PR=$(gh pr list --repo "$REPO" --state open --limit 10 --json number,headRefName \
      | jq -r "[.[] | select(.headRefName | startswith(\"docs/\"))] | .[0].number // empty")

    if [ -n "$OPEN_DESIGN_PR" ]; then
      if gh pr merge "$OPEN_DESIGN_PR" --repo "$REPO" --merge --delete-branch; then
        log_step "Design doc PR #$OPEN_DESIGN_PR auto-merged."
        git checkout main && git pull origin main
      else
        log_step "ERROR: Failed to auto-merge design PR #$OPEN_DESIGN_PR. Manual resolution required."
        exit 1
      fi
    else
      log_step "No open design PR found — may have been merged already."
    fi
  else
    # Interactive mode: poll for human merge
    log_step "Waiting for design doc PR to be merged (human approval gate)..."

    while true; do
      DESIGN_PR=$(gh pr list --repo "$REPO" --state merged --limit 10 --json number,headRefName \
        | jq -r "[.[] | select(.headRefName | startswith(\"docs/\"))] | .[0].number // empty")

      if [ -n "$DESIGN_PR" ]; then
        log_step "Design doc PR #$DESIGN_PR has been merged. Proceeding to Phase 2."
        break
      fi

      OPEN_DESIGN_PR=$(gh pr list --repo "$REPO" --state open --limit 10 --json number,headRefName \
        | jq -r "[.[] | select(.headRefName | startswith(\"docs/\"))] | .[0].number // empty")

      if [ -n "$OPEN_DESIGN_PR" ]; then
        log_step "Design PR #$OPEN_DESIGN_PR is open. Waiting for human to merge..."
      else
        log_step "No design PR found yet. Waiting..."
      fi

      sleep 30
    done
  fi
fi

# ---------------------------------------------------------------------------
# Phase 2: Plan
# ---------------------------------------------------------------------------
if [ "$SKIP_PLAN" = true ]; then
  log_phase "2" "Plan (SKIPPED via --skip-plan)"
else
  log_phase "2" "Plan"
  log_step "Dispatching planner agent for backlog item #$BACKLOG_ISSUE..."

  PLAN_PROMPT="Create an implementation plan for backlog item #$BACKLOG_ISSUE ($BACKLOG_TITLE). Read the backlog issue and design doc for full context."
  if [ "$AUTONOMOUS" = true ]; then
    PLAN_PROMPT="autonomous — $PLAN_PROMPT"
  fi

  PLAN_EXIT=0
  run_claude -p "$PLAN_PROMPT" \
    --agent planner \
    --model sonnet \
    --output-format json \
    || PLAN_EXIT=$?

  if [ "$PLAN_EXIT" -ne 0 ]; then
    log_step "ERROR: Planner agent exited with code $PLAN_EXIT"
    exit "$PLAN_EXIT"
  fi

  log_step "Planner complete."

  if [ "$AUTONOMOUS" = true ]; then
    # Auto-merge the plan PR
    log_step "Autonomous mode: auto-merging plan PR..."
    OPEN_PLAN_PR=$(gh pr list --repo "$REPO" --state open --limit 10 --json number,headRefName \
      | jq -r "[.[] | select(.headRefName | startswith(\"docs/\"))] | sort_by(.number) | reverse | .[0].number // empty")

    if [ -n "$OPEN_PLAN_PR" ]; then
      if gh pr merge "$OPEN_PLAN_PR" --repo "$REPO" --merge --delete-branch; then
        log_step "Plan PR #$OPEN_PLAN_PR auto-merged."
        git checkout main && git pull origin main
      else
        log_step "ERROR: Failed to auto-merge plan PR #$OPEN_PLAN_PR. Manual resolution required."
        exit 1
      fi
    else
      log_step "No open plan PR found — may have been merged already."
    fi
  else
    # Interactive mode: poll for human merge
    log_step "Waiting for plan PR to be merged (human approval gate)..."

    while true; do
      PLAN_PR=$(gh pr list --repo "$REPO" --state merged --limit 10 --json number,headRefName \
        | jq -r "[.[] | select(.headRefName | startswith(\"docs/\"))] | sort_by(.number) | reverse | .[0].number // empty")

      if [ -n "$PLAN_PR" ]; then
        log_step "Plan PR #$PLAN_PR has been merged. Proceeding to Phase 3."
        break
      fi

      OPEN_PLAN_PR=$(gh pr list --repo "$REPO" --state open --limit 10 --json number,headRefName \
        | jq -r "[.[] | select(.headRefName | startswith(\"docs/\"))] | .[0].number // empty")

      if [ -n "$OPEN_PLAN_PR" ]; then
        log_step "Plan PR #$OPEN_PLAN_PR is open. Waiting for human to merge..."
      else
        log_step "No plan PR found yet. Waiting..."
      fi

      sleep 30
    done
  fi
fi

# ---------------------------------------------------------------------------
# Phase 3: Build
# ---------------------------------------------------------------------------
log_phase "3" "Build"

# Discover epic slug if not provided via --epic
if [ -z "$EPIC_SLUG" ]; then
  log_step "No --epic provided. Discovering epic from backlog item's sub-issues..."
  # Scope to this backlog item's issues only (via sub-issue hierarchy) to avoid
  # picking up epics from other features when multiple are in progress.
  # Find sub-issues tagged with hierarchy/epic and parse the slug from their title.
  EPIC_TITLE=$(gh issue view "$BACKLOG_ISSUE" --repo "$REPO" --json body \
    | jq -r '.body' \
    | grep -oE '#[0-9]+' \
    | tr -d '#' \
    | while read -r sub_num; do
        gh issue view "$sub_num" --repo "$REPO" --json title,labels 2>/dev/null \
          | jq -r 'select(.labels[].name == "hierarchy/epic") | .title' 2>/dev/null || true
      done \
    | head -1)

  # Fallback: if sub-issue discovery fails, search by backlog label for hierarchy/epic issues
  if [ -z "$EPIC_TITLE" ]; then
    BACKLOG_LABEL=$(gh issue view "$BACKLOG_ISSUE" --repo "$REPO" --json labels \
      | jq -r '[.labels[].name | select(startswith("backlog/"))] | first // empty')
    if [ -n "$BACKLOG_LABEL" ]; then
      EPIC_TITLE=$(gh issue list --repo "$REPO" --label "$BACKLOG_LABEL" --label "hierarchy/epic" --state open --limit 50 --json title \
        | jq -r '.[0].title // empty')
    fi
  fi

  if [ -z "$EPIC_TITLE" ]; then
    echo "Error: No epic issue found. Provide --epic <eNN-slug> or ensure the planner created epic issues with the hierarchy/epic label."
    exit 1
  fi

  # Derive the epic slug from the epic issue title (e.g. "[#5/E01] My Epic" → "e01-my-epic")
  EPIC_NUM=$(echo "$EPIC_TITLE" | grep -oiE 'E[0-9]+' | head -1 | tr '[:upper:]' '[:lower:]')
  EPIC_TITLE_SLUG=$(echo "$EPIC_TITLE" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/\[#[0-9]*\/e[0-9]*\] *//;s/\[e[0-9]*\] *//' \
    | sed 's/[^a-z0-9]/-/g' \
    | sed 's/-\{2,\}/-/g' \
    | sed 's/^-//;s/-$//')
  EPIC_SLUG="${EPIC_NUM}-${EPIC_TITLE_SLUG}"
  log_step "Discovered epic: $EPIC_SLUG"
fi

EPIC_BRANCH="epic/$EPIC_SLUG"

log_step "Epic branch: $EPIC_BRANCH"

# Find the epic issue number using the hierarchy/epic label and backlog label
BACKLOG_LABEL=$(gh issue view "$BACKLOG_ISSUE" --repo "$REPO" --json labels \
  | jq -r '[.labels[].name | select(startswith("backlog/"))] | first // empty')

EPIC_ISSUE=""
if [ -n "$BACKLOG_LABEL" ]; then
  EPIC_ISSUE=$(gh issue list --repo "$REPO" --label "$BACKLOG_LABEL" --label "hierarchy/epic" --state open --limit 50 --json number,title \
    | jq -r '[.[] | select(.title | test("^\\[#?[0-9]*/?(E[0-9]+)\\]"; "i"))] | .[0].number // empty')
fi

if [ -z "$EPIC_ISSUE" ]; then
  log_step "Warning: Could not find epic issue for $EPIC_SLUG. Epic telemetry will be skipped."
fi

# Ensure the epic branch exists
if ! git rev-parse --verify "$EPIC_BRANCH" &>/dev/null && ! git rev-parse --verify "origin/$EPIC_BRANCH" &>/dev/null; then
  log_step "Creating epic branch: $EPIC_BRANCH"
  git checkout main
  git pull origin main
  git checkout -b "$EPIC_BRANCH"
  git push -u origin "$EPIC_BRANCH"
else
  log_step "Epic branch $EPIC_BRANCH already exists"
fi

# Get all story issues for this epic using the backlog label + hierarchy/story label,
# then filter by title to those belonging to this specific epic (matching EPIC_NUM prefix).
EPIC_NUM_UPPER=$(echo "$EPIC_SLUG" | grep -oiE '^e[0-9]+' | tr '[:lower:]' '[:upper:]')
log_step "Fetching stories for epic $EPIC_SLUG (title prefix: $EPIC_NUM_UPPER)..."
if [ -n "$BACKLOG_LABEL" ]; then
  STORIES_JSON=$(gh issue list --repo "$REPO" --label "$BACKLOG_LABEL" --label "hierarchy/story" --state open --limit 50 --json number,title,labels)
else
  # No backlog label found; fall back to fetching all hierarchy/story issues and filtering by title
  STORIES_JSON=$(gh issue list --repo "$REPO" --label "hierarchy/story" --state open --limit 100 --json number,title,labels)
fi

# Filter to story issues belonging to this epic (title starts with [#N/ENN-SNN] or [ENN-SNN])
STORY_NUMBERS=$(echo "$STORIES_JSON" \
  | jq -r --arg epic_prefix "$EPIC_NUM_UPPER" \
    '[.[] | select(.title | test("^\\[#?[0-9]*/?(" + $epic_prefix + "-S[0-9]+)\\]"; "i"))] | sort_by(.title) | .[].number')

if [ -z "$STORY_NUMBERS" ]; then
  log_step "No open stories found for epic $EPIC_SLUG. Skipping build phase."
else
  STORY_COUNT=$(echo "$STORY_NUMBERS" | wc -l | tr -d ' ')
  log_step "Found $STORY_COUNT stories to build"

  for STORY_NUM in $STORY_NUMBERS; do
    STORY_JSON=$(gh issue view "$STORY_NUM" --repo "$REPO" --json title,labels,state)
    STORY_TITLE=$(echo "$STORY_JSON" | jq -r '.title')
    STORY_STATE=$(echo "$STORY_JSON" | jq -r '.state')

    # Idempotent restart: skip already-closed stories
    if [ "$STORY_STATE" = "CLOSED" ]; then
      log_step "Story #$STORY_NUM ($STORY_TITLE) is already closed. Skipping."
      continue
    fi

    DIFFICULTY=$(echo "$STORY_JSON" | jq -r '[.labels[].name | select(startswith("difficulty/"))] | first // "difficulty/medium"')
    MODEL=$(difficulty_to_model "$DIFFICULTY")
    log_step "--- Story #$STORY_NUM: $STORY_TITLE (difficulty=$DIFFICULTY, model=$MODEL) ---"

    # Update epic board status to In Progress
    if [ -n "$EPIC_ISSUE" ]; then
      set_board_status "$EPIC_ISSUE" "in-progress"
    fi

    # Dispatch builder
    STORY_START=$SECONDS
    BUILD_EXIT=0

    "$SCRIPT_DIR/dispatch-story.sh" "$STORY_NUM" \
      --model "$MODEL" \
      --agent builder \
      --epic-branch "$EPIC_BRANCH" \
      || BUILD_EXIT=$?

    STORY_ELAPSED=$(( SECONDS - STORY_START ))
    STORY_DURATION_MS=$(( STORY_ELAPSED * 1000 ))

    if [ "$BUILD_EXIT" -ne 0 ]; then
      log_step "ERROR: Builder failed for story #$STORY_NUM (exit code $BUILD_EXIT)"
      log_step "Workflow halted. Fix the issue and re-run with the same arguments."
      exit "$BUILD_EXIT"
    fi

    log_step "Builder succeeded for story #$STORY_NUM"

    # Dispatch reviewer on the story branch before merging into epic
    log_step "Dispatching reviewer for story #$STORY_NUM..."

    STORY_TAG=$(extract_story_tag "$STORY_TITLE")
    STORY_TITLE_SLUG=$(title_to_slug "$STORY_TITLE")
    STORY_BRANCH="${STORY_TAG}/${STORY_TITLE_SLUG}"

    REVIEW_EXIT=0
    run_claude -p "Review story #$STORY_NUM ($STORY_TITLE) on branch $STORY_BRANCH against epic branch $EPIC_BRANCH. Post findings as a comment on issue #$STORY_NUM." \
      --agent "reviewer" \
      --output-format json \
      || REVIEW_EXIT=$?

    if [ "$REVIEW_EXIT" -ne 0 ]; then
      log_step "Warning: Reviewer exited with code $REVIEW_EXIT for story #$STORY_NUM. Continuing."
    else
      log_step "Review complete for story #$STORY_NUM"
    fi

    # Merge story branch into epic branch
    log_step "Merging story branch $STORY_BRANCH into $EPIC_BRANCH..."
    git checkout "$EPIC_BRANCH" 2>/dev/null || git checkout -b "$EPIC_BRANCH" "origin/$EPIC_BRANCH"
    git pull origin "$EPIC_BRANCH" 2>/dev/null || true

    if git merge --no-ff "origin/$STORY_BRANCH" -m "chore(epic): merge $STORY_BRANCH into $EPIC_BRANCH"; then
      git push origin "$EPIC_BRANCH"
      log_step "Merged $STORY_BRANCH into $EPIC_BRANCH"
    else
      log_step "Warning: Merge of $STORY_BRANCH failed. Manual resolution may be needed."
      git merge --abort 2>/dev/null || true
    fi

    # Accumulate telemetry
    TOTAL_DURATION_MS=$(( TOTAL_DURATION_MS + STORY_DURATION_MS ))

    case "$MODEL" in
      opus)   HIGHEST_MODEL="opus" ;;
      sonnet) [ "$HIGHEST_MODEL" != "opus" ] && HIGHEST_MODEL="sonnet" ;;
    esac

    DURATION_HUMAN=$(format_duration_human "$STORY_DURATION_MS")
    BREAKDOWN="${BREAKDOWN}| ${STORY_TAG} (#${STORY_NUM}) | ${MODEL} | ${DURATION_HUMAN} | -- | -- |
"
    COMPLETED_ISSUES="${COMPLETED_ISSUES} ${STORY_NUM}"

    log_step "Story #$STORY_NUM complete"
  done
fi

# ---------------------------------------------------------------------------
# Phase 4: Close (epic PR + telemetry)
# ---------------------------------------------------------------------------
log_phase "4" "Close"

# Build Closes links for the PR body (backlog + epic + all stories)
CLOSES_LINKS="Closes #$BACKLOG_ISSUE"
if [ -n "$EPIC_ISSUE" ]; then
  CLOSES_LINKS="$CLOSES_LINKS, closes #$EPIC_ISSUE"
fi

for ISSUE_NUM in $COMPLETED_ISSUES; do
  if [ -n "$CLOSES_LINKS" ]; then
    CLOSES_LINKS="$CLOSES_LINKS, closes #$ISSUE_NUM"
  else
    CLOSES_LINKS="Closes #$ISSUE_NUM"
  fi
done

log_step "Opening epic PR from $EPIC_BRANCH to main..."

EPIC_PR=""
EXISTING_PR=$(gh pr list --repo "$REPO" --head "$EPIC_BRANCH" --base main --state open --json number -q '.[0].number // empty' 2>/dev/null || echo "")

if [ -n "$EXISTING_PR" ]; then
  log_step "Epic PR #$EXISTING_PR already exists"
  EPIC_PR="$EXISTING_PR"
else
  PR_BODY="## Summary

Full implementation of epic \`$EPIC_SLUG\` for backlog item #$BACKLOG_ISSUE.

$CLOSES_LINKS"

  EPIC_PR=$(gh pr create --repo "$REPO" \
    --head "$EPIC_BRANCH" \
    --base main \
    --title "Epic: $EPIC_SLUG" \
    --body "$PR_BODY" 2>/dev/null | grep -oE '[0-9]+$' || echo "")

  if [ -n "$EPIC_PR" ]; then
    log_step "Created epic PR #$EPIC_PR"
  else
    log_step "Warning: Could not create epic PR. It may need to be created manually."
  fi
fi

# Post epic telemetry
if [ -n "$EPIC_ISSUE" ] && [ "$TOTAL_DURATION_MS" -gt 0 ]; then
  EPIC_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

  TELEMETRY_ARGS=(
    "$EPIC_ISSUE"
    --model "$HIGHEST_MODEL"
    --duration "$TOTAL_DURATION_MS"
    --commit "$EPIC_COMMIT"
  )

  if [ -n "$EPIC_PR" ]; then
    TELEMETRY_ARGS+=(--pr "$EPIC_PR")
  fi

  if [ -n "$BREAKDOWN" ]; then
    TOTAL_DURATION_HUMAN=$(format_duration_human "$TOTAL_DURATION_MS")
    FULL_BREAKDOWN="${BREAKDOWN}| **Total** | | **${TOTAL_DURATION_HUMAN}** | -- | -- |"
    TELEMETRY_ARGS+=(--breakdown "$FULL_BREAKDOWN")
  fi

  log_step "Posting epic telemetry..."
  "$SCRIPT_DIR/item-telemetry.sh" "${TELEMETRY_ARGS[@]}" || log_step "Warning: Epic telemetry post failed"
fi

# Update epic board status to In Review
if [ -n "$EPIC_ISSUE" ]; then
  set_board_status "$EPIC_ISSUE" "in-review"
fi

# ---------------------------------------------------------------------------
# Phase 5: Retro
# ---------------------------------------------------------------------------
log_phase "5" "Retro"

log_step "Dispatching retro agent for epic $EPIC_SLUG..."

RETRO_EXIT=0
run_claude -p "Run a retrospective for epic $EPIC_SLUG (backlog item #$BACKLOG_ISSUE). Analyze lessons, telemetry, and review findings. Write a retro doc and propose convention changes if warranted." \
  --agent retro \
  --model sonnet \
  --output-format json \
  || RETRO_EXIT=$?

if [ "$RETRO_EXIT" -ne 0 ]; then
  log_step "Warning: Retro agent exited with code $RETRO_EXIT. The retro can be run manually later."
else
  log_step "Retro complete"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
log_phase "DONE" "Workflow complete for backlog item #$BACKLOG_ISSUE"

if [ -n "$EPIC_PR" ]; then
  log_step "Epic PR: https://github.com/$REPO/pull/$EPIC_PR"
fi
log_step "Next step: Human reviews and merges the epic PR."
