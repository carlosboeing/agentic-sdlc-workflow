---
date: 2026-03-16
author: builder
story: "E01-S04 (#130) — Wire External Python Module in issue-telemetry.sh"
tags: [builder, git, branch]
severity: medium
---

# Stash Pop Landed on Wrong Branch After Conflict

## What happened

When the orchestrator dispatched this story, the working directory was left on
`epic/e01-orchestrator-improvements` (a different epic's branch). The story branch
`e01-s04/wire-external-module` was created with `git checkout -b` but then I began
writing files. When I discovered the branch problem and tried to use `git stash` +
`git checkout e01-s04/wire-external-module` + `git stash pop`, the pop produced a
merge conflict. Using `git checkout --theirs` to resolve the conflict appeared to
succeed, but subsequent edits were silently written back to the original branch instead.

The result: the refactored `issue-telemetry.sh` and new test files were written on
`backlog/105-orchestrator-improvements` rather than the story branch. Running tests
from the wrong branch also meant `compute-dispatches.py` was absent (it only exists
on the telemetry epic branch).

## Root cause

After `git stash pop` with a merge conflict, `git checkout --theirs` marks the file
as resolved in the index but does not switch the HEAD branch. Any subsequent shell
writes via `cat >` or `python3 -c` write to the working tree of the current branch,
not the intended story branch.

Additionally, the `cat > file << 'EOF'` heredoc pattern failed silently — the file
appeared to be written but was actually reverted by an editor/linter hook, so the
large file write didn't take effect.

## Prevention

1. **Always verify branch with `git branch --show-current` after any stash operation.**
2. **Use absolute paths AND verify branch immediately before writing large files.**
3. **For large file rewrites that cannot be expressed as diffs, use `python3 -c
   "open(...,'w').write(...)"` with the full content embedded in Python string rather
   than bash heredocs** — Python doesn't have heredoc escaping issues and the write
   succeeds atomically.
4. When a stash pop produces a conflict, the safest recovery is:
   ```bash
   git stash drop   # abandon stash
   git checkout target-branch
   # reapply changes manually or re-derive from scratch
   ```
5. If you must use `git checkout --theirs` after stash pop conflict, immediately
   verify with `wc -l <file>` and `grep <key-pattern> <file>` to confirm the correct
   content was actually applied.
