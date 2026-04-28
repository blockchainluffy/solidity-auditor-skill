#!/usr/bin/env bash
# run_static_analysis.sh — Phase 2: run Slither and Aderyn, normalize output
# Usage: run_static_analysis.sh <path-to-contracts>
# Output: writes results to /tmp/audit-static-output/

set -uo pipefail

TARGET="${1:-.}"
OUT_DIR="/tmp/audit-static-output"
mkdir -p "$OUT_DIR"

echo "=== Phase 2: Static Analysis ==="
echo "Target: $TARGET"
echo "Output: $OUT_DIR"
echo ""

# --- Slither ---
echo "--- Running Slither ---"
if command -v slither >/dev/null 2>&1; then
  # JSON for parsing, plus human-readable
  slither "$TARGET" \
    --json "$OUT_DIR/slither.json" \
    > "$OUT_DIR/slither.txt" 2>&1 || true
  echo "  Slither JSON: $OUT_DIR/slither.json"
  echo "  Slither text: $OUT_DIR/slither.txt"

  # Quick summary by severity
  if [ -f "$OUT_DIR/slither.json" ]; then
    echo ""
    echo "  Severity summary:"
    python3 -c "
import json, sys
try:
    data = json.load(open('$OUT_DIR/slither.json'))
    detectors = data.get('results', {}).get('detectors', [])
    from collections import Counter
    by_sev = Counter(d.get('impact', 'Unknown') for d in detectors)
    for sev in ['High', 'Medium', 'Low', 'Informational', 'Optimization']:
        if sev in by_sev:
            print(f'    {sev}: {by_sev[sev]}')
    print(f'    Total: {len(detectors)}')
except Exception as e:
    print(f'    (could not parse: {e})')
" 2>/dev/null || echo "    (python3 not available for summary)"
  fi
else
  echo "  Slither not installed. Install: pip install slither-analyzer" | tee "$OUT_DIR/slither.txt"
fi
echo ""

# --- Aderyn ---
echo "--- Running Aderyn ---"
if command -v aderyn >/dev/null 2>&1; then
  (cd "$TARGET" && aderyn . -o "$OUT_DIR/aderyn-report.md") > "$OUT_DIR/aderyn.txt" 2>&1 || true
  echo "  Aderyn report: $OUT_DIR/aderyn-report.md"
  echo "  Aderyn log:    $OUT_DIR/aderyn.txt"
else
  echo "  Aderyn not installed. Install: cargo install aderyn  (or see https://github.com/Cyfrin/aderyn)" | tee "$OUT_DIR/aderyn.txt"
fi
echo ""

echo "=== Static analysis complete ==="
echo ""
echo "Next: read the output files, triage findings as Real / FP / Investigate, then proceed to Phase 3."
