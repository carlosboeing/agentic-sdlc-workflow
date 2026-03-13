# Changelog

## 2026-03-13

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
