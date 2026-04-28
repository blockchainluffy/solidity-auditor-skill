#!/usr/bin/env bash
# scope_contracts.sh — Phase 1: enumerate Solidity contracts and surface scope info
# Usage: scope_contracts.sh <path-to-contracts>
# Output: prints a human-readable scope summary to stdout

set -euo pipefail

TARGET="${1:-.}"

if [ ! -d "$TARGET" ]; then
  echo "Error: '$TARGET' is not a directory" >&2
  exit 1
fi

echo "=== Solidity Audit Scope ==="
echo "Target: $TARGET"
echo ""

# All .sol files, excluding common non-source dirs
SOL_FILES=$(find "$TARGET" \
  -type f -name "*.sol" \
  -not -path "*/node_modules/*" \
  -not -path "*/lib/*" \
  -not -path "*/.git/*" \
  -not -path "*/out/*" \
  -not -path "*/cache/*" \
  -not -path "*/build/*" \
  -not -path "*/artifacts/*" \
  | sort)

FILE_COUNT=$(echo "$SOL_FILES" | grep -c . || true)
echo "Solidity files in scope: $FILE_COUNT"
echo ""

if [ "$FILE_COUNT" -eq 0 ]; then
  echo "No Solidity files found."
  exit 0
fi

# LOC per file (sloc-style: non-blank, non-comment is hard without a parser, so use raw line count)
echo "=== Files & line counts ==="
TOTAL_LOC=0
while IFS= read -r f; do
  LOC=$(wc -l < "$f")
  TOTAL_LOC=$((TOTAL_LOC + LOC))
  printf "  %5d  %s\n" "$LOC" "$f"
done <<< "$SOL_FILES"
echo "  -----"
printf "  %5d  TOTAL\n" "$TOTAL_LOC"
echo ""

# External imports — quick fingerprint of dependencies
echo "=== External imports (top 20 unique) ==="
echo "$SOL_FILES" | xargs grep -h "^import" 2>/dev/null \
  | grep -oE '"[^"]+"' \
  | sort -u \
  | head -20 \
  || echo "  (none found)"
echo ""

# Inheritance fingerprint — helps classify protocol type
echo "=== Inheritance fingerprint (helps identify protocol type) ==="
echo "$SOL_FILES" | xargs grep -hE "contract [A-Za-z0-9_]+ is " 2>/dev/null \
  | grep -oE "is [A-Za-z0-9_, ]+" \
  | tr ',' '\n' \
  | sed 's/is //; s/^ *//; s/ *$//' \
  | sort | uniq -c | sort -rn | head -20 \
  || echo "  (no inheritance found)"
echo ""

# State-changing entry points — external/public non-view, non-pure functions
echo "=== State-changing entry points (external/public, sample) ==="
echo "$SOL_FILES" | xargs grep -hnE "function .+(external|public)" 2>/dev/null \
  | grep -vE "(view|pure)" \
  | head -30 \
  || echo "  (none detected by simple grep — manual review needed)"
echo ""

echo "=== End of scope summary ==="
echo ""
echo "Next: classify the protocol type(s) from inheritance + naming, then proceed to Phase 2."
