# Comprehensive Audit Report: Agentic SDLC Blueprint

> **Errata (2026-11-20).** Later review against current documentation found that some findings below are wrong. The body is left as written in March 2026.
>
> - **Finding 2 is wrong.** `ccusage` is a real open-source npm CLI that reports Claude Code usage and cost. The blueprint's reference to `npx ccusage@latest` was correct (it is third-party, not part of Claude Code).
> - **Finding 3 is wrong.** The Agent SDK does provide a `canUseTool` permission callback. The blueprint text in `03-orchestration-engine.md` was correct.
> - **The finding about `https://api.githubcopilot.com/mcp/` is misleading.** That URL is GitHub's remote endpoint for its official MCP server, and the package the audit recommends instead (`@modelcontextprotocol/server-github`) has since been deprecated in favour of `github/github-mcp-server`.
> - **None of the proposed fixes were applied** to the design documents. They are kept as historical, with status banners and a few targeted claim corrections.
> - Statements such as "cross-references are 100% valid" and "the design is implementable" reflect the audit's scope at the time. The starter kit was never run end to end, and later review found defects in it (see [`../../starter-kit/README.md`](../../starter-kit/README.md)).

**Date:** 2026-03-07

## Context

This audit reviews the agentic-sdlc-blueprint repository — a documentation repo with 8 core design docs, a GitHub-native implementation guide, and a reference implementation for building an end-to-end agentic SDLC with Claude Code. The audit covers 8 dimensions: technical accuracy, MCP accuracy, GitHub Actions accuracy, internal consistency, cross-reference integrity, completeness, reference implementation quality, and real-world viability.

**Methodology:** Three parallel exploration agents read all 30+ files, followed by a Claude Code feature verification agent that checked every CLI flag and feature reference against official documentation. Findings from the exploration agents were then reconciled against verified facts — several initially-flagged issues were reclassified as false positives after verification confirmed the features exist.

---

## Dimension 1: Technical Accuracy (Claude Code Features)

### Verified Features (These ARE Real)

The following features referenced throughout the docs were confirmed as real Claude Code features:

- `claude -p` (headless/print mode) — correct
- `--model` flag with aliases (`opus`, `sonnet`) — correct
- `--output-format json` (values: `text`, `json`, `stream-json`) — correct
- `--allowedTools` with patterns like `"Bash(npm run *)"` — correct
- `--permission-mode` (but see Finding 1 below) — partially correct
- `--max-turns` (print mode only) — correct
- `--append-system-prompt` — correct (4 variants exist)
- `--dangerously-skip-permissions` — correct
- PreToolUse / PostToolUse hooks — correct
- `.mcp.json` with `mcpServers` key — correct
- `anthropics/claude-code-action@v1` — correct (GA version)
- `.claude/agents/` with YAML frontmatter — correct
- `.claude/commands/` slash commands — correct
- `.claude/settings.json` — correct
- Agent SDK `total_cost_usd` on responses — correct
- `CLAUDE_CODE_ENABLE_TELEMETRY` env var — correct

### Finding 1: Permission Mode `full` Does Not Exist

- **Severity:** Major
- **Files:** `blueprint/02-agent-pipeline.md:454`, `blueprint/06-security-model.md:92`
- **Claim:** Three permission modes: `plan`, `acceptEdits`, `full`
- **Reality:** Valid modes are `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan`. There is no `full` mode.
- **Fix:** Replace `full` with the actual equivalent. Likely `bypassPermissions` (skips all checks) or `dontAsk` (auto-deny prompts). Update the permission mode table in both files. Also update the agent definition format spec at `blueprint/02-agent-pipeline.md:444`.

### Finding 2: `ccusage` Tool Does Not Exist

- **Severity:** Major
- **File:** `blueprint/08-monitoring-scaling.md:76-77`
- **Claim:** `npx ccusage@latest` provides per-developer cost reports
- **Reality:** No tool called `ccusage` exists. The real equivalent is the `/cost` command in Claude Code interactive mode, or `--max-budget-usd` flag for budget enforcement.
- **Fix:** Replace the `ccusage` reference with `/cost` command documentation and mention the `--max-budget-usd` flag for programmatic budget limits.

### Finding 3: Agent SDK `canUseTool` Callback Does Not Exist

- **Severity:** Major
- **File:** `blueprint/03-orchestration-engine.md:221`
- **Claim:** Agent SDK provides `canUseTool` callbacks for custom permission logic
- **Reality:** The SDK does not have a `canUseTool` callback. The equivalent is using PreToolUse hooks for tool validation/blocking, or the `permissionMode` option on SDK sessions.
- **Fix:** Replace `canUseTool callbacks` with `PreToolUse hooks` in the Tier 2 Agent SDK capabilities list.

### Finding 4: Hook Input Mechanism Incorrect

- **Severity:** Major
- **Files:** `starter-kit/.claude/settings.json:9`, `blueprint/06-security-model.md:116-122`
- **Claim:** Hook commands access tool input via `$CLAUDE_TOOL_INPUT` environment variable: `echo $CLAUDE_TOOL_INPUT | jq -r '.command'`
- **Reality:** Hooks receive JSON on stdin, not via environment variables. The input includes `tool_name`, `tool_input`, and event-specific fields.
- **Fix:** Update the hook command to read from stdin. Example: `jq -r '.tool_input.command' | grep -qE 'rm -rf|...'` (reading from stdin rather than env var). Update both the settings.json example and the blueprint/06 explanation.

---

## Dimension 2: MCP Server Accuracy

### Finding 5: Inconsistent Notion MCP Server Package Names

- **Severity:** Minor
- **File:** `blueprint/05-integration-layer.md:108` vs `blueprint/05-integration-layer.md:257`
- **Claim:** Line 108 says `makenotion/notion-mcp-server` (official), but the example .mcp.json at line 257 uses `@notionhq/notion-mcp-server`
- **Reality:** These are contradictory within the same document. The correct package name should be verified against npm. The `@notionhq` scoped name (line 257) is more likely correct as it matches Notion's npm org.
- **Fix:** Verify the correct npm package name and make it consistent. If `@notionhq/notion-mcp-server` is correct, update line 108 to match.

### Finding 6: Notion MCP Credential Format May Be Incorrect

- **Severity:** Minor
- **File:** `blueprint/05-integration-layer.md:258-260`
- **Claim:** Notion MCP server uses `OPENAPI_MCP_HEADERS` env var with JSON-encoded Authorization header
- **Reality:** This credential format depends on whether the Notion MCP server is an OpenAPI-based MCP server (which uses `OPENAPI_MCP_HEADERS`) or a native MCP server (which would use `NOTION_API_KEY` directly). The correct format depends on the actual server implementation.
- **Fix:** Verify against the actual Notion MCP server documentation and update accordingly.

### Finding 7: Some MCP Server Names Are Vague or Unverifiable

- **Severity:** Nit
- **File:** `blueprint/05-integration-layer.md:139-147`
- **Claims:** References to `Atlassian Rovo MCP (official)`, `Official Linear MCP`, `Official Asana MCP`, `@azure-devops/mcp (Microsoft)` without npm package names
- **Fix:** Where possible, provide exact npm package names or GitHub repo URLs. Where servers don't exist yet, mark as "Community" or "Planned".

### Finding 8: GitHub PM MCP URL May Be Incorrect

- **Severity:** Minor
- **File:** `blueprint/05-integration-layer.md:264-265`
- **Claim:** `"url": "https://api.githubcopilot.com/mcp/"` for GitHub PM tool
- **Reality:** This URL references GitHub Copilot's MCP endpoint, which is specific to GitHub Copilot integration and may not be accessible from standalone Claude Code. The reference `.mcp.json` in the repo correctly uses `@modelcontextprotocol/server-github` as an npx command instead.
- **Fix:** Use the stdio-based `@modelcontextprotocol/server-github` approach consistently, or clearly document when the HTTP endpoint is appropriate.

### Finding 9: Filesystem MCP Server Package Name

- **Severity:** Minor
- **File:** `blueprint/05-integration-layer.md:303`
- **Claim:** `@anthropic/filesystem-mcp-server`
- **Reality:** The actual package may be `@modelcontextprotocol/server-filesystem`. Verify against npm.
- **Fix:** Confirm the correct npm package name.

---

## Dimension 3: GitHub Actions Accuracy

### Finding 10: `claude-code-action` Inputs Need Verification

- **Severity:** Minor
- **File:** `implementations/github-native/04-ci-cd.md:73-107`
- **Claim:** Action inputs include `anthropic_api_key`, `allowed_tools`, `max_turns`, `prompt`
- **Reality:** `anthropics/claude-code-action@v1` is confirmed as a real action. However, the exact input names (`allowed_tools` vs `allowedTools`, `max_turns` vs `maxTurns`) should be verified against the action's `action.yml`.
- **Fix:** Check the actual action.yml at <https://github.com/anthropics/claude-code-action> for exact input names and update all workflow examples if needed.

### Finding 11: Full Pipeline Workflow Has Conditional Logic Issues

- **Severity:** Minor
- **File:** `implementations/github-native/04-ci-cd.md:437-439`
- **Claim:** `architect` job has condition `if: inputs.entry_point == 'full' || inputs.entry_point == 'design'` and `needs: [approve-product-docs]`
- **Issue:** When `entry_point == 'design'`, the `approve-product-docs` job is skipped (it has `if: inputs.entry_point == 'full'`), so the `architect` job would also be skipped because its dependency wasn't satisfied.
- **Fix:** The `architect` job needs separate conditional dependency handling. Either make the gate job always run, or use GitHub Actions `if: always()` pattern with conditional logic.

---

## Dimension 4: Internal Consistency

### Finding 12: All Terminology Is Consistent

- **Severity:** N/A (Pass)
- **Details:** All 8 consistency categories pass:
  - Agent names (Visionary, Architect, Planner, Builder, Tester, Reviewer) — capitalized consistently across 57+ occurrences
  - Tool names — abstract MCP format (`mcp__docs__*`, `mcp__pm__*`) used correctly in core docs
  - Model names — "Opus" and "Sonnet" capitalized consistently, no version numbers
  - Orchestration tiers, context tiers, security layers, entry points — all consistent
  - Permission modes (`plan`, `acceptEdits`) — lowercase consistently (except `full` which needs to be renamed per Finding 1)
  - Cost modes (`standard`, `economy`) — lowercase consistently
  - Document format — all 8 core docs follow the prescribed structure

---

## Dimension 5: Cross-Reference Integrity

### Finding 13: All Internal Links Are Valid

- **Severity:** N/A (Pass)
- **Details:** 47+ internal markdown links checked across all files. All resolve to existing files with correct relative paths. README doc map, Related Documents sections, and implementation guide sequence links all verified.

---

## Dimension 6: Completeness

### Finding 14: No Gaps Detected

- **Severity:** N/A (Pass)
- **Details:**
  - No TODO/TBD/placeholder markers found
  - All sections have substantive content
  - All architectural decisions include rationale
  - Implementation guide has complete 4-part structure for GitHub-native
  - Other backends (Notion+Linear, Confluence+Jira) correctly marked as "Planned" in the README
  - All 5 templates, 6 agents, 5 commands present

---

## Dimension 7: Reference Implementation Quality

### Finding 15: Economy Mode `model_for()` Bug

- **Severity:** Critical
- **File:** `starter-kit/scripts/sdlc-pipeline.sh:48-62`
- **Claim:** Economy mode should assign Sonnet to Visionary, Planner, Builder, Tester (cheap decomposition/implementation) and Opus to Architect, Reviewer (complex reasoning)
- **Actual behavior in script:**

  ```bash
  economy)
    case "$agent" in
      visionary|planner) echo "sonnet";;
      *) echo "opus";;  # builder, tester, architect, reviewer ALL get opus
    esac;;
  ```

- **Bug:** Builder and Tester get Opus in economy mode. Per `blueprint/02-agent-pipeline.md:399-406`, they should get Sonnet.
- **Impact:** Economy mode is MORE expensive than standard mode for builder/tester agents — the opposite of its purpose.
- **Fix:** Change economy case to:

  ```bash
  economy)
    case "$agent" in
      architect|reviewer) echo "opus";;
      *) echo "sonnet";;
    esac;;
  ```

### Finding 16: `.mcp.json` Missing Doc Tool Server

- **Severity:** Critical
- **File:** `starter-kit/.mcp.json:1-11`
- **Issue:** Only configures GitHub MCP server. No doc management MCP server is configured.
- **Impact:** All agent tool calls to `mcp__docs__*` tools (create_page, update_page, search, get_page) will fail with "tool not found". The Visionary, Architect, Planner, and Reviewer agents all depend on doc tools.
- **Fix:** Add a doc tool MCP server entry. For a minimal reference, add a Notion or filesystem-based doc server. Example:

  ```json
  "docs": {
    "command": "npx",
    "args": ["-y", "@notionhq/notion-mcp-server"],
    "env": { "NOTION_API_KEY": "${NOTION_API_KEY}" }
  }
  ```

  Or for a zero-dependency setup, use the filesystem MCP server pointing to `./docs`.

### Finding 17: `starter-kit/CLAUDE.md` Missing Required Docs Section

- **Severity:** Major
- **File:** `starter-kit/CLAUDE.md`
- **Issue:** The template CLAUDE.md is missing the `## Docs` section that `blueprint/08-monitoring-scaling.md:190` lists as required ("Document tool workspace and organization").
- **Impact:** Agents won't know where to write documents. The Visionary agent specifically needs to know the doc workspace name and organizational structure.
- **Fix:** Add a `## Docs` section matching the example in `blueprint/08-monitoring-scaling.md:222-224`:

  ```markdown
  ## Docs
  - Notion workspace "MyApp Product"
  - PRFAQs/PRDs in "Product Requirements", HLD/LLD in "Technical Design", ADRs in "Architecture Decisions"
  ```

### Finding 18: DAG Execution Doesn't Halt on Task Failure

- **Severity:** Major
- **File:** `starter-kit/scripts/sdlc-pipeline.sh:200-214`
- **Issue:** The wave loop adds all task IDs to `completed` after `wait`, regardless of whether individual tasks failed:

  ```bash
  wait
  completed+=($ready)  # Adds ALL tasks, even failed ones
  ```

- **Impact:** Downstream tasks execute even when their dependencies failed. This violates the DAG contract — a task should only run when ALL its dependencies succeeded.
- **Fix:** Track exit codes per task. Only add successfully completed tasks to the `completed` array. Halt the pipeline if a required task fails.

### Finding 19: Concurrent State Write Race Conditions

- **Severity:** Major
- **File:** `starter-kit/scripts/sdlc-pipeline.sh:206-214`
- **Issue:** Multiple parallel agents in a wave may write to shared state files (`.claude/context/tasks/`, `.claude/context/runs/`) simultaneously. No file locking or atomic write mechanism exists.
- **Fix:** Use per-task output files and merge after `wait`, or use `flock` for file locking.

### Finding 20: `run_checkpoint()` Blocks Non-Interactive Shells

- **Severity:** Minor
- **File:** `starter-kit/scripts/sdlc-pipeline.sh:108`
- **Issue:** `read -p` blocks indefinitely in non-interactive contexts (cron, GitHub Actions).
- **Mitigating factor:** The `--autonomy autonomous` flag skips checkpoints. But the script doesn't validate that non-interactive shells use autonomous mode.
- **Fix:** Add a check: if stdin is not a terminal and autonomy is supervised, either auto-abort or warn.

### Finding 21: Worktree Cleanup Incomplete on Failure

- **Severity:** Minor
- **File:** `starter-kit/scripts/cleanup-worktrees.sh`
- **Issue:** Only removes worktrees whose branches are merged to main. Failed tasks leave orphaned worktrees that accumulate over time.
- **Fix:** Add a `--force` flag (partially implemented) and document the cleanup strategy for failed runs.

---

## Dimension 8: Real-World Viability

### Finding 22: Inter-Agent State Flow Is Fragile But Workable

- **Severity:** Major
- **File:** `starter-kit/scripts/sdlc-pipeline.sh:139-164`
- **Issue:** Manifests from one agent are embedded as plaintext in the next agent's prompt:

  ```bash
  DOC_MANIFEST=$(claude -p "..." | jq -r '.result')
  TECH_MANIFEST=$(claude -p "... Read product docs: $DOC_MANIFEST. ..." | jq -r '.result')
  ```

- **Problems:**
  - Special characters in manifest JSON break bash string interpolation
  - Large manifests could approach prompt size limits
  - No schema validation between stages
  - If an agent returns malformed JSON, `jq -r '.result'` silently returns null
- **Fix:** Write manifests to files instead of embedding in prompts. Pass file paths to agents. Add `jq` validation after each stage.

### Finding 23: MCP Servers Cannot Be Restricted Per-Agent

- **Severity:** Minor
- **File:** `blueprint/05-integration-layer.md` (architectural assumption)
- **Issue:** `.mcp.json` is project-level configuration. All agents share the same MCP servers. The permission matrix in `blueprint/06-security-model.md:73-81` shows different MCP access per agent (e.g., Builder has no Doc MCP access), but this restriction relies entirely on `--allowedTools` filtering, not MCP configuration.
- **Mitigating factor:** `--allowedTools` does enforce tool restrictions in headless mode, so the design works as intended — it just relies on tool-level gating rather than server-level isolation.
- **Status:** Working as designed, but the docs should clarify this mechanism.

### Finding 24: Cost Estimates Lack Sources

- **Severity:** Minor
- **File:** `blueprint/08-monitoring-scaling.md:99-115`
- **Claims:** First-attempt success rate ~33%, productivity gain 10-30%, cost ~$1,000-1,500/mo
- **Issue:** Presented as "empirically observed performance characteristics of agentic SDLC pipelines based on production deployments" but no data sources, studies, or deployment details are cited.
- **Fix:** Either cite sources, reframe as projections/estimates, or add a disclaimer that these are rough benchmarks.

### Finding 25: Token Estimates in Pipeline Manifest Example Are Plausible

- **Severity:** N/A (Pass)
- **File:** `blueprint/03-orchestration-engine.md:315-337`
- **Details:** Example shows 245K input + 89K output tokens for a full pipeline run ($8.45 total). `implementations/github-native/04-ci-cd.md:646` estimates 200K-400K tokens for a full pipeline. These are plausible for a 6-agent pipeline with moderate codebase exploration.

### Finding 26: Worktree Isolation Is Sound for Filesystem

- **Severity:** N/A (Pass)
- **Details:** Git worktrees provide genuine filesystem isolation. The shared `.git` object store is safe for concurrent reads. The only risk is concurrent operations on shared config files (addressed in Finding 19).

---

## Summary by Severity

### Critical (2)

| # | Finding | File | Fix |
|---|---------|------|-----|
| 15 | Economy mode `model_for()` bug — builder/tester get Opus instead of Sonnet | `sdlc-pipeline.sh:48-62` | Swap the case logic |
| 16 | `.mcp.json` missing doc tool MCP server | `starter-kit/.mcp.json` | Add docs MCP server entry |

### Major (8)

| # | Finding | File | Fix |
|---|---------|------|-----|
| 1 | Permission mode `full` doesn't exist | `02-agent-pipeline.md:454`, `06-security-model.md:92` | Replace with `bypassPermissions` or `dontAsk` |
| 2 | `ccusage` tool doesn't exist | `08-monitoring-scaling.md:76-77` | Replace with `/cost` command |
| 3 | Agent SDK `canUseTool` doesn't exist | `03-orchestration-engine.md:221` | Replace with PreToolUse hooks |
| 4 | Hook commands use `$CLAUDE_TOOL_INPUT` env var (hooks receive stdin) | `settings.json:9`, `06-security-model.md:116-122` | Read from stdin instead |
| 17 | `starter-kit/CLAUDE.md` missing Docs section | `starter-kit/CLAUDE.md` | Add `## Docs` section |
| 18 | DAG doesn't halt on task failure | `sdlc-pipeline.sh:200-214` | Track per-task exit codes |
| 19 | Concurrent state write race conditions | `sdlc-pipeline.sh:206-214` | Per-task output files or flock |
| 22 | Inter-agent state flow fragile (plaintext embedding) | `sdlc-pipeline.sh:139-164` | Write manifests to files |

### Minor (8)

| # | Finding | File | Fix |
|---|---------|------|-----|
| 5 | Inconsistent Notion package names within same doc | `05-integration-layer.md:108 vs 257` | Verify and unify |
| 6 | Notion MCP credential format uncertain | `05-integration-layer.md:258-260` | Verify against server docs |
| 8 | GitHub PM MCP URL may be Copilot-specific | `05-integration-layer.md:264-265` | Use stdio server consistently |
| 9 | Filesystem MCP server package name uncertain | `05-integration-layer.md:303` | Verify npm package name |
| 10 | `claude-code-action` input names need verification | `04-ci-cd.md:73-107` | Check action.yml |
| 11 | Full pipeline workflow conditional dependency issue | `04-ci-cd.md:437-439` | Fix gate job conditions |
| 20 | `read -p` blocks non-interactive shells | `sdlc-pipeline.sh:108` | Detect non-interactive stdin |
| 21 | Worktree cleanup incomplete on failure | `cleanup-worktrees.sh` | Add forced cleanup path |

### Nit (2)

| # | Finding | File | Fix |
|---|---------|------|-----|
| 7 | Some MCP server names vague/unverifiable | `05-integration-layer.md:139-147` | Add npm packages or URLs |
| 24 | Cost estimates lack sources | `08-monitoring-scaling.md:99-115` | Cite sources or add disclaimer |

---

## Verification Plan

After implementing fixes:

1. **CLI flag verification:** Run `claude --help` and verify all referenced flags
2. **Hook testing:** Create a test hook in settings.json, trigger it, confirm stdin format
3. **Permission mode testing:** Run `claude -p --permission-mode plan "test"` and verify behavior
4. **Script dry run:** Run `bash -n starter-kit/scripts/sdlc-pipeline.sh` for syntax check
5. **Link verification:** Run a markdown link checker across all docs
6. **MCP package verification:** Run `npm info <package>` for each referenced MCP server
7. **Action verification:** Check <https://github.com/anthropics/claude-code-action/blob/main/action.yml> for exact input names
8. **Economy mode unit test:** Verify `model_for builder` returns `sonnet` in economy mode after fix

---

## What's Working Well

The audit found significant strengths worth noting:

- **Internal consistency is exceptional.** Zero deviations across 8 terminology categories, 30+ files, 57+ agent name references.
- **Cross-references are 100% valid.** All 47+ internal links resolve correctly.
- **Document structure is disciplined.** All 8 core docs follow the prescribed format exactly.
- **No placeholder content.** Every section has substantive content with rationale.
- **Architecture is sound.** The 6-agent pipeline, DAG execution, retry with escalation, and checkpoint gates are well-designed patterns.
- **Most Claude Code features referenced are real.** After verification, the vast majority of CLI flags, hooks, agent definitions, and action references are accurate.
- **The design is implementable.** With the fixes identified above, the reference implementation would be functional.

---

---

# Open Discussion: Framework-Agnostic Blueprint

**Date:** 2026-03-07
**Status:** Deferred for future discussion

## Current State

The blueprint is fully coupled to Claude Code. Every layer uses Claude Code primitives:

- Agent definitions: `.claude/agents/` with Claude Code YAML frontmatter
- Orchestration: `claude -p` (all three tiers)
- Tool integration: Claude Code MCP protocol and `.mcp.json`
- Security: Claude Code hooks (`PreToolUse`), `--allowedTools`, `--permission-mode`
- CI/CD: `anthropics/claude-code-action@v1`
- Slash commands: `.claude/commands/`
- Settings: `.claude/settings.json`

## The Question

Should the blueprint be framework-agnostic, given the rapidly changing AI tooling landscape?

## Two Layers That Could Be Separated

1. **The methodology** (framework-agnostic) — 6-agent pipeline, DAG execution, checkpoint gates, retry with escalation, document-driven design, security principles, state contracts
2. **The implementation** (framework-specific) — `claude -p`, `.claude/agents/`, `--allowedTools`, hooks, `.mcp.json`, `claude-code-action`

Currently these are interleaved throughout the core docs (01-08).

## Three Approaches Considered

### Option A: Full Abstraction (Recommended during discussion)

Core docs (01-08) become purely methodology. ALL tool-specific details move to implementation guides. Add a "Claude Code" implementation guide alongside GitHub-native.

```
docs/
  01-architecture-overview.md    # methodology only
  02-agent-pipeline.md            # roles, contracts, model strategy
  03-orchestration-engine.md      # DAG, retry, checkpoints (abstract)
  ...
  implementations/
    github-native/                # GitHub Issues/Projects/Actions
    claude-code/                  # NEW: CLI, hooks, agents, MCP config
    cursor/                       # future
    aider/                        # future
starter-kit/                      # stays Claude Code-specific
```

### Option B: Light Abstraction

Core docs stay mostly as-is but replace Claude Code-specific syntax with generic pseudocode/patterns. Add callout boxes like "In Claude Code, this maps to --allowedTools".

### Option C: Keep Claude Code-Specific

Don't abstract. The blueprint's value is being a concrete, opinionated guide. Being specific makes it actionable. Just add a README note acknowledging the Claude Code focus.

## Decision

Deferred. Resume this discussion in a future session.
