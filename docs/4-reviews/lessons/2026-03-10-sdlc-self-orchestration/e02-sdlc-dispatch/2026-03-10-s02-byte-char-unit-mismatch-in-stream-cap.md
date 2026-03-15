---
date: 2026-03-10
author: reviewer
story: "E02-S02 (#139) — DispatchWorkerService"
tags: [review, builder, security, memory-safety, correctness]
severity: critical
---

# Byte/Char Unit Mismatch in Stream Cap Logic

## What happened

`ReadCappedAsync` correctly tracks bytes consumed using `Encoding.UTF8.GetByteCount()` throughout the read loop. However, when the cap is hit and the method needs to append "only up to the cap", it computes `remaining = maxBytes - totalBytes` (a byte count) and uses it as `charsToTake = Math.Min(charsRead, remaining)` — treating bytes as chars.

Similarly, `TruncateIfNeeded` compares `output.Length` (char count) against `maxSizeBytes` (byte count) and uses `output.AsSpan(0, maxSizeBytes)` which indexes by chars.

For ASCII content (typical Claude CLI JSON output), bytes == chars so this works. But the parameter names and config constant explicitly say "bytes", creating a contract violation for multi-byte UTF-8.

## Root cause

Easy to conflate bytes and chars when working with ASCII-dominant content. The `ReadCappedAsync` method was 90% correct — it tracked bytes properly for the accumulation check — but slipped back to char-based indexing in the truncation branch. The secondary `TruncateIfNeeded` method didn't use byte counting at all.

## Prevention

- When a parameter or variable name contains "bytes", every comparison and index operation involving it must use byte-aware APIs (`Encoding.UTF8.GetByteCount`, `Encoding.UTF8.GetBytes`).
- Reviewer should flag any comparison between `.Length` (chars) and a "bytes" variable.
- Consider adding a test with multi-byte Unicode content (e.g., emoji or CJK characters) to validate byte-cap correctness.
- The `FileStream` constructor in .NET 7+ accepts a `UnixFileMode` parameter for atomic permission setting — prefer this over create-then-chmod patterns.
