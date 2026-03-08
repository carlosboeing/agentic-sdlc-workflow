#!/bin/bash
# cleanup-worktrees.sh — Remove worktrees for completed/merged tasks
set -euo pipefail

FORCE="${1:-}"

echo "Cleaning up worktrees..."

for wt in ../wt-*; do
  [ -d "$wt" ] || continue

  branch=$(git -C "$wt" branch --show-current 2>/dev/null || echo "unknown")

  # Check if branch is merged
  if git branch --merged main | grep -q "$branch" || [ "$FORCE" = "--force" ]; then
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
