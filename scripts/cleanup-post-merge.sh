#!/usr/bin/env bash
set -uo pipefail

# cleanup-post-merge.sh — Comprehensive post-merge cleanup for the agentic SDLC workflow.
#
# Removes stale branches (local + remote), worktrees, and state directories
# left behind by the current and previous runs. Safe to run multiple times.
#
# Usage: ./scripts/cleanup-post-merge.sh [<backlog-number>]
#
# If <backlog-number> is provided, also cleans up that run's state directory.
# Without it, performs a general sweep of all stale workflow artifacts.
#
# Exit codes:
#   0 — cleanup complete (even if nothing to clean)
#   1 — not on main branch (safety check)

# --- Safety check: must be on main ---
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
  echo "ERROR: Must be on main branch (currently on $CURRENT_BRANCH)."
  echo "Run: git checkout main && git pull"
  exit 1
fi

BACKLOG_NUMBER="${1:-}"
CLEANED=0

echo "=== Post-Merge Cleanup ==="
echo ""

# --- 1. Remove stale worktrees ---
STALE_WORKTREES=$(git worktree list --porcelain | grep "^worktree " | grep -v "$(pwd)$" | sed 's/^worktree //')
if [ -n "$STALE_WORKTREES" ]; then
  echo "Removing stale worktrees:"
  while IFS= read -r wt; do
    echo "  $wt"
    git worktree remove "$wt" --force 2>/dev/null && CLEANED=$((CLEANED + 1))
  done <<< "$STALE_WORKTREES"
  echo ""
fi

# --- 2. Delete local branches merged into main ---
MERGED_BRANCHES=$(git branch --merged main | grep -E "backlog/|epic/|e[0-9]|docs/" | sed 's/^[* ]*//')
if [ -n "$MERGED_BRANCHES" ]; then
  echo "Deleting merged local branches:"
  while IFS= read -r branch; do
    echo "  $branch"
    git branch -d "$branch" 2>/dev/null && CLEANED=$((CLEANED + 1))
  done <<< "$MERGED_BRANCHES"
  echo ""
fi

# --- 3. Delete orphaned workflow branches (unmerged but no remote) ---
WORKFLOW_BRANCHES=$(git branch | grep -E "backlog/|epic/|e[0-9]|docs/|worktree-" | sed 's/^[* ]*//')
if [ -n "$WORKFLOW_BRANCHES" ]; then
  echo "Checking for orphaned local branches:"
  while IFS= read -r branch; do
    # Check if remote tracking branch exists
    REMOTE_EXISTS=$(git ls-remote --heads origin "$branch" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$REMOTE_EXISTS" -eq 0 ]; then
      echo "  $branch (no remote — deleting)"
      git branch -D "$branch" 2>/dev/null && CLEANED=$((CLEANED + 1))
    fi
  done <<< "$WORKFLOW_BRANCHES"
  echo ""
fi

# --- 4. Delete stale remote workflow branches ---
REMOTE_WORKFLOW=$(git branch -r | grep -E "origin/(backlog/|epic/|e[0-9]|docs/)" | sed 's/^[* ]*//' | sed 's|origin/||')
if [ -n "$REMOTE_WORKFLOW" ]; then
  echo "Deleting stale remote workflow branches:"
  while IFS= read -r branch; do
    echo "  origin/$branch"
    git push origin --delete "$branch" 2>/dev/null && CLEANED=$((CLEANED + 1))
  done <<< "$REMOTE_WORKFLOW"
  echo ""
fi

# --- 5. Prune stale remote tracking refs ---
PRUNED=$(git remote prune origin 2>&1 | grep "pruned" | wc -l | tr -d ' ')
if [ "$PRUNED" -gt 0 ]; then
  echo "Pruned $PRUNED stale remote tracking refs."
  CLEANED=$((CLEANED + PRUNED))
  echo ""
fi

# --- 6. Clean up state directories ---
STATE_DIR=".agentic-workflow/runs"
if [ -d "$STATE_DIR" ]; then
  if [ -n "$BACKLOG_NUMBER" ]; then
    # Clean specific run
    if [ -d "$STATE_DIR/$BACKLOG_NUMBER" ]; then
      echo "Removing state directory: $STATE_DIR/$BACKLOG_NUMBER/"
      rm -rf "$STATE_DIR/$BACKLOG_NUMBER"
      CLEANED=$((CLEANED + 1))
    fi
  fi
  # Clean any empty or stale state dirs (all issues closed = safe to remove)
  for dir in "$STATE_DIR"/*/; do
    [ -d "$dir" ] || continue
    BACKLOG_NUM=$(basename "$dir")
    STATE=$(gh issue view "$BACKLOG_NUM" --json state -q '.state' 2>/dev/null || echo "UNKNOWN")
    if [ "$STATE" = "CLOSED" ]; then
      echo "Removing stale state directory: $dir (issue #$BACKLOG_NUM is closed)"
      rm -rf "$dir"
      CLEANED=$((CLEANED + 1))
    fi
  done
  echo ""
fi

# --- Summary ---
echo "=== Cleanup Complete ==="
echo "Items cleaned: $CLEANED"
echo ""

# Final state
echo "Local branches:"
git branch
echo ""
echo "Worktrees:"
git worktree list
