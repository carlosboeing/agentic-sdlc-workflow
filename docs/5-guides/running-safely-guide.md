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
| 2. Tests | Server, telemetry and shell tests (`bun install` downloads packages once) | No | No | No | No |
| 3. Supervised run | Orchestrator in an interactive session | Yes | Yes | Yes | Yes |
| 4. Unattended run | Orchestrator with `--permission-mode dontAsk` | Yes | Yes | Yes | Yes |

## Prerequisites

| Tool | Used for | Check |
|---|---|---|
| `git` | Everything | `git --version` |
| `bash`, `jq`, `python3` (3.10+) | Scripts and telemetry | `jq --version && python3 --version` |
| `pytest` for that Python | Telemetry tests (Level 2) | `python3 -m pytest --version`; install with `python3 -m pip install pytest` |
| `bun` (1.1.39 or newer; 1.4.3 tested) | Server, MCP tools, frontend build | `bun --version` |
| Claude Code CLI | Levels 3 and 4 only | `claude --version` |
| `gh`, authenticated with the `repo` scope, plus `project` if you configure a board | Levels 3 and 4 only | `gh auth status` |

Level 1 needs only `python3`. Level 2 needs the first four rows.

## 1. Offline first run

Run the telemetry computation on its test fixture. It needs only `python3`, reads one JSON file, prints a JSON result, and does nothing else: no Claude, no GitHub, no board, no network.

```bash
python3 scripts/lib/compute-dispatches.py --from-state tests/fixtures/telemetry/state.json --gantt 2>/dev/null
```

Expected: one line of JSON whose `breakdown` field ends with `**Total (3 dispatches)** | **6m 30s** | **130K**`, plus a `gantt` field holding a Mermaid timeline. Cost shows as a dash because no pricing data is cached; the warnings about that go to stderr, which the command above hides. Drop `2>/dev/null` to see them.

## 2. Run the tests

The suites need no Claude session, no GitHub access and no running server. One step uses the network: `bun install` downloads the server's packages from the npm registry the first time.

```bash
# Server (SQLite, REST API, MCP tools, frontend components)
cd server && bun install --frozen-lockfile && bun test && cd ..

# Telemetry computation
python3 -m pytest scripts/lib/test_compute_dispatches.py -q

# Shell tests (scripts, PM adapters, config, retro scope guard)
./scripts/run-offline-tests.sh
```

CI (`.github/workflows/ci.yml`) runs these three suites, and also builds the frontend and runs the retro scope guard over the pushed commit range (it skips the guard when there is no base commit). To cover the same ground locally, also run `cd server && bun run build:frontend` and `./scripts/check-retro-scope.sh origin/main HEAD`.

### Build the frontend

The dashboard bundle in `server/frontend/dist/` is build output and is not committed. The server serves it from disk, so build it once after cloning and after frontend changes:

```bash
cd server && bun install && bun run build:frontend
```

## 3. Supervised interactive run

An interactive run keeps you in the loop: Claude Code asks before each action the allowlist does not cover.

1. Check the configuration. The committed `.claude/agentic-sdlc-config.json` ships with `pm.adapter` set to `null` and an empty board. Work items are then files under `.workflow/`, and no script writes GitHub issues, labels or board items; the run still pushes branches and opens pull requests in your repository. Board scripts print a one-line notice and skip. The `pm.adapter` values:

   | `pm.adapter` | Work items | Writes GitHub issues, labels, board |
   |---|---|---|
   | `null` (default) | Files under `.workflow/` | No |
   | `"server"` | The workflow server's SQLite database while it runs; the files when it does not | No; the server only reads issues from `github.repo` |
   | `"github"` | The files, then GitHub issues, comments, labels and sub-issue links; board status when the board fields are set | Yes |

   To mirror work items to your own GitHub issues and board, set `pm.adapter` to `"github"` and copy the field values you need from `.claude/agentic-sdlc-config.example.json`. Its `_fields` section explains each setting and how to read each ID with `gh`.
2. Only with `pm.adapter` set to `"server"`: start the workflow server in another terminal with `cd server && bun run start`.
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
- Nothing in the workflow caps spend. A budget check exists (`scripts/lib/cost-budget.sh`) but no workflow step calls it. Use your model provider's spend limits, and stop the session if it runs longer than you expect.
- **`--dangerously-skip-permissions` belongs only inside an isolated container** that holds nothing you care about. Never use it on a laptop, a shared machine or a clone with real credentials.

## What mutates GitHub state

Levels 3 and 4 act with your `gh` credentials. Whatever `pm.adapter` says, a run can:

- push integration, epic, story and docs branches to `origin`
- create, comment on and edit pull requests, including telemetry written into PR bodies
- in autonomous mode, merge design and plan PRs into the integration branch with `git merge` and a push (never into `main`), and close such a PR with a comment if GitHub still shows it open

Only with `pm.adapter` set to `"github"` can a run also:

- create, edit, close and comment on issues, and link sub-issues
- create labels (`scripts/setup-labels.sh`)
- add items to a Projects board and change their Status (only when the board fields are set)

With `"server"`, the workflow server reads issues from `github.repo` on first start and on a sync request, and never writes to GitHub. Deleting merged branches on `origin` happens only when you run `scripts/cleanup-post-merge.sh <backlog-number>` after a merge.

Levels 1 and 2 never touch GitHub. Deny rules in `.claude/settings.json` refuse `gh pr merge`, pushes to `main`, force pushes, remote branch deletion, the cleanup script, repository deletion and `gh` DELETE calls in every mode, and they apply before the folder is trusted. They match command text, not intent, so protect `main` with branch protection on your fork as well.

## What costs money

- Every agent run uses Claude API tokens, or subscription quota. Earlier full test runs cost roughly 3 to 11 USD in API-equivalent terms, and one large run about 50 USD.
- `scripts/fetch-pricing.sh` makes network calls to fetch current model prices. It is free but not offline.
- GitHub Actions minutes on your fork, if you enable CI.

Offline tests and the telemetry computation cost nothing.

## Clean up branches and worktrees

Runs leave branches, worktrees and a run state directory behind. Cleanup is a human step after the backlog PR merges; `.claude/settings.json` denies the script to agent sessions because it deletes branches on `origin`:

```bash
git checkout main && git pull
./scripts/cleanup-post-merge.sh                              # report only: lists leftovers, deletes nothing
./scripts/cleanup-post-merge.sh --dry-run <backlog-number>   # shows what removal would delete
./scripts/cleanup-post-merge.sh <backlog-number>             # removes that item's merged leftovers
```

The script refuses to run unless you are on `main`, and without a backlog number it only reports. With a number it deletes a workflow branch, locally or on `origin`, only when its tip is already in `origin/main` or in the head commit of the item's merged pull request (looked up with `gh`), no open pull request uses it, and no remaining worktree has it checked out. It removes a linked worktree only when that worktree has no modified or untracked files. Branches of other backlog items, unmerged branches and dirty worktrees are kept, and each kept item is listed with the reason. If `gh` cannot list open pull requests, nothing on `origin` is deleted. The run state directory is removed only when the merged pull request was found.
