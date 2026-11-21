#!/usr/bin/env bash
# shellcheck disable=SC2016  # check() evaluates its single-quoted condition later
set -uo pipefail

# test-cleanup-post-merge.sh — Offline test for scripts/cleanup-post-merge.sh.
# Builds a throwaway repository with a local bare "origin" and a fake gh on
# PATH; no network, GitHub or Claude needed.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLEANUP="$REPO_ROOT/scripts/cleanup-post-merge.sh"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
check() { if eval "$2"; then pass "$1"; else fail "$1"; fi; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
TMP=$(cd "$TMP" && pwd -P)

# --- Fake gh: answers from JSON files, never touches the network ---
mkdir -p "$TMP/bin" "$TMP/gh"
cat > "$TMP/bin/gh" <<'GH'
#!/usr/bin/env bash
case " $* " in
  *" pr list "*"--state merged"*) cat "$FAKE_GH_DIR/merged.json" ;;
  *" pr list "*"--state open"*) cat "$FAKE_GH_DIR/open.json" ;;
  *) echo "fake gh: unsupported: $*" >&2; exit 1 ;;
esac
GH
chmod +x "$TMP/bin/gh"
export PATH="$TMP/bin:$PATH"
export FAKE_GH_DIR="$TMP/gh"

git init -q --bare "$TMP/origin.git"
git init -q "$TMP/work"
cd "$TMP/work" || exit 1
git config user.email test@example.com
git config user.name Test
git config commit.gpgsign false
git checkout -q -b main
commit() { echo "$1" > "$1.txt"; git add "$1.txt"; git commit -q -m "$1"; }
commit base
git remote add origin "$TMP/origin.git"
git push -q -u origin main
git -C "$TMP/origin.git" symbolic-ref HEAD refs/heads/main

# Backlog 7: integration branch with one merged epic, one merged story, a docs branch
git checkout -q -b backlog/7-feature
commit design
git checkout -q -b docs/feature-design
commit design-notes
git checkout -q backlog/7-feature
git merge -q --no-ff docs/feature-design -m "docs: merge design"
git checkout -q -b epic/e01-core
git checkout -q -b e01-s01/first-story
commit story-one
git checkout -q epic/e01-core
git merge -q --no-ff e01-s01/first-story -m "feat(epic): merge story"
git checkout -q backlog/7-feature
git merge -q --no-ff epic/e01-core -m "feat: merge epic"
MERGED_HEAD=$(git rev-parse backlog/7-feature)

# Unmerged work: an epic branch with a commit that is in neither main nor the PR head
git checkout -q -b epic/e02-wip epic/e01-core
commit wip
# Another backlog item's branch, already contained in main (just created)
git checkout -q main
git branch backlog/8-other
# A docs branch contained in main but the head of an open pull request
git branch docs/open-pr
git push -q origin backlog/7-feature docs/feature-design epic/e01-core e01-s01/first-story epic/e02-wip backlog/8-other docs/open-pr

# Squash-merge backlog 7 into main, as the human does
git merge -q --squash backlog/7-feature
git commit -q -m "feat: backlog 7 (squash)"
git push -q origin main

# Worktrees: a clean one on a merged branch, a dirty one on a merged branch
git worktree add -q "$TMP/wt-clean" e01-s01/first-story
git worktree add -q "$TMP/wt-dirty" docs/feature-design
echo scratch > "$TMP/wt-dirty/untracked.txt"
mkdir -p .agentic-workflow/runs/7 .agentic-workflow/runs/8

printf '[{"number":12,"headRefName":"backlog/7-feature","headRefOid":"%s"}]' "$MERGED_HEAD" > "$FAKE_GH_DIR/merged.json"
echo '[{"headRefName":"docs/open-pr"}]' > "$FAKE_GH_DIR/open.json"

local_has() { git show-ref --verify --quiet "refs/heads/$1"; }
remote_has() { git ls-remote --exit-code --heads origin "$1" > /dev/null 2>&1; }
# Refs, remote heads, worktrees and state dirs. A fetch may add origin/HEAD, which deletes nothing.
snapshot() { { git for-each-ref --format='%(refname) %(objectname)' | grep -v '^refs/remotes/origin/HEAD '; git ls-remote origin; git worktree list --porcelain; ls .agentic-workflow/runs; } 2>/dev/null; }

echo "Test Group: report and dry-run modes delete nothing"
BEFORE=$(snapshot)
out=$("$CLEANUP" 2>&1); rc=$?
check "no_number_exits_0" '[ "$rc" -eq 0 ]'
check "no_number_says_dry_run" 'printf "%s" "$out" | grep -q "dry run"'
check "no_number_changes_nothing" '[ "$(snapshot)" = "$BEFORE" ]'
out=$("$CLEANUP" --dry-run 7 2>&1); rc=$?
check "dry_run_exits_0" '[ "$rc" -eq 0 ]'
check "dry_run_lists_merged_branch" 'printf "%s" "$out" | grep -q "would remove origin/backlog/7-feature"'
check "dry_run_changes_nothing" '[ "$(snapshot)" = "$BEFORE" ]'

echo "Test Group: usage and safety checks"
out=$("$CLEANUP" seven 2>&1); rc=$?
check "non_numeric_backlog_exit_2" '[ "$rc" -eq 2 ]'
git checkout -q backlog/8-other
BEFORE=$(snapshot)
out=$("$CLEANUP" 7 2>&1); rc=$?
check "not_on_main_exit_1" '[ "$rc" -eq 1 ]'
check "not_on_main_changes_nothing" '[ "$(snapshot)" = "$BEFORE" ]'
git checkout -q main

echo "Test Group: removal for backlog 7"
out=$("$CLEANUP" 7 2>&1); rc=$?
check "apply_exits_0" '[ "$rc" -eq 0 ]' || echo "$out"
check "merged_integration_branch_removed_local" '! local_has backlog/7-feature'
check "merged_integration_branch_removed_remote" '! remote_has backlog/7-feature'
check "merged_epic_removed" '! local_has epic/e01-core && ! remote_has epic/e01-core'
check "clean_worktree_removed" '[ ! -d "$TMP/wt-clean" ]'
check "story_branch_removed_after_its_worktree" '! local_has e01-s01/first-story && ! remote_has e01-s01/first-story'
check "unmerged_branch_survives_local" 'local_has epic/e02-wip'
check "unmerged_branch_survives_remote" 'remote_has epic/e02-wip'
check "dirty_worktree_survives" '[ -f "$TMP/wt-dirty/untracked.txt" ]'
check "dirty_worktree_branch_survives" 'local_has docs/feature-design && remote_has docs/feature-design'
check "other_backlog_branch_survives" 'local_has backlog/8-other && remote_has backlog/8-other'
check "open_pr_branch_survives" 'local_has docs/open-pr && remote_has docs/open-pr'
check "own_state_dir_removed" '[ ! -d .agentic-workflow/runs/7 ]'
check "other_state_dir_survives" '[ -d .agentic-workflow/runs/8 ]'
check "main_untouched" 'local_has main && remote_has main'

echo "Test Group: no remote deletion when open pull requests are unknown"
git checkout -q -b docs/late main
git push -q origin docs/late
git checkout -q main
echo "not json" > "$FAKE_GH_DIR/open.json"
out=$("$CLEANUP" 7 2>&1); rc=$?
check "unknown_open_prs_keeps_remote" 'remote_has docs/late'
check "unknown_open_prs_warns" 'printf "%s" "$out" | grep -q "No branch on origin will be deleted"'

echo "Test Group: without a merged pull request, squash-merged work and state are kept"
git checkout -q -b backlog/9-unmerged main
commit nine
git push -q origin backlog/9-unmerged
git checkout -q main
git merge -q --squash backlog/9-unmerged
git commit -q -m "feat: backlog 9 (squash)"
git push -q origin main
mkdir -p .agentic-workflow/runs/9
echo '[]' > "$FAKE_GH_DIR/merged.json"
echo '[]' > "$FAKE_GH_DIR/open.json"
out=$("$CLEANUP" 9 2>&1); rc=$?
check "unmerged_backlog_branch_survives" 'local_has backlog/9-unmerged && remote_has backlog/9-unmerged'
check "unmerged_state_dir_survives" '[ -d .agentic-workflow/runs/9 ]'

echo ""
echo "========================================"
echo "Results: $PASS/$((PASS + FAIL)) passed, $FAIL failed"
echo "========================================"
[ "$FAIL" -eq 0 ]
