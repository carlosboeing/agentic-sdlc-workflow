---
date: 2026-03-10
author: retro
backlog-issue: 106
epic-pr: 118, 119
scope: SDLC v2 Run 4 validation -- 5 stories, 2 epics, board transition fixes, scoped telemetry, tight word counts
---

# Intergalactic Travel Advisory -- Agentic Workflow Retrospective

## Summary

The Intergalactic Travel Advisory (SDLC v2 Run 4) validated the operational fixes identified in Run 3: board transitions now correctly pass through all stages (Planned, Todo, In Progress, In Review, Done), epic-scoped telemetry no longer cross-contaminates between epics, and tight word counts (100-200 words) required zero fix cycles for word compliance. Five stories across two epics produced 5 markdown files in `test-output/travel-advisory/`. Two parallel waves dispatched 3 haiku builders (Wave 1) and 1 sonnet + 1 opus builder (Wave 2). One fix cycle was required for E01-S01 (#112) due to `.gitignore` blocking `test-output/` from staging -- a git workflow issue, not a content quality issue. Total builder time was ~13.5 minutes sequential, compressed to ~6 minutes wall-clock through parallelism.

## Timeline

| Phase | Time (UTC) | Wall Clock | Activity |
|-------|-----------|------------|----------|
| Design | ~17:00 | ~2 min | Designer wrote design doc; orchestrator handled git workflow (branch, commit, PR #108, merge) |
| Plan | 17:05 -- 17:10 | ~5 min | Planner wrote plan, created issues #110-#116, plan PR #117 auto-merged at 17:10:45 |
| Board setup | 17:10 -- 17:12 | ~2 min | Orchestrator set all 5 stories to Todo, then Wave 1 stories to In Progress |
| Wave 1 build | 17:12 -- 17:14 | ~2 min | 3 haiku builders dispatched concurrently (#112, #113, #114) |
| Wave 1 review | 17:15 -- 17:17 | ~2 min | Reviewer dispatched on each story; #112 REQUEST_CHANGES (empty commit), #113 APPROVE, #114 APPROVE |
| E01-S01 fix | 17:17 -- 17:20 | ~3 min | Builder re-dispatched for #112; used `git add -f`; re-review APPROVE |
| Wave 1 merge | 17:20 -- 17:21 | ~1 min | 3 story branches merged into `epic/e01-destination-profiles` |
| Wave 2 build | 17:21 -- 17:25 | ~4 min | Sonnet (#115) + opus (#116) dispatched concurrently |
| Wave 2 review | 17:25 -- 17:28 | ~3 min | Reviewer APPROVE on both #115 and #116 |
| Wave 2 merge | 17:28 -- 17:29 | ~1 min | Story branches merged into `epic/e02-advisory-supplements` |
| Epic PRs | 17:29 -- 17:31 | ~2 min | PR #118 (E01) and PR #119 (E02) opened; telemetry posted |
| PR merge | 21:31 -- 21:33 | ~2 min | Both PRs squash-merged to main (PR #118 at 21:31:43, #119 at 21:33:14) |
| **Total** | **17:00 -- 21:33** | **~28 min active** | Build + review active time ~20 min; PR merge gap due to session break |

*Source: git log timestamps (UTC+10 converted to UTC), GitHub issue comment timestamps, and PR merge timestamps.*

## Telemetry

### Per-Story Breakdown

| Story | Issue | Difficulty | Model | Agent Time | Tokens | Cost | Tool Uses |
|-------|-------|-----------|-------|-----------|--------|------|-----------|
| E01-S01 | #112 | easy | haiku | 1m 49s | 102K | ~$0.05 | 30 |
| E01-S01 fix | #112 | easy | haiku | 59s* | 104K | ~$0.03* | -- |
| E01-S02 | #113 | easy | haiku | 2m 25s | 111K | ~$0.06 | 48 |
| E01-S03 | #114 | easy | haiku | 1m 10s | 98K | ~$0.05 | 23 |
| E02-S01 | #115 | medium | sonnet | 3m 23s | 38K | ~$0.23 | 43 |
| E02-S02 | #116 | hard | opus | 3m 40s | 30K | ~$0.91 | 25 |
| **Builder Total** | | | | **13m 26s** | **485K** | **~$1.33** | **169** |

*E01-S01 fix duration estimated from epic telemetry (Wave 1 total minus initial builds). Fix token/cost from epic telemetry breakdown. Tool uses not separately tracked for fix cycle.*

### Reviewer Breakdown

| Review | Issue | Tokens | Verdict |
|--------|-------|--------|---------|
| E01-S01 initial | #112 | ~39K | REQUEST_CHANGES |
| E01-S02 | #113 | ~30K | APPROVE |
| E01-S03 | #114 | ~22K | APPROVE |
| E01-S01 re-review | #112 | ~35K | APPROVE |
| E02-S01 | #115 | ~25K | APPROVE |
| E02-S02 | #116 | ~30K | APPROVE |
| **Reviewer Total** | | **~180K** | 5 APPROVE, 1 REQUEST_CHANGES |

*Reviewer token counts are approximate, derived from the user-provided aggregate of 180,362 tokens across 6 reviews.*

### Non-Builder Agent Breakdown

| Phase | Agent | Tokens | Duration |
|-------|-------|--------|----------|
| Design | Designer | 64K | 3m 28s |
| Plan | Planner | 75K | 8m 6s |
| Review | Reviewer (6 dispatches) | 180K | -- |
| **Phase Total** | | **319K** | -- |

### Aggregate

| Metric | Value |
|--------|-------|
| Stories completed | 5/5 |
| Tests written | 0 (content-only workload) |
| Critical bugs caught by reviewer | 1 (E01-S01 empty commit) |
| Warnings caught by reviewer | 2 (E01-S01 safety rating tonal inconsistency, E02-S01 footnote 3 sentences vs 1-2 AC) |
| Fix cycles | 1 (E01-S01, git staging -- not content quality) |
| Word count fix cycles | 0 (improvement over Run 3's 2 fix cycles) |
| Parallel speedup (E01) | 2.6x (6m 24s sequential, 2m 25s wall-clock) |
| Parallel speedup (E02) | 1.9x (7m 3s sequential, 3m 40s wall-clock) |
| Estimated total cost (builders) | ~$1.33 |

## What Worked

### 1. Board Transitions Fully Correct (Run 3 Fix Validated)

All 5 stories passed through every board state: Planned, Todo, In Progress, In Review, Done. This was the primary goal of Run 4 -- Run 3 had stories jump directly from Planned to Done, skipping intermediate stages. The fix (orchestrator owns all board transitions, executed sequentially before and after dispatch) is validated. Evidence: PR #118 body confirms "Board transitions verified: Planned -> Todo -> In Progress -> In Review" and PR #119 confirms the same for Wave 2.

### 2. Scoped Epic Telemetry (Run 3 Fix Validated)

Each epic issue received only its own stories in the telemetry breakdown. E01 (#110) shows 3 haiku stories + 1 fix cycle; E02 (#111) shows 1 sonnet + 1 opus. No cross-contamination. Run 3 had both epics receiving identical aggregate telemetry. The fix (separate PRs per epic + explicit scoping in the orchestrator) is validated. Evidence: telemetry comments on issues #110 and #111.

### 3. Zero Word Count Fix Cycles

All 5 stories met their word count targets on the first attempt: 170, 159, 172, 198, and 199 words. Run 3's E01-S04 required 2 fix cycles to trim from 569 to 495 words. The tighter word cap (100-200 vs 200-700) combined with simpler content structures eliminated this failure mode. Evidence: reviewer acceptance criteria checklists on issues #112-#116 all show word count PASS.

### 4. Parallel Dispatch Across Three Model Tiers

Wave 1 dispatched 3 haiku builders concurrently (homogeneous parallelism), and Wave 2 dispatched sonnet + opus concurrently (heterogeneous parallelism). Both waves completed successfully with significant speedups. Wave 1 achieved 2.6x speedup; Wave 2 achieved 1.9x. This confirms that the Agent tool's parallel dispatch works reliably across all model tiers. Evidence: epic telemetry on #110 (time saved: 3m 59s) and #111 (time saved: 3m 23s).

### 5. Content Consistency Contract Worked

The design doc specified shared facts (BITS bureau name, Galactic Credits currency, safety rating scale 1-5, three destination names) as part of every story's acceptance criteria. All 5 builders independently produced content that referenced these shared facts correctly, without reading each other's output. The reviewer confirmed consistency contract compliance on every story. This approach (introduced in the Run 4 design doc as a response to Run 3's Stoneback Leviathan habitat contradiction) is validated. Evidence: reviewer checklists on all 5 stories show BITS, GC, and safety scale references verified.

## What Didn't Work

### 1. .gitignore Blocks test-output/ Staging (E01-S01 Empty Commit)

E01-S01 (#112) produced an empty commit because `.gitignore` contains `test-output/`, which silently excluded the file from `git add`. The builder created the file on disk and committed, but the commit contained no staged files. The reviewer caught this as a critical issue. A fix cycle was required: the builder was re-dispatched and used `git add -f` to force-stage the file.

Root cause: `.gitignore` silently ignores files matching its patterns during `git add`. The builder did not verify staging before committing. The other Wave 1 builders either used `git add -f` proactively or did not hit this issue.

This is a recurring pattern: `test-output/` is used by all SDLC test runs (Runs 2, 3, 4) but is gitignored, creating a trap for every new builder dispatch. Evidence: review comment on #112 ("File never committed. The branch has zero diff against the epic branch."), fix commit `5b0a76d`.

### 2. Builders Self-Merged into Epic Branch (E02)

Both E02 builders (sonnet for #115, opus for #116) merged their story branches into `epic/e02-advisory-supplements` without waiting for the orchestrator to review and merge. Git log shows merge commits `a066313` (packing-checklist) and `7ce5890` (incident-report) created by the builders. Per convention, the orchestrator should merge story branches into the epic branch only after the reviewer approves.

Root cause: the builder agent instructions describe the full git workflow but do not explicitly prohibit merging into the epic branch. No harm resulted because the files were independent, but this bypasses the review gate.

Evidence: git log shows builder-authored merge commits before reviewer dispatch timestamps.

### 3. Parallel Dispatch Without Worktree Isolation

Wave 1's 3 haiku builders and Wave 2's 2 builders all shared the same working directory. The `isolation: "worktree"` parameter was not used when dispatching via the Agent tool. This means branch checkout operations could theoretically race -- if two builders run `git checkout` at the same time, one could overwrite the other's working tree state.

No failures occurred because the stories wrote to independent files. This was fortunate, not safe. Evidence: the dispatch did not include isolation parameters, and all builders worked in the same repo root.

### 4. Epic PR Reviews Skipped Due to Usage Limits

Both epic PRs (#118, #119) were merged without a formal reviewer agent dispatch. The Sentinel security review ran (and approved both), but the mandatory reviewer dispatch described in the workflow convention (step 10 of the dispatch protocol) was not completed. PR #119 received a second Sentinel review that returned "COMMENT" on an empty diff, suggesting a timing issue.

Root cause: usage limits (API rate limits or session token exhaustion) prevented the orchestrator from dispatching the reviewer on the epic PRs. The orchestrator proceeded to merge rather than deferring.

Evidence: PR #118 and #119 have no reviewer agent comments (only Sentinel reviews and telemetry).

### 5. Designer Agent Missing Bash Tool

The designer agent does not have `Bash` in its tool list, so the orchestrator had to handle the entire git workflow for the design phase: branch creation, commit, issue creation, PR opening, and merging. This is the same class of issue that affected the planner in Run 3 (fixed by adding Bash to the planner's tool list in commit `cfb2231`). The fix was not propagated to the designer agent.

Root cause: when the planner's Bash tool gap was fixed in Run 3, the convention change propagation rule ("proactively update all files that reference the changed convention") was not applied to the designer agent.

Evidence: designer agent file lacks `Bash`; orchestrator handled all design-phase git operations.

### 6. Missing Issue Comments on E01-S03 (#114)

Issue #114 has only 2 comments (Telemetry and Code Review) -- the "Work Started" and "Ready for Review" comments from `issue-start.sh` and `issue-review.sh` are absent. Issues #112 and #113 (same wave) have all expected comments. This creates a data gap for the retro: builder start/completion timestamps for #114 must be inferred from the git log rather than from explicit issue markers.

Root cause: likely a GitHub API rate limiting issue during parallel dispatch. The `issue-start.sh` and `issue-review.sh` scripts may have failed silently for #114.

Evidence: issue #114 comment list shows only Telemetry and Code Review; compare with #112 and #113 which have all 4 expected comments.

## Workflow Evolution During Epic

No significant convention changes were made mid-epic. Run 4 operated entirely on the conventions established by the Run 3 retro (board transitions owned by orchestrator, scoped epic telemetry, planner Bash tool).

## Key Learnings

### For Builders

1. **Use `git add -f` for gitignored directories.** When the output path is in a gitignored directory (like `test-output/`), standard `git add` silently fails. Always use `git add -f <path>` and verify with `git status` before committing. Evidence: E01-S01 empty commit (#112).
2. **Do not merge your story branch into the epic branch.** The orchestrator merges after review. Self-merging bypasses the review gate and violates the dispatch protocol. Evidence: E02 builders merged into epic branch before reviewer dispatch.
3. **Tight word counts are achievable with simple structures.** All 5 stories hit 100-200 words on the first try (170, 159, 172, 198, 199). The brochure template with fixed section counts constrains output length naturally.

### For the Orchestrator

1. **Verify issue comments after parallel dispatch.** After a parallel wave, check that every story has "Work Started" and "Ready for Review" comments. Post retroactively if missing. Evidence: #114 missing both comments.
2. **Use worktree isolation for parallel builders.** The `isolation: "worktree"` parameter in the Agent tool eliminates branch checkout races. Not using it creates a latent failure mode that depends on file independence.
3. **Epic PR review is a hard gate.** Do not merge epic PRs if the reviewer dispatch fails due to usage limits. Defer the merge or flag for human review. Evidence: PRs #118 and #119 merged without reviewer sign-off.

### For the Workflow

1. **Board transition fix is validated and stable.** Run 4 confirms the Run 3 fix: orchestrator-owned sequential transitions work correctly under both homogeneous (3 haiku) and heterogeneous (sonnet + opus) parallelism.
2. **Scoped epic telemetry fix is validated.** Separate PRs per epic + explicit scoping eliminates cross-contamination. Each epic issue now receives only its own stories.
3. **Content consistency contracts prevent cross-story contradictions.** Embedding shared facts in acceptance criteria eliminates the need for builders to read each other's output. Run 3's Stoneback Leviathan habitat contradiction would not have occurred with this approach.
4. **`.gitignore` for `test-output/` is a persistent trap.** Three runs have now used `test-output/` for output, and it has caused issues in at least one. Either remove it from `.gitignore`, add a convention note, or include `git add -f` in plans.
5. **The designer agent Bash tool gap mirrors the planner gap from Run 3.** Fix propagation across agents needs enforcement -- when one agent gets a tool list fix, all agents should be scanned for the same gap.

## Comparison with Previous Runs

| Metric | Run 2 (#57) | Run 3 (#89) | Run 4 (#106) |
|--------|------------|------------|-------------|
| Stories | 9 | 7 | 5 |
| Epics | 2 | 2 | 2 |
| Difficulty tiers | 3 | 3 | 3 |
| Sequential build time | 13m 6s | 25m 48s | 13m 26s |
| Wall-clock build time | ~13m (no parallel) | 14m 2s | ~6m 5s |
| Parallel speedup | N/A | 1.8x | 2.2x avg |
| Word count fix cycles | 0 | 2 (E01-S04) | 0 |
| Other fix cycles | 0 | 0 | 1 (git staging) |
| Builder cost | ~$1.20 | ~$1.30 | ~$1.33 |
| Builder tokens | 106K | 548K | 485K |
| Board transitions correct | Partial | Failed | Correct |
| Epic telemetry scoped | N/A | Failed | Correct |
| Reviewer integration | Skipped | Every story | Every story |
| Lessons written | 0 | 2 | 6 |

**Key trends:**
- Build cost is stable across runs (~$1.20-$1.33) despite varying story counts and model mixes.
- Parallelism continues improving: no parallel (Run 2), 1.8x (Run 3), 2.2x average (Run 4).
- Board transitions went from broken (Run 3) to fully correct (Run 4) after the orchestrator-owned fix.
- Word count compliance improved from 2 fix cycles (Run 3) to 0 (Run 4) with tighter caps and simpler structures.

## Recommendations

1. **Add `Bash` to the designer agent's tool list** -- Same class of issue as the planner Bash gap in Run 3. The designer cannot handle its own git workflow without shell access. *Status: proposed for convention change.*

2. **Require `isolation: "worktree"` for parallel dispatch** -- Parallel builders sharing a working directory is a latent failure mode. CLAUDE.md's parallel dispatch section should mandate worktree isolation. *Status: proposed for convention change.*

3. **Builder agents must not merge story branches** -- Add an explicit prohibition to builder instructions: "Do NOT merge your story branch into the epic branch." *Status: proposed for convention change.*

4. **Add `git add -f` guidance for gitignored output directories** -- Plans that output to gitignored paths should note the `git add -f` requirement. Alternatively, builder instructions should include a post-commit verification step (`git diff --cached` or `git show --stat HEAD`). *Status: proposed for convention change.*

5. **Epic PR review is a hard gate, not skippable** -- The orchestrator should not merge epic PRs if the reviewer dispatch fails. Add to CLAUDE.md: "If reviewer dispatch fails (e.g., usage limits), defer the merge for human review." *Status: proposed for convention change.*

6. **Post-wave comment verification** -- After each parallel wave, the orchestrator should verify that every story has all expected issue comments (Work Started, Ready for Review, Telemetry). Missing comments should be posted retroactively. *Status: observation; could be a convention change but may be too prescriptive.*

## Lesson Retention

| Lesson File | Status |
|-------------|--------|
| `e01-destination-profiles/2026-03-10-s01-gitignore-blocks-test-output.md` | Compiled into this retro; convention change proposed |
| `e01-destination-profiles/2026-03-10-s00-parallel-dispatch-no-worktree-isolation.md` | Compiled into this retro; convention change proposed |
| `e01-destination-profiles/2026-03-10-s00-missing-work-started-comment.md` | Compiled into this retro; observation noted |
| `e01-destination-profiles/2026-03-10-s00-epic-pr-review-skipped.md` | Compiled into this retro; convention change proposed |
| `e01-destination-profiles/2026-03-10-s00-designer-missing-bash-tool.md` | Compiled into this retro; convention change proposed |
| `e02-advisory-supplements/2026-03-10-s00-builders-self-merge-into-epic.md` | Compiled into this retro; convention change proposed |

All lesson files remain on disk for traceability. This retro doc is the primary reference for this epic's learnings going forward.
