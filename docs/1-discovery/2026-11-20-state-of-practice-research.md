---
created: "2026-11-20"
updated: "2026-11-21"
title: "State of agentic software engineering, November 2026"
type: research
status: draft
authors:
  - "Carlos Boeing"
  - "claude-opus-5-5 (claude-code)"
scope: [research, agentic-engineering, currency]
related:
  - 2026-11-21-methodology-mapping-research.md
  - ../4-reviews/2026-11-20-public-release-assessment.md
  - ../architecture.md
---

# State of agentic software engineering, November 2026

> Research record, 2026-11-20. It surveys the platforms, standards, methods and evidence as of that date and maps them onto this repository and its reference design. The resulting judgement is the November 2026 revision in the [architecture](../architecture.md#november-2026-revision). Versions, prices and maturity labels change quickly; read them as dated.

## TLDR

- **Most mechanisms the March 2026 workflow built by hand now ship as platform features.** Claude Code provides worktree-isolated subagents, background and cloud sessions, resumable script-driven fan-out ("dynamic workflows"), experimental agent teams with a shared task list, scheduled cloud tasks, native OpenTelemetry cost and token metrics, and verified multi-agent code review [2][3][5][9][11][12][13][16]. Kiro runs spec tasks in dependency-graph waves, and Claude Code's `/batch` splits a change into 5 to 30 worktree-isolated subagents [2][51].
- **The model frontier and its prices have moved.** Current Anthropic models are Claude Fable 5.2, Opus 5.5, Sonnet 5.5 and Haiku 5.5. OpenAI has GPT-6.2 Astra and Sol, and Google has Gemini 4 Carbon, Neon and Hydrogen [19][20][32][38][40]. Opus 5.5 now costs 2x Sonnet 5.5, not 5x, and reasoning effort has become a second routing axis [3][20].
- **The standards have consolidated, mostly under the Linux Foundation's Agentic AI Foundation.** The MCP 2026-07-28 specification is a breaking, stateless revision [54]. AGENTS.md reports use in 60k+ projects [56]. Anthropic donated Agent Skills to the foundation on 2026-10-22 [57]. The OpenTelemetry GenAI agent conventions still carry "Development" status [59].
- **The methods have converged** on harness engineering (feedforward guides plus feedback sensors), spec-driven development (spec, plan, tasks), progressive context disclosure and short instruction files [35][60][65]. Thoughtworks Radar Vol. 35 puts these practices in "Caution": instruction bloat, AI-driven documentation sprawl, human-in-the-loop theater, and coding throughput as a productivity measure [60][61][63].
- **The 2026 outcome evidence is mixed.** Adoption is high and trust is conditional [68]. Verification and review are the recognized bottleneck [69][71]. METR could not get a reliable 2026 speedup estimate [67]. For agent pull requests, task type predicts acceptance better than which agent wrote them [73].
- **Multi-agent pays off only for parallelizable work that can be verified.** Centralized coordination contains errors better than independent agents [77]. Parallel writes need isolation. The test oracle has to be near-perfect [28]. Token cost grows linearly with the number of agents [4].
- **What this means for this repository and its reference design.** Reposition them from an "autonomous pipeline" to a verified, risk-tiered harness. Port the custom mechanics onto native primitives. Lead with the parts that remain a real synthesis: traceable lifecycle records with explicit authority and gates, measured verification, cross-model review, and retrospectives that change the harness.

## How to read this document

- All sources were accessed on 2026-11-20. Documentation pages without a publication date are marked "accessed".
- Evidence labels used in tables: **V** = verified against a primary source fetched for this research; **S** = secondary source only (news, blog, aggregator, or search snippet); **U** = unverified or conflicting across sources.
- Statements prefixed **Inference:** are the author's reading of the evidence, not a sourced fact.
- Figures in this document come from vendors and researchers. None was reproduced here.

## 1. Tools and platforms as of November 2026

### 1.1 Claude Code

Current version: 2.1.329, released 2026-11-19 [1].

| Capability | State in Nov 2026 | Ev. | Src |
|---|---|---|---|
| Subagents | Frontmatter fields include `tools`, `disallowedTools`, `model`, `effort` (low to max), `permissionMode`, `maxTurns`, `skills`, `mcpServers`, `hooks`, `memory` (user/project/local), `background`, `isolation: worktree`. Default limit is 20 concurrent. Subagents nest up to three levels. Fork mode (a subagent that inherits the conversation) is on by default in interactive sessions. | V | [3] |
| Agent teams | A lead session plus peer sessions with a shared task list (dependencies, file-locked claiming) and mailbox messaging. **Experimental, off by default** (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). Teammates are not worktree-isolated. No nested teams. Interactive sessions only. Token cost grows linearly. The docs recommend 3 to 5 teammates. | V | [4] |
| Dynamic workflows | Claude writes a JavaScript orchestration script using `agent()`, `parallel()`, `pipeline()` and optional JSON-schema outputs. The runtime runs it in the background, resumably. Defaults: up to 16 concurrent agents and 1,000 agents per run. Workflows can be saved to `.claude/workflows/` and shipped in plugins. Available in the CLI, `-p` mode and the Agent SDK. The `ultracode` effort setting lets Claude plan workflows automatically. | V | [5][6] |
| Agent view and background sessions | `claude agents` and `claude --bg` (research preview). Background sessions move into their own worktree before editing. `claude agents --json` provides scripting output. | V | [10] |
| Cloud sessions | `claude --cloud`, `--teleport`, PR auto-fix on CI failures and review comments. Anthropic-managed VMs or self-hosted environments. | V | [11] |
| Projects | One ongoing conversation that starts parallel cloud "threads". Public beta on Pro, Max and Ultra. | V | [2] |
| Scheduled tasks (formerly routines) | Cloud runs triggered by a schedule, an API call or GitHub events. Research preview. | V | [12] |
| Worktrees | `--worktree`, `.claude/worktrees/`, `.worktreeinclude` for gitignored files, `worktree.baseRef` (`fresh` or `head`), `WorktreeCreate`/`WorktreeRemove` hooks for other VCSs, enforced isolation checks on edits and git redirects, automatic sweeps. | V | [9] |
| Hooks | 33 events, including `SubagentStart/Stop`, `TaskCreated/Completed`, `TeammateIdle`, `PreCompact/PostCompact`, `WorktreeCreate/Remove`, `PermissionRequest/Denied`, `Elicitation`, `PreModelSwitch`. Five handler types: `command`, `http`, `mcp_tool`, `prompt`, `agent` (experimental). `onFailure: "block"` makes a failing hook block the action. | V | [7] |
| Skills | Follow the Agent Skills format with progressive disclosure: only name and description stay in context. `context: fork` runs a skill as a subagent. Commands are merged into skills. Bundled skills include `/code-review`, `/batch`, `/loop`, `/verify`, `/skill-doctor`. | V | [14] |
| Plugins | Package skills, agents, hooks, MCP servers and workflows. Loadable from the Agent SDK. | V | [5][17] |
| Permission modes | `default`/`manual`, `acceptEdits`, `plan`, `auto` (a classifier reviews actions), `dontAsk` (pre-approved tools only), `bypassPermissions` (containers and VMs only). Since v2.1.302, `claude -p` with no mode set starts in Manual and denies anything that needs approval. | V | [8] |
| Sandboxing | An OS-level Bash sandbox (Seatbelt on macOS, bubblewrap on Linux) works independently of auto mode and combines with it. Anthropic reports the sandbox cut permission prompts by 84%. | V | [8][25] |
| Memory | CLAUDE.md files (target under 200 lines per file), path-scoped `.claude/rules/`, auto memory (`MEMORY.md`, first 200 lines or 25 KB injected). AGENTS.md is read when no CLAUDE.md exists (v2.1.277+). `/doctor prompt-audit` finds stale or conflicting instructions. | V | [15] |
| Telemetry | Native OTel metrics: `cost.usage`, `token.usage`, `lines_of_code.count`, `pull_request.count`, `commit.count`, `code_edit_tool.decision`, `active_time.total`. Events include `api_request`, `tool_decision`, `subagent_completed`. Traces are in beta, with W3C `TRACEPARENT` propagation. GenAI attribute alignment is partial. | V | [16] |
| Code review | Local `/code-review` with an effort level. `/code-review ultra` (ultrareview) runs a cloud fleet of reviewers and reports only independently reproduced findings, at roughly $5 to $25 per review after free runs (research preview). | V | [13] |
| CI | `anthropics/claude-code-action` is still on the v1 line (v1.0.284). | V | [52] |

### 1.2 Claude Agent SDK and Managed Agents

| Product | State | Ev. | Src |
|---|---|---|---|
| Claude Agent SDK (Python, TypeScript) | Runs the Claude Code binary as a library: built-in tools, hooks, subagents, MCP, permissions, sessions (resume and fork), skills, plugins. The workflow tool is available in the SDK. | V | [17][5] |
| Claude Managed Agents (API) | Beta (`managed-agents-2026-04-01`). A hosted harness with cloud or self-hosted sandboxes; self-hosting of the whole service was added 2026-11-12. Webhooks, multi-agent orchestration and "outcomes" (rubric grading by a separate grader) since 2026-05-06. Scheduled deployments, memory stores, dynamic workflows beta (2026-10-09), session budgets. | V | [18][19][21] |
| Architecture note | Managed Agents separates the session (a durable event log), the harness (the loop) and the sandbox ("cattle"). A crashed harness resumes from the log. Credentials never enter the sandbox. | V | [24] |

### 1.3 Other vendors

| Product | State in Nov 2026 | Ev. | Src |
|---|---|---|---|
| OpenAI Codex (CLI, app, cloud) | CLI 0.171.0 (2026-11-20) adds GPT-6.2 Sol (default) and Astra, subagent transcripts and status, suspension and recovery of agent trees, and `codex exec --remote` for headless runs on an app server. Subagents are TOML files in `.codex/agents/`, run in parallel, and inherit the parent's sandbox and approvals. The docs advise against parallel write-heavy work. Skills live in `.agents/skills/`. Hooks exist (experimental per secondary sources). | V (hooks S) | [32][33] |
| Google Antigravity | Antigravity 2.0 (2026-05-19): a standalone desktop app, CLI and SDK with dynamic subagents, async tasks, JSON hooks, scheduled tasks and `/goal`. Gemini CLI was sunset for individual users on 2026-06-18 in favor of Antigravity CLI. Enterprise and API-key access continues. "Orchestrator" (2026-11-18) pairs Gemini 4 Neon as planner with Hydrogen as executor and hands work back to Neon when Hydrogen hits friction. | V (sunset date S) | [37][38][39] |
| Cursor | Cursor 3.0 (2026-04-02): an Agents Window for parallel agents (local, worktrees, cloud, SSH) and `/worktree`. Cloud agents (formerly background agents). Cursor Agent SDK (2026-10-20), with agents as code folders, evals, and GitHub, Slack and cron triggers. | V | [41][42] |
| GitHub Copilot and Agent HQ | Claude and Codex became available as coding agents on GitHub in public preview on 2026-02-04. Security validation for third-party agents reached GA on 2026-06-09. GitHub Universe (2026-10-28) announced the Copilot app, Copilot Projects (multi-repo agent work, public preview), GitHub Agentic Workflows GA (Markdown compiled to Actions; read-only by default, sandboxed behind a firewall, validated "safe outputs") and Copilot Fusion GA (model routing). Nov 2026 added GPT-6.2 and Gemini 4 Neon to Copilot, Copilot code review "adaptive effort", and Copilot activity streaming into Microsoft Agent 365. GA status of the third-party agents themselves: U. | V | [43][44][45][46][47][48] |
| Kiro (AWS) | Specs consist of requirements.md (or bugfix.md), design.md and tasks.md, with a Markdown review step per phase. Running all tasks builds a dependency graph and executes independent tasks in concurrent waves. Feature specs offer Requirements-First or Design-First variants. Available in the IDE, CLI, Web and Mobile. | V | [51] |
| Other notable entrants | Thoughtworks Radar Vol. 35 puts OpenAI Codex and OpenCode in "Adopt" and Pi in "Trial". Microsoft's MAI Code 2 models are available in Copilot. | V | [60][48] |

### 1.4 Frontier models

| Vendor | Current models (Nov 2026) | Ev. | Src |
|---|---|---|---|
| Anthropic | Fable 5.2 (`claude-fable-5-2`, 2026-11-09, $8/$40 per MTok); Opus 5.5 (2026-09-22, $4/$20; Anthropic's suggested starting point "for most workloads"); Sonnet 5.5 (2026-09-28, $2/$10); Haiku 5.5 (2026-10-07, from $0.10/$0.50). All have a 1M-token context window, 128K max output and adaptive thinking with effort control. Mythos 5.2 is limited to verified organizations. Sonnet 4.5 retires 2026-11-30. | V | [19][20] |
| OpenAI | GPT-6 Astra (September 2026). GPT-6 Sol and Luna (2026-09-22; API prices about half of GPT-5.6). GPT-6.2 Astra and Sol (2026-11-17/18, in Codex and Copilot). | V (Astra date S) | [32][34][48] |
| Google | Gemini 4 Carbon (announced 2026-10-28, GA 2026-11-10 per Google posts), Gemini 4 Neon (2026-11-18), Gemini 4 Hydrogen (2026-11-12, S), Gemini 4 Argon (S). | V/S | [38][40] |

**Inference:** Vendor names, prices and defaults changed several times between March and November 2026. A public repository should not hard-code model names or prices in prose. It should state them in one dated configuration table and link to vendor pages.

## 2. Standards

### 2.1 Model Context Protocol

The current specification is **2026-07-28**; the previous stable version was 2025-11-25 [53][54].

| Change since March 2026 | Detail | Ev. | Src |
|---|---|---|---|
| Stateless core | The `initialize`/`initialized` handshake and the `Mcp-Session-Id` header are removed. Version, client identity and capabilities travel in each request's `_meta`. A new optional `server/discover` call returns capabilities. Any server instance can serve any request. | V | [54] |
| Header routing | Streamable HTTP requests must include `Mcp-Method` and `Mcp-Name` headers. | V | [54] |
| Multi Round-Trip Requests | Replace held-open streams for server-initiated elicitation, sampling and roots. The server returns `resultType: "input_required"`. | V | [54] |
| Authorization | RFC 9207 issuer validation. Client ID Metadata Documents are the preferred registration path, and Dynamic Client Registration is deprecated. | V | [54] |
| Tasks | Moved from the experimental core to the `io.modelcontextprotocol/tasks` extension, with `tasks/get`, `tasks/update` and `subscriptions/listen`. | V | [54] |
| Extensions framework | Formal, with negotiated capabilities. Named extensions: Tasks, MCP Apps, Enterprise Managed Authorization, Skills over MCP. | V | [53][54] |
| Deprecations | Roots, Sampling, Logging and the legacy HTTP+SSE transport are deprecated, with a 12-month minimum window. | V | [54] |
| SDKs | Tier 1 SDKs (TypeScript, Python, Go, C#) support 2026-07-28. | V | [54] |
| Registry | The official MCP Registry is **still in preview** ("breaking changes or data resets may occur before general availability"). | V | [55] |

### 2.2 Instruction, skill and agent-interop formats

| Standard | State | Ev. | Src |
|---|---|---|---|
| AGENTS.md | Stewarded by the Agentic AI Foundation (Linux Foundation). Its site claims 60k+ open-source projects and lists support in Codex, Jules, Cursor, Copilot coding agent, Devin, Junie, Amp, Zed, Warp, VS Code and others. Claude Code reads AGENTS.md natively when no CLAUDE.md is present. | V | [56][15] |
| Agent Skills | `SKILL.md` folders with progressive disclosure. Contributed by Anthropic to the Agentic AI Foundation on 2026-10-22, alongside OpenAI's Open Responses, Hugging Face's OpenEnv and Alibaba's OpenSandbox. Anthropic's claim of 70+ integrating platforms is a vendor figure. Antigravity CLI carries over skills, hooks and subagents. | V (count S) | [57][14][39] |
| A2A (Agent2Agent) | Hosted by the Linux Foundation since 2025. Reports of a v1.0 release (2026-03) and a move into the Agentic AI Foundation (2026-08) could not be confirmed from primary sources. No coding-agent product in this survey exposes A2A as its main integration path. | U | [58] |
| OpenTelemetry GenAI | Agent span operations (`create_agent`, `invoke_agent`, `invoke_workflow`, `plan`, `execute_tool`) and attributes (`gen_ai.agent.id`, `gen_ai.agent.name`, `gen_ai.conversation.id`, `gen_ai.usage.*`) are all **Development** status, in a dedicated `semantic-conventions-genai` repository. | V | [59] |

**Inference:** MCP and Agent Skills are the interoperability layers that matter for a coding-agent SDLC. A2A is relevant only if the workflow exposes agents to other organizations' agents, which neither repository does.

## 3. Methods

### 3.1 Spec-driven development (SDD)

| Approach | What it is now | Ev. | Src |
|---|---|---|---|
| GitHub Spec Kit | Specify, plan, tasks, implement, converge. A "constitution" file holds project rules. Reports of a 1.0 release (2026-08-21) are secondary. Thoughtworks teams saw the constitution help on brownfield code but also saw instruction bloat, and moved reusable guidance into skills. | S (1.0), V (Radar text via search) | [64][66] |
| Kiro specs | requirements, design and tasks files, a review step per phase, and wave-parallel task execution. | V | [51] |
| OpenSpec | Changes are deltas against a persistent source-of-truth spec. Radar Vol. 35: Trial. | V | [60] |
| BMAD, Tessl | BMAD v6 ships 12+ role agents. Tessl moved from a spec registry toward a skills registry in January 2026. | S | search only |
| Anthropic Labs harness | A planner expands a prompt into a spec. Generator and evaluator negotiate a "sprint contract" (what done means, how it is verified) before each sprint. Handoffs go through files. With Opus 4.6 the sprint construct was removed and the evaluator moved to a single pass at the end. | V | [23] |

**Inference:** Spec, plan, tasks with durable Markdown artifacts is now mainstream. What still differs between tools is how specs stay current (deltas and convergence) and how "done" is verified.

### 3.2 Context engineering

| Practice | Field position | Ev. | Src |
|---|---|---|---|
| Progressive context disclosure | Radar Vol. 35: Adopt. Skills load only metadata until invoked. Path-scoped rules load only for matching files. | V | [60][14][15] |
| Short instruction files | Claude Code docs: under 200 lines per CLAUDE.md, because longer files "reduce adherence". OpenAI kept the agent instruction file short and pointed it at structured docs. Radar Caution: agent instruction bloat. | V/S | [15][35][60] |
| Sub-agent context isolation | Radar: Trial ("subagents for better context management"). Claude Code docs position subagents for side tasks that would flood the main context. | V | [60][2] |
| Compaction | Built into Claude Code (auto-compact window, `/compact`) and the API (compaction on demand, beta 2026-09-14). Anthropic's workflows post notes "each summarization step is lossy" and links compaction to goal drift. Radar Caution: naive context compression. | V | [11][19][6][60] |
| Memory | Anthropic (2026-11-06) describes a hierarchy: transcripts, then memory notes, then representations such as wikis, then a small injected layer. Its findings: incorrect notes persist across sessions; parallel agents writing one shared file overwrite each other, so give each agent its own file; rigid memory rules reduce gains on strong models; offline consolidation ("dreaming") corrects notes. | V | [26] |
| Just-in-time retrieval | Anthropic's 2025 guidance favors lightweight identifiers and tool-based retrieval over front-loading. In one corpus, wiki plus search beat search alone (61% vs 53%). | V | [31][26] |

### 3.3 Harness engineering

- Böckeler (2026-04-02): the harness is everything except the model. **Guides** (feedforward) steer before the agent acts. **Sensors** (feedback) let it self-correct. Computational sensors (tests, linters, types) are cheap and run on every change; inferential ones (LLM review) are slower and less deterministic. Human review is one more sensor, aimed "to where our input is most important". Behaviour is the hardest category, and AI-generated tests are "not yet good enough" [65].
- OpenAI (2026-02-11): about a million lines in five months with no hand-written source. Engineers designed the environment: app bootable per worktree, Chrome DevTools access for the agent, structural tests enforcing layering, docs as the system of record [35][36].
- Thoughtworks Radar Vol. 35 makes harness engineering a theme. Trial: self-improving harness, feedback flywheel, risk-tiered human oversight, unattended overnight agentic builds. Assess: harness quality evaluation, enterprise harness. "The harness is a living asset that requires ongoing ownership" [60].
- Anthropic: every harness component encodes an assumption about what the model cannot do. Re-test the components whenever a new model ships [23].

### 3.4 Evaluation and verification of coding agents

| Finding | Ev. | Src |
|---|---|---|
| Use code-based graders first, model-based graders calibrated against humans, and humans to calibrate. Measure pass^k (all k trials succeed) when consistency matters. Read transcripts before trusting scores. A 0% pass rate usually means a broken task. Keep each trial's environment clean, because leftover git history can leak answers. | V | [30] |
| Infrastructure configuration alone moved Terminal-Bench 2.0 scores by 6 points. Be skeptical of leaderboard gaps under about 3 points unless configurations match. | V | [29] |
| The C compiler project (16 parallel agents, about $20k): "the task verifier is nearly perfect, otherwise Claude will solve the wrong problem." Late regressions needed CI enforcement. | V | [28] |
| Plain TDD-procedure prompting raised regressions to 9.94% (baseline 6.08%). Giving the agent targeted test-impact context cut regressions to 1.82%. | V | [80] |
| Across 5,000 SWE-bench Verified runs, prompting agents to write or skip tests changed resolved totals by 0 to 13 of 500, which is not significant. Agent-written tests contained more print statements than assertions. | V | [81] |
| Failure modes that dynamic workflows target: agentic laziness (stopping early), self-preferential bias, goal drift. Patterns: adversarial verification per output, generate-and-filter, tournament, loop-until-done. "Most traditional coding tasks do not need a panel of 5 reviewers." | V | [6] |
| SWE-bench Verified is widely considered contaminated and saturated. SWE-bench Pro and other successors exist, but none is a settled standard. | S | [84] |

### 3.5 Cross-model review

- A controlled study (2026-10-01; 30 artifacts, 150 planted errors, 900 sessions) found that a top-tier cross-model reviewer did not differ significantly in F1 from a same-model reviewer in a fresh session. One same-model review plus one cross-model review caught more errors than two same-model reviews (56.7% vs 42.7%), but not significantly more than two strong cross-model reviews. Reviewer capability mattered at least as much as model independence [79].
- Self-preference bias in LLM judges is documented, but its size and direction vary by model. Several 2026 preprints exist, and only the study above was read in full [79].
- **Inference:** Cross-family review is a reasonable diversity measure for high-risk changes. The evidence supports "a second strong, independent reviewer helps". It does not support "a different vendor is required". Claims in the repositories should say this.

### 3.6 Human-in-the-loop checkpoint design

| Position | Ev. | Src |
|---|---|---|
| Radar Caution: "Human-in-the-loop theater is keeping a human in an agent's loop as an empty approval step rather than a real check." It becomes an "accountability sink". | V | [61] |
| Radar Trial: risk-tiered oversight. Match review depth to what a change could break. Send the riskiest and hardest-to-reverse changes to humans, and let agents auto-merge low-risk changes through CI. Use codebase zones and fallible LLM change classification to decide. | V | [62] |
| Users approved about 93% of Claude Code permission prompts, which motivated auto mode. The auto mode classifier blocks about 0.4% of benign commands and misses about 17% of overeager actions. | V | [25] |
| Developers trust AI output when they can verify it (Stack Overflow 2026). | V | [68] |

### 3.7 Security for coding agents

| Topic | Field position | Ev. | Src |
|---|---|---|---|
| Containment first | "The engineering question becomes how to cap the blast radius." Match isolation strength to the user's capacity for oversight. Every function reachable through an allowlisted domain is attack surface. | V | [25] |
| Permission defaults | `bypassPermissions` "offers no protection against prompt injection". Use it only in isolated containers or VMs. Use auto mode or a `dontAsk` allowlist for unattended runs. | V | [8] |
| Sandboxing | Radar Vol. 35: Adopt (agent sandboxing). | V | [60] |
| Multi-agent trust | Claude Code tells agents that a message came from another session. Relayed approvals are untrusted. Workflow-computed prompts do not count as user intent for the classifier. | V | [4][5] |
| Untrusted content | The quarantine pattern: reader agents with no privileges, and an actor that only sees their summaries. | V | [6] |
| Threat lists | OWASP Top 10 for Agentic Applications (ASI01 goal hijack, ASI02 tool misuse). Exact text not verified. | S | [82] |
| Supply chain | 2026 CVEs and research on MCP launch paths, malicious MCP servers and malicious skills. Individual CVE IDs not verified against NVD. | S/U | [83] |
| Platform controls | GitHub Agentic Workflows: read-only by default, firewall, safe-outputs validation, threat-detection job. GitHub security validation applies to third-party agents. | V | [46][44] |

## 4. Evidence about outcomes (2026)

| Study | Finding | Caveat | Ev. | Src |
|---|---|---|---|---|
| METR uplift follow-up (2026-02-24) | 57 developers, 800+ tasks. Estimates ranged from -18% (CI -38% to +9%) to -4% (CI -15% to +9%) change in task time. METR calls the estimate "a bad proxy" because developers refused to work without AI and withheld tasks. | METR is redesigning the study. Treat as "measurement is now hard", not as a speedup figure. | V | [67] |
| DORA "Balancing AI tensions" (2026-03-10) | "The time saved in creation is frequently re-allocated to auditing and verification." Review shifts load onto reviewers. Risk of skill degradation. 30% report little or no trust in AI code. | Qualitative analysis of 1,110 Google engineer responses, plus the 2025 survey. | V | [69] |
| DORA ROI report 2026.01 (InfoQ 2026-05-11) | AI as amplifier. A J-curve with an early dip. A "verification tax" and an "instability tax". Advises against headcount cuts. | ROI figures are illustrative, not measured. | V (via InfoQ) | [71] |
| DORA on tokenmaxxing (2026-06-02) | Token leaderboards are a vanity metric. Measure cost per accepted change, rework rate and DORA outcomes. "Company-wide aggregates are meaningless, and individual scores are harmful." | Opinion piece with cited examples. | V | [70] |
| Stack Overflow survey (2026-10-06) | 30,000+ respondents. 73% of AI coding tool users use them daily. 66% of AI users work in coding agents; Claude Code (66%) and Copilot (59%) lead. 93% need source attribution to trust output. Only 20% use AI for production operations. 27% of organizations route work across models. | Self-reported. | V | [68] |
| Pinna et al., MSR '26 | 7,156 agent PRs. Acceptance by agent ranges 61.6% to 77.9%. Task type spread (chore 84% vs perf 55%) is larger than the agent spread. No agent is best across all task types. | Observational. Acceptance is a weak proxy for quality. Small Claude Code sample. | V | [73] |
| GitHub Octoverse 2026 (2026-10-28) | Reported: agents started more than 40% of PRs in September 2026 (17% in March), and about 90% of agent-started PRs merged within two weeks. | Figures come from secondary coverage; the primary article could not be fetched. "Agent-started" does not mean "AI-written". | S | [74][75] |
| Faros AI | 2025: high-AI teams merged 98% more PRs while review time rose 91%. Reported 2026 figures are larger but disagree between secondary sources. | Vendor telemetry. 2026 report not read. | S/U | [76] |
| Anthropic source control (2026-10-13) | Merged changes per day at Anthropic rose from about 2,500 (May 2026) to more than 30,000 (September). Merge queues stopped making sense, and Anthropic invested in post-merge and pre-deploy testing instead. Engineers' role was often "to tell Claude 'no.'" | Single organization at the frontier. | V | [27] |

**Synthesis**

- **Review bottleneck.** DORA, Thoughtworks, Faros (S) and Anthropic all point to review and verification as the limiting step once generation is cheap [27][60][69][76]. The blueprint's March 2026 statement that "the bottleneck shifts to reviewing diffs" still holds, and the field now treats it as the central design problem.
- **Verification cost.** It shows up as the verification tax, the instability tax, extra rework and larger PRs [69][71]. Remedies the field converges on: small batches, deterministic sensors, risk-tiered review, and post-merge or pre-deploy testing [27][62][65][71].
- **Where agents help.** Chore, docs, CI and test tasks have the highest acceptance [73]. So do well-specified tasks with a strong oracle [28] and greenfield work (Stanford figures cited by DORA: 35 to 40% gain on simple greenfield tasks versus 10% or less on complex legacy code, S via [71]).
- **Where agents hurt.** Performance and bug-fix PRs have the lowest acceptance [73]. Delivery instability rises with AI adoption [69]. Unverified tests can mislead [80][81]. Skills can erode when engineers stop working through hard problems themselves [69].

## 5. Multi-agent orchestration

| Topic | What vendors and practitioners now say | Ev. | Src |
|---|---|---|---|
| When it is worth it | Claude Code: agent teams suit research, review, independent modules and competing debugging hypotheses. Single sessions or subagents are better for sequential work, same-file edits or many dependencies. Anthropic's workflows post: "Parallelism and specialization have to earn their coordination cost." Codex: parallel agents for read-heavy work, caution for parallel writes. Radar: Thoughtworkers "are mostly running multiple sessions under more direct control." | V | [4][6][33][60] |
| Topology | Across 180 configurations, centralized orchestration contained error amplification (4.4x) far better than independent agents (17.2x) and improved parallelizable tasks by about 80.8%. | V (abstract and project page) | [77] |
| Failure taxonomy | MAST: 14 failure modes in three groups (specification or system design, inter-agent misalignment, task verification). Multi-agent gains over a single agent are often minimal. | V (abstract) | [78] |
| Who holds the plan | Moving the plan into a script (dynamic workflows) keeps intermediate results out of the model's context, allows resume, and makes the orchestration repeatable. Agent teams leave coordination to a lead model turn by turn. | V | [5] |
| Isolation | Worktrees are the standard isolation for parallel writers in Claude Code, Cursor, Codex app and Kiro. Agent teams do not isolate, so partition files instead. | V | [4][9][41][32] |
| Reported failure modes | Agents converging on the same bug and overwriting each other; frequent merge conflicts; late regressions [28]. Teammates failing to mark tasks done, which blocks dependents; the lead stopping early [4]. Overwrites in shared memory files [26]. Agentic laziness and goal drift [6]. | V | [4][6][26][28] |
| Cost | Teams and workflows use "significantly more tokens". Example runs: 14 agents and 482k tokens for a change review; 22 agents and 1.1M tokens for deep research. | V | [4][6] |
| Model pairing | Planner and executor pairing (Antigravity Orchestrator), cascade and critique (Copilot Fusion), per-stage models in Claude Code workflows. | V | [38][47][5] |

**Inference:** The field's recommendation for software delivery is: one orchestrating context, or one script, that holds the plan; isolated workers for parallel, verifiable units; independent verifiers; and a human who steers the harness, not every step. That matches the March 2026 workflow's architecture. The workflow's hand-built mechanics are what is now redundant.

## 6. Telemetry and metrics for agentic SDLCs

| What is measured in practice | Notes | Ev. | Src |
|---|---|---|---|
| Cost and tokens per session, model and query source | Claude Code exports these natively, including cache read and creation tokens. The Codex and Copilot ecosystems export activity to enterprise tools (for example Agent 365). | V | [16][48] |
| Tool decisions (accept or reject, source) | `claude_code.code_edit_tool.decision` and the `tool_decision` event. A proxy for approval friction. | V | [16] |
| Lines changed, commits, PRs | Native counters. Radar and DORA warn against using them as productivity targets. | V | [16][63][70] |
| First-pass acceptance rate | Suggested by Radar Vol. 34/35 as a leading indicator that exposes rework. | V | [63] |
| Rework | DORA's fifth metric, deployment rework rate; DORA also suggests code rework rate and cost per accepted change. | V | [70][72] |
| Agent run structure | OTel GenAI agent spans (`invoke_agent`, `execute_tool`), still in Development. Claude Code traces are in beta. | V | [59][16] |
| Workflow-level | Per-agent tokens and phase progress in `/workflows`. "Large workflow" warning above 25 agents or 1.5M projected tokens. | V | [5] |
| Budgets and circuit breakers | Managed Agents session budgets. Shopify-style spend circuit breakers (cited by DORA). | V | [19][70] |

**Emerging standards.** OTel GenAI is the only cross-vendor schema, and it is pre-stable [59]. DORA has added rework rate [72]. There is no standard yet for "agent-initiated change" quality metrics. **Inference:** a public workflow should emit OTel with GenAI attribute names where they exist, keep custom names namespaced, and pin the convention version it follows.

## Mapping to the blueprint and workflow

| Concept | Field now | March 2026 approach status | Recommended update |
|---|---|---|---|
| Phases | Spec, plan, tasks, implement is mainstream (Spec Kit, Kiro, OpenSpec) [51][60][66]. Anthropic removes harness stages as models improve [23]. Radar Caution: documentation sprawl [60]. | revise | Keep the phase model, but present phases as responsibilities with a lighter route for small changes rather than a fixed six-agent chain. Fold the separate Tester into verification sensors. Cite convergence with Spec Kit and Kiro. Add a rule to re-test each phase's value when a new model ships. |
| Context engineering | Progressive disclosure (Adopt), short instruction files, subagent isolation (Trial), built-in compaction, memory hierarchy, just-in-time retrieval [14][15][26][31][60]. All current Claude models have 1M-token context [20]. | revise | Replace the token-budget tables (200K era) and the "Tier 3 vector RAG via MCP" end state with: skills and path-scoped rules, agentic search, subagent isolation, per-agent memory files. Cut the workflow's 68 KB CLAUDE.md to under 200 lines plus skills and rules. |
| Lifecycle docs | Durable spec, plan and task artifacts are standard [51][66]. OpenAI treats docs as the system of record, mechanically linted [36]. Radar Caution: AI-driven documentation sprawl [60]. | holds | Present durable lifecycle records as a known pattern. Add mechanical sensors (frontmatter and link lint, status flow). Define what stays evergreen and what freezes, and add supersession rules against sprawl. Consider OpenSpec-style deltas against a current-state spec. |
| Handoffs between phases | File-based handoffs and a "sprint contract" agreed before building [23]. JSON-schema agent results in workflows [5]. Rubric-graded outcomes [21]. | holds | Keep PR-reviewed handoff documents. Add a machine-checkable contract per task (acceptance criteria plus verification method agreed before the build starts) and schema-validated agent returns. |
| Inter-phase context | Durable session event log outside the harness [24]. Platform task lists, subagent `memory`, resumable workflow results [3][4][5]. Compaction is lossy, which causes goal drift [6]. | revise | Reframe the run manifests and the SQLite service as a durable event log, the same pattern as Managed Agents sessions. Keep only state the platform does not provide (cross-run, cross-repo, queryable). Pass original sources by stable reference at each handoff to limit drift. |
| Telemetry | Native Claude Code OTel for cost, tokens, LOC, PRs and tool decisions; traces in beta [16]. GenAI conventions are in Development [59]. | superseded | Drop token-based cost estimation and transcript parsing where native metrics exist. Export OTel with GenAI attribute names and a pinned convention version. Keep the Gantt timeline and per-phase tables as derived views. |
| Metrics | Outcome over output. Rework rate, first-pass acceptance, cost per accepted change. Avoid throughput and token targets [63][70][72]. | revise | Remove or source the blueprint's "~33% first-attempt success / 10-30% gain / $1,000-1,500 per month" table. Adopt: first-pass acceptance, fix-loop count, review findings per change, cost per merged change, lead time, change failure rate and rework. State the experiment scope on every number. |
| Verification | Guides plus sensors; computational before inferential [65]. A near-perfect oracle [28]. Naive TDD prompting raised regressions, while test-impact context helped [80]. Agent-written tests show no significant effect [81]. Mutation testing: Adopt [60]. Evals: pass^k, read transcripts, control infrastructure noise [29][30]. | revise | Replace "Builder implements via TDD" as the quality claim with layered verification: deterministic gates, an independent evaluator against the agreed contract, test-impact selection, mutation testing on critical paths. Evaluate the workflow on a fixed real-task set with pass^k. |
| Human checkpoints | Human-in-the-loop theater: Caution. Risk-tiered oversight: Trial [61][62]. About 93% of prompts are approved anyway [25]. | revise | Replace the binary supervised/autonomous mode with risk tiers: zones plus change classification, with human gates on irreversible actions (merge to protected branches, deploy, visibility, deletion). Remove "zero human intervention" from the README. |
| Orchestration | Dynamic workflows (a script holds the plan, resumable), agent teams (experimental), `/batch`, Kiro wave execution, Codex subagents, GitHub Agentic Workflows [2][4][5][33][46][51]. Centralized topology contains errors [77]. | superseded | Keep the DAG and wave algorithm as the design. Implement it on native primitives: a saved dynamic workflow or an Agent SDK script with `isolation: worktree` subagents. Replace "Tier 3 Actions" with GitHub Agentic Workflows or `claude-code-action@v1`. State that wave execution is now table stakes. |
| Worktrees | Native `--worktree`, `isolation: worktree`, `.worktreeinclude`, `worktree.baseRef`, enforced isolation checks, automatic sweeps [9]. Cursor, Codex and agent view have equivalents [10][32][41]. | superseded | Delete custom worktree creation and cleanup scripts. Use `isolation: worktree` (with `baseRef: head` for work stacked on in-progress branches). Keep the merge-ordering and conflict-resolution logic, which the platforms do not cover. |
| Review loops | Built-in `/code-review` effort levels and ultrareview with reproduced findings [13]. Copilot adaptive-effort review [48]. Fusion critique [47]. Adversarial verification [6]. A second strong reviewer adds detections; vendor independence alone is unproven [79]. | holds | Keep review tiers and bounded fix loops, with explicit convergence and stop criteria. Require reproduction or evidence for blocking findings. Route only high-risk tiers to a cross-family reviewer, and state the evidence level honestly. |
| Model routing | Prices compressed (Sonnet 5.5 $2/$10, Opus 5.5 $4/$20, Fable 5.2 $8/$40) [20]. Effort is a routing axis [3]. Vendor routers (Fusion cascade and critique, Antigravity Orchestrator) [38][47]. Radar Caution: blanket frontier-model usage [60]. | revise | Route on (model, effort) pairs. Re-baseline the difficulty-to-model table with current models. Remove the "~$6/M" and "~$30/M" figures and the Haiku history from prose. Prefer a cascade (cheaper first pass, escalate on failed verification), which the blueprint's retry escalation already describes. Record each routing decision in telemetry. |
| PM integration | Native sub-issues and issue types (GA 2025-04-09), dependencies (GA 2025-08-21) [49][50]. Agent HQ assigns issues to agents [43]. Agentic Workflows triage issues [46]. `gh` PR event streaming (2026-11) [48]. | revise | Map epics and stories to native sub-issues and blocked-by dependencies instead of label conventions. Make the GitHub board optional for the first run. Avoid confusion between GitHub Projects (boards), Copilot Projects and Claude Code Projects (agent workspaces) [2][45]. |
| Retrospectives | Self-improving harness and feedback flywheel: Trial [60]. The steering loop [65]. Memory consolidation ("dreaming") [19][26]. Instruction audits [15]. Risks: wrong notes persist, rigid rules hurt [26]. | holds | Keep the retro agent, but require evidence links and a before-and-after measurement for each proposed convention change. Have a human approve harness changes. Make "prune instructions" a standing retro output. |
| Security and permissions | Containment first; sandbox (Adopt); auto mode as one layer; `bypassPermissions` only in containers; `-p` defaults to Manual [8][25][60]. | revise | Make the default run sandbox plus auto mode (interactive) or a `dontAsk` allowlist (CI). Use `--dangerously-skip-permissions` only inside a container. Correct the blueprint's permission-mode table: `plan` is read-only analysis until the plan is approved, and no `full` mode exists. Add skill and MCP supply-chain controls, and treat allowlisted domains as capability grants. |
| Runtime service (Bun, SQLite, MCP) | MCP 2026-07-28 is stateless: no initialize handshake or sessions, header routing, tasks as an extension, DCR deprecated [54]. The Managed Agents session-log pattern [24]. | revise | Check the server against 2026-07-28 and the current TypeScript SDK, especially if it uses HTTP transport. Document the supported spec version. Position the service as a local durable event store and query surface, not as an orchestrator. |

## Table stakes versus differentiated

**Table stakes in November 2026 (do not present as novel):**

| Capability | Shipped by |
|---|---|
| Specialized subagents with isolated context and per-agent tools and models | Claude Code, Codex, Antigravity [3][33][37] |
| Parallel agents in git worktrees | Claude Code, Cursor 3, Codex app, agent view [9][10][32][41] |
| Dependency-aware wave execution of tasks | Kiro specs, Claude Code `/batch` and dynamic workflows [2][5][51] |
| Spec, plan and tasks as durable Markdown artifacts | Spec Kit, Kiro, OpenSpec [51][60][66] |
| Project instruction files and reusable skills | AGENTS.md, CLAUDE.md, Agent Skills [14][15][56][57] |
| Hooks as deterministic guardrails | Claude Code, Codex (S), Antigravity [7][37] |
| Background and cloud agents, scheduled agent runs, PR auto-fix loops | Claude Code, Cursor, Codex, Copilot [11][12][42][45] |
| Issue-to-PR agents on GitHub | Copilot coding agent and Agent HQ with Claude and Codex [43] |
| Automated multi-agent code review | Claude Code ultrareview, Copilot code review [13][48] |
| Model routing across tiers | Copilot Fusion, Antigravity Orchestrator [38][47] |
| Cost and token telemetry over OTel | Claude Code [16] |
| Plan approval before edits | Claude Code plan mode, Kiro phase review [8][51] |

**Still a differentiated engineering synthesis (Inference: no single vendor product found in this research combines these):**

| Differentiator | Why it still matters |
|---|---|
| End-to-end traceability from requirement to PR, with authority and human gates recorded in durable records | Platforms log sessions. They do not record which human authorized which phase transition or which obligations carried over between phases. |
| Risk-tiered checkpoint design tied to reversibility | The Radar puts this in Trial and names HITL theater as a Caution. Few published reference designs exist [61][62]. |
| Inter-phase obligation accounting (preserved, changed, excluded obligations across requirements, design, plan and code) | Directly addresses goal drift and lossy compaction [6]. |
| Measured verification layering (deterministic, evaluator, mutation, human) with stated evidence | The field has guidance [65] but little published end-to-end practice with numbers. |
| Cross-model review loop with structured findings and an honest evidence level | Built in neighbouring tools; evidence is mixed, so a calibrated design is useful [79]. |
| Retrospectives that change the harness with before-and-after measurement | Self-improving harness is Trial; most reports are anecdotal [60]. |
| Backend-agnostic PM abstraction (GitHub, Linear, Jira, Notion, local-first) | Vendors integrate their own trackers first. |
| Honest experiment history: failures, cost tables with scope, design evolution in git | Rare in public repositories, and it is what a practitioner reader asks for. |

## Open questions and unverified items

- GA status of Claude and Codex as third-party agents in GitHub Agent HQ: the docs still say public preview; only security validation is confirmed GA [44] (U).
- A2A version history and its move to the Agentic AI Foundation: secondary sources only [58] (U).
- Primary Octoverse 2026 article and Faros 2026 report: not read. Figures come from secondary coverage [75][76] (S).
- Spec Kit 1.0 release date and BMAD and Tessl details: secondary only (S).
- The OpenAI harness engineering post returned HTTP 403. Details come from search snippets and InfoQ [35][36] (S).
- Codex hooks maturity (S). Gemini 4 Hydrogen and Argon dates (S).

## Sources

1. Claude Code changelog (v2.1.329). https://code.claude.com/docs/en/changelog. 2026-11-19 (accessed 2026-11-20).
2. Run agents in parallel, Claude Code docs. https://code.claude.com/docs/en/agents. Accessed 2026-11-20.
3. Create custom subagents, Claude Code docs. https://code.claude.com/docs/en/sub-agents. Accessed 2026-11-20.
4. Orchestrate teams of Claude Code sessions (agent teams), Claude Code docs. https://code.claude.com/docs/en/agent-teams. Accessed 2026-11-20.
5. Orchestrate subagents at scale with dynamic workflows, Claude Code docs. https://code.claude.com/docs/en/workflows. Accessed 2026-11-20.
6. Shihipar and Bidasaria, "A harness for every task: dynamic workflows in Claude Code". https://claude.dev/blog/a-harness-for-every-task-dynamic-workflows-in-claude-code/. 2026-06-02.
7. Hooks reference, Claude Code docs. https://code.claude.com/docs/en/hooks. Accessed 2026-11-20.
8. Permission modes, Claude Code docs. https://code.claude.com/docs/en/permission-modes. Accessed 2026-11-20.
9. Run parallel sessions with worktrees, Claude Code docs. https://code.claude.com/docs/en/worktrees. Accessed 2026-11-20.
10. Manage agents with agent view, Claude Code docs. https://code.claude.com/docs/en/agent-view. Accessed 2026-11-20.
11. Use Claude Code in the cloud, Claude Code docs. https://code.claude.com/docs/en/claude-code-on-the-web. Accessed 2026-11-20.
12. Automate work with scheduled tasks (formerly routines), Claude Code docs. https://code.claude.com/docs/en/routines. Accessed 2026-11-20.
13. Find bugs with ultrareview, Claude Code docs. https://code.claude.com/docs/en/ultrareview. Accessed 2026-11-20.
14. Skills, Claude Code docs. https://code.claude.com/docs/en/skills. Accessed 2026-11-20.
15. How Claude remembers your project (memory), Claude Code docs. https://code.claude.com/docs/en/memory. Accessed 2026-11-20.
16. Monitoring usage (OpenTelemetry), Claude Code docs. https://code.claude.com/docs/en/monitoring-usage. Accessed 2026-11-20.
17. Agent SDK overview, Claude Code docs. https://code.claude.com/docs/en/agent-sdk/overview. Accessed 2026-11-20.
18. Claude Managed Agents overview, Claude Platform docs. https://platform.claude.com/docs/en/managed-agents/overview. Accessed 2026-11-20.
19. Claude Platform release notes. https://platform.claude.com/docs/en/release-notes/overview. Entries 2026-04-29 to 2026-11-17 (accessed 2026-11-20).
20. Models overview (models, IDs, prices), Claude Platform docs. https://platform.claude.com/docs/en/about-claude/models/overview. Accessed 2026-11-20.
21. Define outcomes, Claude Managed Agents docs, and "New in Claude Managed Agents: dreaming, outcomes, and multiagent orchestration". https://platform.claude.com/docs/en/managed-agents/define-outcomes and https://claude.com/blog/new-in-claude-managed-agents. May 2026 (sources give 6 and 19 May; read via search results).
22. Anthropic Engineering index. https://www.anthropic.com/engineering. Accessed 2026-11-20.
23. Rajasekaran, "Harness design for long-running application development", Anthropic Engineering. https://www.anthropic.com/engineering/harness-design-long-running-apps. 2026-03-24.
24. Martin, Cemaj and Cohen, "Scaling Managed Agents: Decoupling the brain from the hands", Anthropic Engineering. https://www.anthropic.com/engineering/managed-agents. 2026-04-08.
25. McGuinness et al., "How we contain Claude across products", Anthropic Engineering. https://www.anthropic.com/engineering/how-we-contain-claude. 2026-05-25.
26. Martin, "The components of agent memory", Anthropic Engineering. https://www.anthropic.com/engineering/components-of-agent-memory. 2026-11-06.
27. Nick G. et al., "Redesigning source control at Anthropic", Anthropic Engineering. https://www.anthropic.com/engineering/redesigning-source-control. 2026-10-13.
28. Carlini, "Building a C compiler with a team of parallel Claudes", Anthropic Engineering. https://www.anthropic.com/engineering/building-c-compiler. 2026-02-05.
29. Segato, "Quantifying infrastructure noise in agentic coding evals", Anthropic Engineering. https://www.anthropic.com/engineering/infrastructure-noise. 2026-02-05.
30. "Demystifying evals for AI agents", Anthropic Engineering. https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents. 2026-01-09.
31. "Effective context engineering for AI agents", Anthropic Engineering. https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents. 2025-09-29.
32. ChatGPT and Codex changelog (Codex CLI 0.171.0). https://learn.chatgpt.com/docs/changelog (redirected from https://developers.openai.com/codex/changelog). Entries to 2026-11-20.
33. Codex subagents docs. https://learn.chatgpt.com/docs/agent-configuration/subagents. Accessed 2026-11-20.
34. "OpenAI launches GPT-6 Sol and Luna", TechCrunch. https://techcrunch.com/2026/09/22/openai-launches-gpt-6-sol-and-luna/. 2026-09-22.
35. Lopopolo, "Harness engineering: leveraging Codex in an agent-first world", OpenAI. https://openai.com/index/harness-engineering/. 2026-02-11 (HTTP 403 on fetch; read via search results).
36. "OpenAI harness engineering with Codex", InfoQ. https://www.infoq.com/news/2026/02/openai-harness-engineering-codex. 2026-02-21.
37. "Introducing Google Antigravity 2.0". https://antigravity.google/blog/introducing-google-antigravity-2/. 2026-05-19.
38. "Gemini 4 Neon and Orchestrator now in Google Antigravity". https://antigravity.google/blog/gemini-4-neon-in-google-antigravity. 2026-11-18.
39. "An important update: Transitioning Gemini CLI to Antigravity CLI", Google Developers Blog. https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/. 2026-05-19 (read via search results).
40. "Gemini 4 Carbon: our next frontier model" and "Gemini 4 Carbon is now available", Google. https://blog.google/innovation-and-ai/models-and-research/gemini-models/introducing-gemini-4-carbon/ and https://blog.google/innovation-and-ai/models-and-research/gemini-models/gemini-4-carbon-now-available/. 2026-10-28 and 2026-11-10 (read via search results).
41. Cursor 3.0 changelog. https://cursor.com/changelog/3-0. 2026-04-02.
42. Cursor changelog. https://cursor.com/changelog. Entries 2026-10-13 to 2026-11-06.
43. "Claude and Codex are now available in public preview on GitHub", GitHub Changelog. https://github.blog/changelog/2026-02-04-claude-and-codex-are-now-available-in-public-preview-on-github/. 2026-02-04 (read via search results).
44. "Security validation for third-party coding agents", GitHub Changelog. https://github.blog/changelog/2026-06-09-security-validation-for-third-party-coding-agents. 2026-06-09 (read via search results).
45. "GitHub Copilot app, Universe releases", GitHub Changelog. https://github.blog/changelog/2026-10-28-github-copilot-app-universe-releases. 2026-10-28.
46. "GitHub Agentic Workflows generally available", GitHub Changelog. https://github.blog/changelog/2026-10-28-github-agentic-workflows-generally-available. 2026-10-28.
47. "Route and orchestrate models with GitHub Copilot Fusion", GitHub Changelog. https://github.blog/changelog/2026-10-28-route-and-orchestrate-models-with-github-copilot-fusion. 2026-10-28.
48. GitHub Changelog, November 2026 (page 1). https://github.blog/changelog/month/11-2026/. Entries 2026-11-17 to 2026-11-19 (accessed 2026-11-20).
49. "Evolving GitHub Issues and Projects" (sub-issues, issue types GA), GitHub Changelog. https://github.blog/changelog/2025-04-09-evolving-github-issues-and-projects/. 2025-04-09 (read via search results).
50. "Dependencies on issues", GitHub Changelog. https://github.blog/changelog/2025-08-21-dependencies-on-issues/. 2025-08-21 (read via search results).
51. Specs, Kiro docs. https://kiro.dev/docs/specs/. Updated 2026-11-12.
52. anthropics/claude-code-action releases. https://github.com/anthropics/claude-code-action/releases. Accessed 2026-11-20 (latest v1.0.284).
53. Model Context Protocol specification (latest, 2026-07-28). https://modelcontextprotocol.io/specification/latest. Accessed 2026-11-20.
54. "The 2026-07-28 Specification", MCP blog. https://blog.modelcontextprotocol.io/posts/2026-07-28/. 2026-07-28.
55. The MCP Registry (preview). https://modelcontextprotocol.io/registry/about. Accessed 2026-11-20.
56. AGENTS.md. https://agents.md/. Accessed 2026-11-20.
57. "Agentic AI Foundation Announces Four New Projects: Agent Skills, Open Responses, OpenEnv, and OpenSandbox", Linux Foundation. https://www.linuxfoundation.org/press/agentic-ai-foundation-announces-four-new-projects-agent-skills-open-responses-openenv-and-opensandbox. 2026-10-22 (read via search results).
58. Agent2Agent, Wikipedia (secondary). https://en.wikipedia.org/wiki/Agent2Agent. Accessed 2026-11-20 via search results.
59. GenAI agent spans, OpenTelemetry semantic-conventions-genai. https://github.com/open-telemetry/semantic-conventions-genai/blob/main/docs/gen-ai/gen-ai-agent-spans.md. Accessed 2026-11-20.
60. Thoughtworks Technology Radar Vol. 35. https://www.thoughtworks.com/radar. November 2026.
61. "Human-in-the-loop theater", Thoughtworks Radar. https://www.thoughtworks.com/radar/techniques/human-in-the-loop-theater. November 2026.
62. "Risk-tiered human oversight", Thoughtworks Radar. https://www.thoughtworks.com/radar/techniques/risk-tiered-human-oversight. November 2026.
63. "Coding throughput as a measure of productivity", Thoughtworks Radar. https://www.thoughtworks.com/radar/techniques/coding-throughput-as-a-measure-of-productivity. April and November 2026.
64. "GitHub Spec Kit", Thoughtworks Radar. https://www.thoughtworks.com/radar/languages-and-frameworks/github-spec-kit. 2026 (read via search results).
65. Böckeler, "Harness engineering for coding agent users", martinfowler.com. https://martinfowler.com/articles/harness-engineering.html. 2026-04-02.
66. github/spec-kit repository. https://github.com/github/spec-kit. Accessed 2026-11-20 via search results (1.0 release date secondary).
67. "We are Changing our Developer Productivity Experiment Design", METR. https://metr.org/blog/2026-02-24-uplift-update/. 2026-02-24.
68. "The results of the 2026 Developer Survey are here!", Stack Overflow. https://stackoverflow.blog/2026/10/06/the-results-of-the-2026-developer-survey-are-here/. 2026-10-06.
69. Baolin and Harvey, "Balancing AI tensions: Moving from AI adoption to effective SDLC use", DORA. https://dora.dev/insights/balancing-ai-tensions/. 2026-03-10.
70. Conaway, "Finding balance in the era of tokenmaxxing", DORA. https://dora.dev/insights/finding-balance-in-the-era-of-tokenmaxxing/. 2026-06-02.
71. Saunders, "New DORA Report Claims Strong Engineering Foundations Drive AI Return on Investment", InfoQ. https://www.infoq.com/news/2026/05/dora-roi-ai-assisted-dev-report/. 2026-05-11.
72. A history of DORA's software delivery metrics. https://dora.dev/guides/dora-metrics/history/. Accessed 2026-11-20 via search results.
73. Pinna, Gong, Williams and Sarro, "Comparing AI Coding Agents: A Task-Stratified Analysis of Pull Request Acceptance", MSR '26. https://arxiv.org/html/2602.08915v2. v2 2026-05-07.
74. Octoverse 2026, GitHub. https://octoverse.github.com/. 2026-10-28.
75. "GitHub Octoverse: Agents Started More Than 40% of September Pull Requests", Visual Studio Magazine. https://visualstudiomagazine.com/articles/2026/10/29/github-octoverse-agents-started-more-than-40-percent-of-september-pull-requests.aspx. 2026-10-29 (HTTP 403 on fetch; read via search results).
76. "The AI Productivity Paradox Report 2025", Faros AI. https://www.faros.ai/blog/ai-productivity-paradox-report-2025. 2025 (2026 figures secondary only).
77. Kim et al., "Towards a Science of Scaling Agent Systems". https://arxiv.org/abs/2512.08296. 2025-12-09 (v2 2025-12-17).
78. Cemri et al., "Why Do Multi-Agent LLM Systems Fail?" (MAST), NeurIPS 2025. https://arxiv.org/abs/2503.13657. 2025-03 (v3 2025-10).
79. Song, "When Does a Second Model Help? Cross-Model Review in LLM Verification". https://arxiv.org/abs/2610.01471. 2026-10-01 (v2 2026-10-06).
80. Alonso, Yovine and Braberman, "TDAD: Test-Driven Agentic Development". https://arxiv.org/abs/2603.17973. 2026-03-18.
81. Chen et al., "Rethinking the Value of Agent-Generated Tests for LLM-Based Software Engineering Agents". https://arxiv.org/abs/2602.07900. 2026-02-08 (v3 2026-11-09).
82. "OWASP Drops First AI Agent Risk List" (OWASP Top 10 for Agentic Applications), TechRepublic. https://www.techrepublic.com/article/news-owasp-ai-agent-risk-list/. Date not verified (read via search results).
83. "MCP Launch Paths as RCE: The opencode OAuth Flaw and Copilot CVE-2026-103572", Cloud Security Alliance research note. https://labs.cloudsecurityalliance.org/research/csa-research-note-mcp-launch-path-rce-opencode-copilot-20261/. 2026 (read via search results; CVE details not verified).
84. "AI Coding Benchmarks Explained: SWE-bench, LiveBench, and More", OpenHands. https://www.openhands.dev/blog/ai-coding-benchmarks-explained. Date not verified (read via search results).
