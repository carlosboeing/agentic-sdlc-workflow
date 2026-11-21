---
name: briefing
description: "Context-aware project orientation. Detects whether a cycle is in progress (debrief mode) or between cycles (briefing mode) and produces a structured summary of project state, key findings, and recommended next actions. Invoke as /briefing, /briefing quick, or /briefing deep."
---

# /briefing — Project Orientation Skill

## Purpose

The `/briefing` skill provides structured project orientation for humans managing the agentic SDLC workflow. It detects project state, consults all relevant data sources, and produces a synthesized report that answers the most important questions at the moment of invocation — without the human needing to know which files to read or which commands to run.

**When to use:**
- Returning between workflow cycles: "Where are we at? What should I do next?"
- Returning after an autonomous cycle completes: "What happened? Is the PR safe to merge?"
- Any time you need a structured re-orientation to project state

**Invocation syntax:**
```
/briefing           → standard depth (default, or as configured in agentic-sdlc-config.json)
/briefing quick     → minimal sources, fast overview (200-400 words)
/briefing deep      → all sources, full analysis, trend comparison (1000-2000 words)
```

---

## Step 1: Mode Detection

Before reading any other sources, determine which mode applies. Mode detection must run first because it changes which sources to consult and what output to produce.

**Check signal 1 — Open PRs from backlog branches:**
```bash
gh pr list --head 'backlog/' --state open --json number,title,headRefName,state,reviewDecision,createdAt,url
```
If this returns any results: **debrief mode**.

**Check signal 2 — State files with incomplete phases:**
Read `.agentic-workflow/runs/*/orchestrator.json` (find the most recent file). Check the `phases` array for any phase with status not equal to `completed`. If any incomplete phase is found: **debrief mode**.

**Decision:**
- If either signal is present → **Debrief Mode** (a cycle is active or just completed)
- If neither signal is present → **Briefing Mode** (between cycles)

Announce the detected mode at the start of your response before presenting the briefing.

---

## Step 2: Depth Configuration

Determine the effective depth level for this invocation:

1. Read `briefing.defaultDepth` from `.claude/agentic-sdlc-config.json`
2. If the user passed an argument (`quick` or `deep`), it overrides the config default
3. Check `briefing.sources.*` in the config for per-source toggles — these override depth presets for individual sources (e.g., `"gitLog": false` disables git log even in deep mode)

**Depth levels:**

| Aspect | Quick | Standard | Deep |
|--------|-------|----------|------|
| Sources consulted | Top 3-4 priority | All required + judgment on optional | All 13 sources |
| Retro docs read | TL;DR/summary of latest only | Full latest retro | Last 2-3 retros + comparison |
| Lesson files | Skip | Critical/high severity only | All severities |
| Changelog depth | Last entry only | Last 3 entries | Last 5 entries + trend analysis |
| Recommendations tracker | Skip | Outstanding section only | Full file |
| Design/plan doc scan | Skip | Recent/pending only | Full scan |
| Cross-source synthesis | Skip | Basic (dependency chains, consistency) | Full (trends, recurring patterns, artifact readiness) |
| Output length | 200-400 words | 600-1000 words | 1000-2000 words |

---

## Step 3: Data Source Checklist

Consult sources in priority order. If context limits are reached, stop at the highest-priority sources already read rather than skipping to lower ones.

### Tier 1 — Frontmatter-Driven Discovery

These sources are discovered dynamically via frontmatter grep commands. Do not hardcode paths per document type — use the grep patterns to find relevant docs.

**Priority 3 — Retro docs (last 1-2, or more in deep mode):**
```bash
# Find all retro docs by date — sort descending, take most recent
grep -rl "^date:" docs/4-reviews/ | sort -r | head -3
```
Read YAML frontmatter to get `date`, `backlog-issue`, and `author`. Then read the full body for:
- "What Worked" section → patterns to repeat
- "What Didn't Work" section → issues to address
- Specific recommendations → actions not yet taken
- Metrics summary → cost, duration, fix cycle rate for trend analysis

In quick mode: read only the TL;DR or summary section of the most recent retro.
In deep mode: read the last 2-3 retros and compare metrics across them.

**Priority 4 — Design docs (open/pending/recent):**
```bash
# Find design docs with pending status
grep -rl "^status: [Dd]raft" docs/2-design/
# Find approved design docs (may be awaiting planning)
grep -rl "^status: [Aa]pproved" docs/2-design/
# Find most recent by date prefix
ls -t docs/2-design/*.md 2>/dev/null | head -5
```
Extract: status, backlog reference, whether a corresponding plan exists. Surface design docs that represent pending work (Draft = needs attention; Approved + no plan = ready to plan).

Skip in quick mode.

**Priority 5 — Plan docs (open/pending/recent):**
```bash
# Find plan docs with pending status
grep -rl "^status: [Dd]raft" docs/3-plans/
grep -rl "^status: [Aa]pproved" docs/3-plans/
ls -t docs/3-plans/*.md 2>/dev/null | head -5
```
Extract: status, backlog reference, whether execution has started. Surface plans that are approved and ready to build.

Skip in quick mode.

**Priority 7 — Lesson files (debrief mode, or critical lessons in briefing mode):**
```bash
# Find critical/high severity lessons — read frontmatter first
grep -rl "^severity: critical" docs/4-reviews/lessons/
grep -rl "^severity: high" docs/4-reviews/lessons/

# For debrief: scope to current cycle's lesson folder
# Use the backlog number from the active PR to find the right folder
grep -rl "^backlog" docs/4-reviews/lessons/
```
Read YAML frontmatter (`severity`, `tags`, `story`) first. Then read full body only for critical and high severity items. Group by severity. Count total lessons (high count signals a turbulent cycle). Look for lessons with the same `tags` appearing across multiple files — these are systemic patterns.

In deep mode: read all severities.
In quick mode: skip.
Per config: respect `briefing.sources.lessonFiles.severityThreshold`.

### Tier 2 — Fixed-Path Sources

These sources are at known locations or accessed via known commands. Read them directly without discovery.

**Priority 1 — Open PRs (always, all modes):**
```bash
gh pr list --state open --json number,title,headRefName,state,reviewDecision,createdAt,url
```
Extract:
- PRs from `backlog/*` branches (primary debrief signal — already checked in Step 1)
- PR review status: `reviewDecision` field (APPROVED, CHANGES_REQUESTED, REVIEW_REQUIRED)
- PR age: `createdAt` vs current date
- Non-backlog PRs: design/plan doc PRs, dependency PRs

**Priority 2 — Roadmap (`docs/ROADMAP.md`):**
Read the full file. Extract:
- Completed vs total items (count lines with `[x]` vs total checkboxes)
- Priority order of remaining items
- Dependency chains (what becomes unblocked after the last completed cycle)
- Items marked as "blocked" with their blockers
- Plugin/future track items (strategic context)

**Priority 6 — Orchestrator state file (debrief mode only, standard/deep):**
```bash
# Find the most recent state file
ls -t .agentic-workflow/runs/*/orchestrator.json 2>/dev/null | head -1
```
Read the most recent file. Extract from:
- `session` → `orchestrator_model`, `start_wall_clock`, `mode`
- `phases` → which phases completed vs pending vs in-progress
- `dispatches[]` → per-agent durations, tokens, models, results, `review_tier`
- `overhead` → orchestrator overhead duration

Do NOT compute costs or durations yourself from raw token counts — read computed values from telemetry comments on issues instead (use `gh issue view <N> --comments` to find the "Telemetry" comment posted by `item-telemetry.sh`).

**Priority 8 — Reviewer comments on story issues (debrief mode only, standard/deep):**
For each story in the current cycle (find story issue numbers from the backlog PR or the state file dispatches):
```bash
gh issue view <story-N> --comments
```
Look for comments containing `APPROVE` or `REQUEST_CHANGES` verdict. Extract:
- Verdict per story
- Specific findings (critical, warning, suggestion labels in reviewer comments)
- Whether fix cycles resolved the findings
- Cross-story patterns: the same type of finding appearing in multiple stories

**Priority 9 — Changelog (`docs/CHANGELOG.md`):**
Read and extract the last 1 entry (quick), 3 entries (standard), or 5 entries (deep). Per config: respect `briefing.sources.changelog`.
Extract:
- Recent cycle outcomes (topic, scope, duration, key results)
- Wall-clock and cost across entries for trend analysis in deep mode

**Priority 10 — Retro recommendations tracker (`docs/4-reviews/retro-recommendations.md`):**
This file may lag behind actual retro docs — treat as supplementary to retro docs, not a replacement. Skip in quick mode; read outstanding section only in standard mode; read full file in deep mode.
Extract:
- Outstanding recommendations with recurrence count > 1 (systemic patterns)
- High-priority outstanding items
- Recently implemented recommendations (progress on tech debt)
- Total outstanding vs implemented ratio

Per config: respect `briefing.sources.retroRecommendations`.

**Priority 11 — CLAUDE.md-referenced docs (see Tier 3 below)**

**Priority 12 — GitHub board (`./scripts/item-list.sh --state open --limit 50`):**
Skip in quick mode. In standard/deep mode, extract:
- Issue count by status (Ready, In Progress, In Review)
- Anomalies: issues stuck in a status, mixed epic statuses
- Total open issue count

Per config: respect `briefing.sources.board`.

**Priority 13 — Git log (deep mode only, if config `gitLog: true`):**
```bash
git log --oneline -20
git log main --oneline -5
```
Extract: recent commit activity, whether integration branch is ahead of main, any unusual commits (manual fixes, reverts). Per config: `gitLog` defaults to `false` — only read if explicitly enabled.

### Tier 3 — CLAUDE.md-Referenced Docs

CLAUDE.md is already loaded into your context. Scan it for references to project documentation files — file paths, doc sections, or explicitly listed reference documents. Use judgment to identify which referenced docs are relevant to project orientation (architecture docs, vision docs, guides) vs operational details (script flags, config schemas).

Examples of relevant references:
- `docs/architecture.md` → current architecture context
- `docs/ROADMAP.md` → strategic direction
- `docs/6-adrs/` → recent architectural decisions
- `CONTRIBUTING.md` → team conventions

Read the relevant docs and weave their key points into the appropriate briefing sections. Skip in quick mode.

**Priority 11** in the source table — supplementary, read only if standard or deep depth.

---

## Step 4: Cross-Source Synthesis

After reading sources, look for connections that no single source reveals. This step applies in standard and deep mode; skip in quick mode.

**Recurring patterns:** Check if a recommendation in `retro-recommendations.md` also appears as a lesson in the current cycle. If yes, flag as "still happening — needs escalation" rather than just listing both.

**Trend detection:** If you have data from 3+ retro docs or changelog entries, note whether metrics (cost, duration, fix cycle rate) are improving or degrading. Avoid computing precise aggregates — describe the direction.

**Dependency chains:** Cross-reference the roadmap with the recently completed cycle. Which roadmap items just became unblocked because a prerequisite completed? Highlight these as "newly available."

**Artifact readiness:** For items on the roadmap: check if a design doc exists (approved or draft), whether a plan exists, and whether execution has started. Synthesize into a readiness state: "design done, needs planning" or "approved plan, ready to build" or "not started."

**Consistency checks:** Compare board status (`item-list.sh`) with state file phases and PR status. Flag any discrepancies (e.g., board shows "In Progress" but PR is already open, state file shows all phases complete).

---

## Step 5: Output

Use the appropriate template based on the mode detected in Step 1.

### Output Template: Briefing Mode

Use this template when between cycles (no active PR or incomplete state file found).

```
## Briefing — <project name>
<date> · <time since last cycle completed, if determinable>

### TL;DR
<1-2 sentences: where the project stands and the suggested next action.
Lead with the most important thing. Be specific — name the backlog item.>

### Project Pulse
- **Last completed:** <topic> (backlog #N, <wall-clock if available>, <cost if available>)
- **Roadmap:** X/Y items complete · next priority: <item> (<difficulty if labeled>)
- **Tech debt:** N outstanding recommendations (<M high-priority>)
- **Trends:** <1-2 notable cross-cycle trends, or "insufficient data" if only 1 cycle available>

### What Happened Last
<3-5 bullets summarizing the last cycle's key outcomes, notable findings, and
any unresolved issues. Synthesize from retro doc + changelog. Do not reproduce
raw metrics — summarize what mattered.>

### Roadmap & Priorities
<Current state: what's done, what's next, what's blocked.
Highlight newly unblocked items after last merge.
Include dependency reasoning for the recommended next item.
If design/plan docs exist for upcoming items, note their readiness state.>

### Outstanding Issues
<Accumulated recommendations not yet addressed, grouped by urgency.
Recurring patterns flagged with recurrence count.
Source: retro-recommendations.md + recent lesson files.
If nothing outstanding: state that explicitly.>

### Decisions & Attention Needed
<2-3 items requiring human judgment. Examples:
- Design decisions the AI cannot make alone
- Recurring issues that need a convention change
- Priority or scope trade-offs
- Cost or effort concerns
If nothing requires attention: state that explicitly.>
```

### Output Template: Debrief Mode

Use this template when an active backlog PR or incomplete state file is detected.

```
## Debrief — <topic from PR title>
<date> · backlog #N · <wall-clock from telemetry, if available> · <cost from telemetry, if available>

### TL;DR
<1-2 sentences: how the cycle went and the single most important thing
before considering a merge. Be specific about merge readiness.>

### Summary
- **Stories:** N built, M reviewed, K fix cycles
- **Cost:** $X.XX (<comparison to recent average if available>)
- **Duration:** Xm wall-clock (Ym sequential, Z% parallel speedup if available)
- **Models used:** <list from state file dispatches or telemetry>

(Read metrics from existing telemetry comments on issues — do not compute from raw token counts.)

### Key Findings
<Synthesized from reviewer comments, retro doc, and lesson files.
Grouped by impact:>
- **Needs fixing before merge:** <specific items, or "none">
- **Worth knowing:** <notable findings that don't block merge>
- **Positive patterns:** <things that went well worth reinforcing>

### What Went Well
<2-3 highlights worth repeating in future cycles. Source: retro doc "What Worked" section + reviewer APPROVE comments.>

### What Needs Attention
<Issues that may need fixing before merge.
For each item: what it is, severity, and whether it is fixable now or should be deferred.
Clear distinction between "must fix before merge" and "nice to have.">

### Merge Readiness
<Explicit recommendation: one of:
- "Ready to merge" — all reviewer findings resolved, no critical issues
- "Merge with caution" — minor unresolved items, acceptable to merge with awareness
- "Fix before merging" — specific items must be addressed first (list them)
- "Discuss before merging" — requires human judgment on a design question

If recommending fixes: provide a numbered list of specific items to address.>

### What's Next
<After merge, what becomes unblocked on the roadmap?
Suggested next backlog item with rationale — reference roadmap priority and dependency chain.>
```

---

## Tone and Style

- **Lead with the most important thing.** The TL;DR should be the first thing read and contain the key message. If you had to cut everything else, this should still be useful.
- **Be specific.** Name backlog items, reference issue numbers, cite actual metrics from sources. Vague summaries ("some issues were found") are less useful than specific ones ("reviewer flagged missing DI registration in 2 of 4 stories").
- **Use metrics where available.** If telemetry is posted, cite the numbers. If a retro records costs and durations, surface them. Do not estimate — if you cannot find a metric in existing sources, note that it is unavailable.
- **Concise over comprehensive.** Each section should say what it needs to say without padding. Bullets over prose where structure helps scanning. No filler phrases like "It's worth noting that..."
- **Neutral tone.** Report what the sources say. Do not overstate urgency or add editorial judgment beyond what is warranted.

---

## Anti-Patterns

These behaviors are explicitly prohibited. Do not do any of the following:

- **Do not generate from memory.** Every data point in the briefing must come from a source you read during this invocation. Do not rely on what you remember from earlier in the conversation — always read current sources.
- **Do not modify any files.** The `/briefing` skill is strictly read-only. Do not write to docs, config, or any other file.
- **Do not post comments or update issues.** Do not run `gh issue comment`, `item-comment.sh`, `item-set-status.sh`, or any command that modifies GitHub state.
- **Do not compute metrics from raw data.** Do not compute costs from token counts, durations from timestamps, or other aggregates. Read them from existing telemetry comments, changelog entries, or state files where they are already computed by deterministic scripts.
- **Do not skip sources in the checklist without noting it.** If a source is unavailable (file not found, command fails, config disabled), note it explicitly in the output: "Retro recommendations tracker not found — skipping." This keeps the briefing honest about its coverage.
- **Do not present the briefing as definitive.** The briefing reflects what the sources say at the moment of invocation. Conditions may have changed if files were modified, issues updated, or PRs merged since you started reading.

---

## Conversational Continuation

After presenting the briefing, remain available for follow-up questions using the full context gathered during investigation. Common follow-ups include:

- "Tell me more about [finding X]" → read deeper into the source you already identified
- "Show me the reviewer comment about [issue]" → run `gh issue view <N> --comments` and display the relevant comment
- "Let's start working on [BL#N]" → transition naturally to helping the user begin the next cycle
- "What exactly did the retro recommend about [topic]?" → pull the specific section from the retro doc you already read

You do not need to re-read sources from scratch for follow-up questions unless the human explicitly requests a refresh. The context from your investigation is your working memory for this conversation.
