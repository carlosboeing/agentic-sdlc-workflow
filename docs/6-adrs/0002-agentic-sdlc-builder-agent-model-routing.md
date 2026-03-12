# ADR-0002: Builder Agent Model Routing via Variant Files

**Date:** 2026-03-08
**Status:** Accepted
**Context:** Dispatch Protocol — routing builder agents to different Claude models based on story difficulty

## Context

The dispatch protocol routes stories to Claude models by difficulty label: `difficulty/easy` → Haiku, `difficulty/medium` → Sonnet, `difficulty/hard` → Opus. The orchestrator needs a way to spawn builder subagents on the correct model. The `builder.md` agent file uses `model: inherit` (runs on the orchestrator's model), so a routing mechanism is needed.

## Decision

Use **pre-created variant agent files** with different `model` frontmatter values:

- `.claude/agents/builder.md` — `model: inherit` (default, for direct use)
- `.claude/agents/builder-haiku.md` — `model: haiku`
- `.claude/agents/builder-sonnet.md` — `model: sonnet`
- `.claude/agents/builder-opus.md` — `model: opus`

All variants share identical body content with `builder.md`. Only the `name` and `model` fields in the YAML frontmatter differ. The orchestrator dispatches with `subagent_type: "builder-haiku"` etc.

## Alternatives Considered

### 1. Agent tool `model` parameter

The Agent tool's hook documentation lists a `model` field in the input schema, suggesting runtime override capability. However, testing confirmed the parameter is **not in the tool's schema** (`additionalProperties: false`) and cannot be passed by the orchestrator.

**Verdict:** Not available in current Claude Code.

### 2. Dynamic temp files at runtime

Create a temporary agent file (e.g., `_builder-dispatch.md`) mid-session with the desired model, dispatch from it, then delete it.

**Verdict:** Does not work. Agent types are loaded at session start only. Files created mid-session are not discovered as valid `subagent_type` values.

### 3. PreToolUse hook with `updatedInput`

A shell hook intercepts Agent tool calls, extracts a `[MODEL:xxx]` tag from the prompt, and injects `model` via `updatedInput`.

**Verdict:** Crashes Claude Code. The `updatedInput` mechanism works for other tools (Bash, Edit, etc.) but causes an internal error (`undefined is not an object (evaluating 'K.length')`) when applied to Agent tool calls.

### 4. Edit `builder.md` in-place

Modify the frontmatter before dispatch, restore after.

**Verdict:** Not parallel-safe. Two concurrent dispatches would race on the same file.

## Consequences

- **Sync obligation:** Any change to `builder.md` body must be propagated to all three variants. A sync command is documented in CLAUDE.md.
- **Session-start loading:** Variant files are committed to the repo, so every session has them. No runtime discovery needed.
- **Parallel-safe:** Each variant is an independent file — concurrent dispatches with different models work correctly.
- **Three extra files:** Adds 3 files to `.claude/agents/` that are near-duplicates. Acceptable given the alternatives.
