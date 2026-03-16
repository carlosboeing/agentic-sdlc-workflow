# Project Cleanup

This repo was extracted from NeuralNorris and still contains NeuralNorris-specific references in agent files (builder, designer, planner, reviewer, orchestrator, retro). These references don't affect test runs (which use content-only workloads) but would need to be removed before the workflow can be used on a different codebase.

**Affected files:** All 9 agent `.md` files in `.claude/agents/` contain `.NET`, `NeuralNorris`, `Blazor`, `dotnet`, or `NN.*` references.

**When to fix:** When packaging for external distribution or running the workflow on real software in this repo. See the [roadmap](docs/1-discovery/2026-03-15-roadmap.md) for the full prioritised plan.
