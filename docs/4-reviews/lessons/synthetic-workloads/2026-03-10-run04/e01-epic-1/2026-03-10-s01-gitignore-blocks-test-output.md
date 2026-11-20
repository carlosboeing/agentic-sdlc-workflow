---
date: 2026-03-10
author: carlosboeing
agent: retro
story: "E01-S01"
tags: [builder, gitignore, staging, empty-commit, orchestrator]
severity: high
---

# .gitignore Silently Blocks test-output/ Staging

## What happened

The haiku builder for E01-S01 created a content file under `test-output/run4/` on disk and ran `git add` followed by `git commit`. However, `.gitignore` contains `test-output/` which silently excluded the file from staging. The result was two empty commits (`9e69336`, `6926671`) -- the commit messages described creating the file, but no files were staged. The reviewer caught this as a critical issue: "File never committed. The branch has zero diff against the epic branch."

A fix cycle was required: the builder was re-dispatched and used `git add -f` to force-stage the file past `.gitignore`, producing commit `5b0a76d`. The other two Wave 1 builders (E01-S02, E01-S03) either used `git add -f` proactively or did not encounter this issue.

## Root cause

The `.gitignore` file in the repo root contains the pattern `test-output/`, which excludes the entire directory from git tracking. Standard `git add` silently skips ignored files. The builder did not check whether the file was actually staged before committing.

## Prevention

- Builders working in `test-output/` (or any gitignored directory) MUST use `git add -f <path>` to force-add files past `.gitignore`.
- Alternatively, the orchestrator or plan should note when output directories are gitignored and include `git add -f` in the acceptance criteria or builder instructions.
- Builders should verify staging with `git status` or `git diff --cached` before committing to confirm files are actually staged.
