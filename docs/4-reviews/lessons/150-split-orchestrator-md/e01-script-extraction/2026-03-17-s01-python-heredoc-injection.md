---
date: 2026-03-17
author: reviewer
story: "E01-S01 (#157) -- state.sh Core CRUD Subcommands"
tags: [builder, reviewer, security, bash, heredoc, injection]
severity: critical
---

# Python Heredoc Injection via Unquoted PYEOF Markers

## What happened

The builder created `scripts/state.sh` with 5 embedded Python heredoc blocks using unquoted markers (`python3 << PYEOF`). When bash encounters an unquoted heredoc marker, it expands variables inside the heredoc body before the child process (Python) sees them. This allowed bash variable expansion to inject arbitrary content into the Python code.

The reviewer demonstrated working exploits for 3 of the 5 heredocs (C1-C3) on the first review. The builder fixed those 3 using the env-var pattern (`export _STATE_VAR; python3 << 'PYEOF'`; `os.environ["_STATE_VAR"]`), but did not fix the remaining 2 heredocs (`_cmd_update_story` and `_cmd_update_epic`). The second review caught C4-C5. The third review confirmed all 5 were fixed.

## Root cause

The builder used the common `python3 << PYEOF` pattern without quoting the marker. This is a well-known bash pitfall: quoting the heredoc delimiter (`<< 'PYEOF'`) prevents all shell expansion inside the body, while unquoting it (`<< PYEOF`) allows `$variable`, backtick, and backslash expansion. The builder correctly used Python3 for JSON manipulation (consistent with project conventions) but missed the security implications of the data-passing mechanism.

## Prevention

- **Convention: Always quote heredoc markers when embedding Python/Ruby/Perl in bash.** The pattern is `python3 << 'PYEOF'` (single-quoted), never `python3 << PYEOF`.
- **Pass data via environment variables**, not shell interpolation: `export _VAR="$value"` before the heredoc, `os.environ["_VAR"]` inside Python, `unset _VAR` after.
- **Reviewer checklist item:** When reviewing bash scripts with embedded heredocs, verify the marker is quoted. `grep -n '<< [^'"'"']' scripts/*.sh` finds unquoted markers.
- The fix cycle took 2 rounds because the first fix only addressed the 3 heredocs the reviewer cited, not all 5 in the file. Reviewers should grep the entire file for the pattern, not just the flagged locations.
