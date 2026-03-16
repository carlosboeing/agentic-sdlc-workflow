---
date: 2026-03-16
author: builder
story: "E01-S02 (#136) — Early Story Branch Creation"
tags: [builder, worktree, edit-tool, platform-limitation]
severity: high
---

# Edit Tool Operates on CWD, Not Git Branch — Worktree Confusion

## What happened

The session started in a worktree at
`.claude/worktrees/agent-a65246c1/` on branch `e01-s02/early-story-branch-creation`.
After switching the working directory via `git checkout` (inside a Bash call), the
next Bash call reset the CWD back to the original working directory — which was the
MAIN worktree path (`/Users/carlos/Projects/carlos/agentic-sdlc-workflow`) on
`main`.

The Edit tool claimed success when called with the absolute path
`.../agentic-sdlc-workflow/.claude/agents/orchestrator.md` but the file it edited
was not the story branch's version — it was editing against a stale internal cache
that didn't match the disk state (the file had been modified by the epic branch
merge).

The result: three "success" messages from the Edit tool, zero actual changes on
disk. The changes only landed after using a Python `str.replace()` approach
directly, which bypassed the Edit tool's cache.

## Root cause

Two compounding issues:

1. **Shell state does not persist between Bash calls.** The CWD resets to the
   session's initial working directory after every Bash call. A `git checkout`
   in one call has no effect in the next call. This is documented in the
   system prompt but easy to forget when doing multi-step git operations.

2. **The Edit tool uses an internal cache** that can become stale when the file
   is modified by a process outside the Edit/Write/Read tool chain (e.g., the
   Python `str.replace` approach, or a `git stash pop` that auto-merges).
   When the cache is stale, `Edit` reports "File has been modified since read" or
   silently succeeds without actually writing. Re-reading the file before editing
   does not always clear the cache if the read also hits the stale cache.

## Prevention

- **Always chain git operations in a single Bash call** when you need git state to
  persist: `git checkout branch && git add file && git commit -m "msg"`.
- **Never rely on `git checkout` from a previous Bash call** — the next Bash call
  starts fresh.
- **Use Python or `sed` as a fallback** when the Edit tool reports stale-cache
  errors repeatedly. Write the change as a `str.replace()` operation with exact
  string matching.
- **After any git stash/pop or auto-merge**, use Bash `grep` to verify file
  content rather than the Read tool (which may also cache).
- **The definitive pattern for committing on a story branch** when the session
  starts on a different branch:
  ```bash
  cd /path/to/repo && git stash && git checkout <story-branch> && git stash pop && git add <files> && git commit -m "msg"
  ```
  All in a single `&&` chain.
