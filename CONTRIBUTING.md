# Contributing to agentic-sdlc-workflow

Thank you for contributing. This repository is an experimental March 2026 implementation, repaired in November 2026; see the [ROADMAP](docs/ROADMAP.md) for what changes next. Bug reports and fixes that keep the first run safe are the most useful contributions.

## Code of conduct

This project adheres to the Contributor Covenant [Code of Conduct](CODE_OF_CONDUCT.md).

## Security disclosures

If you discover a security vulnerability, please do not open a public issue. Refer to [SECURITY.md](SECURITY.md).

## Workflow and branches

- Branch off `origin/main`: `git fetch && git checkout -b <type>/<topic> origin/main`.
- Keep changes surgical and focused on a single concern.
- Run the three offline suites before submitting a pull request. None of them needs Claude or GitHub access:

```bash
cd server && bun install --frozen-lockfile && bun test && cd ..
python3 -m pytest scripts/lib/test_compute_dispatches.py -q
./scripts/run-offline-tests.sh
```

- Never commit owner-specific configuration, credentials, local paths or the contents of `.agentic-workflow/`.
- Lifecycle documents under `docs/` start with YAML frontmatter at byte 0; the pre-push hook in `scripts/githooks/` checks it.

## Conventional Commits

`<type>(<scope>): <description>` - types `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`. Subject at most 72 chars, imperative mood. Body explains why.

## Pull requests

- Open a pull request against `main`.
- Follow the template in `.github/PULL_REQUEST_TEMPLATE.md`.
- All pull requests must pass the `required` CI check.
- Linear history (squash-merge).

## Continuous integration

Workflows are pinned to full commit SHAs with version comments. The `required` job is the stable aggregate. Do not replace a SHA with a tag.
