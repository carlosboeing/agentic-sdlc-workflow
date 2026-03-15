---
date: 2026-03-09
author: orchestrator
story: "Pre-dispatch — all Wave 1 stories"
tags: [orchestrator, dispatch, cli, infrastructure]
severity: critical
---

# dispatch-story.sh --max-turns Flag Not Supported

## What happened

All 5 Wave 1 builder dispatches failed immediately with:
```
Error: claude CLI does not support the '--max-turns' flag.
```

The `dispatch-story.sh` script included `--max-turns 100` in both its preflight
check and the `claude -p` invocation, but the Claude Code CLI (v2.1.71) does not
support this flag. The CLI supports `--max-budget-usd` instead.

## Root cause

The `--max-turns` flag was added to the dispatch script during initial SDLC v2
development, likely based on an expected API that was never shipped. The preflight
check correctly validates flag availability but the script was never tested against
the production CLI.

## Prevention

- Before adding CLI flags to scripts, verify they exist with `claude --help`
- The dispatch script's preflight check is a good pattern — it caught the issue
  with a clear error. The fix is simply to remove the unsupported flag.
- If turn limits are needed, use `--max-budget-usd` instead
- Update CLAUDE.md Known Limitations section when CLI flags change
