# Workflow Analysis Prompt

Use this prompt to perform a comprehensive critical analysis of the agentic SDLC pipeline. Run it between runs (or at the start of a new run) to identify bugs, gaps, stale content, and improvement opportunities.

## Usage

```bash
claude --agent orchestrator --dangerously-skip-permissions \
  "$(cat docs/workflow-analysis-prompt.md)"
```

Or paste the prompt below directly into an interactive session.

---

## Prompt

Perform a critical workflow analysis of the agentic SDLC pipeline. Do NOT just check for documentation consistency — analyze the workflow as a system.

Read every agent file in `.claude/agents/`, every script in `scripts/`, the telemetry template, CLAUDE.md, the recommendations tracker, and the last 3 retro docs. Then analyze across these dimensions:

**Correctness & Consistency**

1. **Phase symmetry:** For each workflow phase (design, plan, build, review, retro), verify it has: a tracked GitHub issue, board status transitions, telemetry capture, inclusion in the `Closes` list, and a defined deliverable. Flag any phase that's missing artifacts the others have.
2. **Convention propagation:** For every convention in CLAUDE.md, verify the relevant agent file(s) reflect it. For every command example in agent files, verify it matches CLAUDE.md. Check for duplicated source-of-truth (same data in multiple files).
3. **Script coverage:** For every script in `scripts/`, verify it's documented in CLAUDE.md's helper scripts table and referenced correctly in agent files. Check if any agent file describes manual commands that a script already handles.
4. **Stale content:** Check for references to patterns that have been superseded (e.g., old API patterns, removed flags, renamed files). Check lesson files for issues that are now fixed — candidates for archiving.

**Robustness**

5. **Workflow gaps:** Trace through a complete autonomous run end-to-end (Phase 0 through Phase 11) and identify any step where the orchestrator has to improvise because the instructions are ambiguous, missing, or contradictory.
6. **Error path coverage:** For each phase, check if the failure mode is documented (what happens if the agent fails, hits a rate limit, or produces bad output).

**Innovation & Leverage**

7. **Untapped capabilities:** Given the tools available (Agent tool with worktree isolation, parallel dispatch, GitHub API, telemetry scripts, state persistence), what workflow capabilities are technically possible but not yet implemented? Think about: feedback loops, self-healing, adaptive routing, cross-run learning, predictive sizing, quality gates, or workflow introspection.
8. **Friction points:** Based on the retro docs and lesson files, where does the workflow spend disproportionate time or tokens? What repetitive manual steps could be automated with a new script or convention? Where do agents waste effort on things that could be pre-computed or cached?
9. **Missing agents or roles:** Are there phases of work that no current agent owns? Would a new specialized agent (e.g., a changelog writer, a test-output validator, a board reconciler) reduce orchestrator complexity or improve quality?

**Output Format**

Present findings in three sections:

1. **Prioritized fix table** — issue, type (bug/gap/stale/observation), effort, and impact
2. **Quick wins** — improvements achievable in under 30 minutes
3. **Big ideas** — capabilities that would meaningfully change how the workflow operates
