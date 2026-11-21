# Security Policy

## Supported versions

This repository is experimental and unversioned. Only the latest `main` receives fixes.

| Version | Supported |
|---------|-----------|
| `main`  | Yes       |
| Older commits | No  |

## Reporting a vulnerability

Please do not report security vulnerabilities through public GitHub issues, pull requests, or discussions.

Report privately through GitHub's private vulnerability reporting:

1. Go to the repository's **Security** tab.
2. Select **Report a vulnerability** under **Advisories**.
3. Provide a description, reproduction steps, affected version, and impact.

If you cannot use private reporting, contact [@carlosboeing](https://github.com/carlosboeing) via GitHub with the same detail. Include `agentic-sdlc-workflow security` in the subject, or open a draft advisory at https://github.com/carlosboeing/agentic-sdlc-workflow/security/advisories/new.

You can expect an initial acknowledgement within 7 days.

## Scope

In scope: anything in this repository that could let an agent run act beyond its documented boundaries, for example a gap in the `.claude/settings.json` allowlist or deny rules, a hook or guard that can be bypassed, a script that leaks credentials or mutates GitHub state it should not, or an injection path through work-item content.

Out of scope: the documented behavior of unattended runs. The allowlist is a filter, not an isolation boundary; run unattended sessions in a disposable container as the [running-safely guide](docs/5-guides/running-safely-guide.md) describes.
