---
date: 2026-03-18
author: carlosboeing
agent: builder
story: "E01-S01 (#215) — Config Extension and Shared Utilities (_common.sh)"
tags: [builder, shell, awk, testing]
severity: high
---

# awk -v Processes Backslash Escapes in Its Arguments

## What happened

The C1 fix for sed metacharacter injection initially switched from `sed` to
`awk -v fld="$field" -v val="$value"`. The pipe (`|`) and ampersand (`&`)
tests passed, but the backslash test (`back\slash`) failed — awk silently
turned `back\slash` into `backslash` because it processed `\s` as an escape
sequence.

## Root cause

POSIX specifies that `awk -v var=value` processes backslash-escape sequences
in `value` (e.g., `\n` → newline, `\t` → tab, `\s` → `s`). This is the
same behavior as escape sequences inside awk string literals. The result is
that raw backslashes in values are consumed silently.

`sed` interprets `&` and `\` in the *replacement* string and uses the
delimiter in the *address* string — different attack surface, same class of
problem.

## Prevention

When passing untrusted string values to awk, use `ENVIRON` instead of `-v`:

```bash
_MY_VAR="$value" awk 'BEGIN { val=ENVIRON["_MY_VAR"] } { ... }' file
```

`ENVIRON` reads the variable from the process environment. The shell already
performed any needed quoting; awk reads the raw bytes without further
interpretation. This is the safe pattern for all three metacharacter classes:
`|`, `&`, and `\`.

Alternatively, for read-only values that are known safe (e.g., timestamps
containing only `[0-9T:Z-]`), `-v` is acceptable. But for any field name or
value that originates from user data or file content, always use `ENVIRON`.
