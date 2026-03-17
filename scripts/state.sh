#!/usr/bin/env bash
set -euo pipefail

# state.sh — Orchestrator state file CRUD operations.
#
# Encapsulates all reads and writes to the workflow state file at
# .agentic-workflow/runs/<backlog>/orchestrator.json.
#
# Usage:
#   scripts/state.sh init <backlog-number> --mode <autonomous|interactive> --model <model>
#   scripts/state.sh update --dispatch '<json>'
#   scripts/state.sh update --story <number> --status <status>
#   scripts/state.sh update --phase <name> --status <status> [--pr <n>] [--telemetry '<json>']
#   scripts/state.sh update --epic <slug> --base-sha <sha>
#   scripts/state.sh get <jq-path>
#
# Auto-detects the state file from .agentic-workflow/runs/*/orchestrator.json
# or accepts --backlog <N> as an override for update/get subcommands.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_BASE_DIR="$REPO_ROOT/.agentic-workflow/runs"

# ─── Usage ────────────────────────────────────────────────────────────────────

_usage() {
  cat >&2 << 'EOF'
Usage:
  state.sh init <backlog-number> --mode <autonomous|interactive> --model <model>
  state.sh update --dispatch '<json>'
  state.sh update --story <number> --status <status> [--backlog <N>]
  state.sh update --phase <name> --status <status> [--pr <n>] [--telemetry '<json>'] [--backlog <N>]
  state.sh update --epic <slug> --base-sha <sha> [--backlog <N>]
  state.sh get <jq-path> [--backlog <N>]
EOF
}

# ─── State file location ──────────────────────────────────────────────────────

# Locate state file. If --backlog is provided, use that directory.
# Otherwise, auto-detect from .agentic-workflow/runs/*/orchestrator.json.
# Prints the path to stdout; exits non-zero if not found.
_find_state_file() {
  local backlog_override="${1:-}"

  if [ -n "$backlog_override" ]; then
    local path="$STATE_BASE_DIR/$backlog_override/orchestrator.json"
    if [ ! -f "$path" ]; then
      echo "Error: state file not found: $path" >&2
      exit 1
    fi
    echo "$path"
    return
  fi

  # Auto-detect: find the single state file under runs/
  local found=()
  while IFS= read -r -d '' f; do
    found+=("$f")
  done < <(find "$STATE_BASE_DIR" -maxdepth 2 -name "orchestrator.json" -print0 2>/dev/null)

  if [ "${#found[@]}" -eq 0 ]; then
    echo "Error: no state file found under $STATE_BASE_DIR. Run 'state.sh init' first, or pass --backlog <N>." >&2
    exit 1
  fi

  if [ "${#found[@]}" -gt 1 ]; then
    echo "Error: multiple state files found — pass --backlog <N> to disambiguate." >&2
    printf '  %s\n' "${found[@]}" >&2
    exit 1
  fi

  echo "${found[0]}"
}

# ─── Subcommand: init ─────────────────────────────────────────────────────────

_cmd_init() {
  local backlog=""
  local mode=""
  local model=""

  if [ $# -lt 1 ]; then
    echo "Error: 'init' requires <backlog-number>" >&2
    _usage
    exit 1
  fi

  backlog="$1"
  shift

  # Validate backlog is numeric
  if ! [[ "$backlog" =~ ^[0-9]+$ ]]; then
    echo "Error: backlog number must be a positive integer, got: $backlog" >&2
    exit 1
  fi

  while [ $# -gt 0 ]; do
    case "$1" in
      --mode)    mode="$2";  shift 2 ;;
      --model)   model="$2"; shift 2 ;;
      *) echo "Error: unknown option for init: $1" >&2; _usage; exit 1 ;;
    esac
  done

  if [ -z "$mode" ]; then
    echo "Error: --mode is required for init" >&2
    _usage
    exit 1
  fi

  if [ -z "$model" ]; then
    echo "Error: --model is required for init" >&2
    _usage
    exit 1
  fi

  local state_dir="$STATE_BASE_DIR/$backlog"
  local state_file="$state_dir/orchestrator.json"

  # Guard: do not overwrite existing state file
  if [ -f "$state_file" ]; then
    echo "Error: state file already exists: $state_file" >&2
    echo "Use 'state.sh get' to inspect current state. Delete the file manually to reinitialize." >&2
    exit 1
  fi

  mkdir -p "$state_dir"

  # Fetch live pricing
  local pricing
  if ! pricing=$("$SCRIPT_DIR/fetch-pricing.sh" 2>/dev/null); then
    echo "Error: fetch-pricing.sh failed — cannot initialize state file without pricing data" >&2
    exit 1
  fi

  # Capture wall-clock start timestamp
  local start_wall_clock
  start_wall_clock=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Get current repo and git HEAD
  local repo git_main_sha
  repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "$CFG_REPO")
  git_main_sha=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")

  # Write initial state JSON via Python for correctness.
  # Pass variable data via environment variables and use a quoted heredoc marker
  # ('PYEOF') to prevent bash from expanding variables inside the Python code.
  export _STATE_PRICING="$pricing"
  export _STATE_BACKLOG="$backlog"
  export _STATE_MODE="$mode"
  export _STATE_MODEL="$model"
  export _STATE_START_WALL_CLOCK="$start_wall_clock"
  export _STATE_REPO="$repo"
  export _STATE_GIT_MAIN_SHA="$git_main_sha"
  export _STATE_FILE="$state_file"
  python3 << 'PYEOF'
import json, os, sys

pricing = json.loads(os.environ["_STATE_PRICING"])

state = {
    "version": 1,
    "session": {
        "backlog": int(os.environ["_STATE_BACKLOG"]),
        "mode": os.environ["_STATE_MODE"],
        "orchestrator_model": os.environ["_STATE_MODEL"],
        "started_at": os.environ["_STATE_START_WALL_CLOCK"],
        "lifecycle_duration_ms": None,
        "start_wall_clock": os.environ["_STATE_START_WALL_CLOCK"],
        "repo": os.environ["_STATE_REPO"],
        "git_main_sha": os.environ["_STATE_GIT_MAIN_SHA"]
    },
    "overhead": {
        "duration_ms": None,
        "estimated_cost": None
    },
    "pricing": pricing,
    "phases": {
        "design":  {"status": "pending"},
        "plan":    {"status": "pending"},
        "build":   {"status": "pending"},
        "review":  {"status": "pending"},
        "retro":   {"status": "pending"}
    },
    "epics": {},
    "dispatches": []
}

with open(os.environ["_STATE_FILE"], "w") as f:
    json.dump(state, f, indent=2)
    f.write("\n")

print(os.environ["_STATE_FILE"])
PYEOF
  unset _STATE_PRICING _STATE_BACKLOG _STATE_MODE _STATE_MODEL \
        _STATE_START_WALL_CLOCK _STATE_REPO _STATE_GIT_MAIN_SHA _STATE_FILE
}

# ─── Subcommand: update ───────────────────────────────────────────────────────

_cmd_update() {
  local backlog_override=""

  if [ $# -lt 1 ]; then
    echo "Error: 'update' requires a subcommand flag (--dispatch, --story, --phase, --epic)" >&2
    _usage
    exit 1
  fi

  # Peek at first arg to route subcommand
  case "$1" in
    --dispatch)  _cmd_update_dispatch "$@" ;;
    --story)     _cmd_update_story    "$@" ;;
    --phase)     _cmd_update_phase    "$@" ;;
    --epic)      _cmd_update_epic     "$@" ;;
    *)
      echo "Error: unknown update subcommand: $1" >&2
      _usage
      exit 1
      ;;
  esac
}

_cmd_update_dispatch() {
  shift  # consume --dispatch
  local dispatch_json=""
  local backlog_override=""

  if [ $# -lt 1 ]; then
    echo "Error: --dispatch requires a JSON argument" >&2
    exit 1
  fi

  dispatch_json="$1"
  shift

  while [ $# -gt 0 ]; do
    case "$1" in
      --backlog) backlog_override="$2"; shift 2 ;;
      *) echo "Error: unknown option for update --dispatch: $1" >&2; exit 1 ;;
    esac
  done

  local state_file
  state_file=$(_find_state_file "$backlog_override")

  # Pass dispatch JSON via environment variable and use a quoted heredoc marker
  # ('PYEOF') to prevent bash from expanding variables inside the Python code.
  export _STATE_DISPATCH_JSON="$dispatch_json"
  export _STATE_FILE="$state_file"
  python3 << 'PYEOF'
import json, os, sys
from datetime import datetime, timezone, timedelta

dispatch_input = json.loads(os.environ["_STATE_DISPATCH_JSON"])

# Validate required fields (issue is required per spec — use null explicitly for non-story dispatches)
required = ["agent", "model", "issue", "started_at", "duration_ms", "tokens", "tool_uses", "result"]
for field in required:
    if field not in dispatch_input:
        print(f"Error: dispatch JSON missing required field: {field}", file=sys.stderr)
        sys.exit(1)

with open(os.environ["_STATE_FILE"]) as f:
    state = json.load(f)

# Compute finished_at from started_at + duration_ms
started_at = dispatch_input["started_at"]
duration_ms = int(dispatch_input["duration_ms"])
try:
    start_dt = datetime.fromisoformat(started_at.replace("Z", "+00:00"))
    end_dt = start_dt + timedelta(milliseconds=duration_ms)
    finished_at = end_dt.strftime("%Y-%m-%dT%H:%M:%SZ")
except Exception as e:
    print(f"Error: could not parse started_at '{started_at}': {e}", file=sys.stderr)
    sys.exit(1)

# Assign sequential id
dispatch_id = len(state.get("dispatches", [])) + 1

record = {
    "id": dispatch_id,
    "agent": dispatch_input["agent"],
    "model": dispatch_input["model"],
    "issue": dispatch_input["issue"],
    "started_at": started_at,
    "finished_at": finished_at,
    "duration_ms": duration_ms,
    "tokens": int(dispatch_input["tokens"]),
    "tool_uses": int(dispatch_input["tool_uses"]),
    "result": dispatch_input["result"]
}

if "dispatches" not in state:
    state["dispatches"] = []
state["dispatches"].append(record)

# If issue matches a story in epics, update build/review telemetry
issue = dispatch_input["issue"]
agent = dispatch_input.get("agent", "")
if issue is not None:
    issue_str = str(issue)
    for epic_slug, epic in state.get("epics", {}).items():
        stories = epic.get("stories", {})
        if issue_str in stories:
            story = stories[issue_str]
            telemetry = {
                "duration_ms": duration_ms,
                "tokens": int(dispatch_input["tokens"]),
                "tool_uses": int(dispatch_input["tool_uses"])
            }
            # builder agents update build telemetry; reviewers update review telemetry
            if "builder" in agent or agent == "builder":
                story["build"] = telemetry
                story["status"] = "built"
            elif "reviewer" in agent or agent == "reviewer":
                telemetry["verdict"] = dispatch_input.get("result", "")
                story["review"] = telemetry
                story["status"] = "reviewed"
            break

with open(os.environ["_STATE_FILE"], "w") as f:
    json.dump(state, f, indent=2)
    f.write("\n")

print(dispatch_id)
PYEOF
  unset _STATE_DISPATCH_JSON _STATE_FILE
}

_cmd_update_story() {
  shift  # consume --story
  local story_number=""
  local status=""
  local backlog_override=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --status)  status="$2";  shift 2 ;;
      --backlog) backlog_override="$2"; shift 2 ;;
      -*)        echo "Error: unknown option for update --story: $1" >&2; exit 1 ;;
      *)
        if [ -z "$story_number" ]; then
          story_number="$1"
        else
          echo "Error: unexpected argument for update --story: $1" >&2
          exit 1
        fi
        shift
        ;;
    esac
  done

  if [ -z "$story_number" ]; then
    echo "Error: --story requires a story number" >&2
    _usage
    exit 1
  fi

  if [ -z "$status" ]; then
    echo "Error: --story requires --status" >&2
    _usage
    exit 1
  fi

  # Validate status values
  local valid_statuses="pending building built reviewing reviewed merged done"
  if ! echo "$valid_statuses" | grep -qw "$status"; then
    echo "Error: invalid story status '$status'. Valid values: $valid_statuses" >&2
    exit 1
  fi

  local state_file
  state_file=$(_find_state_file "$backlog_override")

  python3 << PYEOF
import json, sys

with open("$state_file") as f:
    state = json.load(f)

story_number = "$story_number"
found = False
for epic_slug, epic in state.get("epics", {}).items():
    stories = epic.get("stories", {})
    if story_number in stories:
        stories[story_number]["status"] = "$status"
        found = True
        break

if not found:
    print(f"Error: story {story_number} not found in any epic in the state file", file=sys.stderr)
    sys.exit(1)

with open("$state_file", "w") as f:
    json.dump(state, f, indent=2)
    f.write("\n")

print(f"Story {story_number} status updated to $status")
PYEOF
}

_cmd_update_phase() {
  shift  # consume --phase
  local phase_name=""
  local phase_status=""
  local phase_pr=""
  local phase_telemetry=""
  local backlog_override=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --status)    phase_status="$2";    shift 2 ;;
      --pr)        phase_pr="$2";        shift 2 ;;
      --telemetry) phase_telemetry="$2"; shift 2 ;;
      --backlog)   backlog_override="$2"; shift 2 ;;
      -*)          echo "Error: unknown option for update --phase: $1" >&2; exit 1 ;;
      *)
        if [ -z "$phase_name" ]; then
          phase_name="$1"
        else
          echo "Error: unexpected argument for update --phase: $1" >&2
          exit 1
        fi
        shift
        ;;
    esac
  done

  if [ -z "$phase_name" ]; then
    echo "Error: --phase requires a phase name" >&2
    _usage
    exit 1
  fi

  if [ -z "$phase_status" ]; then
    echo "Error: --phase requires --status" >&2
    _usage
    exit 1
  fi

  # Validate phase name
  local valid_phases="design plan build review retro"
  if ! echo "$valid_phases" | grep -qw "$phase_name"; then
    echo "Error: invalid phase name '$phase_name'. Valid values: $valid_phases" >&2
    exit 1
  fi

  # Validate phase status
  local valid_statuses="pending in_progress complete skipped"
  if ! echo "$valid_statuses" | grep -qw "$phase_status"; then
    echo "Error: invalid phase status '$phase_status'. Valid values: $valid_statuses" >&2
    exit 1
  fi

  local state_file
  state_file=$(_find_state_file "$backlog_override")

  # Pass all variable data via environment variables and use a quoted heredoc
  # marker ('PYEOF') to prevent bash from expanding variables inside Python.
  export _STATE_FILE="$state_file"
  export _STATE_PHASE_NAME="$phase_name"
  export _STATE_PHASE_STATUS="$phase_status"
  export _STATE_PHASE_PR="$phase_pr"
  export _STATE_PHASE_TELEMETRY="$phase_telemetry"
  python3 << 'PYEOF'
import json, os, sys

with open(os.environ["_STATE_FILE"]) as f:
    state = json.load(f)

if "phases" not in state:
    state["phases"] = {}

phase_name = os.environ["_STATE_PHASE_NAME"]
phase = state["phases"].get(phase_name, {})
phase["status"] = os.environ["_STATE_PHASE_STATUS"]

phase_pr = os.environ.get("_STATE_PHASE_PR", "")
if phase_pr:
    phase["pr"] = int(phase_pr)

phase_telemetry = os.environ.get("_STATE_PHASE_TELEMETRY", "")
if phase_telemetry:
    phase["telemetry"] = json.loads(phase_telemetry)

state["phases"][phase_name] = phase

with open(os.environ["_STATE_FILE"], "w") as f:
    json.dump(state, f, indent=2)
    f.write("\n")

print(f"Phase {phase_name} status updated to {os.environ['_STATE_PHASE_STATUS']}")
PYEOF
  unset _STATE_FILE _STATE_PHASE_NAME _STATE_PHASE_STATUS _STATE_PHASE_PR _STATE_PHASE_TELEMETRY
}

_cmd_update_epic() {
  shift  # consume --epic
  local epic_slug=""
  local base_sha=""
  local backlog_override=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --base-sha) base_sha="$2";         shift 2 ;;
      --backlog)  backlog_override="$2"; shift 2 ;;
      -*)         echo "Error: unknown option for update --epic: $1" >&2; exit 1 ;;
      *)
        if [ -z "$epic_slug" ]; then
          epic_slug="$1"
        else
          echo "Error: unexpected argument for update --epic: $1" >&2
          exit 1
        fi
        shift
        ;;
    esac
  done

  if [ -z "$epic_slug" ]; then
    echo "Error: --epic requires a slug" >&2
    _usage
    exit 1
  fi

  if [ -z "$base_sha" ]; then
    echo "Error: --epic requires --base-sha" >&2
    _usage
    exit 1
  fi

  local state_file
  state_file=$(_find_state_file "$backlog_override")

  python3 << PYEOF
import json, sys

with open("$state_file") as f:
    state = json.load(f)

if "epics" not in state:
    state["epics"] = {}

epic_slug = "$epic_slug"
if epic_slug not in state["epics"]:
    # Create new epic entry
    state["epics"][epic_slug] = {
        "base_sha": "$base_sha",
        "stories": {}
    }
else:
    # Update base_sha on existing entry (preserve other fields)
    state["epics"][epic_slug]["base_sha"] = "$base_sha"
    if "stories" not in state["epics"][epic_slug]:
        state["epics"][epic_slug]["stories"] = {}

with open("$state_file", "w") as f:
    json.dump(state, f, indent=2)
    f.write("\n")

print(f"Epic {epic_slug} updated with base_sha $base_sha")
PYEOF
}

# ─── Subcommand: get ──────────────────────────────────────────────────────────

_cmd_get() {
  local jq_path=""
  local backlog_override=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --backlog) backlog_override="$2"; shift 2 ;;
      -*)        echo "Error: unknown option for get: $1" >&2; exit 1 ;;
      *)
        if [ -z "$jq_path" ]; then
          jq_path="$1"
        else
          echo "Error: unexpected argument for get: $1" >&2
          exit 1
        fi
        shift
        ;;
    esac
  done

  if [ -z "$jq_path" ]; then
    echo "Error: 'get' requires a jq path argument" >&2
    _usage
    exit 1
  fi

  local state_file
  state_file=$(_find_state_file "$backlog_override")

  jq -r "$jq_path" "$state_file"
}

# ─── Main router ─────────────────────────────────────────────────────────────

if [ $# -lt 1 ]; then
  _usage
  exit 1
fi

SUBCOMMAND="$1"
shift

case "$SUBCOMMAND" in
  init)    _cmd_init    "$@" ;;
  update)  _cmd_update  "$@" ;;
  get)     _cmd_get     "$@" ;;
  *)
    echo "Error: unknown subcommand '$SUBCOMMAND'" >&2
    _usage
    exit 1
    ;;
esac
