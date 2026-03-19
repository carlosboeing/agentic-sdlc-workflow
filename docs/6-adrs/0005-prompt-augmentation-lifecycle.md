---
title: "Prompt Augmentation for Story Lifecycle Coupling"
date: 2026-03-19
status: Accepted
backlog: 243
---

# ADR 0005: Prompt Augmentation for Story Lifecycle Coupling

## Context

The orchestrator's dispatch model treats building and reviewing as separate sequential phases. This creates a "wait gate" where fast builders' completed work sits idle while the slowest builder in a parallel wave finishes. The review phase adds wall-clock time equal to `max(reviews)` on top of `max(builds)`.

Five approaches were evaluated to couple the build and review lifecycle into a single parallel unit per story. See the design doc (`docs/2-design/2026-03-19-phase-restructuring.md` section 2) for the full comparison.

## Decision

Use **Approach E: Orchestrator-Driven Prompt Augmentation**.

The orchestrator injects a "POST-BUILD LIFECYCLE" section into each builder's dispatch prompt. After completing implementation, the builder reads the lifecycle instructions and dispatches a reviewer agent via the Agent tool. The builder handles fix cycles (up to 2) and returns combined metrics.

## Rationale

| Factor | Prompt Augmentation (E) | Wrapper Agent (A) |
|--------|------------------------|-------------------|
| New agent files | None | 1 new file (story-implementer.md) |
| Session start constraint | None | Agent must pre-exist before session start |
| Builder.md changes | Tools field only | None |
| Per-story customization | Orchestrator varies prompt per story | Wrapper agent reads config |
| Maintenance burden | Prompt template in orchestrator.md | Separate agent file to maintain |
| Telemetry capture | Builder returns reviewer metrics in response | Wrapper aggregates and returns metrics |

Key advantages of prompt augmentation:

1. **No new agent file** -- avoids the known platform limitation that agent files must exist before session start
2. **Orchestrator controls lifecycle per-story** -- different stories can get different lifecycle instructions (REVIEW vs SKIP) without the agent needing to read config
3. **builder.md stays focused on building** -- lifecycle behavior comes from the prompt, not the agent's identity
4. **Same nesting depth as Approach A** (3 levels) but without a separate coordination layer

## Consequences

**Positive:**
- Wave duration reduces from `max(builds) + max(reviews)` to `max(build + review per story)`
- Fix cycles run in parallel with sibling stories' lifecycles
- Builder agent identity remains clean (focused on TDD implementation)

**Negative:**
- 3-level Agent nesting (Orchestrator -> Builder -> Reviewer) is untested in this project
- Builder sessions are longer (include reviewer dispatch time)
- If builder hits a usage limit during reviewer dispatch, reviewer metrics may be lost

**Neutral:**
- Builder.md gains `Agent` in its tools field (minimal persistent change)
- Telemetry recording adds `nested_in` and `review_tier` fields to dispatch entries (additive, backward compatible)
