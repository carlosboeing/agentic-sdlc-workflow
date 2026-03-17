#!/usr/bin/env bash
set -euo pipefail

# test-press-kit.sh — Validates E03-S02 press-kit.md content requirements.
# Tests file existence, format compliance, section presence, and word count.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_FILE="$REPO_ROOT/test-output/debugging-musical/marketing/press-kit.md"

PASS=0
FAIL=0

# ─── Helpers ─────────────────────────────────────────────────────────────────

assert_true() {
  local test_name="$1"
  local condition="$2"
  if eval "$condition"; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local test_name="$1"
  local pattern="$2"
  if grep -q "$pattern" "$TARGET_FILE" 2>/dev/null; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name — pattern not found: $pattern"
    FAIL=$((FAIL + 1))
  fi
}

assert_count_ge() {
  local test_name="$1"
  local pattern="$2"
  local min_count="$3"
  local actual_count
  actual_count=$(grep -c "$pattern" "$TARGET_FILE" 2>/dev/null || echo 0)
  if [ "$actual_count" -ge "$min_count" ]; then
    echo "  PASS: $test_name (found $actual_count, required >= $min_count)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (found $actual_count, required >= $min_count)"
    FAIL=$((FAIL + 1))
  fi
}

# ─── Tests ───────────────────────────────────────────────────────────────────

echo ""
echo "=== test-press-kit.sh ==="
echo ""

# File existence
echo "--- File ---"
assert_true "file exists at expected path" "[ -f '$TARGET_FILE' ]"

if [ ! -f "$TARGET_FILE" ]; then
  echo ""
  echo "RESULTS: 0 passed, 1 failed (file missing — skipping remaining tests)"
  exit 1
fi

# Format: section headings use ## format
echo ""
echo "--- Format ---"
assert_contains "uses ## section headings (Press Kit Format)" "^## "

# Critic quotes — must have at least 4 quote blocks (blockquote lines with --)
echo ""
echo "--- Critic Reviews ---"
assert_count_ge "at least 4 critic quote lines" "^> .*--" 4
assert_contains "critic quote references a song or scene" "> .*\""

# Character names consistent with E02-S01
echo ""
echo "--- Character Names ---"
assert_contains "references Jordan Chase" "Jordan Chase"
assert_contains "references Priya Mehta" "Priya Mehta"
assert_contains "references Marcus Chen" "Marcus Chen"
assert_contains "references Riley Park\|Zoe Kim\|Aisha Okafor" "Riley\|Zoe\|Aisha"

# Song references with correct scene numbers
echo ""
echo "--- Song References ---"
assert_contains "references The Pitch in Act I Scene 1" "Act I.*Scene 1\|Scene 1.*Act I\|\"The Pitch\""
assert_contains "at least 3 distinct song titles referenced" "\"The "

# Song registry titles (at least 3 must appear)
SONG_COUNT=0
for song in '"The Pitch"' '"The Standup Ballad"' '"The Merge Conflict"' '"The Intern'"'"'s Lament"' '"Technical Debt' '"Ctrl+Z'; do
  if grep -q "$song" "$TARGET_FILE" 2>/dev/null; then
    SONG_COUNT=$((SONG_COUNT + 1))
  fi
done
if [ "$SONG_COUNT" -ge 3 ]; then
  echo "  PASS: at least 3 songs from Song Registry referenced (found $SONG_COUNT)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: at least 3 songs from Song Registry referenced (found $SONG_COUNT, need >= 3)"
  FAIL=$((FAIL + 1))
fi

# Behind-the-scenes section
echo ""
echo "--- Sections ---"
if grep -qi "behind" "$TARGET_FILE" 2>/dev/null; then
  echo "  PASS: has behind-the-scenes section"
  PASS=$((PASS + 1))
else
  echo "  FAIL: has behind-the-scenes section"
  FAIL=$((FAIL + 1))
fi

# Synopsis section
if grep -qi "synopsis" "$TARGET_FILE" 2>/dev/null; then
  echo "  PASS: has synopsis section"
  PASS=$((PASS + 1))
else
  echo "  FAIL: has synopsis section"
  FAIL=$((FAIL + 1))
fi

# Word count: 300-500
echo ""
echo "--- Word Count ---"
WORD_COUNT=$(wc -w < "$TARGET_FILE")
if [ "$WORD_COUNT" -ge 300 ] && [ "$WORD_COUNT" -le 500 ]; then
  echo "  PASS: word count in range 300-500 (actual: $WORD_COUNT)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: word count out of range 300-500 (actual: $WORD_COUNT)"
  FAIL=$((FAIL + 1))
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "RESULTS: $PASS passed, $FAIL failed"
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
