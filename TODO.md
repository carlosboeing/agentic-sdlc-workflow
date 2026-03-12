# TODO: Make Workflow Project-Agnostic

This repo was extracted from [NeuralNorris](https://github.com/carlosboeing/agentic-sdlc-workflow) and still contains NeuralNorris-specific references that need to be generalized.

## What needs refactoring

### CLAUDE.md
- **Build & Run** section references `dotnet build`, `dotnet test`, `dotnet ef`, and `docker compose` commands specific to a C#/.NET project
- **Architecture** section describes NeuralNorris internals (`NN.Gateway`, `NN.Agent`, `AgentSession`, `ToolRegistry`, EF Core, SQLite, Blazor Server, etc.)
- **Testing Conventions** references xUnit + NSubstitute (C#-specific)
- **CI** section references `.NET 10` GitHub Actions workflow
- **Project Documentation** references NeuralNorris-specific doc structure
- These sections should either be removed, templated with placeholders, or moved to a "example project config" section

### Agent files (`.claude/agents/`)
- `builder.md` + variants reference `dotnet build`, `dotnet test`, C# conventions
- `reviewer.md` may reference C#/.NET patterns
- `planner.md` may reference .NET project structure conventions
- All agents should be language/framework-agnostic, with project-specific config injected via CLAUDE.md

### Config (`.claude/settings.json`)
- Permission whitelist includes `dotnet` — should be generalized or documented as "add your project's build tools here"

### Scripts (`scripts/`)
- Scripts themselves are project-agnostic (bash + GitHub API) — no changes expected
- `dispatch-workflow.sh` and `dispatch-story.sh` may have hardcoded assumptions worth reviewing

## Goal

The workflow should be droppable into any repo regardless of language/framework. Project-specific config (build commands, test commands, architecture context) should live in the consuming project's `CLAUDE.md`, not in the workflow files themselves.
