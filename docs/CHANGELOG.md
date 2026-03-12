# Changelog

## 2026-03-12

### Test SDLC v2 Workflow (Run 8) — Worktree Isolation

- **Primary result:** Validated `isolation: "worktree"` for parallel builder dispatch — zero workspace collision across 3 parallel builders
- Created "The Office Worker: A Nature Documentary" test content (5 episodes/documents)
- 2 epics, 5 stories across 3 dispatch waves (Wave 1: 3 parallel, Waves 2-3: sequential)
- All three difficulty levels tested (easy → haiku, medium → sonnet, hard → opus)
- One fix cycle triggered by reviewer (sentence count violation on E01-S01)
- Convention updates: post-worktree cleanup requirements, defense-in-depth reclassification
- Lessons captured: worktree untracked file cleanup, worktree remote push verification
