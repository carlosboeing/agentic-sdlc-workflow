## date: 2026-03-13
author: orchestrator
status: implemented
backlog: 14

# Design: Orchestrator & Board Status Diagnostic Logging

## Problem

During Run 9 (backlog #14), all story and epic issues remained at **In Progress** on the project board despite the orchestrator reporting successful status transitions (`✓ #18 → in-review`). The root cause is unknown — the `issue-set-status.sh` script reports success based on the `gh project item-edit` API call completing, but doesn't verify the status actually persisted.

We need diagnostic logging at two layers:

1. **Board status script** (`issue-set-status.sh`) — capture API internals: item ID lookup, mutation response, and a post-mutation verification read.
2. **Orchestrator workflow** — capture the orchestrator's decisions and actions: agent dispatches, branch operations, phase transitions.

---

## Design

### Layer 1: Board Status Script Logging

**File:** `.claude/logs/board-status.log`

**What changes in `scripts/issue-set-status.sh`:**

1. **Log every invocation** with timestamp, issue number, requested status, caller PID.
2. **Log the item ID lookup result** and the current board status before mutation.
3. **Skip if already at desired status** (log and exit early — avoids unnecessary API calls).
4. **Capture the `gh project item-edit` response** (stdout + exit code).
5. **Post-mutation verification read** — after a 1-second delay for eventual consistency, re-fetch the board item and compare actual status to expected. Log `VERIFY_OK` or `VERIFY_MISMATCH`.
6. **On mismatch**, print a `⚠` warning to stderr (instead of `✓`) but still exit 0 — the mutation call succeeded, the mismatch is a diagnostic signal, not a hard failure.

**Log format (one line per event):**

```
[2026-03-13T02:30:00Z] issue=18 status=in-review START caller_pid=12345
[2026-03-13T02:30:00Z] issue=18 status=in-review option_id=9bb97c15
[2026-03-13T02:30:01Z] issue=18 status=in-review item_id=PVTI_xxx current_status=in-progress
[2026-03-13T02:30:02Z] issue=18 status=in-review MUTATION exit=0 response=...
[2026-03-13T02:30:03Z] issue=18 status=in-review VERIFY_OK actual_status=in-review
```

Or on mismatch:

```
[2026-03-13T02:30:03Z] issue=18 status=in-review VERIFY_MISMATCH expected=in-review actual=in-progress
```

### Layer 2: Orchestrator Workflow Logging via Claude Code Hooks

**Mechanism:** `PostToolUse` hooks on `Bash` and `Agent` tools, registered in `.claude/settings.json`.

**Hook script:** `.claude/hooks/log-tool.sh` — reads JSON from stdin, applies an allowlist filter, and appends structured entries to `.claude/logs/orchestrator.log`.

**Filter config:** `.claude/hooks/log-filter.conf` — allowlist of regex patterns. Only Bash commands matching at least one pattern are logged. Agent tool calls are always logged (no filtering needed — every dispatch is significant).

#### Filter Config Format

```conf
# .claude/hooks/log-filter.conf
# One extended regex per line. Blank lines and # comments are ignored.
# Matched against the full Bash command string.

# Board and workflow scripts
issue-set-status
issue-close
issue-start
issue-review
issue-telemetry
fetch-pricing
dispatch-story
dispatch-workflow

# GitHub CLI
gh (issue|pr|project|api)

# Git branch operations (excludes status, log, diff, ls-remote, show-current)
git (merge|push|pull|checkout|branch -[dD]|clean|cherry-pick|rebase)
git checkout -b

# Build/test
dotnet (build|test)
```

#### Hook Script Logic

Note: The Claude Code API uses `Task` as the tool name (not `Agent`). The hook checks for both names for compatibility.

```
read JSON from stdin
extract tool_name, tool_input, tool_output

if tool_name == "Task" (or "Agent" for compatibility):
    always log (extract subagent_type, prompt summary, duration, tokens, tool_uses)

if tool_name == "Bash":
    extract command from tool_input
    load allowlist patterns from log-filter.conf
    if command matches any pattern:
        log (command, exit_code, stdout first 500 chars)
    else:
        skip (exit 0)
```

#### Orchestrator Log Format

```
[2026-03-13T02:15:00Z] session=abc123 tool=Bash cmd="./scripts/issue-set-status.sh 18 in-progress" exit=0 stdout="✓ #18 → in-progress"
[2026-03-13T02:15:05Z] session=abc123 tool=Task type=builder-haiku prompt="Implement story #18..." duration=149628 tokens=113527 tool_uses=43
[2026-03-13T02:20:00Z] session=abc123 tool=Bash cmd="git merge origin/e01-s01/kitchen-counter --no-ff" exit=0
```

#### Hook Registration

Hooks are registered in `.claude/settings.json` using a flat `matcher` string and nested `hooks` array structure. Note: Claude Code API uses `Task` as the tool name, not `Agent`.

```jsonc
// .claude/settings.json (merged with existing permissions)
{
  "permissions": { ... },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/log-tool.sh"
          }
        ]
      },
      {
        "matcher": "Task",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/log-tool.sh"
          }
        ]
      }
    ]
  }
}
```

### File Layout

```
.claude/
  hooks/
    log-tool.sh           ← PostToolUse hook script (executable)
    log-filter.conf       ← allowlist patterns for Bash command filtering
  logs/                   ← gitignored, ephemeral
    orchestrator.log      ← workflow-level log (from hook)
    board-status.log      ← board API diagnostic log (from issue-set-status.sh)
  .gitignore              ← add: logs/
```

### Gitignore

Add `logs/` to `.claude/.gitignore` (alongside `state/` and `worktrees/`). Logs are ephemeral diagnostic data, not project content.

### What Gets Logged Where


| Event                                 | `orchestrator.log` (hook)                | `board-status.log` (script)                                |
| ------------------------------------- | ---------------------------------------- | ---------------------------------------------------------- |
| `issue-set-status.sh` called          | ✓ command + exit code + stdout           | ✓ item ID, current status, mutation response, verification |
| `gh pr create`                        | ✓ command + exit code                    | —                                                          |
| `git merge ...`                       | ✓ command + exit code                    | —                                                          |
| Agent dispatched                      | ✓ type, prompt summary, duration, tokens | —                                                          |
| Board item ID lookup                  | —                                        | ✓ found/not-found, retry                                   |
| Post-mutation verification            | —                                        | ✓ VERIFY_OK or VERIFY_MISMATCH                             |
| Noisy commands (`git status`, `echo`) | ✗ filtered out                           | —                                                          |


### Scope

**In scope:**

- `scripts/issue-set-status.sh` — add logging + post-mutation verification
- `.claude/hooks/log-tool.sh` — new hook script
- `.claude/hooks/log-filter.conf` — new filter config
- `.claude/settings.json` — add hook registration
- `.claude/.gitignore` — add `logs/`

**Out of scope:**

- Changes to other scripts (`issue-close.sh`, `issue-start.sh`, etc.) — they delegate to `issue-set-status.sh` which will now log internally.
- Changes to orchestrator agent file — the hook captures orchestrator actions automatically without explicit logging calls.
- Log rotation or cleanup — logs are per-session and small enough to not need rotation.

### Open Questions

1. **Should the hook truncate long stdout?** Proposed: first 500 chars. Some `gh` commands return verbose JSON.
2. **Should the hook log stderr separately?** Proposed: yes, if non-empty (captures warnings/errors).
3. **Should the post-mutation verification in `issue-set-status.sh` retry on mismatch?** Proposed: no — log the mismatch for diagnosis but don't retry (the current run's manual fix already handles it). We want data first, then decide on auto-remediation.

---

## Post-Implementation Notes

### Status

This design has been implemented and merged to `main` as of commit `c7d2eda`. The logging infrastructure is now fully operational.

### Implementation Details

All artifacts specified in the design have been implemented:

- **`.claude/hooks/log-tool.sh`** — PostToolUse hook script that filters and logs tool invocations
- **`.claude/hooks/log-filter.conf`** — allowlist patterns for Bash command filtering
- **`.claude/settings.json`** — hook registration with updated format (flat `matcher` string + nested `hooks` array)
- **`scripts/issue-set-status.sh`** — enhanced with board status logging and post-mutation verification
- **`.claude/.gitignore`** — includes `logs/` directory to keep ephemeral diagnostics out of the repo

### Validation

A validation script is available at `scripts/validate-logs.sh` to verify log integrity after a workflow session:

```bash
# After running a workflow session, validate the logs
./scripts/validate-logs.sh
```

This script performs basic sanity checks on both `orchestrator.log` and `board-status.log`, such as verifying timestamp ordering and checking for incomplete entries.

### Key Implementation Discrepancies from Design

1. **Hook registration format:** Design showed nested `matcher` object; actual implementation uses flat `matcher` string with nested `hooks` array containing `type` and `command` fields.
2. **Tool naming:** Design referred to `Agent` tool; Claude Code API uses `Task` as the tool name in the hook payload.

Both discrepancies have been documented in this file to prevent future confusion.

