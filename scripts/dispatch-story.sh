#!/usr/bin/env bash
set -euo pipefail

# dispatch-story.sh — Read a GitHub issue, write a prompt file, invoke claude -p, post telemetry or failure.
# Usage: ./scripts/dispatch-story.sh <issue-number> --model <model> --agent <agent> [--epic-branch <branch>]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"
REPO="$CFG_REPO"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DISPATCH_DIR="$REPO_ROOT/.agentic-workflow/dispatch"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <issue-number> --model <model> --agent <agent> [--epic-branch <branch>]"
  exit 1
fi

ISSUE_NUMBER="$1"
shift

MODEL=""
AGENT=""
EPIC_BRANCH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --model)       MODEL="$2";       shift 2 ;;
    --agent)       AGENT="$2";       shift 2 ;;
    --epic-branch) EPIC_BRANCH="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$MODEL" ]; then
  echo "Error: --model is required"
  exit 1
fi

if [ -z "$AGENT" ]; then
  echo "Error: --agent is required"
  exit 1
fi

# ---------------------------------------------------------------------------
# Pre-flight: verify claude CLI is available and supports required flags
# ---------------------------------------------------------------------------
if ! command -v claude &>/dev/null; then
  echo "Error: 'claude' CLI not found in PATH. Install Claude Code CLI before dispatching."
  exit 1
fi

CLAUDE_HELP=$(claude --help 2>&1 || true)

for FLAG in "--agent" "--model" "--output-format"; do
  if ! echo "$CLAUDE_HELP" | grep -qF -- "$FLAG"; then
    echo "Error: claude CLI does not support the '$FLAG' flag."
    echo "  Expected: Claude Code CLI >= 1.0 with --agent, --model, --output-format support."
    echo "  Run 'claude --help' to inspect available flags, then update or reinstall the CLI."
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# Fetch issue metadata
# ---------------------------------------------------------------------------
echo "Fetching issue #$ISSUE_NUMBER from $REPO..."
ISSUE_JSON=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json title,body,labels)

ISSUE_TITLE=$(echo "$ISSUE_JSON" | jq -r '.title')
ISSUE_BODY=$(echo "$ISSUE_JSON" | jq -r '.body')
DIFFICULTY=$(echo "$ISSUE_JSON" | jq -r '[.labels[].name | select(startswith("difficulty/"))] | first // "difficulty/unknown"')

# Derive story branch convention from issue number and title slug
TITLE_SLUG=$(echo "$ISSUE_TITLE" \
  | tr '[:upper:]' '[:lower:]' \
  | sed 's/\[#[0-9]*\/e[0-9]*-s[0-9]*\] *//;s/\[e[0-9]*-s[0-9]*\] *//' \
  | sed 's/[^a-z0-9]/-/g' \
  | sed 's/--*/-/g' \
  | sed 's/^-//;s/-$//')

# Extract epic/story numbers from title e.g. [E01-S01]
EPIC_STORY_TAG=$(echo "$ISSUE_TITLE" | grep -oiE 'E[0-9]+-S[0-9]+' | head -1 | tr '[:upper:]' '[:lower:]' || echo "")
STORY_BRANCH_CONVENTION="${EPIC_STORY_TAG}/${TITLE_SLUG}"

if [ -z "$EPIC_BRANCH" ] && [ -n "$EPIC_STORY_TAG" ]; then
  EPIC_NUM=$(echo "$EPIC_STORY_TAG" | grep -oE 'e[0-9]+')
  # Attempt to find the epic branch from remote refs
  EPIC_BRANCH=$(git branch -a 2>/dev/null \
    | sed 's|remotes/origin/||' \
    | grep -oE "epic/${EPIC_NUM}-[a-z0-9-]+" \
    | head -1 || echo "epic/${EPIC_NUM}")
fi

# ---------------------------------------------------------------------------
# Gather builder-tagged lessons
# ---------------------------------------------------------------------------
LESSONS_DIR="$REPO_ROOT/docs/4-reviews/lessons"
LESSONS_SECTION=""
if [ -d "$LESSONS_DIR" ]; then
  LESSON_FILES=$(grep -rl "tags:.*builder" "$LESSONS_DIR" 2>/dev/null || true)
  if [ -n "$LESSON_FILES" ]; then
    LESSONS_SECTION="## Lessons (builder-tagged)

The following lessons from past epics apply to builder agents. Read and apply them before writing code.

"
    while IFS= read -r LESSON_FILE; do
      LESSON_TITLE=$(grep -m1 '^# ' "$LESSON_FILE" 2>/dev/null | sed 's/^# //' || basename "$LESSON_FILE")
      LESSONS_SECTION="${LESSONS_SECTION}- **${LESSON_TITLE}**: \`${LESSON_FILE#"$REPO_ROOT/"}\`
"
    done <<< "$LESSON_FILES"
  fi
fi

# ---------------------------------------------------------------------------
# Write prompt file
# ---------------------------------------------------------------------------
mkdir -p "$DISPATCH_DIR"
PROMPT_FILE="$DISPATCH_DIR/story-${ISSUE_NUMBER}.md"

cat > "$PROMPT_FILE" <<PROMPT
# Story: ${ISSUE_TITLE}

**Issue:** #${ISSUE_NUMBER}
**Difficulty:** ${DIFFICULTY}
**Epic branch:** ${EPIC_BRANCH}
**Story branch convention:** ${STORY_BRANCH_CONVENTION}

## Story Details

${ISSUE_BODY}

## Branch Instructions

- Create story branch from the epic branch: \`git checkout ${EPIC_BRANCH} && git checkout -b ${STORY_BRANCH_CONVENTION}\`
- After completing the story, merge it back into the epic branch (not \`main\`).

${LESSONS_SECTION}
PROMPT

echo "Prompt written to $PROMPT_FILE"

# ---------------------------------------------------------------------------
# Invoke claude -p
# ---------------------------------------------------------------------------

# Detect nested Claude Code session. The CC CLI sets CLAUDECODE to prevent
# recursive launches, but dispatch-story.sh intentionally spawns an independent
# builder on a separate branch — no shared state with the parent session.
# We unset CLAUDECODE for the child process only so the dispatch proceeds.
run_claude() {
  if [ -n "${CLAUDECODE:-}" ]; then
    env -u CLAUDECODE claude "$@"
  else
    claude "$@"
  fi
}

if [ -n "${CLAUDECODE:-}" ]; then
  echo "Note: running inside a Claude Code session — unsetting CLAUDECODE for child process."
fi

echo "Dispatching claude agent (agent=$AGENT, model=$MODEL)..."
START_SECONDS=$SECONDS
EXIT_CODE=0

CLAUDE_OUTPUT=$(run_claude -p "$(cat "$PROMPT_FILE")" \
  --agent "$AGENT" \
  --model "$MODEL" \
  --output-format json \
  2>&1) || EXIT_CODE=$?

ELAPSED_SECS=$(( SECONDS - START_SECONDS ))
DURATION_MS=$(( ELAPSED_SECS * 1000 ))

# Extract telemetry from claude JSON output
TOTAL_TOKENS=$(echo "$CLAUDE_OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('usage',{}).get('total_tokens',0))" 2>/dev/null || echo "0")
TOOL_USES=$(echo "$CLAUDE_OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len([m for m in d.get('messages',[]) if m.get('role')=='tool']))" 2>/dev/null || echo "0")

# ---------------------------------------------------------------------------
# Post telemetry or failure
# ---------------------------------------------------------------------------
if [ "$EXIT_CODE" -eq 0 ]; then
  # Retrieve the head commit on the story branch (builder should have pushed it)
  git fetch origin &>/dev/null || true
  STORY_COMMIT=$(git log "origin/${STORY_BRANCH_CONVENTION}" --format="%H" -1 2>/dev/null \
    || git log "${STORY_BRANCH_CONVENTION}" --format="%H" -1 2>/dev/null \
    || echo "unknown")

  echo "Success. Posting telemetry (duration=${DURATION_MS}ms, tokens=${TOTAL_TOKENS}, commit=${STORY_COMMIT})..."
  TELEM_ARGS=("$ISSUE_NUMBER" --model "$MODEL" --duration "$DURATION_MS" --commit "$STORY_COMMIT")
  [ "$TOTAL_TOKENS" -gt 0 ] 2>/dev/null && TELEM_ARGS+=(--tokens "$TOTAL_TOKENS")
  [ "$TOOL_USES" -gt 0 ] 2>/dev/null && TELEM_ARGS+=(--tool-uses "$TOOL_USES")
  "$SCRIPT_DIR/item-telemetry.sh" "${TELEM_ARGS[@]}"
else
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "claude exited with code $EXIT_CODE. Posting failure comment..."
  gh issue comment "$ISSUE_NUMBER" --repo "$REPO" --body "$(cat <<EOF
### Build Failed

The \`claude -p\` dispatch for this story exited with code \`${EXIT_CODE}\`.

| Field | Value |
|-------|-------|
| **Agent** | ${AGENT} |
| **Model** | ${MODEL} |
| **Exit code** | ${EXIT_CODE} |
| **Duration** | ${ELAPSED_SECS}s |
| **Failed at** | ${TIMESTAMP} |

Check the dispatch logs and re-dispatch when the issue is resolved.
EOF
)"
  exit "$EXIT_CODE"
fi
