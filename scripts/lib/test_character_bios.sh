#!/usr/bin/env bash
# Test suite for E02-S01: Character Bios and Vocal Casting Notes
# Verifies acceptance criteria for test-output/debugging-musical/handbook/character-bios.md

set -uo pipefail

TARGET="test-output/debugging-musical/handbook/character-bios.md"
PASS=0
FAIL=0

check() {
  local desc="$1"
  local result="$2"
  if [ "$result" = "0" ]; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Testing: $TARGET ==="
echo ""

# AC1: File exists
[ -f "$TARGET" ]; FILE_EXISTS=$?
check "File exists at $TARGET" $FILE_EXISTS

if [ "$FILE_EXISTS" != "0" ]; then
  echo ""
  echo "RESULTS: $PASS passed, $FAIL failed"
  echo "FATAL: File does not exist. Cannot run remaining tests."
  exit 1
fi

# AC2 + AC3: All 7 characters from Character Roster with ## headings
for name in "Jordan Chase" "Priya Mehta" "Marcus Chen" "Zoe Kim" "Aisha Okafor" "Riley Park" "The Legacy Codebase"; do
  grep -q "^## $name" "$TARGET"; check "Character heading '## $name' present" $?
done

# AC4: Vocal range and type metadata
grep -q "^\*\*Vocal Range:\*\*" "$TARGET"; check "Vocal Range metadata present" $?
grep -q "^\*\*Vocal Type:\*\*" "$TARGET"; check "Vocal Type metadata present" $?
grep -q "^\*\*Role:\*\*" "$TARGET"; check "Role metadata present" $?

# AC5: Costume notes for each character
costume_count=$(grep -c "^### Costume Notes" "$TARGET" 2>/dev/null || echo 0)
[ "$costume_count" -ge 7 ]; check "At least 7 '### Costume Notes' sections (found: $costume_count)" $?

# Marcus hoodie detail
grep -qi "hoodie" "$TARGET"; check "Marcus hoodie detail mentioned" $?

# AC6: Song assignment table for each character
song_section_count=$(grep -c "^### Song Assignments" "$TARGET" 2>/dev/null || echo 0)
[ "$song_section_count" -ge 7 ]; check "At least 7 '### Song Assignments' sections (found: $song_section_count)" $?

# Song Registry titles present
for song in "The Pitch" "The Standup Ballad" "The Merge Conflict" "Rebase or Rewrite?" \
            "The Intern's Lament" "It Worked on My Machine" "The Rollback Waltz" \
            "Technical Debt (The Musical Number)" "Ctrl+Z (The Reprise)"; do
  grep -q "$song" "$TARGET"; check "Song Registry title '$song' referenced" $?
done

# Song table column headers
grep -q "Role in Number" "$TARGET"; check "Song assignment table with 'Role in Number' column header" $?

# AC7: Legacy Codebase ensemble personification concept
grep -qi "personif\|module\|dancer" "$TARGET"; check "Legacy Codebase personification concept described" $?
grep -qi "6\|six\|seven\|eight\|nine\|10\|minimum" "$TARGET"; check "Ensemble size (6+) mentioned" $?

# AC8: Word count 300-500
word_count=$(wc -w < "$TARGET")
[ "$word_count" -ge 300 ] && [ "$word_count" -le 500 ]
check "Word count $word_count is within 300-500 range" $?

# Format structure checks
backstory_count=$(grep -c "^### Backstory" "$TARGET" 2>/dev/null || echo 0)
[ "$backstory_count" -ge 7 ]; check "At least 7 '### Backstory' sections (found: $backstory_count)" $?

motivation_count=$(grep -c "^### Motivation" "$TARGET" 2>/dev/null || echo 0)
[ "$motivation_count" -ge 7 ]; check "At least 7 '### Motivation' sections (found: $motivation_count)" $?

echo ""
echo "=== RESULTS: $PASS passed, $FAIL failed ==="

[ "$FAIL" -eq 0 ]
