# Starter kit (illustrative, March 2026)

This is an illustrative kit from March 2026 that accompanies the reference design. It is not maintained, it has not been run end to end, and it is not a supported way to run an agentic SDLC. Treat it as a sketch of the design's agent definitions, templates and orchestration idea. The implementation of record is the rest of this repository.

## What was fixed when it was imported

- `.claude/settings.json`: the sample PreToolUse hook read a non-existent environment variable and returned an approve decision for every Bash command, so it approved `rm -rf`. It now calls `.claude/hooks/guard-bash.sh`, which reads the hook JSON from stdin, denies a small list of destructive patterns (`rm -rf`, pushes to `main` or `master`, force pushes, `DROP TABLE`, `TRUNCATE TABLE`, `chmod 777`) and otherwise prints nothing so Claude Code's normal permission flow applies. It is a tripwire, not a security boundary. Checked against the [hooks reference](https://code.claude.com/docs/en/hooks) and a local test with sample inputs.
- `.claude/agents/*.md`: removed a stray `# .claude/agents/<name>.md` line above the YAML frontmatter in all six files. Frontmatter must start at byte 0 or Claude Code does not load the agent.
- `scripts/sdlc-pipeline.sh`: the Builder wave loop never terminated because completed tasks were selected again; completed tasks are now excluded and a failed task halts the run. The retry check read a `.success` field that the JSON output does not have, so every task ran four times; success is now a zero exit status without `is_error`.
- `scripts/cleanup-worktrees.sh`: branch matching is now exact, and a worktree with no branch (detached HEAD) is kept instead of being treated as merged.

Verification was limited to `bash -n`, `jq empty` and offline `jq` checks of the wave query and the success test. Nothing here called Claude.

## Known problems that remain

- `sdlc-pipeline.sh` still looks for task specs at `tasks/<task_id>.md` while specs are named like `001-billing-api.md`, writes specs uncommitted in the main checkout while builders run in worktrees branched from `main`, and never loads `.claude/agents/`. The Tester stage looks for the wrong worktree names. The run manifest is written once and never updated.
- Agents and the script reference `mcp__docs__*` and `mcp__pm__*` tools, but `.mcp.json` defines only a GitHub server, and its npm package is deprecated in favour of `github/github-mcp-server`.
- The Reviewer is granted `Bash(git *)`, which allows pushes and branch deletion.
- The Planner agent sets `permissionMode: plan`, which is read-only planning and blocks the writes the role needs.
- Model prices and flags reflect March 2026.

Cost note: a real run would spend model tokens. If you try it, set `--max-turns` and `--max-budget-usd` on every `claude -p` call first.

## Running it safely

The pipeline runs unattended Claude Code sessions with per-stage tool allowlists. Allowlists narrow what a stage can do; they are not an isolation boundary. Run the kit only inside a disposable container or VM with no host credentials, or with Claude Code's sandbox enabled and network egress restricted. The allowlists were tightened in November 2026: no `find` (it can execute and delete through `-exec` and `-delete`; stages use Glob and Grep instead), exact `npm run test` and `npm run lint` scripts, and read-only `git diff`, `git log` and `git show` for the reviewer.
