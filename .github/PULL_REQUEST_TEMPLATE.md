## Summary

<!-- Brief 1-3 sentence summary explaining what this PR changes and why. -->

## Changes

<!-- Bullet list of specific public changes. -->
- 

## Verification

<!-- Exact commands executed locally and their outcomes. -->
- `cd server && bun install --frozen-lockfile && bun test`
- `python3 -m pytest scripts/lib/test_compute_dispatches.py -q`
- `./scripts/run-offline-tests.sh`

## Governance Checklist

- [ ] Commit conforms to Conventional Commits
- [ ] Staged in one clean atomic commit
- [ ] No secrets, credentials, or private paths included
- [ ] Documentation updated where applicable
- [ ] `required` aggregate check is green
