#!/usr/bin/env bash
# log-tool.sh — PostToolUse hook for orchestrator workflow logging.
#
# Reads hook JSON from stdin, filters Bash commands by allowlist, and appends
# structured entries to .claude/logs/orchestrator.log.
# Agent/Task dispatches are always logged (no filtering).
#
# This hook is diagnostic-only — it MUST always exit 0 to never block Claude Code.

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)}"
LOG_DIR="$REPO_ROOT/.claude/logs"
LOG_FILE="$LOG_DIR/orchestrator.log"
FILTER_CONF="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/log-filter.conf"

mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

# Read all stdin
INPUT=$(cat) || exit 0

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null) || SESSION_ID="unknown"
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0

if [ -z "$TOOL_NAME" ]; then
  exit 0
fi

# --- Task/Agent tool: always log ---
if [ "$TOOL_NAME" = "Task" ] || [ "$TOOL_NAME" = "Agent" ]; then
  TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // "unknown"' 2>/dev/null) || TYPE="unknown"
  PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null | head -c 80 | tr '\n' ' ') || PROMPT=""

  # Try to extract metrics from tool_response (structured object or nested)
  DURATION=$(echo "$INPUT" | jq -r '.tool_response.duration_ms // .tool_response.duration // empty' 2>/dev/null) || true
  TOKENS=$(echo "$INPUT" | jq -r '.tool_response.total_tokens // empty' 2>/dev/null) || true
  TOOL_USES=$(echo "$INPUT" | jq -r '.tool_response.tool_uses // empty' 2>/dev/null) || true

  echo "[$TIMESTAMP] session=$SESSION_ID tool=$TOOL_NAME type=$TYPE prompt=\"$PROMPT\" duration=${DURATION:-?} tokens=${TOKENS:-?} tool_uses=${TOOL_USES:-?}" >> "$LOG_FILE"
  exit 0
fi

# --- Bash tool: filter by allowlist, then log ---
if [ "$TOOL_NAME" = "Bash" ]; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0

  if [ -z "$COMMAND" ]; then
    exit 0
  fi

  # Check against allowlist patterns
  if [ ! -f "$FILTER_CONF" ]; then
    exit 0
  fi

  MATCHED=false
  while IFS= read -r pattern || [ -n "$pattern" ]; do
    # Skip blank lines and comments
    [[ -z "$pattern" || "$pattern" =~ ^[[:space:]]*# ]] && continue
    pattern=$(echo "$pattern" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$pattern" ] && continue

    if echo "$COMMAND" | grep -qE "$pattern" 2>/dev/null; then
      MATCHED=true
      break
    fi
  done < "$FILTER_CONF"

  if [ "$MATCHED" = false ]; then
    exit 0
  fi

  # Extract output — tool_response may be a string or object
  RESPONSE_TYPE=$(echo "$INPUT" | jq -r '.tool_response | type' 2>/dev/null) || RESPONSE_TYPE="null"

  EXIT_CODE="?"
  STDOUT=""
  STDERR=""

  if [ "$RESPONSE_TYPE" = "string" ]; then
    STDOUT=$(echo "$INPUT" | jq -r '.tool_response' 2>/dev/null | head -c 500 | tr '\n' '↵') || true
  elif [ "$RESPONSE_TYPE" = "object" ]; then
    STDOUT=$(echo "$INPUT" | jq -r '.tool_response.stdout // .tool_response.output // (.tool_response | tostring)' 2>/dev/null | head -c 500 | tr '\n' '↵') || true
    EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_response.exitCode // .tool_response.exit_code // "?"' 2>/dev/null) || EXIT_CODE="?"
    STDERR=$(echo "$INPUT" | jq -r '.tool_response.stderr // empty' 2>/dev/null | head -c 200 | tr '\n' '↵') || true
  fi

  # Quote command as JSON string for safe log embedding
  CMD_QUOTED=$(echo "$COMMAND" | jq -Rs '.' 2>/dev/null) || CMD_QUOTED="\"$COMMAND\""

  LOG_LINE="[$TIMESTAMP] session=$SESSION_ID tool=Bash cmd=$CMD_QUOTED exit=$EXIT_CODE stdout=\"${STDOUT:-}\""

  if [ -n "${STDERR:-}" ]; then
    LOG_LINE="$LOG_LINE stderr=\"$STDERR\""
  fi

  echo "$LOG_LINE" >> "$LOG_FILE"
  exit 0
fi

# Unknown tool — ignore
exit 0
