#!/bin/bash
# setup-worktrees.sh — Create git worktrees for parallel task execution
set -euo pipefail

MANIFEST="${1:?Usage: setup-worktrees.sh <task-manifest.json>}"
BASE_BRANCH="${2:-main}"

echo "Setting up worktrees from manifest: $MANIFEST"

for task_id in $(jq -r '.dag | keys[]' "$MANIFEST"); do
  wt_dir="../wt-$task_id"
  branch="feat/$task_id"

  if [ -d "$wt_dir" ]; then
    echo "Worktree already exists: $wt_dir"
    continue
  fi

  echo "Creating worktree: $wt_dir (branch: $branch)"
  git worktree add "$wt_dir" -b "$branch" "$BASE_BRANCH"
done

echo "Worktrees created. List:"
git worktree list
