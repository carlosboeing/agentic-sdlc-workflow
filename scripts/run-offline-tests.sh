#!/usr/bin/env bash
set -uo pipefail

# run-offline-tests.sh — Run every offline shell test.
#
# Needs only bash, jq, python3 and git. No Claude, no GitHub access, no board,
# no running server. Each test runs with an empty HOME so it cannot read your
# gh or git configuration.
#
# Usage: ./scripts/run-offline-tests.sh
# Exit code: 0 when all tests pass, 1 otherwise.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

# Tests that check content removed from this repository; they are deleted
# upstream and must not gate CI while they remain.
SKIP="test-press-kit.sh test_character_bios.sh test_orchestra_notes.sh"

FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME"' EXIT

pass=0
fail=0
failed=()
for t in tests/scripts/test-*.sh scripts/lib/test_*.sh; do
  [ -f "$t" ] || continue
  case " $SKIP " in *" $(basename "$t") "*) continue ;; esac
  if HOME="$FAKE_HOME" bash "$t" > "$FAKE_HOME/out.log" 2>&1 < /dev/null; then
    echo "PASS $t"
    pass=$((pass + 1))
  else
    echo "FAIL $t"
    tail -n 15 "$FAKE_HOME/out.log" | sed 's/^/     /'
    fail=$((fail + 1))
    failed+=("$t")
  fi
done

echo ""
echo "Shell tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
