---
title: Running the Workflow Safely
type: guide
authors: ["Carlos Boeing", "claude-sonnet-5-5 (claude-code)"]
---

# Running the Workflow Safely

This guide takes a stranger from a fresh clone to a supervised run without touching anyone's GitHub board or spending money by accident. Start at the top and stop at the first level that meets your need.

| Level | What you run | Needs Claude | Needs GitHub | Costs money | Mutates GitHub |
|---|---|---|---|---|---|
| 1. Offline first run | Telemetry computation on a fixture | No | No | No | No |
| 2. Tests | Server, telemetry and shell tests | No | No | No | No |
| 3. Supervised run | Orchestrator in an interactive session | Yes | Yes | Yes | Yes |
| 4. Unattended run | Orchestrator with `--permission-mode dontAsk` | Yes | Yes | Yes | Yes |

## Prerequisites

| Tool | Used for | Check |
|---|---|---|
| `git` | Everything | `git --version` |
| `bash`, `jq`, `python3` (3.10+) | Scripts and telemetry | `jq --version && python3 --version` |
| `bun` (1.1.39 or newer; 1.4.3 tested) | Server, MCP tools, frontend build | `bun --version` |
| Claude Code CLI | Levels 3 and 4 only | `claude --version` |
| `gh`, authenticated with `repo` and `project` scopes | Levels 3 and 4 only | `gh auth status` |

Levels 1 and 2 need only the first three rows.

## 1. Offline first run

Run the telemetry computation on its test fixture. It reads one JSON file, prints a JSON result, and does nothing else: no Claude, no GitHub, no board, no network.

```bash
python3 scripts/lib/compute-dispatches.py --from-state tests/fixtures/telemetry/state.json --gantt 2>/dev/null
```

Expected: one line of JSON whose `breakdown` field ends with `**Total (3 dispatches)** | **6m 30s** | **130K**`, plus a `gantt` field holding a Mermaid timeline. Cost shows as a dash because no pricing data is cached; the warnings about that go to stderr, which the command above hides. Drop `2>/dev/null` to see them.

## 2. Run the tests

All three suites are offline.

```bash
# Server (SQLite, REST API, MCP tools, frontend components)
cd server && bun install --frozen-lockfile && bun test && cd ..

# Telemetry computation
python3 -m pytest scripts/lib/test_compute_dispatches.py -q

# Shell tests (scripts, PM adapters, config, retro scope guard)
./scripts/run-offline-tests.sh
```

CI runs the same three commands (`.github/workflows/ci.yml`), so a green local run predicts a green CI run.

### Build the frontend

The dashboard bundle in `server/frontend/dist/` is build output and is not committed. The server serves it from disk, so build it once after cloning and after frontend changes:

```bash
cd server && bun install && bun run build:frontend
```

## 3. Supervised interactive run

An interactive run keeps you in the loop: Claude Code asks before each action the allowlist does not cover.

1. Check the configuration. The committed `.claude/agentic-sdlc-config.json` ships with an empty board and `pm.adapter` set to `server`. With no board configured, board scripts print a one-line notice and skip. Work items live in the local workflow server, or in files under `.workflow/` when the server is not running. To use your own GitHub Projects board, copy the field values you need from `.claude/agentic-sdlc-config.example.json` into `.claude/agentic-sdlc-config.json`. The example explains how to read each ID with `gh`.
2. Optional: start the workflow server in another terminal with `cd server && bun run start`.
3. Use a repository you own. The orchestrator creates issues, branches and pull requests there.
4. Start the orchestrator and give it a small, low-risk backlog item:

   ```bash
   claude --agent orchestrator
   ```

5. Read each permission prompt. Prefer a throwaway repository for the first run.

## 4. Unattended run with `dontAsk`

> **The allowlist is not an isolation boundary.** The rules in `.claude/settings.json` filter which commands Claude Code may run without asking. They do not confine what an allowed command does. `bun`, `git` and the repository scripts can still read files, call the network and run arbitrary code if a prompt or a tool result steers them there. Run unattended sessions in a disposable clone inside a container, or inside the Claude Code sandbox, with credentials limited to a throwaway repository.

`--permission-mode dontAsk` auto-denies anything not matched by an `allow` rule, instead of prompting. That makes the project allowlist the whole policy for the run. Deny rules apply in every mode. (Behavior checked against the [permission modes](https://code.claude.com/docs/en/permission-modes) and [settings](https://code.claude.com/docs/en/settings) pages.)

Recommended setup:

```bash
# In a disposable container, in a fresh clone of a repository you can afford to lose
git clone <your-fork-url> work && cd work
cd server && bun install --frozen-lockfile && bun run build:frontend && cd ..

claude --agent orchestrator --permission-mode dontAsk -p "<your backlog prompt>"
```

Things to know:

- Allow rules in a committed `.claude/settings.json` apply only after the folder is trusted. Start `claude` interactively once in the clone and accept the trust prompt, or place the rules in `.claude/settings.local.json`.
- An action outside the allowlist is denied, not skipped silently. If the run stalls on a denied command, add a narrow rule for it in `.claude/settings.local.json` and rerun. Do not add `Bash(*)`.
- Writes to `.git`, `.claude` and similar protected paths are denied in this mode.
- Set `workflow.maxCostPerRun` in the config to cap spend per run.
- **`--dangerously-skip-permissions` belongs only inside an isolated container** that holds nothing you care about. Never use it on a laptop, a shared machine or a clone with real credentials.

## What mutates GitHub state

Levels 3 and 4 act with your `gh` credentials. A run can:

- create, edit, close and comment on issues, and link sub-issues
- create labels (`scripts/setup-labels.sh`)
- add items to a Projects board and change their Status (only when a board is configured)
- push branches, and delete remote branches (`git push origin --delete`, used by `scripts/cleanup-post-merge.sh`)
- create, merge, comment on and edit pull requests, including telemetry written into PR bodies

Levels 1 and 2 never do. Deny rules in `.claude/settings.json` block force pushes, repository deletion and `gh` DELETE calls even in unattended mode.

## What costs money

- Every agent run uses Claude API tokens, or subscription quota. Earlier full test runs cost roughly 3 to 11 USD in API-equivalent terms, and one large run about 50 USD.
- `scripts/fetch-pricing.sh` makes network calls to fetch current model prices. It is free but not offline.
- GitHub Actions minutes on your fork, if you enable CI.

Offline tests and the telemetry computation cost nothing.

## Clean up branches and worktrees

Runs leave branches, worktrees and state directories behind. After a pull request merges and you are on an up-to-date `main`:

```bash
git checkout main && git pull
./scripts/cleanup-post-merge.sh <backlog-number>     # omit the number for a general sweep
```

The script refuses to run unless you are on `main`. It removes stale local and remote workflow branches, worktrees, and the run's state directory, so it deletes remote branches on `origin`. Read `scripts/cleanup-post-merge.sh` first, and use a repository you own.

To list leftovers without deleting anything: `git worktree list` and `git branch --list 'backlog/*'`.
