# Changelog

## 2026-11-21

### Public release preparation

Prepares the March 2026 system for a public first run: repaired, not extended. Decision: [ADR 0007](6-adrs/0007-merge-reference-design-and-publish.md). Assessment: [public release assessment](4-reviews/2026-11-20-public-release-assessment.md).

- **Reference design merged** under `blueprint/` with its history, marked historical and unexecuted; the starter kit's approve-all hook replaced, its agents and scripts repaired, and the kit labelled illustrative
- **Synthetic outputs removed from the tree:** workload outputs, per-run designs and plans, and file-adapter residue are gone from the current tree and remain in Git history; lesson folders renamed to neutral run names; lifecycle records sanitized and given a historical note
- **Regression fixed:** the code reverted by retro commit `4d3ab9b` is restored (`72f7476`); server 681 of 681, telemetry 252 of 252 and offline shell 34 of 34 pass
- **CI:** server, telemetry and offline shell jobs behind a single `required` gate, SHA-pinned actions, Dependabot for GitHub Actions and the server packages (`ab3d57e`)
- **Retro scope guard:** `scripts/check-retro-scope.sh` fails `docs(retro)` commits that touch code; it runs in CI and in the orchestrator after the retro, followed by the full test suite (`b5a4212`)
- **Safe defaults:** owner board IDs removed and board work skipped when unconfigured (`93c7598`); permissions shaped for `--permission-mode dontAsk` with deny rules, and the logging hook fixed for the `Agent` tool name (`4be6d23`, `57aabfa`); built frontend assets untracked (`00e2db0`)
- **Docs:** README rewritten around evidence and human gates; new [architecture](architecture.md), [methodology](methodology.md), [case studies](case-studies.md), [running-safely guide](5-guides/running-safely-guide.md), ROADMAP, the [real-task backlog](3-plans/2026-11-20-real-task-backlog-plan.md) and the November 2026 research records; community health files and issue and PR templates
- **Restored:** the backlog item 116 entry below, which `4d3ab9b` had deleted
- **Run names:** synthetic run headings in this file now use run numbers instead of workload themes

## 2026-03-23

### GitHub-to-SQLite Sync — Pull Direction (backlog #364)

- **Pull sync engine:** Fetches all issues from GitHub GraphQL API with cursor pagination and upserts into SQLite. Three components: GitHubPullFetcher, IssueMapper, DatabaseUpserter
- **Three trigger points:** `POST /api/sync/pull` API endpoint, `bun run server/src/index.ts sync` CLI command, automatic on startup (replaces file-based seed with GitHub-first + file fallback)
- **Rate limit awareness:** Pre-flight check, per-page monitoring, abort at 500-point threshold (~126-400 points for 300 issues)
- **PM adapter simplified:** Workflow server (SQLite) is now the default local PM adapter. `pm.adapter` config names the sync target. Old `.workflow/items/` files removed
- **Infrastructure fixes:** Server API accepts explicit IDs for dual-write sync, `_local_pm_create_item_with_id` added to server adapter, port file path bug fixed
- 2 epics, 5 stories (2 medium, 2 easy, 1 medium), 1 fix cycle (E01-S01 comment overflow data corruption), 1 PR fix cycle (interface mismatch NaN counters)

## 2026-03-22

### Workflow Runtime Service (backlog #116)

Persistent Bun server that replaces the file-system PM adapter with SQLite, serves a React dashboard, provides a document viewer with inline comments, and exposes PM operations as MCP tools.

**6 epics, 18 stories:**

- **E01: Server Foundation** — Bun project setup, Drizzle ORM schema (7 tables), PM service layer (6 services, 112 tests), server lifecycle with daemon management
- **E02: HTTP API & Shell Adapter** — 20+ Hono REST endpoints, Zod validation, server PM shell adapter with fallback to local file adapter
- **E03: MCP Server** — 13 MCP tools via stdio transport, `.mcp.json` for Claude Code auto-discovery, dual-mode startup (HTTP + MCP)
- **E04: Sync Engine** — Durable sync queue with retry/backoff/dead-letter, GitHub external adapter, YAML-to-SQLite migration script
- **E05: Dashboard UI** — React SPA with Kanban board (drag-and-drop), item detail view, telemetry summary, WebSocket activity feed
- **E06: Document Viewer** — Document API, markdown preview with Mermaid, paragraph-anchored comment threads with stale detection

### Briefing Skill: Context-Aware Project Orientation (backlog #316)

- **New `/briefing` skill:** Pure AI-driven Claude Code skill that provides structured project orientation with two modes — briefing (between cycles) and debrief (PR open/cycle completed)
- **Three-tier data source discovery:** Frontmatter-driven (Tier 1), fixed-path (Tier 2), CLAUDE.md-referenced (Tier 3) — 13 sources total with priority ordering
- **Configurable depth:** `/briefing quick`, `/briefing`, `/briefing deep` with config overrides in `.claude/agentic-sdlc-config.json`
- **SBAR-inspired debrief:** Healthcare shift-handoff model adapted for merge-readiness assessment
- **Read-only, zero side effects:** Safe to run at any time; model improvements directly improve briefing quality
- 1 epic, 2 stories (1 easy, 1 medium), 0 fix cycles

## 2026-03-20

### Run 17 -- synthetic workload (backlog #303, 52m wall-clock)

- **Full e2e pipeline validated:** Design → plan → build → review → retro with no skipped phases
- **Tiered review strategy:** 4 easy stories (SKIP tier) bypassed per-story review, 1 medium story (REVIEW tier) received per-story review with APPROVE verdict
- **Parallel dispatch:** 4 builders dispatched simultaneously in Wave 1 (3+1 due to maxParallelBuilders: 3)
- **Cross-reference validation:** E02-S03 correctly cross-referenced specific details from E01-S01 and E01-S02
- **Planted bug detection:** 2 bugs planted — one in E02-S02 (SKIP tier, for the PR reviewer), one in E02-S03 (REVIEW tier, caught by the per-story reviewer)
- **Content:** 5 synthetic prose files (removed from the tree in November 2026; kept in Git history)
- **Test run asset conventions:** All docs in `test-agentic-sdlc/` subfolders validated
- 2 epics, 5 stories (4 easy, 1 medium), 0 fix cycles

### Run 15 -- synthetic workload (backlog #290, 49m wall-clock)

- **First end-to-end synthetic run of the tiered review strategy:** 4 easy stories successfully bypassed per-story review (`review_tier = SKIP`), 1 medium story received full per-story review (`review_tier = REVIEW`) with 1 fix cycle (formatting issue)
- **Parallel dispatch validated:** 4 builders dispatched simultaneously in Wave 1, all completed successfully
- **Content:** synthetic prose files: listings and guides (removed from the tree in November 2026; kept in Git history)
- **Cross-reference validation:** E02-S03 correctly cross-referenced all six E01 entries by name with consistent details
- **Agent attribution:** All issues created with `--created-by` metadata
- 2 epics, 5 stories (4 easy, 1 medium), 1 fix cycle

## 2026-03-19

### Phase Restructuring: Parallel Reviews, Tiered Review Strategy, and Phase Simplification (backlog #243)

- **Orchestrator phase restructuring:** Collapsed 10+ phases into 7 (Phases 0-6: Setup, Design, Plan, Implementation, Open PR, Review + Retro, Telemetry + Cleanup)
- **Parallel review dispatch:** Reviewers for a wave are now dispatched in parallel (multiple Agent tool calls) instead of sequentially. Parallel fix cycles also supported.
- **Tiered review strategy:** Easy test stories skip per-story review when `reviewStrategy.skipPerStoryReview.enabled` is true in config. PR review remains the cross-story quality gate.
- **Config:** Added `reviewStrategy` section to `agentic-sdlc-config.json` with `skipPerStoryReview.enabled`, `conditions.maxDifficulty`, and `conditions.requireLabel`
- **config.sh:** Three new variables: `CFG_SKIP_REVIEW_ENABLED`, `CFG_SKIP_REVIEW_MAX_DIFFICULTY`, `CFG_SKIP_REVIEW_REQUIRE_LABEL`
- **CLAUDE.md:** Updated Dispatch Protocol with parallel review dispatch, review tier logic, and new phase numbering
- **Convention improvements:** Added mandatory Research & Feasibility Verification to designer agent; added "Do NOT over-constrain the designer" guidance to orchestrator; documented subagent nesting hard cap in Known Platform Limitations
- 2 epics, 4 stories (all sequential due to config → library → agent → convention dependency chain)
- 51 tests (35 existing + 16 new for review strategy config)


## 2026-03-19

### Gantt Chart Readability: Story Code Regression and Work Timeline Mode (backlog #242, ~100m wall-clock)

- **Story code regression fixed:** Breakdown table now includes a Story column (e.g., `E01-S02`) for builder/reviewer/fix dispatches, with `--` for design/plan/retro
- **Fallback story code extraction:** When branch-based story labels fail, reverse-lookup via `state.epics.*.stories` keys derives codes automatically; diagnostic warning logged to stderr
- **Work Timeline mode (default):** Gantt X-axis now shows cumulative active time instead of wall-clock; gaps between waves are collapsed. `--gantt-mode work` (default) vs `--gantt-mode wall-clock` (original behavior preserved)
- **Gap annotations:** `gantt_note` generated below the chart when inter-wave gaps > 5 minutes are compressed, listing individual gap durations
- **Stalled dispatch detection:** Dispatches with < 50 tok/s throughput annotated with `[stalled]` suffix in Gantt labels; count included in `gantt_note`
- **Template update:** `scripts/templates/telemetry.md` breakdown header updated to 6-column format; `GANTT_NOTE` conditional block added
- **CLI passthrough:** `item-telemetry.sh --gantt-mode` flag passes through to `compute-dispatches.py`
- 2 epics, 5 stories: E01 Story Code Regression (2 stories), E02 Work Timeline Mode (3 stories)
- 252 Python tests + 44 shell integration tests, all passing
- 2 fix cycles: E01-S01 (template scope creep), E02-S03 (stalled note inside Mermaid fence + None guard)

## 2026-03-19

### Dual-Write PM Layer (backlog #227)

- **Primary result:** Refactored `pm.sh` from single-adapter ("pick local OR github") to dual-write ("local always-on, external optional fire-and-forget")
- `pm.sh` loader now always sources local adapter first, renames functions to `_local_pm_*`, then optionally sources external adapter as `_external_pm_*`
- Dual-write wrapper generation: classifies all 16 `pm_*` functions into three categories:
  - **Dual-write** (9 functions): calls local sync, then external fire-and-forget in background
  - **Local-only** (3 functions): reads always from local (source of truth)
  - **Composed** (4 functions): delegates to local, which calls dual-write primitives internally
- Special `pm_create_item` wrapper: calls external synchronously to get ID, creates local with same ID, falls back gracefully
- Prefix injection (`_PM_FN_PREFIX`) added to all 7 GitHub adapter modules — functions define as `pm_*` or `_external_pm_*` based on `_PM_LOADING_EXTERNAL` flag
- `_local_pm_create_item_with_id` helper for explicit-ID item creation with `_next_id` counter bump
- `workflowDir` promoted to top-level config (not PM-specific), backward compat with `pm.local.workflowDir`
- `pm.adapter` semantic shift: from "which adapter to use" to "which external adapter to sync to"
- Fire-and-forget external calls with logging to `.agentic-workflow/logs/external-sync.log`
- 2 epics, 6 stories: E01 Foundation (3 stories), E02 Dual-Write Loader (3 stories)
- 460+ tests across 11 test suites, all passing
- 2 fix cycles: E01-S02 (test line-count threshold), E02-S01 (test regression + stale comment + guard tracking)
## 2026-03-18

### Local-First PM System (backlog #111)

- **Primary result:** Built the complete local/file-based PM adapter so the workflow works without any external PM tool
- Created `scripts/lib/adapters/pm/local/` with 8 modules: _common.sh, items.sh, board.sh, comments.sh, hierarchy.sh, labels.sh, lifecycle.sh, reconcile.sh
- All 15 `pm_*` functions implemented: switching `pm.adapter` from `"github"` to `"local"` in config is the only change needed
- `.workflow/items/*.md` with YAML frontmatter — human-readable, git-diffable, greppable work items
- `.workflow/comments/<id>/NNN-slug.md` — timestamped comment history per item
- Auto-increment ID generation via `_next_id` file, no external dependencies
- Individual files ARE the index — no centralized board.yaml, no concurrent write conflicts by design
- Refactored `item-telemetry.sh` to use `pm_add_comment` (adapter-agnostic telemetry posting)
- Added `CFG_LOCAL_WORKFLOW_DIR` config field (default: `.workflow`)
- 3 epics, 9 stories: E01 Foundation (2 stories), E02 Domain Modules (3 stories), E03 Composition + Integration (4 stories)
- 300+ unit tests across 16 test suites plus integration test, all passing
- 3 fix cycles: E01-S01 (sed metachar injection + labels-last drop), E01-S02 (JSON title escaping), E03-S01 (emoji mismatch)

### PM Abstraction Layer (backlog #109)

- **Primary result:** Introduced a clean PM adapter boundary between workflow process logic and external project management platforms
- Created `scripts/lib/pm.sh` adapter loader with config-driven adapter selection (`pm.adapter` in config)
- Built GitHub adapter in `scripts/lib/adapters/pm/github/` with 7 modules: items.sh, board.sh, reconcile.sh, comments.sh, hierarchy.sh, labels.sh, lifecycle.sh
- Defined ~13 generic PM functions (pm_create_item, pm_get_item, pm_list_items, pm_close_item, pm_set_status, pm_add_to_board, pm_batch_set_status, pm_reconcile, pm_add_comment, pm_post_telemetry, pm_link_child, pm_add_label, pm_start_work, pm_complete_work, pm_update_item)
- Converted 8 existing scripts (item-set-status.sh, batch-set-status.sh, item-start.sh, item-review.sh, item-close.sh, item-create.sh, reconcile-board.sh, setup-labels.sh) to thin wrappers delegating to pm.sh
- Added cost budget enforcement library (`scripts/lib/cost-budget.sh`) with `maxCostPerRun` config support
- Created ADR-0004: Shadow Stack Migration Strategy (build-alongside-verify-swap pattern)
- Design doc includes three-layer abstraction landscape (PM/VCS/DOC), agent architecture audit, and forward compatibility for local-first PM (#111) and multi-PM adapters (#113)
- 3 epics, 10 stories: E01 Foundation (6 stories), E02 Lifecycle + Cost Budget (2 stories), E03 Swap + ADR (2 stories)
- 289 unit tests across 9 test suites, all passing with zero regressions
- 1 fix cycle: E01-S06 hierarchy.sh/labels.sh (reviewer found unchecked GraphQL exit code + silenced label creation errors)

## 2026-03-17

### Run 16 -- synthetic workload (backlog #167, 136m wall-clock)

- **Primary result:** First test run with the slimmed orchestrator.md (503 lines) and `state.sh` for all state management
- Validated `state.sh` integration: `init`, `update --dispatch`, `update --add-story`, `update --epic --base-sha`, `overhead`, `lifecycle-duration`
- Validated `maxParallelBuilders: 3` config enforcement: Wave 1 (5 stories) correctly split into 3+2 sub-waves
- Synthetic content across three document sets (removed from the tree in November 2026; kept in Git history)
- 3 epics, 9 stories: E01 (4 stories), E02 (3 stories), E03 (2 stories)
- Dispatch: 5 waves — Wave 1a parallel (3-way), Wave 1b parallel (2-way), Wave 2 sequential, Wave 3 parallel (2-way), Wave 4 sequential
- 3 fix cycles: E02-S02 (word count + missing template sections), E02-S01 (missing table column + short backstories), E02-S03 (planted bug — wrong cross-reference caught by reviewer)
- Planted bug validation: reviewer correctly identified a planted wrong cross-reference, triggering a fix cycle
- Difficulty: 4 easy, 4 medium, 1 hard; Models: 8 sonnet builds + 1 opus build, 4 sonnet reviews + 5 opus reviews

## 2026-03-17

### Split orchestrator.md — Run 15 (backlog #150, 77m wall-clock)

- **Primary result:** Reduced `orchestrator.md` from 1,323 to 503 lines (62% reduction) by extracting inline scripts into real scripts and deleting dead/redundant content
- Created `scripts/state.sh` (836 lines) with subcommands: `init`, `update` (dispatch/story/phase/epic), `get`, `overhead`, `lifecycle-duration`, `reconstruct` (stub)
- Extended `compute-dispatches.py` with `--overhead` flag for orchestrator overhead telemetry row
- Created `scripts/schemas/orchestrator-state.v1.json` (236 lines) — state file schema as actual JSON Schema
- Added "Fault Tolerance" design principle to CLAUDE.md alongside "Determinism First"
- Updated CLAUDE.md state file section to use `state.sh` calls instead of inline code
- Fixed heredoc injection vulnerability (unquoted `PYEOF` markers allowing bash variable expansion in Python code)
- 2 epics, 5 stories: E01 Script Extraction (3 stories), E02 Documentation Rewrite (2 stories)
- Dispatch: 4 waves — Wave 1 parallel (2-way), Waves 2-4 sequential
- 1 fix cycle: E01-S01 heredoc injection (2 rounds — reviewer found additional unquoted heredocs in re-review)
- 142 Python tests + 48 bash tests covering extracted scripts

## 2026-03-16

### Telemetry Accuracy & Automation (backlog #106)

- **Primary result:** Refactored the telemetry pipeline to eliminate manual Gantt construction, extract embedded Python into a testable module, and add fix cycle tracking
- Extracted ~230 lines of embedded Python from `item-telemetry.sh` into standalone `scripts/lib/compute-dispatches.py` (875 lines with Gantt + fix cycle features)
- Added `--gantt-from-state` flag: generates Mermaid Gantt charts with absolute HH:MM:SS offsets from state file dispatch data (no more hand-crafted `after` dependencies)
- Added fix cycle detection: automatically counts builder re-dispatches, computes cost/duration overhead, and includes metrics in telemetry summaries
- Added `lifecycle_duration_ms` convention: orchestrator records wall-clock duration at end of workflow for baseline tracking
- 123 Python unit tests + 35 bash integration tests cover the extracted module
- Script reduced from 662 to 469 lines (29% reduction)
- 2 epics, 7 stories: E01 Telemetry Pipeline Refactor (4 stories), E02 Conventions & Documentation (3 stories)
- Dispatch: 4 waves — Wave 1 sequential, Wave 2 parallel (2-way), Wave 3 sequential, Wave 4 parallel (3-way)
- 1 fix cycle: E01-S02 Gantt generation had `section Wave N` directives that violated convention (removed in fix)
- Addresses retro recommendations G (lifecycle duration), I (Python extraction), L (fix cycle tracking)

## 2026-03-16

### Orchestrator Improvements (Backlog #105)

- **6 orchestrator enhancements** implemented across 4 waves (2 parallel, 2 sequential):
  - **Sonnet Reviews for Easy Stories:** Added `reviewerRouting` config and reviewer variant files (`reviewer-sonnet.md`, `reviewer-opus.md`), reducing review cost ~15-20% for easy stories
  - **Early Story Branch Creation:** Moved all branch creation to Phase 4, eliminating ~30s per wave transition
  - **Batched Board Updates:** New `batch-set-status.sh` script for batch status transitions at wave boundaries
  - **Format Templates for Parallel Content:** Added planner guideline requiring format contracts for shared structural elements
  - **Orchestrator Override Pattern:** Formalized the override convention for pre-fixed reviewer findings in `orchestrator.md`
  - **Capture Orchestrator Overhead Metrics:** Added wall-clock heuristic for measuring orchestrator overhead
- 2 improvements deferred: Streaming Reviews (high complexity), Batch Issue Creation (obsoleted by PM Abstraction Layer)
- Retro recommendations E, F, H moved to Implemented
- First real workflow-on-workflow run (orchestrator agents modifying their own instructions)

## 2026-03-15

### Test SDLC v2 Workflow (Run 14) — Fix-Cycle Validation

- **Primary result:** Validated the fix cycle path (reviewer REQUEST_CHANGES → builder fix → re-review) for the first time in SDLC v2. Two fix cycles completed successfully out of 4 planted bugs
- Content: synthetic prose documents (removed from the tree in November 2026; kept in Git history)
- 2 epics, 12 stories: E01 (7 stories), E02 (5 stories)
- Dispatch: 5 waves with max 3 parallel builders per wave (Wave 1-3: 3-way parallel sonnet, Wave 4: 2-way parallel opus, Wave 5: sequential opus)
- Bug planting results: 4 bugs planted (contradictory AC, missing section, format contradiction, wrong cross-reference). 2 triggered fix cycles (E01-S04 word count, E02-S01 format), 2 were avoided by builders following acceptance criteria
- Fix cycle machinery confirmed working: REQUEST_CHANGES → builder fix → re-review → APPROVE
- Cross-epic dependencies validated: E02 stories reference E01 documents by document number
- Worktree cross-contamination observed in fix cycle 2 (E01-S04) — E02-S01 file leaked into E01-S04 branch via worktree artifact


## 2026-03-15

### Test SDLC v2 Workflow (Run 13) — Runtime Data and Live Pricing

- **Primary result:** Validated runtime data consolidation (.agentic-workflow/), live pricing (fetch-pricing.sh), and dispatches-from-state telemetry computation
- Content: synthetic prose documents (removed from the tree in November 2026; kept in Git history)
- 1 epic, 6 stories
- Dispatch: Wave 1 (3-way parallel easy), Wave 2 (2-way parallel medium), Wave 3 (sequential hard with cross-references to all prior docs)
- All three difficulty levels tested: easy x3 sonnet, medium x2 sonnet, hard x1 opus
- Zero fix cycles — all 6 stories passed review on first attempt (6 APPROVE verdicts)
- Live pricing fetched successfully from anthropic.com/pricing (Opus $5/$25, Sonnet $3/$15, Haiku $1/$5)
- ~464K tokens across 12 build+review dispatches for epic E01

## 2026-03-15

### Test SDLC v2 Workflow (Run 12) — Configurable Settings

- **Primary result:** Validated configurable workflow settings from PR #55 — scripts reading from `.claude/agentic-sdlc-config.json`, model routing, pricing, and YAML frontmatter plan detection
- Content: synthetic prose documents (removed from the tree in November 2026; kept in Git history)
- 1 epic, 5 stories, the last one cross-referencing the other four
- Dispatch: Wave 1 (3-way parallel with worktree isolation), Wave 2 (sequential medium), Wave 3 (sequential hard with cross-references)
- All three difficulty levels tested: easy x2 sonnet, medium x2 sonnet, hard x1 opus
- Zero fix cycles — all 5 stories passed review on first attempt
- Lesson captured: backlog issue should be set to In Progress at design phase start, not at builder dispatch
- Telemetry note: original cost of ~$4.77 was correct ($10/M blended Opus rate). The "correction" to $12.55 used an incorrect $30/M rate — see `docs/1-discovery/2026-03-19-workflow-optimization-analysis.md` § 1 for verification across all runs


## 2026-03-14

### Test SDLC v2 Workflow (Run 11) — Board Drift Detection

- **Primary result:** Validated board drift detection infrastructure and 3-way parallel content dispatch with worktree isolation
- Two workstreams: board drift detection infrastructure (2 stories) + synthetic content (4 stories)
- Created `scripts/check-board-drift.sh` diagnostic script for detecting board status persistence drift at timed intervals
- Extended `scripts/validate-logs.sh` with Board Drift Log section for drift event surfacing
- Created 4 synthetic prose documents (removed from the tree in November 2026; kept in Git history)
- 2 epics, 6 stories across 4 dispatch waves (Waves 1-2: sequential infra, Wave 3: 3-way parallel content with worktree isolation, Wave 4: sequential hard content)
- All three difficulty levels tested (easy x3 haiku, medium x2 sonnet, hard x1 opus)
- Zero fix cycles — all 6 stories passed review on first attempt (5 APPROVE, 1 COMMENT)
- Convention changes: post-wave comment verification for parallel dispatch, `gh project item-add` status warning
- ~957K tokens across 15 agent dispatches, estimated cost ~$6.57

## 2026-03-13

### Test SDLC v2 Workflow (Run 10) — Orchestrator Logging

- **Primary result:** Validated two-layer diagnostic logging (board-status.log + orchestrator.log) during a full autonomous lifecycle
- Two workstreams: logging infrastructure validation (2 stories) + synthetic content (4 stories)
- Created log validation script (`scripts/validate-logs.sh`) and reconciled logging design doc with implementation
- Created 4 synthetic prose documents (removed from the tree in November 2026; kept in Git history)
- 2 epics, 6 stories across 4 dispatch waves (Waves 1-2: sequential logging, Wave 3: 3 parallel content, Wave 4: sequential)
- All three difficulty levels tested (easy x3 haiku, medium x2 sonnet, hard x1 opus)
- Zero fix cycles — all 6 stories passed review on first attempt
- Encountered and worked around GraphQL API rate limit exhaustion (5000 points/hour depleted by planner API calls)
- Discovered design artifact matching bug: orchestrator grep matched wrong backlog items due to missing YAML frontmatter filtering
- Lessons captured: artifact matching gap, rate limit workaround via lightweight GraphQL queries

### Test SDLC v2 Workflow (Run 9) — Full Autonomous Lifecycle

- **Primary result:** Validated full autonomous lifecycle end-to-end — design, plan, build, review, merge, telemetry, and retro in a single unattended orchestrator session
- Created 5 synthetic prose documents (removed from the tree in November 2026; kept in Git history)
- 2 epics, 5 stories across 3 dispatch waves (Wave 1: 3 parallel, Waves 2-3: sequential)
- All three difficulty levels tested (easy x2 haiku, medium x2 sonnet, hard x1 opus)
- Zero fix cycles — all 5 stories passed review on first attempt
- Worktree cross-contamination on E01-S03 caught by reviewer, repaired by the orchestrator via cherry-pick
- Model routing correctly dispatched haiku/sonnet/opus based on difficulty labels
- ~29 minutes wall-clock time, ~541K tokens, ~$2.66 estimated cost across 12 agent dispatches

## 2026-03-12

### Test SDLC v2 Workflow (Run 8) — Worktree Isolation

- **Primary result:** Validated `isolation: "worktree"` for parallel builder dispatch — zero workspace collision across 3 parallel builders
- Created 5 synthetic prose documents (removed from the tree in November 2026; kept in Git history)
- 2 epics, 5 stories across 3 dispatch waves (Wave 1: 3 parallel, Waves 2-3: sequential)
- All three difficulty levels tested (easy → haiku, medium → sonnet, hard → opus)
- One fix cycle triggered by reviewer (sentence count violation on E01-S01)
- Convention updates: post-worktree cleanup requirements, defense-in-depth reclassification
- Lessons captured: worktree untracked file cleanup, worktree remote push verification
