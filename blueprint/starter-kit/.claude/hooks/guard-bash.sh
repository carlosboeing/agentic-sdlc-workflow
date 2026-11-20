#!/usr/bin/env bash
# PreToolUse hook for the Bash tool: deny a small list of destructive patterns.
# Anything else produces no output, so Claude Code's normal permission flow applies.
# This is a tripwire, not a security boundary: pattern matching is easy to bypass.
set -euo pipefail

command=$(jq -r '.tool_input.command // empty')

patterns=(
  'rm[[:space:]]+(-[a-zA-Z]*[rR][a-zA-Z]*[fF]|-[a-zA-Z]*[fF][a-zA-Z]*[rR])'
  'git[[:space:]]+push([^;&|]*)[[:space:]](origin[[:space:]]+)?(main|master)([[:space:];&|]|$)'
  'git[[:space:]]+push([^;&|]*)[[:space:]](--force|-f)([[:space:];&|]|$)'
  'DROP[[:space:]]+TABLE'
  'TRUNCATE[[:space:]]+TABLE'
  'chmod[[:space:]]+(-R[[:space:]]+)?777'
)

for p in "${patterns[@]}"; do
  if printf '%s' "$command" | grep -qiE -- "$p"; then
    jq -n --arg reason "Destructive command blocked by hook guard (pattern: $p)" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }
    }'
    exit 0
  fi
done

exit 0
