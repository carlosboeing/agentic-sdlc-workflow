#!/usr/bin/env bash
set -uo pipefail

# test-check-retro-scope.sh — Offline test for scripts/check-retro-scope.sh.
# Builds a throwaway git repository; no network, GitHub or Claude needed.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GUARD="$REPO_ROOT/scripts/check-retro-scope.sh"

PASS=0
FAIL=0
check() {
  local name="$1" expected_rc="$2" rc="$3" out="$4" needle="${5:-}"
  if [ "$rc" -eq "$expected_rc" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -qF -- "$needle"; }; then
    echo "  PASS: $name"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (rc=$rc, expected $expected_rc)"; echo "    $out"; FAIL=$((FAIL + 1))
  fi
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$TMP" || exit 1
git init -q .
git config user.email test@example.com
git config user.name Test
git config commit.gpgsign false
mkdir -p docs server/src .claude/agents
echo base > docs/a.md; echo base > server/src/x.ts
git add -A; git commit -q -m "chore: base"
BASE=$(git rev-parse HEAD)

echo "Test Group: retro scope guard"

# 1. Docs-only retro commit passes
echo one > docs/retro.md; echo one > CLAUDE.md; echo one > .claude/agents/retro.md
git add -A; git commit -q -m "docs(retro): add retrospective"
out=$("$GUARD" "$BASE" HEAD); rc=$?
check "docs_only_retro_passes" 0 "$rc" "$out" "OK"

# 2. Retro commit that also edits code fails and lists the file
echo two > docs/retro.md; echo two > server/src/x.ts
git add -A; git commit -q -m "docs(retro): add retrospective for BL 1"
BAD=$(git rev-parse HEAD)
out=$("$GUARD" "$BASE" HEAD); rc=$?
check "code_in_retro_fails" 1 "$rc" "$out" "server/src/x.ts"
check "offending_commit_listed" 1 "$rc" "$out" "${BAD:0:7}"

# 3. A convention-change commit is a retro commit too
git checkout -q -b conventions "$BASE"
mkdir -p .claude/agents
echo conv > CLAUDE.md; echo conv > .claude/agents/builder.md
git add -A; git commit -q -m "docs(conventions): require startup wiring tests"
out=$("$GUARD" "$BASE" HEAD); rc=$?
check "docs_only_conventions_passes" 0 "$rc" "$out" "OK"
echo conv > scripts.sh
git add -A; git commit -q -m "docs(conventions): also tweak a script"
CONV_BAD=$(git rev-parse HEAD)
out=$("$GUARD" "$BASE" HEAD); rc=$?
check "code_in_conventions_fails" 1 "$rc" "$out" "scripts.sh"
check "conventions_commit_listed" 1 "$rc" "$out" "${CONV_BAD:0:7}"

# 4. A non-retro commit touching code is not this guard's business
git checkout -q -b other "$BASE"
echo three > server/src/x.ts
git add -A; git commit -q -m "fix(server): change code"
out=$("$GUARD" "$BASE" HEAD); rc=$?
check "non_retro_code_commit_passes" 0 "$rc" "$out" "OK"

# 5. Range that excludes the bad commit passes
out=$("$GUARD" "$BAD" "$BAD"); rc=$?
check "empty_range_passes" 0 "$rc" "$out" "OK"

# 6. Usage and bad range
out=$("$GUARD" 2>&1); rc=$?
check "missing_args_exit_2" 2 "$rc" "$out" "Usage"
out=$("$GUARD" deadbeef HEAD 2>&1); rc=$?
check "bad_range_exit_2" 2 "$rc" "$out" "cannot read"

echo ""
echo "========================================"
echo "Results: $PASS/$((PASS + FAIL)) passed, $FAIL failed"
echo "========================================"
[ "$FAIL" -eq 0 ]
