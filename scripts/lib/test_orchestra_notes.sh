#!/usr/bin/env bash
# Test suite for E02-S03: Orchestra Arrangement Notes and Song Index
# Verifies acceptance criteria for test-output/debugging-musical/handbook/orchestra-notes.md

set -uo pipefail

TARGET="test-output/debugging-musical/handbook/orchestra-notes.md"
BIOS="test-output/debugging-musical/handbook/character-bios.md"
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

# AC2: Follows Orchestra Notes Format template for each song (## heading)
for song in "The Pitch" "The Standup Ballad" "The Merge Conflict" "Rebase or Rewrite?" \
            "The Intern's Lament" "It Worked on My Machine" "The Rollback Waltz" \
            "Technical Debt (The Musical Number)" "Ctrl+Z (The Reprise)"; do
  grep -q "^## $song" "$TARGET"; check "Song heading '## $song' present" $?
done

# AC3: All 9 songs present
song_count=$(grep -c "^## " "$TARGET" 2>/dev/null || echo 0)
[ "$song_count" -ge 9 ]; check "At least 9 song headings (found: $song_count)" $?

# AC4: Scene numbers matching Song Registry from the issue
grep -A2 "^## The Pitch" "$TARGET" | grep -q "Act I, Scene 1"; check "'The Pitch' assigned to Act I, Scene 1" $?
grep -A2 "^## The Standup Ballad" "$TARGET" | grep -q "Act I, Scene 4"; check "'The Standup Ballad' assigned to Act I, Scene 4" $?
grep -A2 "^## The Merge Conflict" "$TARGET" | grep -q "Act I, Scene 3"; check "'The Merge Conflict' assigned to Act I, Scene 3" $?
grep -A2 "^## Rebase or Rewrite" "$TARGET" | grep -q "Act I, Scene 3"; check "'Rebase or Rewrite?' assigned to Act I, Scene 3" $?
grep -A2 "^## The Intern's Lament" "$TARGET" | grep -q "Act I, Scene 4"; check "'The Intern's Lament' assigned to Act I, Scene 4" $?
grep -A2 "^## It Worked on My Machine" "$TARGET" | grep -q "Act II, Scene 1"; check "'It Worked on My Machine' assigned to Act II, Scene 1" $?
grep -A2 "^## The Rollback Waltz" "$TARGET" | grep -q "Act II, Scene 2"; check "'The Rollback Waltz' assigned to Act II, Scene 2" $?
grep -A2 "^## Technical Debt" "$TARGET" | grep -q "Act II, Scene 3"; check "'Technical Debt' assigned to Act II, Scene 3" $?
grep -A2 "^## Ctrl+Z" "$TARGET" | grep -q "Act II, Scene 3"; check "'Ctrl+Z (The Reprise)' assigned to Act II, Scene 3" $?

# AC5: Each song has key, tempo, and time signature
grep -c "\*\*Key:\*\*" "$TARGET" | xargs -I{} test {} -ge 9; check "At least 9 **Key:** entries" $?
grep -c "\*\*Tempo:\*\*" "$TARGET" | xargs -I{} test {} -ge 9; check "At least 9 **Tempo:** entries" $?
grep -c "\*\*Time Signature:\*\*" "$TARGET" | xargs -I{} test {} -ge 9; check "At least 9 **Time Signature:** entries" $?

# AC6: Full pit vs. acoustic-only indicated for each song
grep -c "\*\*Full Pit:\*\*" "$TARGET" | xargs -I{} test {} -ge 9; check "At least 9 **Full Pit:** entries" $?

# AC7: Transition timing between all scenes
transition_count=$(grep -c "### Transition" "$TARGET" 2>/dev/null || echo 0)
[ "$transition_count" -ge 9 ]; check "At least 9 '### Transition' sections (found: $transition_count)" $?

grep -c "\*\*Transition Duration:\*\*" "$TARGET" | xargs -I{} test {} -ge 9; check "At least 9 transition duration entries" $?
grep -c "\*\*Transition Type:\*\*" "$TARGET" | xargs -I{} test {} -ge 9; check "At least 9 transition type entries" $?

# AC8: Vocal requirements table for each song
vocal_table_count=$(grep -c "### Vocal Requirements" "$TARGET" 2>/dev/null || echo 0)
[ "$vocal_table_count" -ge 9 ]; check "At least 9 '### Vocal Requirements' sections (found: $vocal_table_count)" $?

# Vocal table column headers
grep -q "Character | Range Required | Notes" "$TARGET"; check "Vocal requirements table headers present" $?

# AC9: Cross-references character vocal ranges from E02-S01
# Check that vocal ranges from character bios are referenced
grep -q "Tenor" "$TARGET"; check "Tenor range referenced (Jordan/Riley)" $?
grep -q "Mezzo-soprano" "$TARGET"; check "Mezzo-soprano range referenced (Priya)" $?
grep -q "Baritone" "$TARGET"; check "Baritone range referenced (Marcus)" $?
grep -q "Soprano" "$TARGET"; check "Soprano range referenced (Zoe)" $?
grep -q "Alto" "$TARGET"; check "Alto range referenced (Aisha)" $?

# AC10: Word count 300-500
word_count=$(wc -w < "$TARGET")
[ "$word_count" -ge 300 ] && [ "$word_count" -le 500 ]
check "Word count $word_count is within 300-500 range" $?

# Format structure: Orchestration sections
orch_count=$(grep -c "### Orchestration" "$TARGET" 2>/dev/null || echo 0)
[ "$orch_count" -ge 9 ]; check "At least 9 '### Orchestration' sections (found: $orch_count)" $?

# Lead Instruments listed
grep -c "\*\*Lead Instruments:\*\*" "$TARGET" | xargs -I{} test {} -ge 9; check "At least 9 **Lead Instruments:** entries" $?

# Arrangement Notes listed
grep -c "\*\*Arrangement Notes:\*\*" "$TARGET" | xargs -I{} test {} -ge 9; check "At least 9 **Arrangement Notes:** entries" $?

# Scene metadata
grep -c "\*\*Scene:\*\*" "$TARGET" | xargs -I{} test {} -ge 9; check "At least 9 **Scene:** entries" $?

echo ""
echo "=== RESULTS: $PASS passed, $FAIL failed ==="

[ "$FAIL" -eq 0 ]
