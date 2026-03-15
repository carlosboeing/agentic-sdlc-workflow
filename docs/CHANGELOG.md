# Changelog

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
