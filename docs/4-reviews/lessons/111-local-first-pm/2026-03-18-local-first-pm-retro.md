---
date: 2026-03-18
author: retro
backlog-issue: 111
backlog-pr: 225
scope: Local-First PM System -- file-based PM adapter implementing all 15 pm_* functions against .workflow/ files
---

# Local-First PM System -- Agentic Workflow Retrospective

## Summary

Backlog item #111 implemented the local PM adapter (`scripts/lib/adapters/pm/local/`), a file-based implementation of the `pm_*` function contract defined by the PM Abstraction Layer (#109). When `pm.adapter` is set to `"local"`, the entire workflow operates against `.workflow/` files instead of GitHub Issues/Projects -- zero-config, offline-capable project management. The work created 8 modules across 3 epics (9 stories), all 15 `pm_*` functions, and refactored `issue-telemetry.sh` to use the adapter boundary. All 9 stories completed with 391 tests across 14 test files, 5 fix cycles across 4 stories, and 53 total review findings. This was the second infrastructure backlog item and the first to build a complete adapter against the `pm.sh` interface.

## Timeline

| Phase | Time (UTC) | Wall Clock | Activity |
|-------|-----------|------------|----------|
| Design | 06:47 -- 07:02 | ~15 min | Designer creates design doc, PR #210 merged |
| Plan | 07:04 -- 07:15 | ~11 min | Planner creates 3 epics, 9 stories; plan PR #224 merged |
| Build W1 (E01-S01) | 07:18 -- 07:44 | ~26 min | _common.sh -- build + review + 2 fix cycles |
| Build W2 (E01-S02) | 07:45 -- 08:07 | ~22 min | items.sh -- build + review + 1 fix cycle |
| Merge E01 + sync | 08:07 -- 08:08 | ~1 min | E01 merged into integration, E02/E03 synced |
| Build W3 (E02-S01/S02/S03) | 08:08 -- 08:27 | ~19 min | 3-way parallel build + 3-way parallel review + S03 fix cycle |
| Merge E02 + sync | 08:28 -- 08:29 | ~1 min | E02 merged into integration, E03 synced |
| Build W4 (E03-S01/S02/S03) | 08:29 -- 08:47 | ~18 min | 3-way parallel build + 3-way parallel review + S01 fix cycle |
| Build W5 (E03-S04) | 08:48 -- 08:56 | ~8 min | Integration test -- sequential build + review |
| Merge E03 + changelog | 08:57 -- 08:58 | ~1 min | E03 merged into integration, changelog entry, PR #225 created |
| **Total** | 06:47 -- 08:58 | **~2h 11m** | Design: ~15m, Plan: ~11m, Build+Review: ~94m, Merge: ~3m |

*Source: `git log main..backlog/111-local-first-pm --format="%h %ai %s"` and dispatch timestamps from `.agentic-workflow/runs/111/orchestrator.json`.*

## Telemetry

### Per-Story Breakdown

| Story | Issue | Difficulty | Build Model | Review Model | Agent Time | Tokens | Est. Cost | Tool Uses | Fix Cycles | Verdict |
|-------|-------|-----------|------------|-------------|-----------|--------|-----------|-----------|------------|---------|
| E01-S01 | #215 | medium | sonnet | opus | 23m 52s | 339K | ~$2.61 | 207 | 2 | REQ x2 then APPROVE (implicit) |
| E01-S02 | #216 | medium | sonnet | opus | 20m 45s | 324K | ~$2.52 | 168 | 1 | REQ then APPROVE |
| E02-S01 | #217 | easy | sonnet | sonnet | 8m 26s | 125K | ~$0.75 | 87 | 0 | APPROVE |
| E02-S02 | #218 | easy | sonnet | sonnet | 8m 3s | 123K | ~$0.74 | 76 | 0 | APPROVE |
| E02-S03 | #219 | easy | sonnet | sonnet | 15m 51s | 230K | ~$1.39 | 140 | 1 | REQ then APPROVE |
| E03-S01 | #220 | easy | sonnet | sonnet | 9m 25s | 183K | ~$1.10 | 105 | 1 | REQ then APPROVE (no re-review) |
| E03-S02 | #221 | medium | sonnet | opus | 8m 18s | 162K | ~$1.34 | 73 | 0 | APPROVE |
| E03-S03 | #222 | medium | sonnet | opus | 12m 29s | 163K | ~$1.21 | 110 | 0 | APPROVE |
| E03-S04 | #223 | easy | sonnet | sonnet | 8m 3s | 130K | ~$0.78 | 86 | 0 | APPROVE |
| **Story Total** | | | | | **115m 12s** | **1,779K** | **~$12.44** | **1,052** | **5** | |

*Note: E01-S01 had two fix cycle rounds (reviewer requested changes twice). The third build+delete was a one-line fix that passed without a formal re-review. E03-S01 had one fix cycle (emoji mismatch) with the builder committing the fix without a formal re-review dispatch.*

### Design and Plan

| Phase | Dispatches | Agent Time | Tokens | Est. Cost | Tool Uses |
|-------|-----------|-----------|--------|-----------|-----------|
| Design | 1 | 14m 37s | 111K | ~$1.12 | 41 |
| Plan | 1 | 11m 21s | 114K | ~$1.14 | 73 |
| **Total** | **2** | **25m 58s** | **225K** | **~$2.26** | **114** |

### Aggregate

| Metric | Value |
|--------|-------|
| Stories completed | 9/9 |
| Tests written | 391 (across 14 test files) |
| Lines added (net) | +6,966 |
| Files changed | 31 |
| Critical issues caught by reviewer | 6 |
| Warnings caught by reviewer | 21 |
| Suggestions made by reviewer | 26 |
| Fix cycles | 5 across 4/9 stories (44%) |
| Parallel waves | 2 (Waves 3 and 4, each 3-way parallel) |
| Parallelism savings | ~30m 50s (1.3x speedup) |
| Build+Review wall clock | ~94 min |
| Sequential sum (all dispatches) | 141m 15s |
| Total agent time (all phases) | 141m 15s |
| Total tokens (all phases) | 2,010K |
| Total estimated cost (all phases) | ~$14.70 |

*Cost breakdown: Design $1.12 (8%), Plan $1.14 (8%), Build $6.29 (43%), Review $6.15 (42%). Fix cycles added ~$3.36 and 29m 52s (23% of total cost).*

## What Worked

### 1. Design and Plan Phases Were Efficient

Unlike BL109 (which consumed 10 design dispatches and $7.05 for the PM abstraction design), this backlog item completed design in a single dispatch ($1.12) and planning in a single dispatch ($1.14). Combined design+plan cost was $2.26 (15% of total), compared to BL109's $8.08 (42% of total). The design phase was 6.3x cheaper.

**Evidence:** Dispatch 1 (designer, 14m 37s, 111K tokens) and dispatch 2 (planner, 11m 21s, 114K tokens) in the state file. No usage limit interruptions. The BL109 design doc served as a direct prerequisite -- the designer could reference the existing `pm_*` function contract and adapter folder structure rather than defining them from scratch.

### 2. Layered Plan Decomposition Enabled Maximum Parallelism

The planner's three-epic structure with clear dependency layers (Foundation -> Domain Modules -> Composition) enabled two 3-way parallel waves:

- **Wave 3** (E02-S01/S02/S03): 3 independent domain modules built in parallel. All 3 builders started at `2026-03-18T08:08:55Z`. Wall clock ~19 min vs ~30 min sequential.
- **Wave 4** (E03-S01/S02/S03): 3 modules with no cross-dependencies built in parallel. All 3 builders started at `2026-03-18T08:29:37Z`. Wall clock ~18 min vs ~28 min sequential.

**Evidence:** The telemetry on issue #214 reports "Actual Duration (with parallelism): 110m 25s" vs sequential "Duration: 141m 15s", saving 30m 50s (22%).

### 3. Reviewer Routing Worked Correctly

The model routing followed the configured `reviewerRouting` convention: Sonnet for easy stories, Opus for medium stories. Across 13 reviews (9 initial + 4 re-reviews):

- **Sonnet reviews (easy stories):** Issues #217, #218, #219, #223 -- all 4 initial reviews produced correct verdicts. The Sonnet reviewer on #219 caught both warnings (test file over 200 lines, missing required test case) and issued REQUEST_CHANGES. The Sonnet reviewer on #220 caught the critical emoji mismatch.
- **Opus reviews (medium stories):** Issues #215, #216, #221, #222 -- the Opus reviews on the foundation modules were thorough, catching sed injection (C1 on #215), labels-last drop (C2 on #215), JSON escaping (C1 on #216), and dead test code (W1-W2 on #221).

**Evidence:** Dispatch records in the state file show reviewer model assignments match difficulty labels on each issue.

### 4. Shell Metacharacter Issues Were Caught and Fixed Systematically

The reviewer on E01-S01 (#215) identified that `_local_fm_write` was vulnerable to sed delimiter injection -- pipe, ampersand, and backslash characters in values would corrupt data. The builder's fix switched to the ENVIRON pattern for awk, and the lesson file (`2026-03-18-s01-awk-backslash-escape.md`) documented the root cause and prevention pattern. This lesson was then applied forward: the re-review caught that `_local_fm_append_label` had the same `-v` vulnerability, which was fixed in the second round (commit `714716a`).

**Evidence:** Issue #215 review comments show C1 (sed injection) and the re-review W1 (awk -v in append_label) both tracing to the same metacharacter class. Lesson file correctly documents the ENVIRON pattern.

### 5. Test Coverage Was Comprehensive

391 tests across 14 test files covering all 15 `pm_*` functions plus shared utilities. Every acceptance criterion in every story had at least one corresponding test. The integration test suite (36 tests, #223) validated end-to-end workflows through the adapter layer.

**Evidence:** All 14 test files pass (`bash tests/scripts/test-local-*.sh` runs clean). Test count: _common.sh split files: 40, items.sh: 90, board.sh: 51, comments.sh: 28, hierarchy+labels: 63 (across 3 files), lifecycle.sh: 42, reconcile.sh: 41, integration: 36.

## What Didn't Work

### 1. Fix Cycle Rate Was High (44% of Stories)

4 of 9 stories required fix cycles (5 total fix cycle rounds), consuming $3.36 and 29m 52s (23% of total cost). This is significantly higher than BL109's 10% rate (1/10 stories) and the historical average of ~5.6% organic fix cycles.

**Root cause analysis by story:**

- **E01-S01 (#215):** 2 fix cycles. Round 1: sed metacharacter injection (C1, real correctness bug), labels-last drop (C2, real correctness bug), test file over 200 lines (C3, convention violation). Round 2: original test file not deleted (C1), awk -v inconsistency with ENVIRON lesson (W1). All were genuine issues.
- **E01-S02 (#216):** 1 fix cycle. JSON title escaping missing (C1), labels separator wrong (W1), `ls` in loop fragile (W2), naming convention inconsistency (S4). The C1 was a real correctness bug; the builder applied body escaping but missed the title field.
- **E02-S03 (#219):** 1 fix cycle. Test file over 200 lines (W1), missing required test case from AC (W2). Both were convention/completeness issues, not correctness bugs.
- **E03-S01 (#220):** 1 fix cycle. Emoji mismatch in lifecycle headings (C1) -- the design doc showed headings without emoji, but the GitHub adapter (the canonical reference for byte-identical output) uses emoji. The builder followed the design doc rather than the implementation reference.

**Pattern:** 3 of 5 fix cycle rounds involved test file size violations (the 200-line convention). The convention applies to all files, but test files routinely exceed it (items.sh: 690 lines, reconcile.sh: 601 lines, lifecycle.sh: 475 lines). This suggests either the convention needs amendment for test files or the planner needs to specify separate test files to stay under the limit.

### 2. The 200-Line Convention Is Systematically Violated by Test Files

Of the 14 test files produced, at least 5 exceed 200 lines: `test-local-items-sh.sh` (690), `test-local-reconcile-sh.sh` (601), `test-local-lifecycle-sh.sh` (475), `test-local-board-sh.sh` (419), `test-local-hierarchy-labels-sh.sh` (410, later split). The split test files from E01-S01's fix cycles are all under 200 lines, but the original combined file (485 lines) was not deleted until the second fix cycle.

**Root cause:** The 200-line convention was designed for implementation files to keep modules focused and reviewable. Test files have different characteristics -- they contain many small, independent test functions that share setup helpers. Splitting test files adds overhead (duplicated helpers, more files to maintain) without the modularity benefit that splitting provides for implementation code.

**Evidence:** E02-S02 (#218) reviewer noted "precedent: all other test files in `tests/scripts/` also exceed 200 lines" and recommended updating the AC template. E02-S03 (#219) fix cycle was specifically triggered by test file size. The convention is enforced inconsistently -- some reviewers flag it as blocking, others approve despite violations.

### 3. Design Doc Was Stale on Emoji Convention

E03-S01 (#220) had a fix cycle because the design doc's example lifecycle headings (`### Work Started`) lacked the emoji prefix that the GitHub adapter uses (`### [rocket] Work Started`). The builder followed the design doc rather than the GitHub adapter implementation, producing a byte mismatch.

**Root cause:** The design doc was written during the current run, but the emoji convention was added to the GitHub adapter in a previous backlog item (#109). The designer did not cross-reference the live implementation when documenting the expected output format.

**Evidence:** Issue #220 review C1: "The GitHub adapter uses `### [rocket] Work Started`. The local adapter uses `### Work Started` (no emoji)." The reviewer noted: "The design doc was not updated when emojis were added to the GitHub adapter in PR #206."

### 4. Worktree Path Confusion in E03-S03

The builder on E03-S03 (#222, telemetry refactor) experienced path confusion between the worktree and main working tree. Read/Edit tools used absolute paths rooted at the main repo, while Bash CWD was in the worktree. This caused edits to land in the main working tree instead of the worktree, with changes lost when the orchestrator switched the main tree's branch.

**Root cause:** Read/Edit tools operate on the absolute path given, regardless of the Bash CWD. When a builder is dispatched in a worktree, it must use paths rooted at the worktree path (e.g., `.claude/worktrees/agent-XXXX/scripts/...`), not the main repo root.

**Evidence:** Lesson file `e03-composition-integration/2026-03-18-s03-worktree-path-confusion.md`. The builder's work was eventually completed successfully after recognizing the issue.

## Workflow Evolution During Epic

No changes were made to CLAUDE.md or agent files during this backlog item. The `git diff main..HEAD -- CLAUDE.md .claude/agents/` output was empty.

| Commit | Change | Trigger |
|--------|--------|---------|
| `1d54d40` | Lesson: awk -v backslash escape behavior | E01-S01 fix cycle 1 -- ENVIRON pattern documented |
| `13dc04f` | Lesson: shell && short-circuit exit code | E01-S02 -- `[ -n "" ] && action` leaves exit code 1 |
| `9a4c79b` | Lesson: worktree path confusion for Read/Edit tools | E03-S03 -- absolute paths must use worktree root |

## Key Learnings

### For Builders

1. **Always cross-reference live implementations, not just design docs, for output format contracts.** The design doc's lifecycle headings were stale (missing emoji). When the acceptance criteria say "byte-identical to the GitHub adapter," the builder should read the GitHub adapter's source, not the design doc's description. Evidence: E03-S01 (#220) fix cycle.

2. **The ENVIRON pattern must be applied consistently within a file.** E01-S01's first fix correctly switched `_local_fm_write` to ENVIRON, but left `_local_fm_append_label` using `awk -v` in the same file. The re-reviewer caught the inconsistency. When applying a security/correctness fix, grep the file for all instances of the vulnerable pattern. Evidence: Issue #215 re-review W1.

3. **Shell `&&` short-circuit at the end of a function returns the test's exit code, not 0.** `[ -n "$var" ] && action` at the end of a function returns 1 when `$var` is empty, even if the function succeeded. Use `if/fi` for the last conditional action. Evidence: Lesson file `e01-foundation/2026-03-18-s02-shell-and-short-circuit-exit.md`.

### For the Orchestrator

1. **The 200-line convention needs clarification for test files.** 4 of 9 stories produced test files over 200 lines, and 3 of 5 fix cycle rounds were triggered by this. Either amend the convention to exempt test files (with a higher limit), or require the planner to split test files across stories.

2. **Design+plan efficiency improves dramatically when building on prior work.** This run's design+plan cost $2.26 (2 dispatches, 25m 58s) compared to BL109's $8.08 (11 dispatches, 30m 57s). The prerequisite design doc from BL109 provided the function contract and folder structure, eliminating the need for architectural exploration.

### For the Workflow

1. **Local adapter validates the PM abstraction layer end-to-end.** All 15 `pm_*` functions were implemented against a completely different backend (filesystem vs. GitHub API) without modifying any workflow scripts. The `issue-telemetry.sh` refactor (E03-S03, 2 lines changed) was the only modification to an existing script, and it made telemetry posting adapter-agnostic. This validates the abstraction boundary designed in BL109.

2. **Greenfield adapter implementation is significantly cheaper than abstraction extraction.** BL111 (9 stories, $14.70) is comparable in scope to BL109 (10 stories, $19.03) but 23% cheaper. The cost difference comes almost entirely from the design phase ($1.12 vs $7.05). Build costs are similar ($6.29 vs $6.23). This confirms observation xii: greenfield infrastructure takes 1.5-2x less time than refactoring existing code.

3. **Fix cycle cost is the dominant cost variance across stories.** Stories without fix cycles cost $0.74-$1.34 each. Stories with fix cycles cost $1.10-$2.61 each. The 4 stories with fix cycles consumed $7.62 (52% of story costs) while the 5 stories without consumed $4.82 (33%). Reducing the fix cycle rate by 1 story would have saved ~$1.50 and ~8 minutes.

4. **Sonnet reviewers catch real issues on easy infrastructure stories.** Sonnet reviews on #219 (hierarchy+labels) and #220 (lifecycle) both issued REQUEST_CHANGES with genuine findings. The #219 reviewer caught a missing required test case from the acceptance criteria. The #220 reviewer caught the byte-identical emoji violation. Neither was a false positive.

## Recommendations

1. **Amend the 200-line convention to exempt or raise the limit for test files** -- 3 of 5 fix cycle rounds were triggered by test files exceeding 200 lines. Test files have different characteristics than implementation files (many independent functions, shared helpers, no modularity benefit from splitting). Proposed change: "Implementation files under 200 lines. Test files under 700 lines." Evidence: 5 of 14 test files exceed 200 lines; the largest (items) is 690 lines. The fix cycle cost for this convention violation was ~$1.50 across 3 stories.

2. **Add "cross-reference live implementation" convention for byte-identical contracts** -- When acceptance criteria require byte-identical output matching another adapter, the builder should read the target adapter's source code (not the design doc) to extract the exact format strings. The design doc may be stale. Evidence: E03-S01 (#220) fix cycle caused by missing emoji in lifecycle headings.

3. **Document the ENVIRON pattern for awk in builder instructions** -- When passing untrusted string values to awk, builders must use `ENVIRON` instead of `-v` to avoid backslash escape interpretation. This pattern appeared in E01-S01 and required two fix cycle rounds to apply consistently. Evidence: Lesson `e01-foundation/2026-03-18-s01-awk-backslash-escape.md`.

4. **Require builders to grep for the full vulnerable pattern during fix cycles (reinforces recommendation S)** -- E01-S01 fixed `_local_fm_write` with ENVIRON but left `_local_fm_append_label` using `-v` in the same file. This is the same "fix cited locations, not file-wide pattern" behavior observed in BL150 (recommendation S). The second fix cycle cost 7m 46s and $0.86.

## Lesson Retention

Three lesson files were created during this backlog item:

| Lesson File | Status | Absorbed Into |
|-------------|--------|---------------|
| `e01-foundation/2026-03-18-s01-awk-backslash-escape.md` | Compiled | Recommendation 3 (ENVIRON pattern convention) |
| `e01-foundation/2026-03-18-s02-shell-and-short-circuit-exit.md` | Compiled | Key Learning: Builders 3 |
| `e03-composition-integration/2026-03-18-s03-worktree-path-confusion.md` | Compiled | What Didn't Work 4 |

All three lesson files remain on disk for traceability. This retro doc is the primary reference for this backlog item's learnings going forward.
