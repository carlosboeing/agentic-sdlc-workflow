---
date: 2026-03-18
author: builder
story: "E01-S02 (#216) — Local Items Module (items.sh)"
tags: [builder, shell, exit-code, testing]
severity: medium
---

# Shell `&&` Short-Circuit Leaves Non-Zero Exit Code

## What happened

`pm_update_item` updated the title correctly (the file was modified as expected)
but returned exit code 1. The test `assert_exit_zero "pm_update_item_title_exits_zero"`
failed even though the title was updated.

The implementation was:
```bash
[ -n "$new_title" ] && _local_fm_write "$item_path" title "\"$new_title\""
[ -n "$new_body" ]  && _local_write_body "$item_path" "$new_body"
```

When only `--title` was passed (no `--body`), `$new_body` was empty. The
expression `[ -n "$new_body" ]` evaluated to false (exit 1). Because `&&`
short-circuits on false, `_local_write_body` was never called — which is
correct. But the exit code of the last statement in the function was 1 (from
the failed `[ -n ... ]` test), not 0 from a successful operation.

## Root cause

In bash, a function's exit code is the exit code of its last executed statement.
`[ -n "" ]` returns 1 (false). When this is the final statement and nothing
else is evaluated after it, the function returns 1 even though it succeeded.

This is a subtle trap with the compact `[ condition ] && action` pattern — it
is correct for conditional execution but incorrect as the final statement of a
function that should report success.

## Prevention

Use `if/fi` for the last conditional action in any function that must return 0
on success:

```bash
# BAD: returns 1 when new_body is empty (even if new_title succeeded)
[ -n "$new_title" ] && _local_fm_write "$item_path" title "\"$new_title\""
[ -n "$new_body" ]  && _local_write_body "$item_path" "$new_body"

# GOOD: always exits 0 when the block completes without error
if [ -n "$new_title" ]; then
  _local_fm_write "$item_path" title "\"$new_title\""
fi
if [ -n "$new_body" ]; then
  _local_write_body "$item_path" "$new_body"
fi
```

Alternatively, append `return 0` or `: #no-op` as the last line to guarantee
exit 0 after optional conditional blocks. The `if/fi` approach is clearer and
self-documenting.

The same pattern applies to `pm_done` when `pm_set_status` may not be defined:
`declare -f pm_set_status > /dev/null 2>&1 && pm_set_status ... || true` is safe
because `|| true` ensures exit 0 either way. But pure `&&` chains without `||`
at the end are dangerous as terminal statements.
