#!/usr/bin/env bash
set -uo pipefail

# check-retro-scope.sh — Fail when a retro commit touches code.
#
# Retro commits (message starts with "docs(retro)") may change only docs/,
# CLAUDE.md and .claude/agents/. Commit 4d3ab9b reverted about 1,000 lines of
# server and script code under a docs(retro) message; this guard catches that.
#
# Usage: ./scripts/check-retro-scope.sh <base-sha> <head-sha>
#   Checks every non-merge commit in <base-sha>..<head-sha>.
#
# Exit codes:
#   0 — every docs(retro) commit in the range stays inside the allowed paths
#   1 — at least one docs(retro) commit touches other paths (listed on stdout)
#   2 — usage error or unreadable range

if [ $# -ne 2 ]; then
  echo "Usage: $0 <base-sha> <head-sha>" >&2
  exit 2
fi

BASE="$1"
HEAD="$2"

COMMITS=$(git rev-list --no-merges "$BASE..$HEAD" 2>/dev/null) || {
  echo "ERROR: cannot read commit range $BASE..$HEAD" >&2
  exit 2
}

status=0
for sha in $COMMITS; do
  subject=$(git log -1 --format=%s "$sha")
  case "$subject" in
    "docs(retro)"*) ;;
    *) continue ;;
  esac
  offending=$(git show --name-only --format= "$sha" | grep -vE '^(docs/|CLAUDE\.md$|\.claude/agents/)' || true)
  if [ -n "$offending" ]; then
    status=1
    echo "FAIL: ${sha:0:7} \"$subject\" touches paths outside docs/, CLAUDE.md and .claude/agents/:"
    echo "$offending" | sed 's/^/  /'
  fi
done

[ "$status" -eq 0 ] && echo "OK: retro commits in $BASE..$HEAD stay inside docs/, CLAUDE.md and .claude/agents/"
exit "$status"
