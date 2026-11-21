#!/usr/bin/env bash
set -uo pipefail

# cleanup-post-merge.sh — Remove the merged leftovers of one backlog item.
#
# A human runs this after squash-merging a backlog PR. Agents may not run it:
# .claude/settings.json denies it, because it deletes branches on origin.
#
# Usage:
#   ./scripts/cleanup-post-merge.sh                       report only, deletes nothing
#   ./scripts/cleanup-post-merge.sh --dry-run <backlog>   show what <backlog> would remove
#   ./scripts/cleanup-post-merge.sh <backlog>             remove <backlog>'s merged leftovers
#
# Without a backlog number the script only reports. Removal needs the number.
#
# A branch (local or on origin) is removed only when all of these hold:
#   - it is a workflow branch: backlog/<backlog>-*, epic/*, eNN-sNN/*, docs/*,
#     worktree-*. Other items' backlog/* integration branches are never
#     touched; their epic, story, docs and worktree branches can be removed
#     when the remaining conditions hold, because their work is merged.
#   - its tip is contained in origin/main, or in the head commit of the merged
#     pull request from backlog/<backlog>-* into main (a squash merge leaves no
#     ancestry in main, so the PR head is the proof that the work merged).
#   - no open pull request uses it as head. If gh cannot answer, no branch on
#     origin is deleted.
#   - no remaining worktree has it checked out (this also keeps the copy on origin).
# A linked worktree is removed only when it is not locked, has no modified or
# untracked files, and holds a removable branch or a detached commit contained
# in merged work. Dirty worktrees and their branches are kept.
#
# Deletions are compare-and-delete: a local branch is deleted with git
# update-ref against its verified tip, and a branch on origin with
# --force-with-lease against its verified tip, so a branch that moved after the
# check is kept. The run state directory .agentic-workflow/runs/<backlog> is
# removed only when the merged pull request was found.
#
# Needs git, jq and, for removal, an authenticated gh.
#
# Exit codes:
#   0 — done, or report only
#   1 — not on main, origin unreadable, or a deletion failed
#   2 — usage error

usage() {
  echo "Usage: $0 [--dry-run] [<backlog-number>]"
  echo "  Without a backlog number: report only, delete nothing."
}

DRY_RUN=0
BACKLOG=""
while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "ERROR: unknown option $1" >&2; usage >&2; exit 2 ;;
    *)
      if [ -n "$BACKLOG" ]; then usage >&2; exit 2; fi
      BACKLOG="$1"
      ;;
  esac
  shift
done

if [ -n "$BACKLOG" ]; then
  case "$BACKLOG" in
    *[!0-9]*) echo "ERROR: backlog number must be digits, got '$BACKLOG'" >&2; exit 2 ;;
  esac
else
  DRY_RUN=1
fi

# --- Safety check: must be on main ---
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
  echo "ERROR: Must be on main branch (currently on $CURRENT_BRANCH)."
  echo "Run: git checkout main && git pull"
  exit 1
fi

if [ "$DRY_RUN" -eq 1 ]; then
  git fetch --quiet origin || { echo "ERROR: git fetch origin failed" >&2; exit 1; }
else
  git fetch --quiet --prune origin || { echo "ERROR: git fetch origin failed" >&2; exit 1; }
fi
MAIN_REF="refs/remotes/origin/main"
if ! git rev-parse --verify --quiet "$MAIN_REF^{commit}" > /dev/null; then
  echo "ERROR: origin/main not found" >&2
  exit 1
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "=== Post-Merge Cleanup (dry run: nothing is deleted) ==="
else
  echo "=== Post-Merge Cleanup for backlog $BACKLOG ==="
fi

# --- Merged pull request for this backlog item ---
MERGED_HEAD=""
if [ -n "$BACKLOG" ]; then
  if merged_json=$(gh pr list --state merged --base main --limit 200 --json number,headRefName,headRefOid 2>/dev/null); then
    merged_line=$(printf '%s' "$merged_json" \
      | jq -r --arg p "backlog/$BACKLOG-" '.[] | select(.headRefName | startswith($p)) | "\(.number) \(.headRefOid)"' 2>/dev/null \
      | head -n 1)
    if [ -n "$merged_line" ]; then
      pr_number="${merged_line%% *}"
      MERGED_HEAD="${merged_line#* }"
      if ! git cat-file -e "$MERGED_HEAD^{commit}" 2>/dev/null; then
        git fetch --quiet origin "refs/pull/$pr_number/head" 2>/dev/null || true
      fi
      if git cat-file -e "$MERGED_HEAD^{commit}" 2>/dev/null; then
        echo "Merged pull request $pr_number for backlog $BACKLOG, head ${MERGED_HEAD:0:7}."
      else
        echo "WARNING: head commit of pull request $pr_number is not available locally; using origin/main only."
        MERGED_HEAD=""
      fi
    else
      echo "No merged pull request into main found for backlog/$BACKLOG-*. Only work already in origin/main counts as merged."
    fi
  else
    echo "WARNING: gh could not list merged pull requests. Only work already in origin/main counts as merged."
  fi
fi

# --- Open pull requests: their head branches are active work ---
OPEN_KNOWN=0
OPEN_HEADS=""
if open_json=$(gh pr list --state open --limit 200 --json headRefName 2>/dev/null) \
   && OPEN_HEADS=$(printf '%s' "$open_json" | jq -r '.[].headRefName' 2>/dev/null); then
  OPEN_KNOWN=1
else
  echo "WARNING: gh could not list open pull requests. No branch on origin will be deleted."
fi

has_open_pr() {
  [ -n "$OPEN_HEADS" ] && printf '%s\n' "$OPEN_HEADS" | grep -qxF -- "$1"
}

# is_workflow_branch <name> — branch names the workflow creates. In report
# mode every backlog/* branch is shown; removal is limited to this backlog.
is_workflow_branch() {
  case "$1" in
    backlog/*)
      [ -z "$BACKLOG" ] && return 0
      case "$1" in "backlog/$BACKLOG-"*) return 0 ;; esac
      return 1
      ;;
    epic/*|docs/*|worktree-*) return 0 ;;
    e[0-9][0-9]-s[0-9][0-9]/*) return 0 ;;
  esac
  return 1
}

# unmerged_reason — why a commit that is not contained is kept.
unmerged_reason() {
  if [ -n "$MERGED_HEAD" ]; then echo "has commits that are not merged"; else echo "not in origin/main"; fi
}

# contained <sha> — true when the commit is already part of merged work.
contained() {
  git merge-base --is-ancestor "$1" "$MAIN_REF" 2>/dev/null && return 0
  [ -n "$MERGED_HEAD" ] && git merge-base --is-ancestor "$1" "$MERGED_HEAD" 2>/dev/null && return 0
  return 1
}

# Linked worktrees, one per line: path<TAB>head<TAB>branch<TAB>locked
WORKTREES=$(git worktree list --porcelain | awk '
  /^worktree / { if (p != "") print p "\t" h "\t" b "\t" l; p = substr($0, 10); h = ""; b = ""; l = 0 }
  /^HEAD /     { h = $2 }
  /^branch /   { b = substr($0, 8); sub("^refs/heads/", "", b) }
  /^locked/    { l = 1 }
  END          { if (p != "") print p "\t" h "\t" b "\t" l }')
MAIN_WORKTREE=$(printf '%s\n' "$WORKTREES" | head -n 1 | cut -f1)
THIS_WORKTREE=$(git rev-parse --show-toplevel)
REMOVED_WORKTREES=""

# in_worktree <branch> — true when a worktree that stays has the branch checked out.
in_worktree() {
  local path head branch locked
  while IFS="$(printf '\t')" read -r path head branch locked; do
    [ -n "$path" ] || continue
    [ "$branch" = "$1" ] || continue
    if [ -n "$REMOVED_WORKTREES" ] && printf '%s\n' "$REMOVED_WORKTREES" | grep -qxF -- "$path"; then
      continue
    fi
    return 0
  done <<< "$WORKTREES"
  return 1
}

FAILED=0
REMOVED=0
KEPT=0
act() {  # act <description> <command...> — returns non-zero when the command failed
  local what="$1"; shift
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  would remove $what"
    REMOVED=$((REMOVED + 1))
  elif "$@" < /dev/null; then
    echo "  removed $what"
    REMOVED=$((REMOVED + 1))
  else
    echo "  FAILED to remove $what"
    FAILED=1
    return 1
  fi
}
keep() {  # keep <description> <reason>
  echo "  kept $1 ($2)"
  KEPT=$((KEPT + 1))
}

# --- 1. Worktrees ---
echo ""
echo "Worktrees:"
while IFS="$(printf '\t')" read -r path head branch locked; do
  [ -n "$path" ] || continue
  [ "$path" = "$MAIN_WORKTREE" ] && continue
  [ "$path" = "$THIS_WORKTREE" ] && continue
  if [ ! -d "$path" ]; then
    keep "$path" "directory missing; git worktree prune clears it"
    continue
  fi
  label="$path${branch:+ [$branch]}"
  if [ "$locked" = "1" ]; then keep "$label" "locked"; continue; fi
  if [ -n "$branch" ]; then
    if ! is_workflow_branch "$branch"; then keep "$label" "not a workflow branch of this item"; continue; fi
    if has_open_pr "$branch"; then keep "$label" "open pull request"; continue; fi
  fi
  if ! contained "$head"; then keep "$label" "$(unmerged_reason)"; continue; fi
  if [ -n "$(git -C "$path" status --porcelain --untracked-files=all 2>/dev/null)" ]; then
    keep "$label" "modified or untracked files"
    continue
  fi
  if [ -z "$BACKLOG" ]; then keep "$label" "merged; pass the backlog number to remove it"; continue; fi
  if act "worktree $label" git worktree remove "$path"; then
    REMOVED_WORKTREES="$REMOVED_WORKTREES$path
"
  fi
done <<< "$WORKTREES"
echo ""

# --- 2. Local branches ---
echo "Local branches:"
while read -r ref tip; do
  [ -n "$ref" ] || continue
  branch="${ref#refs/heads/}"
  [ "$branch" = "main" ] && continue
  is_workflow_branch "$branch" || continue
  if has_open_pr "$branch"; then keep "$branch" "open pull request"; continue; fi
  if in_worktree "$branch"; then keep "$branch" "checked out in a worktree"; continue; fi
  if ! contained "$tip"; then keep "$branch" "$(unmerged_reason)"; continue; fi
  if [ -z "$BACKLOG" ]; then keep "$branch" "merged; pass the backlog number to remove it"; continue; fi
  act "local branch $branch" git update-ref -d "refs/heads/$branch" "$tip"
done <<< "$(git for-each-ref --format='%(refname) %(objectname)' refs/heads)"
echo ""

# --- 3. Branches on origin ---
echo "Branches on origin:"
while read -r ref tip; do
  [ -n "$ref" ] || continue
  branch="${ref#refs/remotes/origin/}"
  [ "$branch" = "main" ] && continue
  [ "$branch" = "HEAD" ] && continue
  is_workflow_branch "$branch" || continue
  if has_open_pr "$branch"; then keep "origin/$branch" "open pull request"; continue; fi
  if in_worktree "$branch"; then keep "origin/$branch" "checked out in a worktree"; continue; fi
  if ! contained "$tip"; then keep "origin/$branch" "$(unmerged_reason)"; continue; fi
  if [ -z "$BACKLOG" ]; then keep "origin/$branch" "merged; pass the backlog number to remove it"; continue; fi
  if [ "$OPEN_KNOWN" -ne 1 ]; then keep "origin/$branch" "open pull requests unknown"; continue; fi
  act "origin/$branch" git push --quiet --force-with-lease="refs/heads/$branch:$tip" origin --delete "$branch"
done <<< "$(git for-each-ref --format='%(refname) %(objectname)' refs/remotes/origin)"
echo ""

# --- 4. Run state directory ---
STATE_DIR=".agentic-workflow/runs/${BACKLOG:-}"
if [ -n "$BACKLOG" ] && [ -d "$STATE_DIR" ]; then
  echo "Run state:"
  if [ -n "$MERGED_HEAD" ]; then
    act "$STATE_DIR/" rm -rf -- "$STATE_DIR"
  else
    keep "$STATE_DIR/" "no merged pull request found"
  fi
  echo ""
fi

[ "$DRY_RUN" -eq 0 ] && git worktree prune

# --- Summary ---
if [ "$DRY_RUN" -eq 1 ]; then
  echo "=== Dry run complete: $REMOVED would be removed, $KEPT kept ==="
  [ -z "$BACKLOG" ] && echo "Pass a backlog number to remove that item's merged branches and worktrees."
else
  echo "=== Cleanup complete: $REMOVED removed, $KEPT kept ==="
fi

[ "$FAILED" -eq 0 ]
