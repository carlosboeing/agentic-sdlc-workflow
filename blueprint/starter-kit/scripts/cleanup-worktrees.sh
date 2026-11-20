#!/bin/bash
# cleanup-worktrees.sh — Remove worktrees for completed/merged tasks
set -euo pipefail

FORCE="${1:-}"

echo "Cleaning up worktrees..."

for wt in ../wt-*; do
  [ -d "$wt" ] || continue

  branch=$(git -C "$wt" branch --show-current 2>/dev/null || true)

  # A detached HEAD has no branch name: never treat that as merged.
  if [ -z "$branch" ]; then
    echo "Keeping worktree: $wt (no branch checked out)"
    continue
  fi

  # Check if branch is merged (exact name match, not substring)
  if git branch --merged main --format='%(refname:short)' | grep -qxF -- "$branch" || [ "$FORCE" = "--force" ]; then
    echo "Removing worktree: $wt (branch: $branch — merged)"
    git worktree remove "$wt" 2>/dev/null || git worktree remove --force "$wt"
    git branch -d "$branch" 2>/dev/null || true
  else
    echo "Keeping worktree: $wt (branch: $branch — not merged)"
  fi
done

git worktree prune
echo "Done. Remaining worktrees:"
git worktree list
