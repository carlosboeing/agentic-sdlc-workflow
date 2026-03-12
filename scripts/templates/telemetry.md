<!--
  Telemetry Template — Reusable across projects.
  Single source of truth for all telemetry output (story, epic, backlog, PR).
  Used by issue-telemetry.sh to render GitHub issue comments and PR comments.

  Syntax:
    {{VAR}}                  — Variable substituted at render time
    <!-- IF_X -->            — Conditional block (included when condition X is true)
    <!-- END_X -->           — End of conditional block

  Conditions:
    TOKENS                   — Token count provided
    TOOL_USES                — Tool use count provided
    NO_PARALLELISM           — Single story (no wall-clock data)
    PARALLELISM              — Parallel dispatch (wall-clock data provided)
    TIME_SAVED               — Time saved > 0
    BREAKDOWN                — Per-story breakdown table provided
    PARALLELISM_BREAKDOWN    — Parallelism data + breakdown + time saved > 0
    GANTT                    — Gantt chart data provided
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
<!-- IF_PARALLELISM -->

### ⏱️ Duration

| Metric | Value |
|--------|-------|
| **Sequential Duration** | {{DURATION_HUMAN}} |
| **Actual Duration** _(with parallelism)_ | {{WALL_CLOCK_HUMAN}} |
<!-- IF_TIME_SAVED -->
| **Time Saved** _({{SPEEDUP}} parallel speedup)_ | {{TIME_SAVED_HUMAN}} |
<!-- END_TIME_SAVED -->
<!-- END_PARALLELISM -->
<!-- IF_BREAKDOWN -->

#### Breakdown

| Wave | Dispatch | Story | Model | Duration | Tokens | Est. Cost |
|------|----------|-------|-------|----------|--------|-----------|
{{BREAKDOWN}}
<!-- IF_PARALLELISM_BREAKDOWN -->
| | | **Actual** _(with parallelism)_ | | **{{WALL_CLOCK_HUMAN}}** | | |
| | | **Saved** _({{SPEEDUP}} parallel speedup)_ | | **{{TIME_SAVED_HUMAN}}** | | |
<!-- END_PARALLELISM_BREAKDOWN -->
<!-- END_BREAKDOWN -->
<!-- IF_GANTT -->

#### Timeline

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
<!-- IF_DISCLAIMER -->

---
*💡 Cost estimates use [Anthropic's published API token pricing](https://www.anthropic.com/pricing) with a blended rate (75% input / 25% output tokens). Actual costs vary by usage pattern. Subscription plans (Pro, Max, Team, Enterprise) include token allowances and are not charged per-token — these figures represent equivalent API value for reference only.*
<!-- END_DISCLAIMER -->
