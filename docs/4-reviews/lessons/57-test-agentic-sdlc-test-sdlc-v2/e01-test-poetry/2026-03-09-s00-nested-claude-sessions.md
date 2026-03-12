---
date: 2026-03-09
author: orchestrator
story: "Pre-dispatch — all Wave 1 stories"
tags: [orchestrator, dispatch, cli, infrastructure]
severity: critical
---

# Cannot Dispatch CLI Builders from Within a Claude Code Session

## What happened

After fixing the `--max-turns` flag issue, all 5 Wave 1 builder dispatches via
`dispatch-story.sh` failed again with:
```
Error: Claude Code cannot be launched inside another Claude Code session.
```

The `claude -p` command detects it is running inside another Claude Code session
(via the `CLAUDECODE` environment variable) and refuses to start.

## Root cause

The `dispatch-story.sh` script invokes `claude -p` which spawns a nested Claude
Code process. When the orchestrator runs inside Claude Code (e.g., via Cursor or
the Claude Code terminal), the `CLAUDECODE` env var is set, and nested launches
are blocked to prevent resource conflicts.

## Prevention

- **Primary dispatch method:** Use the Agent tool with `subagent_type` for
  in-session orchestration. This is explicitly documented as the primary method
  in the orchestrator agent file.
- **CLI dispatch is for out-of-session only:** `dispatch-story.sh` works when
  invoked from a standalone terminal, not from within a Claude Code session.
- The orchestrator agent file should emphasize that CLI dispatch is a fallback
  for out-of-session or test scenarios, not the default.
- Consider adding `unset CLAUDECODE` to the dispatch script as a workaround,
  but this risks resource conflicts between sessions.
