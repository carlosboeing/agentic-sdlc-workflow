---
date: 2026-03-19
status: Accepted
backlog: 243
---

# ADR-0005: Parallel Reviews and Tiered Review Strategy

## Context

The orchestrator's dispatch model treats building and reviewing as separate sequential phases. In a typical 3-story wave:

- Builders run in parallel: `max(2m 30s, 2m 10s, 1m 50s)` = 2m 30s
- Reviewers run sequentially: `1m 10s + 1m 10s + 1m 10s` = 3m 30s
- Wave total: **6m 00s**

Additionally, telemetry data across 14 runs and 40+ easy test stories shows zero fix cycles triggered by per-story review on easy stories. The review gate is over-applied for this difficulty tier.

## Decision

1. **Parallel review dispatch:** After all builders in a wave complete, dispatch reviewers for eligible stories in parallel (multiple simultaneous Agent tool calls) instead of sequentially.

2. **Tiered review strategy:** Skip per-story review for easy stories when `reviewStrategy.skipEasyReview` is `true` in config. Infrastructure stories (those without the `test-agentic-sdlc` label) always get reviewed when `reviewStrategy.requireReviewForInfra` is `true`.

3. **No new agent files:** The orchestrator drives all dispatch sequencing. No `story-implementer.md` wrapper is created. The builder's prompt is augmented with review tier context (SKIP or REVIEW) so it can calibrate self-validation rigor.

4. **PR review remains the cross-story quality gate:** The PR review after all stories merge is always performed, regardless of tiered review settings.

## Alternatives Considered

- **Approach A (builder dispatches reviewer):** Rejected. Violates separation of concerns -- builders should focus on implementation, not review orchestration.
- **Approach B (story-implementer wrapper agent):** Rejected. Introduces a new agent file and nested dispatch complexity. The Agent tool is available only on the orchestrator; adding it to a wrapper creates harder-to-debug dispatch chains.
- **Approach C (orchestrator sequences within parallel slot):** Not feasible. The Agent tool's parallel dispatch model requires the orchestrator to wait for all dispatched agents before acting on any individual result.

## Consequences

### Positive

- Wave duration reduces from `max(builds) + sum(reviews)` to `max(builds) + max(reviews)` (~39% improvement for 3-story waves)
- Easy test story waves skip review entirely (saves ~84K tokens and 3-5 minutes per test run)
- No new abstractions or agent files to maintain
- Orchestrator retains full control of dispatch sequencing and state management

### Negative

- True `max(build + review per story)` parallelism is not achieved -- the orchestrator still waits for all builders before dispatching any reviewers. The practical difference is negligible for typical workloads.
- Skipping easy reviews means format violations surface only at the PR review stage, where they are harder to isolate. Mitigated by builder self-validation instructions and the `requireReviewForInfra` safety net.

### Neutral

- The orchestrator state file's dispatch log format is unchanged. Builder and reviewer dispatches are still recorded individually.
- Telemetry computation scripts require no changes.
