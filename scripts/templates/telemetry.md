<!--
  Telemetry Template — Reusable across projects.
  Single source of truth for all telemetry output (story, epic, backlog, PR).
  Used by issue-telemetry.sh to render GitHub issue comments and PR descriptions.

  Syntax:
    {{VAR}}                  — Variable substituted at render time
    <!-- IF_X -->            — Conditional block (included when condition X is true)
    <!-- END_X -->           — End of conditional block

  Modes:
    BACKLOG mode (--summary provided):
      ## heading → Summary table → Breakdown → Duration → Timeline → Footer → Disclaimer
    STORY mode (default, no --summary):
      ### heading → Metric/Value table → Breakdown → Duration → Timeline → Disclaimer

  Conditions:
    BACKLOG                  — Backlog-level telemetry (--summary provided)
    STORY                    — Story/epic-level telemetry (no --summary)
    TOKENS                   — Token count provided
    TOOL_USES                — Tool use count provided
    NO_PARALLELISM           — Single story (no wall-clock data)
    PARALLELISM              — Parallel dispatch (wall-clock data provided)
    TIME_SAVED               — Time saved > 0
    BREAKDOWN                — Per-story breakdown table provided
    GANTT                    — Gantt chart data provided
    FOOTER                   — Footer text provided (e.g., notes, PR link)
    FIX_CYCLES               — Fix cycle footer line provided (computed from dispatches)
    DISCLAIMER               — Cost estimates or breakdown shown

  Value columns contain only numbers/formatted values — no labels.
  Labels and annotations go in Metric/Story columns for machine-parseability.

  Gantt chart:
    No sections — task labels are self-explanatory. Color by task tag (no theme key):
      :active  → Violet (#8b5cf6)  — Design, Plan, Retro
      (default) → Emerald (#059669) — Build tasks
      :done    → Yellow (#ca8a04)  — Review tasks
      :crit    → Red (#dc2626)     — Fix / re-review
    No theme key in %%{init}%% — lets GitHub auto-detect dark/light mode for text
    and backgrounds while bar colors are applied on top. 600-level shades optimized
    for ~4:1+ contrast with both white text (dark mode) and black text (light mode).
    Tasks ordered chronologically top-to-bottom for a natural visual flow.
-->
<!-- IF_BACKLOG -->
## {{HEADING}}

### Summary

| Phase | Agent | Duration | Tokens | Est. Cost |
|-------|-------|----------|--------|-----------|
{{SUMMARY}}
<!-- END_BACKLOG -->
<!-- IF_STORY -->
### {{HEADING}}

| Metric | Value |
|--------|-------|
| **Model** | {{MODEL}} |
| **Commit** | `{{COMMIT_SHORT}}` |
<!-- IF_TOKENS -->
| **Tokens** | {{TOKENS_FMT}} |
| **Speed** | {{TOKENS_PER_SEC}} tokens/s |
| **Est. Cost** | {{COST_EST}} |
<!-- END_TOKENS -->
<!-- IF_TOOL_USES -->
| **Tool Uses** | {{TOOL_USES}} |
<!-- END_TOOL_USES -->
<!-- IF_NO_PARALLELISM -->
| **Duration** | {{DURATION_HUMAN}} |
<!-- END_NO_PARALLELISM -->
<!-- END_STORY -->
<!-- IF_BREAKDOWN -->

### Breakdown

| Agent | Task | Duration | Tokens | Est. Cost |
|-------|------|----------|--------|-----------|
{{BREAKDOWN}}

<!-- END_BREAKDOWN -->
<!-- IF_PARALLELISM -->

### Duration

| Metric | Value |
|--------|-------|
| **Duration** | {{DURATION_HUMAN}} |
| **Actual Duration** _(with parallelism)_ | {{WALL_CLOCK_HUMAN}} |
<!-- IF_TIME_SAVED -->
| **Time Saved** _({{SPEEDUP}} parallel speedup)_ | {{TIME_SAVED_HUMAN}} |
<!-- END_TIME_SAVED -->
<!-- END_PARALLELISM -->
<!-- IF_GANTT -->

### Timeline

```mermaid
%%{init: {'themeVariables':{
  'taskBkgColor':'#059669',
  'activeTaskBkgColor':'#8b5cf6',
  'doneTaskBkgColor':'#ca8a04',
  'critBkgColor':'#dc2626',
  'taskBorderColor':'#047857',
  'activeTaskBorderColor':'#7c3aed',
  'doneTaskBorderColor':'#a16207',
  'critBorderColor':'#b91c1c'
}}}%%
gantt
{{GANTT}}
```
<!-- END_GANTT -->
<!-- IF_FOOTER -->

{{FOOTER}}
<!-- END_FOOTER -->
<!-- IF_FIX_CYCLES -->

{{FIX_FOOTER}}
<!-- END_FIX_CYCLES -->
<!-- IF_DISCLAIMER -->

---
*💡 Cost estimates use [Anthropic's published API token pricing](https://www.anthropic.com/pricing) with a blended rate (75% input / 25% output tokens). Actual costs vary by usage pattern. Subscription plans (Pro, Max, Team, Enterprise) include token allowances and are not charged per-token — these figures represent equivalent API value for reference only.*
<!-- END_DISCLAIMER -->
