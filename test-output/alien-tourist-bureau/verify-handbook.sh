#!/usr/bin/env bash
# Verification script for handbook-survival.md acceptance criteria
set -euo pipefail

FILE="test-output/alien-tourist-bureau/handbook-survival.md"
ERRORS=0

check() {
  if ! "$@" >/dev/null 2>&1; then
    echo "FAIL: $DESC"
    ERRORS=$((ERRORS + 1))
  else
    echo "PASS: $DESC"
  fi
}

# File exists
DESC="File exists" check test -f "$FILE"

# Document header fields
DESC="Document No. GFBTT-PUB-2026-001" check grep -q "GFBTT-PUB-2026-001" "$FILE"
DESC="Issuing Authority: Office of the Director-General" check grep -q "Office of the Director-General" "$FILE"
DESC="Classification: UNCLASSIFIED" check grep -q "UNCLASSIFIED -- FOR TOURIST USE" "$FILE"

# Cross-references (at least 4 of 5)
REF_COUNT=0
for doc in GFBTT-HAZ-2026-001 GFBTT-HAZ-2026-002 GFBTT-CUL-2026-001 GFBTT-CUL-2026-002 GFBTT-ADM-2026-001; do
  if grep -q "$doc" "$FILE"; then
    REF_COUNT=$((REF_COUNT + 1))
  fi
done
DESC="References at least 4 of 5 prior documents (found $REF_COUNT)"
if [ "$REF_COUNT" -ge 4 ]; then echo "PASS: $DESC"; else echo "FAIL: $DESC"; ERRORS=$((ERRORS + 1)); fi

# Required sections
DESC="Director-General's Welcome Message" check grep -qi "Director-General" "$FILE"
DESC="Quick Reference Card table" check grep -qi "Quick Reference" "$FILE"
DESC="FAQ section" check grep -qi "Frequently Asked" "$FILE"
DESC="Known Issues and Errata" check grep -qi "Known Issues" "$FILE"

# FAQ entry count (at least 5 Q: entries)
FAQ_COUNT=$(grep -c "^**Q:" "$FILE" 2>/dev/null || echo 0)
DESC="FAQ has at least 5 entries (found $FAQ_COUNT)"
if [ "$FAQ_COUNT" -ge 5 ]; then echo "PASS: $DESC"; else echo "FAIL: $DESC"; ERRORS=$((ERRORS + 1)); fi

# Word count 400-600
WC=$(wc -w < "$FILE" | tr -d ' ')
DESC="Word count 400-600 (found $WC)"
if [ "$WC" -ge 400 ] && [ "$WC" -le 600 ]; then echo "PASS: $DESC"; else echo "FAIL: $DESC"; ERRORS=$((ERRORS + 1)); fi

echo ""
if [ "$ERRORS" -eq 0 ]; then
  echo "ALL CHECKS PASSED"
else
  echo "$ERRORS CHECK(S) FAILED"
  exit 1
fi
