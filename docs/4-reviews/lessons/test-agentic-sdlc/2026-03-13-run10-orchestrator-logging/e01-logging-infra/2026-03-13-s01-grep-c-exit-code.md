---
date: 2026-03-13
author: builder
story: "E01-S01 (#33) — Logging Validation Script"
tags: [builder, testing, shell, posix]
severity: medium
---

# grep -c Returns Exit Code 1 on Zero Matches (Not An Error)

## What happened

In `validate-logs.sh`, `count_matching()` used `grep -c "$pattern" "$file" 2>/dev/null || echo 0`.
When the pattern matched zero lines, `grep -c` returned exit code 1 (POSIX spec for "no matches"),
which triggered the `|| echo 0` fallback. The result was both the literal "0" from grep AND "0"
from the fallback, producing a two-line "0\n0" value. This caused the `[ "$COUNT_MISMATCH" -gt 0 ]`
integer comparison to fail with "integer expression expected".

## Root cause

POSIX `grep` exit codes:
- 0: one or more matches found
- 1: no matches found (not an error — this is normal)
- 2: error (file not found, bad pattern, etc.)

The `|| echo 0` idiom treats exit 1 as an error, which is wrong for `grep -c`.

## Prevention

Capture the count first, then use `||` only for true errors (exit 2+):

```bash
count_matching() {
  local file="$1"
  local pattern="$2"
  if [ ! -f "$file" ]; then echo 0; return; fi
  # Exit 1 = no matches (normal), not an error
  local n
  n=$(grep -c "$pattern" "$file" 2>/dev/null) || n=0
  echo "$n"
}
```

This works because the `||` still runs when grep exits 1 (setting `n=0`), but now the `echo "$n"`
at the end outputs exactly one value rather than having both grep's "0" and the fallback "0" both
printed to stdout.

For extended-regex patterns (alternation), remember to pass `-E` to `grep -c`:

```bash
COUNT=$(grep -cE " tool=(Task|Agent) " "$file" 2>/dev/null) || COUNT=0
```
