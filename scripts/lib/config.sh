#!/usr/bin/env bash
# config.sh — Shared config reader for agentic SDLC workflow scripts.
#
# Sources configuration from .claude/agentic-sdlc-config.json with fallback
# defaults for every value. Scripts source this file to get standard variables.
#
# Usage (from any script in scripts/):
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/lib/config.sh"
#
# After sourcing, these variables are available:
#   CFG_REPO, CFG_PROJECT_NUMBER, CFG_PROJECT_OWNER,
#   CFG_PROJECT_ID, CFG_STATUS_FIELD_ID,
#   CFG_STATUS_BACKLOG, CFG_STATUS_PLANNED, CFG_STATUS_TODO,
#   CFG_STATUS_IN_PROGRESS, CFG_STATUS_IN_REVIEW, CFG_STATUS_DONE,
#   CFG_ROUTE_EASY, CFG_ROUTE_MEDIUM, CFG_ROUTE_HARD

# Locate config file relative to the repo root
_CFG_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
_CFG_FILE="$_CFG_REPO_ROOT/.claude/agentic-sdlc-config.json"

# Helper: read a JSON field with a fallback default.
# Usage: _cfg <jq-path> <default>
_cfg() {
  local path="$1" default="$2"
  if [ -f "$_CFG_FILE" ]; then
    local val
    val=$(jq -r "$path // empty" "$_CFG_FILE" 2>/dev/null) || val=""
    if [ -n "$val" ]; then
      echo "$val"
      return
    fi
  fi
  echo "$default"
}

# --- GitHub ---
CFG_REPO=$(_cfg '.github.repo' "")
CFG_PROJECT_NUMBER=$(_cfg '.github.projectNumber' "")
CFG_PROJECT_OWNER=$(_cfg '.github.owner' "")
CFG_PROJECT_ID=$(_cfg '.github.projectId' "")
CFG_STATUS_FIELD_ID=$(_cfg '.github.statusFieldId' "")

# Auto-detect repo from git remote if not in config
if [ -z "$CFG_REPO" ]; then
  CFG_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
fi

# Derive owner and repo name from CFG_REPO if available
CFG_REPO_OWNER="${CFG_REPO%%/*}"
CFG_REPO_NAME="${CFG_REPO##*/}"

# --- Board status option IDs ---
CFG_STATUS_BACKLOG=$(_cfg '.boardStatus.backlog' "17425ce6")
CFG_STATUS_PLANNED=$(_cfg '.boardStatus.planned' "cf183d2a")
CFG_STATUS_TODO=$(_cfg '.boardStatus.todo' "f75ad846")
CFG_STATUS_IN_PROGRESS=$(_cfg '.boardStatus["in-progress"]' "47fc9ee4")
CFG_STATUS_IN_REVIEW=$(_cfg '.boardStatus["in-review"]' "9bb97c15")
CFG_STATUS_DONE=$(_cfg '.boardStatus.done' "98236657")

# --- Model routing ---
CFG_ROUTE_EASY=$(_cfg '.modelRouting.easy' "sonnet")
CFG_ROUTE_MEDIUM=$(_cfg '.modelRouting.medium' "sonnet")
CFG_ROUTE_HARD=$(_cfg '.modelRouting.hard' "opus")
