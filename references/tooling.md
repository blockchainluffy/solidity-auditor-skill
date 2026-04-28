# Static Analysis Tooling Guide

How to invoke and interpret output from Slither and Aderyn during Phase 2.

## Slither

**Install:** `pip install slither-analyzer` (requires solc, install via `solc-select`)

**Invocation:** Done by `scripts/run_static_analysis.sh`. If running manually:
```bash
slither <path> --json output.json
slither <path> --print human-summary  # quick overview
slither <path> --print contract-summary  # per-contract function visibility
slither <path> --print inheritance-graph  # outputs .dot file
```

**Output structure (JSON):**
```
results.detectors[]:
  - check: detector name (e.g., "reentrancy-eth")
  - impact: High | Medium | Low | Informational | Optimization
  - confidence: High | Medium | Low
  - description: human-readable
  - elements: [code locations]
```

### Common Slither detectors and how to interpret

| Detector | Real-issue likelihood | Notes |
|---|---|---|
| `reentrancy-eth` (High impact) | High | Treat as candidate, verify state changes happen after external call |
| `reentrancy-no-eth` | Medium | Often real but needs context — check what state is read/written |
| `reentrancy-benign` | Low | Usually safe to dismiss unless integrated with hooks (ERC777, ERC1155 callbacks) |
| `arbitrary-send-eth` | High | Almost always a real finding |
| `unchecked-transfer` | High | Real for non-standard ERC20s (USDT etc.); flag as needing SafeERC20 |
| `unchecked-lowlevel` | Medium | Verify whether the return value matters |
| `tx-origin` | High | Real, always |
| `controlled-delegatecall` | Critical | Real, almost always |
| `uninitialized-state` | High | Real |
| `uninitialized-storage` | Critical | Real, can corrupt storage |
| `incorrect-equality` | Medium | Strict equality on balances often exploitable via direct transfer |
| `weak-prng` | High | Real if used for anything important |
| `timestamp` | Low/Info | Usually noise — flag only if used for short-window logic |
| `solc-version` | Informational | Style |
| `naming-convention` | Informational | Almost always skip |
| `dead-code` | Informational | Skip unless suspicious |
| `external-function` | Optimization | Skip |

### Common Slither false positives

- **Reentrancy on view-only external calls** — flagged but not exploitable. Verify the call truly is view (some `view` functions still issue side effects via libraries — rare but possible).
- **`unchecked-transfer` on standard tokens** — if the token is a known-compliant ERC20 (e.g., a project's own token with standard impl), the warning is pedantic. Still recommend SafeERC20 in the report.
- **`reentrancy-benign` on internal accounting** — sometimes Slither flags state changes after a hook that can't actually re-enter the same path. Trace the call graph before dismissing.

## Aderyn

**Install:** `cargo install aderyn` (Rust toolchain required) or download from https://github.com/Cyfrin/aderyn

**Invocation:** Done by `scripts/run_static_analysis.sh`. If running manually:
```bash
cd <project-root>  # must contain foundry.toml or hardhat config
aderyn . -o report.md
```

**Output:** Markdown report with findings grouped by severity (High / Low / NC).

### Aderyn vs Slither

Aderyn is newer and focuses on patterns Cyfrin sees in real audits. It overlaps with Slither but catches some things Slither doesn't (and vice versa). Run both, deduplicate by location.

Aderyn's strengths:
- Catches `block.timestamp` used in modifier conditions
- Flags centralization risks (admin-controlled critical functions)
- Detects missing events on state changes
- Flags loops over unbounded arrays for DoS
- Catches use of deprecated Solidity features

Aderyn's weaknesses:
- Higher false positive rate on "centralization risk" — most protocols have admin functions for legitimate reasons; report only if the admin power is unexpectedly broad
- Limited reentrancy detection compared to Slither

## Triage workflow for static output

For each finding from either tool:

1. **Read the finding's code location.** Open the file at the reported line.
2. **Trace reachability.** Can an external caller hit this code path? Through what entry point?
3. **Classify:**
   - **Real:** Add to candidate findings list. Note tool, detector, severity.
   - **FP:** Note the reason for dismissal. Do not include in report.
   - **Investigate:** Mark for deeper review in Phase 3 manual pass.
4. **Deduplicate.** If both Slither and Aderyn flag the same line for the same root cause, count it once.

## When neither tool is installed

If both tools fail to run (e.g., chat environment without local installs), proceed to Phase 3 with manual review only. Note in the final report's "Tools used" section that static analysis was not run, and flag this as a limitation of the audit.
