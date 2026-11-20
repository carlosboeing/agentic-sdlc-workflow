---
title: "Multi-Pass Review Research: Evidence from Backlog #106"
type: research
authors: ["Carlos Boeing"]
date: 2026-03-16
agent: orchestrator
scope: Research into multi-pass review strategy for critical decision points in the agentic SDLC workflow
backlog-context: 106
---

# Multi-Pass Review Research: Evidence from Backlog #106

> Historical record (March 2026). Measurements come from controlled synthetic workloads and early infrastructure runs; see [case studies](../case-studies.md) for scoped findings.

> **Purpose:** This document captures a natural experiment in multi-pass review that occurred during the backlog PR review for #106 (Telemetry Accuracy & Automation). The human asked the orchestrator to review the PR three times, each time asking for deeper verification. The results provide empirical data on the value, cost, and failure modes of repeated review passes — informing whether to add a dedicated integrator/inspector agent at critical decision points.

## Context

Backlog #106 refactored the telemetry pipeline: extracting ~230 lines of embedded Python from `item-telemetry.sh` into a standalone `scripts/lib/compute-dispatches.py` module, adding Gantt generation from state data, and implementing fix cycle detection. The PR (#145) included 16 files, +4,390/-318 lines, 123 Python tests, and 35 bash integration tests.

The automated reviewer (opus model) performed the standard two-pass review (initial + re-review after fix). The human then asked the orchestrator for three additional analysis passes.

## The Five Review Passes

### Pass 0: Automated Reviewer (Standard Workflow)

**Dispatch:** Two reviewer dispatches — initial review (REQUEST_CHANGES) and re-review after fix (APPROVE).

**Cost:** ~173K tokens, ~$1.73, ~12 minutes agent time.

**Prompt (orchestrator → reviewer):**

> Review PR #145 for this project. This is the backlog PR for Telemetry Accuracy & Automation (#106).
>
> Check for:
> 1. Cross-epic integration issues (E01 pipeline + E02 conventions must be consistent)
> 2. Convention violations in CLAUDE.md and orchestrator.md
> 3. Security concerns (no secrets, proper file permissions)
> 4. Test coverage (Python unit tests, bash integration tests)
> 5. Backward compatibility (existing --dispatches and --gantt flags still work)
> 6. The Python module compute-dispatches.py output matches the original embedded Python
> 7. Template changes are correct (FIX_CYCLES condition, FIX_FOOTER injection)
> 8. Convention propagation (all references to changed flags/features updated)
>
> Post findings as a review comment on the PR.

**Findings:**

| ID | Severity | Finding | Correct? |
|----|----------|---------|----------|
| C1 | Critical | Premature `if __name__ == "__main__"` block at line 1076 causes 35 Gantt tests to be silently skipped when running `python3` directly. Only 88 of 123 tests execute. | ✓ Correct. Fixed in commit `f82ad14`. |
| W1 | Warning | `compute-dispatches.py` is 875 lines — above the 200-line guideline that motivated this refactoring. | ✓ Correct. |
| W2 | Warning | Test fixtures use `schema_version` while documented schema uses `version`. Non-functional but inconsistent. | ✓ Correct. Code reads neither field. |
| W3 | Warning | CLAUDE.md helper scripts table entry for `compute-dispatches.py` shows only `--from-state` mode but omits the `--dispatches` mode. | ✓ Correct. |
| W4 | Warning | The backlog-level telemetry example passes `--summary` and `--breakdown` alongside `--gantt-from-state`, but `--gantt-from-state` auto-computes both. The manual values get silently replaced. | ✓ Correct (and more significant than initially apparent — see Pass 3). |
| W5 | Warning | Telemetry heading emoji (📊) was removed but template disclaimer emoji (💡) remains. | ✓ Correct. |
| S1 | Suggestion | `_build_story_labels` branch name parsing has no guard for non-standard names. | ✓ Correct. |
| S2 | Suggestion | Redundant `capitalize()` on line 427 — `agent_base` is already capitalized on line 421. | ✓ Correct. |
| S3 | Suggestion | Changelog claims "123 tests" but only 88 pass with direct runner (moot after C1 fix). | ✓ Correct (moot after fix). |
| S4 | Suggestion | `--dispatches` + `--gantt-from-state` together: `--dispatches` silently wins with no warning. | ✓ Correct. |

**Assessment:** 10/10 findings verified correct. Zero false positives. The reviewer stayed within scope (PR diff) and was precise. C1 was a genuine blocking bug that justified the mandatory PR review policy.

---

### Pass 1: Orchestrator Analysis (Human Request)

**Human prompt:**

> Can you review the PR and the reviewer's findings and give me your critical analysis.

**Approach:** Read the PR code, reviewer comments, and the retro. Gave a high-level assessment with opinions.

**Cost:** Minimal token cost (reading existing data, no agent dispatch).

**New findings beyond the reviewer:**

| Finding | Correct? |
|---------|----------|
| Per-row costs in epic telemetry are all wrong (sonnet over-reported, opus under-reported) | ✓ Correct finding, but the explanation was fabricated ("the orchestrator used `78562 * 7.5/1M`" — this rate doesn't correspond to any formula). |
| PR telemetry (computed by `compute-dispatches.py`) has zero errors | ✓ Correct (verified in Pass 2). |
| Fix cycle detection has a false positive for interrupted dispatches | ✓ Correct (confirmed with test in Pass 2). |
| PR-level Gantt labels are generic ("Build", "Re-review" without "PR" prefix) | ✓ Correct. |
| Reviewer "didn't catch" the epic cost discrepancy | ✗ Unfair — epic posts are outside the PR diff. |

**Errors made:**

| Error | What happened |
|-------|---------------|
| Fabricated root cause for cost errors | Said the orchestrator "used $7.5/M rate." In Pass 2, I proved the errors follow no consistent formula — they were bad mental math, not a systematic rate error. I invented a tidy explanation that sounded plausible. |
| Dismissed reviewer's W4 | Said W4 was about "a hypothetical misuse" without actually checking whether the CLAUDE.md example had the contradictory flags. It did. |

**Assessment:** Found real issues (epic costs, generic labels) but drew unreliable conclusions. The fabricated root cause is the most concerning error — it was stated with confidence and would have been accepted without further checking.

---

### Pass 2: Systematic Verification (Human Request)

**Human prompt:**

> Can you double check the PR and the reviewer's comments and your findings?

**Approach:** Methodical verification of each claim (reviewer's and my own) against actual code and computed data. Ran Python scripts to compare expected vs actual costs. Ran live tests for the fix cycle false positive.

**Cost:** Minimal token cost (bash/python commands).

**New findings beyond Pass 1:**

| Finding | Correct? |
|---------|----------|
| All 15 per-row costs in both epic telemetry posts are wrong (systematically proven) | ✓ Correct. Every sonnet cost over-reported by ~$0.04-0.08, every opus cost under-reported by ~$0.09-0.22. |
| E01-S03 Build row entirely missing from E01 epic breakdown | ✓ Correct. |
| Redundant `--dispatches-from-state` in orchestrator.md preferred example | ✓ Correct. `--gantt-from-state` already does everything `--dispatches-from-state` does. |
| Fix cycle false positive confirmed with live test | ✓ Correct. Two sequential builder dispatches (no reviewer between) falsely detected as fix cycle. |
| Reviewer's W4 "partially wrong" — CLAUDE.md example doesn't have conflicting flags | ✗ **Wrong.** I checked the wrong section. The CLAUDE.md example absolutely does pass `--summary`, `--breakdown`, `--cost`, `--tokens`, `--duration` alongside `--gantt-from-state`. |

**Errors made:**

| Error | What happened |
|-------|---------------|
| Wrongly dismissed W4 (again) | Searched CLAUDE.md, found the orchestrator.md preferred method text (which correctly doesn't have the conflicting flags), confused it with the CLAUDE.md example, and declared the reviewer "partially wrong." The reviewer was completely right both times I dismissed the finding. |
| Premature closure on Gantt t21 | Found my verification script had a bug regarding `issue=None` handling, corrected it, declared "all 22 Gantt tasks correct," and stopped investigating. Missed the deeper inconsistency between Gantt coloring and fix cycle metrics. |

**Assessment:** The arithmetic verification was highly valuable (proving 15/15 costs wrong, finding the missing row). But the judgment calls were still unreliable — I dismissed a correct finding for the second time, and I stopped too early on the Gantt investigation.

---

### Pass 3: Fresh Complete Verification (Human Request)

**Human prompt:**

> Can you one final check on everything: the PR, the reviewer's analysis and your first 2 analysis of everything? I want a final definite picture of the whole thing.

**Approach:** Started from scratch. Verified every number, every claim from all parties. Traced code paths. Compared outputs of different systems against each other (not just against their own specifications).

**Cost:** Minimal token cost (bash/python commands).

**New findings beyond Pass 2:**

| Finding | Correct? |
|---------|----------|
| CLAUDE.md example IS contradictory (correcting my own Pass 2 error) | ✓ Correct. Finally read the right section. |
| Gantt and fix cycle metrics use different detection algorithms that disagree | ✓ Correct. Gantt uses `(issue, agent_prefix) → count` (simple repeat detection). `compute_fix_cycles` uses `first_builder_seen` + `pending_re_review` (builder→reviewer→builder pattern). For PR-level fix cycles (reviewer→builder→reviewer pattern), they give different answers. |
| Gantt t20/t21 visual inconsistency | ✓ Correct. t20 (PR fix build) is green (no tag) while t21 (PR re-review) is red (`:crit`). Same logical fix cycle but different colors. For E01-S02 story-level fix cycles, both the fix and re-review are correctly red. |
| PR-level fix cycles invisible to metrics | ✓ Correct. `compute_fix_cycles` requires an initial builder dispatch to establish the baseline. PR-level patterns start with a reviewer, so no fix cycle is detected. The Gantt partially detects it (re-review is `:crit`) but the fix build is not. |

**Errors made:** None identified.

**Assessment:** The key methodological difference was asking "do these two systems agree?" instead of checking each against its own specification. The Gantt/metrics disagreement was the most significant new finding and was only visible through cross-system comparison.

---

## Comparative Analysis

### Finding Discovery by Pass

| Finding | Severity | Reviewer | Pass 1 | Pass 2 | Pass 3 |
|---------|----------|----------|--------|--------|--------|
| C1: `__name__` block (35 tests skipped) | **Blocking** | ✓ Found | Confirmed | Verified fix | ✓ |
| W1: 875-line module | Low | ✓ Found | Confirmed | ✓ | ✓ |
| W2: schema_version inconsistency | Cosmetic | ✓ Found | Confirmed | ✓ | ✓ |
| W3: Incomplete helper table | Low | ✓ Found | Confirmed | ✓ | ✓ |
| W4: Silent flag overwrite | **Medium** | ✓ Found | ✗ Dismissed | ✗ Dismissed | ✓ Confirmed |
| W5: Emoji inconsistency | Cosmetic | ✓ Found | Confirmed | ✓ | ✓ |
| S1-S4: Suggestions | Low | ✓ Found | Confirmed | ✓ | ✓ |
| Epic per-row costs all wrong (15/15) | Medium | ✗ Not in scope | ✓ Found (wrong cause) | ✓ Proved | ✓ |
| E01-S03 Build row missing | Medium | ✗ Not in scope | ✗ Missed | ✓ Found | ✓ |
| Redundant --dispatches-from-state | Low | ✗ Missed | ✗ Missed | ✓ Found | ✓ |
| Fix cycle false positive (interrupted) | Medium | ✓ Found (S03 W2) | ✓ Flagged | ✓ Confirmed with test | ✓ |
| Generic PR-level Gantt labels | Low | ✗ Missed | ✓ Found | ✓ | ✓ |
| Gantt/metrics detection disagreement | **Medium** | ✗ Missed | ✗ Missed | ✗ Missed | ✓ Found |
| Gantt t20/t21 visual inconsistency | Low | ✗ Missed | ✗ Missed | ✗ Missed | ✓ Found |
| CLAUDE.md example contradictory | **Medium** | ✓ Found (W4) | ✗ Dismissed | ✗ Dismissed | ✓ Confirmed |

### Error Rate by Pass

| Pass | Findings | Errors | Error Rate | Error Type |
|------|----------|--------|------------|------------|
| Reviewer | 10 | 0 | 0% | — |
| Pass 1 | 5 new | 2 | 40% | Fabrication, dismissal |
| Pass 2 | 3 new | 2 | 67% | Dismissal (same finding!), premature closure |
| Pass 3 | 4 new | 0 | 0% | — |

Note: Pass 2 has a higher error rate than Pass 1 not because it was worse overall, but because its correct findings (arithmetic proofs) were trivially verifiable while its errors were judgment calls. The lesson: **computation is reliable, judgment degrades under overconfidence from prior "corrections."**

### Cumulative Value by Pass

| After Pass | Total unique correct findings | Blocking bugs found | Medium+ issues found | Errors in the analysis itself |
|---|---|---|---|---|
| Reviewer | 10 | 1 | 2 (C1, W4) | 0 |
| + Pass 1 | 14 | 1 | 3 (+epic costs) | 2 |
| + Pass 2 | 17 | 1 | 5 (+missing row, false positive confirmed) | 4 (cumulative) |
| + Pass 3 | 20 | 1 | 7 (+Gantt/metrics disagreement, CLAUDE.md confirmed) | 4 (no new errors) |

The blocking bug was found in the reviewer pass. All subsequent passes found medium-severity and low-severity issues. The cumulative error count grew through Passes 1-2 (judgment errors) and stabilized in Pass 3 (computation-only approach).

### What Each Pass Was Good and Bad At

| Capability | Reviewer | Pass 1 | Pass 2 | Pass 3 |
|---|---|---|---|---|
| Reading the diff | Excellent | Good | N/A | N/A |
| Checking claims against code | Good | Poor (assumed) | Good (but misread once) | Thorough |
| Arithmetic verification | Not attempted | Invented explanations | Computed everything | Cross-verified |
| Cross-system consistency | Not attempted | Not attempted | Not attempted | Found the key bug |
| Self-correction | N/A | N/A | Overconfident in corrections | Skeptical of own corrections |
| Knowing scope boundaries | Correctly limited to PR | Blamed reviewer for scope | Corrected this | Correctly scoped |
| Judgment reliability | High (0 errors) | Low (40% error rate) | Low (67% on new findings) | High (0 errors) |

### Cost-Effectiveness

| Pass | Agent Cost | New Correct Findings | Cost per New Finding | Highest-Severity Find |
|------|-----------|---------------------|---------------------|-----------------------|
| Reviewer | ~$1.73 | 10 | ~$0.17 | **Blocking** (C1) |
| Pass 1 | ~$0 (orchestrator time) | 3 correct | ~$0 | Medium (epic costs) |
| Pass 2 | ~$0 (orchestrator time) | 3 correct | ~$0 | Medium (missing row) |
| Pass 3 | ~$0 (orchestrator time) | 4 correct | ~$0 | Medium (Gantt/metrics) |

The human-prompted passes had near-zero marginal cost because they reused the orchestrator session — no new agent dispatches. If implemented as a dedicated agent, each pass would cost ~$1-2 (comparable to the reviewer).

## Key Observations

### 1. The Reviewer Found the Only Blocking Bug

Across all five passes (reviewer + 3 orchestrator + 1 re-review), only one blocking bug was found (C1), and the reviewer found it on the first pass. Every subsequent finding was medium-severity or lower. This suggests the existing single-reviewer model is sufficient for catching merge-blocking issues.

### 2. Judgment Degrades Under Overconfidence; Computation Does Not

The orchestrator's Passes 1 and 2 had high error rates (40%, 67%) because they used AI judgment to evaluate findings. The reviewer and Pass 3 had zero errors because they relied on reading code (reviewer) or running computations (Pass 3). The project's "determinism first" principle applies to reviews too: **when a claim can be verified by computation, compute it; don't reason about it.**

### 3. Cross-System Consistency Checks Are Uniquely Valuable

The most significant finding from Pass 3 (Gantt/metrics detection disagreement) required comparing the outputs of two different code paths against each other. No single-system review — reading the Gantt code, reading the fix cycle code, or testing either in isolation — would have revealed this. It only became visible by asking "do these two systems agree on what is a fix cycle?"

### 4. The Same Finding Can Be Dismissed Multiple Times

The orchestrator dismissed the reviewer's W4 in both Pass 1 and Pass 2, each time with a different but equally wrong justification. This suggests that re-review by the same agent is unreliable for overturning initial judgments — **confirmation bias persists across passes.** A different agent or a different methodology (computation vs judgment) is needed to reliably catch dismissed findings.

### 5. Documentation Bugs Are the Primary Output of Later Passes

Of the 10 findings unique to Passes 1-3, most are documentation issues (contradictory examples, missing rows, redundant flags) rather than code bugs. This shapes what kind of agent would be most effective: not a code reviewer, but a **documentation/integration verifier** that checks whether docs match code behavior.

## Implications for Workflow Design

### Option A: Multi-Pass Same Agent

Re-dispatch the same reviewer with "look harder" prompts.

**Evidence against:** The orchestrator's Passes 1-2 show that the same agent re-examining the same material makes judgment errors and dismisses valid findings repeatedly. The error rate was 40-67% on new findings. Confirmation bias persists.

### Option B: Dedicated Inspector Agent (Different Role)

A specialized agent that runs after the reviewer, focused on integration and consistency checks rather than code quality.

**Evidence for:** The highest-value findings from Passes 2-3 were all verifiable by computation:
- Run both test runners and compare counts (catches C1-class bugs)
- Compute expected costs from token counts + pricing and compare to posted values
- Execute code paths described in documentation examples and verify behavior
- Run the same input through multiple code paths and compare outputs

This is a fundamentally different task from code review. The reviewer reads diffs and applies judgment. The inspector runs verifications and reports factual discrepancies.

**Proposed Inspector Capabilities:**

| Check | What it catches | Method |
|-------|----------------|--------|
| Test runner consistency | Silent test skipping (C1) | Run `pytest` and `python3` direct, compare counts |
| Documentation-code agreement | Contradictory examples (W4) | Parse CLI examples from docs, execute them, verify behavior |
| Cross-path consistency | Gantt/metrics disagreement | Run same input through multiple code paths, diff outputs |
| Telemetry accuracy | Epic cost errors | Recompute costs from raw data, compare to posted values |
| Flag precedence | Silent overwrites (S4) | Test all flag combinations, check for silent conflicts |

### Option C: Enhanced Single Reviewer with Computation Tools

Give the existing reviewer explicit instructions to run verification scripts, not just read diffs.

**Evidence for:** The reviewer's zero error rate came from staying within its comfort zone (reading code). The orchestrator's errors came from judgment calls. If the reviewer had instructions to *run* tests both ways and *compute* expected costs, it might have caught C1 before it was committed and W4 at the code level.

**Evidence against:** The reviewer already had 57 tool uses in its dispatch. Adding computational verification would increase cost and time. The reviewer's strength is judgment about code quality — diluting that with mechanical checks may reduce both.

### Recommendation

**Option B (Dedicated Inspector) is the strongest fit** for this workflow's "determinism first" philosophy. The inspector would be a computation-focused agent, not a judgment-focused one. It runs after the reviewer approves, performing scripted checks that verify integration-level properties. This separates the concerns:

- **Reviewer:** "Is the code well-written, correct, and following conventions?" (Judgment)
- **Inspector:** "Do the tests actually all run? Do the docs match the code? Do different code paths agree?" (Computation)

The inspector's checks should be **deterministic and scriptable** — not "review this code again" but "run these specific verification scripts and report any failures." This eliminates the judgment-error problem observed in Passes 1-2 while capturing the cross-system consistency value observed in Pass 3.

### Open Questions for Design Phase

1. **When to deploy the inspector:** Every backlog PR? Only for PRs above a size threshold? Only for infrastructure/workflow PRs (where documentation-code consistency matters most)?
2. **Inspector scope:** Should it also verify story-level builds (catching the `__name__` bug earlier), or only the final integration?
3. **Cost budget:** If the inspector costs ~$1-2 per dispatch (comparable to a reviewer), is that justified for the class of medium-severity findings it would catch?
4. **Integration with existing workflow:** Does the inspector run as a Phase 8.5 (between reviewer approval and human review), or as part of Phase 8 (before the reviewer)?
5. **Failure handling:** If the inspector finds a discrepancy, does it re-dispatch the builder, or just report to the human?

## Appendix: Session Transcript

### Human Prompt 1 (Triggering Pass 1)

> Can you review the PR and the reviewer's findings and give me your critical analysis.

### Orchestrator Response 1 (Pass 1 — Summary)

The orchestrator read the PR code (`compute-dispatches.py`, `item-telemetry.sh`, `telemetry.md`), the reviewer's two comments on PR #145, and the retro doc. Key outputs:

- Confirmed all reviewer findings (C1 through S4) as valid
- Identified epic telemetry per-row cost errors — claimed "the orchestrator used `78562 * 7.5/1M`" as root cause (fabricated)
- Noted fix cycle false positive risk for interrupted dispatches
- Noted generic PR-level Gantt labels
- Assessed code architecture as "solid" and retro as "excellent"
- Dismissed W4 as being about "a hypothetical misuse"
- Stated the PR "delivers on its goals" and issues found are non-blocking

Errors: Fabricated the $7.5/M rate explanation. Dismissed W4 without verification.

### Human Prompt 2 (Triggering Pass 2)

> Can you double check the PR and the reviewer's comments and your findings?

### Orchestrator Response 2 (Pass 2 — Summary)

The orchestrator ran systematic computations:

- Computed all 15 epic per-row costs against the correct formula — proved every one wrong
- Verified all 22 PR telemetry rows — proved every one correct
- Confirmed fix cycle false positive with a live `python3` test
- Found the missing E01-S03 Build row in E01 epic telemetry
- Found the redundant `--dispatches-from-state` in orchestrator.md
- Checked CLAUDE.md for W4 — misread the file and declared W4 "partially wrong" (was wrong about this)
- Found verification script bug for Gantt t21, corrected it, declared "all 22 tasks correct" and stopped

Errors: Wrongly dismissed W4 by reading the wrong section. Premature closure on Gantt investigation.

### Human Prompt 3 (Triggering Pass 3)

> Can you one final check on everything: the PR, the reviewer's analysis and your first 2 analysis of everything? I want a final definite picture of the whole thing.

### Orchestrator Response 3 (Pass 3 — Summary)

The orchestrator started fresh, verifying every number and claim:

- Corrected the W4 dismissal — confirmed CLAUDE.md example IS contradictory
- Discovered Gantt/metrics fix cycle detection disagreement (two different algorithms, different results for PR-level patterns)
- Traced the Gantt t20 (green) / t21 (red) visual inconsistency
- Traced why PR-level fix cycles are invisible to `compute_fix_cycles` (no initial builder dispatch)
- Verified Gantt offsets for all 22 tasks against state file timestamps
- Verified retro's numbers ($13.92 for 21 dispatches, ~1.75M tokens) as correct
- Cross-verified wall-clock computation (118m 7s dispatch-based vs ~2h 3m retro-estimated including overhead)

Errors: None identified.

### Human Prompt 4 (Triggering Comparison)

> Can you give me a comparison between your 3 passes on the PR and reviewer's findings and how they stack up?

### Orchestrator Response 4 (Comparison — Summary)

Produced the comparative table of findings by pass, error rates, cumulative value, and the meta-lesson about premature closure. Recommended against general multi-pass review but suggested a focused re-verification step for backlog PRs only, using scripted deterministic checks rather than AI judgment.

### Human Prompt 5 (Triggering This Document)

> Can you create a comprehensive discovery (research) doc and add all these details, including my prompts for each pass and your responses and the break down and comparison of each pass and the comparison and analysis you made? I want to use this doc in the future to brainstorm the idea of multi-pass and/or dedicated integrator or inspector agent for important decision points.
