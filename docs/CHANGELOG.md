# Changelog
## 2026-03-17

### The Debugging: A Silicon Valley Musical — Run 16 (backlog #167, 136m wall-clock)

- **Primary result:** First test run with the slimmed orchestrator.md (503 lines) and `state.sh` for all state management
- Validated `state.sh` integration: `init`, `update --dispatch`, `update --add-story`, `update --epic --base-sha`, `overhead`, `lifecycle-duration`
- Validated `maxParallelBuilders: 3` config enforcement: Wave 1 (5 stories) correctly split into 3+2 sub-waves
- Creative content: tech-satire musical with 9 songs, 7 characters, across script/handbook/marketing materials
- 3 epics, 9 stories: E01 Script (4 stories), E02 Production Handbook (3 stories), E03 Marketing (2 stories)
- Dispatch: 5 waves — Wave 1a parallel (3-way), Wave 1b parallel (2-way), Wave 2 sequential, Wave 3 parallel (2-way), Wave 4 sequential
- 3 fix cycles: E02-S02 (word count + missing template sections), E02-S01 (missing table column + short backstories), E02-S03 (planted bug — wrong scene number caught by reviewer)
- Planted bug validation: reviewer correctly identified "The Standup Ballad" as Scene 4 instead of Scene 2, triggering fix cycle
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
- Extracted ~230 lines of embedded Python from `issue-telemetry.sh` into standalone `scripts/lib/compute-dispatches.py` (875 lines with Gantt + fix cycle features)
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

### Test SDLC v2 Workflow (Run 14) — Interdimensional Restaurant Health Inspections

- **Primary result:** Validated the fix cycle path (reviewer REQUEST_CHANGES → builder fix → re-review) for the first time in SDLC v2. Two fix cycles completed successfully out of 4 planted bugs
- Content theme: "Interdimensional Restaurant Health Inspections" — official MFSA inspection reports, violation notices, appeal rulings, compliance certificates, and regulatory memos
- 2 epics, 12 stories: E01 Inspection Reports (7 stories), E02 Regulatory & Administrative (5 stories)
- Dispatch: 5 waves with max 3 parallel builders per wave (Wave 1-3: 3-way parallel sonnet, Wave 4: 2-way parallel opus, Wave 5: sequential opus)
- Bug planting results: 4 bugs planted (contradictory AC, missing section, format contradiction, wrong cross-reference). 2 triggered fix cycles (E01-S04 word count, E02-S01 format), 2 were avoided by builders following acceptance criteria
- Fix cycle machinery confirmed working: REQUEST_CHANGES → builder fix → re-review → APPROVE
- Cross-epic dependencies validated: E02 stories reference E01 documents by MFSA document number
- Worktree cross-contamination observed in fix cycle 2 (E01-S04) — E02-S01 file leaked into E01-S04 branch via worktree artifact


## 2026-03-15

### Test SDLC v2 Workflow (Run 13) — Alien Tourist Bureau

- **Primary result:** Validated runtime data consolidation (.agentic-workflow/), live pricing (fetch-pricing.sh), and dispatches-from-state telemetry computation
- Content theme: "Alien Tourist Bureau" — official travel advisories and visitor guides from the Galactic Federation Bureau of Terran Tourism (GFBTT)
- 1 epic, 6 stories: Coffee Advisory, Traffic Advisory, Customs Form, Small Talk Guide, Dining Guide, Survival Handbook
- Dispatch: Wave 1 (3-way parallel easy), Wave 2 (2-way parallel medium), Wave 3 (sequential hard with cross-references to all prior docs)
- All three difficulty levels tested: easy x3 sonnet, medium x2 sonnet, hard x1 opus
- Zero fix cycles — all 6 stories passed review on first attempt (6 APPROVE verdicts)
- Live pricing fetched successfully from anthropic.com/pricing (Opus $5/$25, Sonnet $3/$15, Haiku $1/$5)
- ~464K tokens across 12 build+review dispatches for epic E01

## 2026-03-15

### Test SDLC v2 Workflow (Run 12) — Time Traveler's Yelp Reviews

- **Primary result:** Validated configurable workflow settings from PR #55 — scripts reading from `.claude/agentic-sdlc-config.json`, model routing, pricing, and YAML frontmatter plan detection
- Content theme: "Time Traveler's Yelp Reviews" — formal Yelp-style reviews of historical events written by time-traveling tourists
- 1 epic, 5 stories: Great Fire of London (1★), Great Pyramid (3★), Magna Carta (4★), Moon Landing (5★), and a ChronoTrip Comparative Guide
- Dispatch: Wave 1 (3-way parallel with worktree isolation), Wave 2 (sequential medium), Wave 3 (sequential hard with cross-references)
- All three difficulty levels tested: easy x2 sonnet, medium x2 sonnet, hard x1 opus
- Zero fix cycles — all 5 stories passed review on first attempt
- Lesson captured: backlog issue should be set to In Progress at design phase start, not at builder dispatch
- Telemetry fix: corrected cost underreporting (was ~$4.77, correct ~$12.55) caused by using memorized $10/M Opus rate instead of config $30/M


## 2026-03-14

### Test SDLC v2 Workflow (Run 11) — Board Drift Detection

- **Primary result:** Validated board drift detection infrastructure and 3-way parallel content dispatch with worktree isolation
- Two workstreams: board drift detection infrastructure (2 stories) + content creation (4 Fairy Tale HR incident reports)
- Created `scripts/check-board-drift.sh` diagnostic script for detecting board status persistence drift at timed intervals
- Extended `scripts/validate-logs.sh` with Board Drift Log section for drift event surfacing
- Created "Incident Reports from Fairy Tale HR" content (4 incident reports from FairyTale Corp's HR department)
- 2 epics, 6 stories across 4 dispatch waves (Waves 1-2: sequential infra, Wave 3: 3-way parallel content with worktree isolation, Wave 4: sequential hard content)
- All three difficulty levels tested (easy x3 haiku, medium x2 sonnet, hard x1 opus)
- Zero fix cycles — all 6 stories passed review on first attempt (5 APPROVE, 1 COMMENT)
- Convention changes: post-wave comment verification for parallel dispatch, `gh project item-add` status warning
- ~957K tokens across 15 agent dispatches, estimated cost ~$6.57

## 2026-03-13

### Test SDLC v2 Workflow (Run 10) — Orchestrator Logging

- **Primary result:** Validated two-layer diagnostic logging (board-status.log + orchestrator.log) during a full autonomous lifecycle
- Two workstreams: logging infrastructure validation (2 stories) + content creation (4 stories, Season 2 episodes)
- Created log validation script (`scripts/validate-logs.sh`) and reconciled logging design doc with implementation
- Created "Nature Documentary: The Open-Plan Office, Season 2" content (3 episodes + 1 formal habitat assessment)
- 2 epics, 6 stories across 4 dispatch waves (Waves 1-2: sequential logging, Wave 3: 3 parallel content, Wave 4: sequential)
- All three difficulty levels tested (easy x3 haiku, medium x2 sonnet, hard x1 opus)
- Zero fix cycles — all 6 stories passed review on first attempt
- Encountered and worked around GraphQL API rate limit exhaustion (5000 points/hour depleted by planner API calls)
- Discovered design artifact matching bug: orchestrator grep matched wrong backlog items due to missing YAML frontmatter filtering
- Lessons captured: artifact matching gap, rate limit workaround via lightweight GraphQL queries

### Test SDLC v2 Workflow (Run 9) — Full Autonomous Lifecycle

- **Primary result:** Validated full autonomous lifecycle end-to-end — design, plan, build, review, merge, telemetry, and retro in a single unattended orchestrator session
- Created "Pet Cats: Declassified CIA Field Reports" test content (5 CIA-style intelligence documents)
- 2 epics, 5 stories across 3 dispatch waves (Wave 1: 3 parallel, Waves 2-3: sequential)
- All three difficulty levels tested (easy x2 haiku, medium x2 sonnet, hard x1 opus)
- Zero fix cycles — all 5 stories passed review on first attempt
- Worktree cross-contamination on E01-S03 caught by reviewer, self-healed by orchestrator via cherry-pick
- Model routing correctly dispatched haiku/sonnet/opus based on difficulty labels
- ~29 minutes wall-clock time, ~541K tokens, ~$2.66 estimated cost across 12 agent dispatches

## 2026-03-12

### Test SDLC v2 Workflow (Run 8) — Worktree Isolation

- **Primary result:** Validated `isolation: "worktree"` for parallel builder dispatch — zero workspace collision across 3 parallel builders
- Created "The Office Worker: A Nature Documentary" test content (5 episodes/documents)
- 2 epics, 5 stories across 3 dispatch waves (Wave 1: 3 parallel, Waves 2-3: sequential)
- All three difficulty levels tested (easy → haiku, medium → sonnet, hard → opus)
- One fix cycle triggered by reviewer (sentence count violation on E01-S01)
- Convention updates: post-worktree cleanup requirements, defense-in-depth reclassification
- Lessons captured: worktree untracked file cleanup, worktree remote push verification
