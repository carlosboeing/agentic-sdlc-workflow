---
date: 2026-03-19
author: retro
story: "E02-S03 (#253) -- Stalled Dispatch Detection"
tags: [builder, reviewer, mermaid, template, rendering]
severity: critical
---

# Stalled Note Appended Inside Mermaid Code Fence

## What happened

E02-S03's builder appended the stalled dispatch annotation (a Markdown italic line) to the `lines` list inside `generate_gantt()`. This list produces the Mermaid Gantt body, which is placed between triple-backtick mermaid fences by the telemetry template. The italic text (`*1 stalled dispatch detected...*`) became invalid Mermaid syntax and would break chart rendering.

The reviewer (dispatch 14) correctly identified this as C1 and noted that the format contract specifies stalled notes should appear in `gantt_note`, not in the Gantt body.

## Root cause

The builder placed the stalled note inside `generate_gantt()` because that function already had access to the stalled count (computed during the dispatch loop). The design doc specified that `gantt_note` is a separate output channel rendered outside the Mermaid fence, but the builder took the expedient path of appending to the existing `lines` list rather than routing through the `gantt_note` channel.

The E02-S02 story (Gap Annotation Generation) had already built the `generate_gantt_note()` function and the `gantt_note` JSON output channel, but since E02-S02 and E02-S03 were dispatched in parallel, the E02-S03 builder did not have access to E02-S02's code and independently solved the output routing problem incorrectly.

## Prevention

- When parallel stories contribute to the same output channel (in this case `gantt_note`), the plan should explicitly document the integration point. The plan mentioned "Integrate stalled count into `gantt_note` generation (the gantt_note function from E02-S02)" but the builder could not see E02-S02's implementation at build time.
- The Mermaid rendering constraint (no arbitrary text inside Gantt body) should be noted as a test assertion: "verify that `generate_gantt()` output contains only valid Mermaid Gantt syntax." The tests added in the fix cycle (`test_stalled_note_not_in_gantt_body_singular`, `test_stalled_note_not_in_gantt_body_plural`) serve this purpose going forward.
