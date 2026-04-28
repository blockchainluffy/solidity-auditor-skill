# Findings Report Template

Use this exact format for the final `audit-report.md`. Each finding follows the structure below. Severity ordering matches industry standard (Cyfrin / Spearbit / Trail of Bits / Code4rena).

## Report skeleton

```markdown
# Security Audit Report: <Protocol Name>

**Auditor:** Solidity-Auditor Skill (Claude)
**Date:** <YYYY-MM-DD>
**Commit:** <git commit hash if known, else "uncommitted">
**Scope:** <list of files audited, total LOC>

---

## Executive Summary

<2-3 sentences. What was audited, what kind of protocol, overall security posture.>

## Severity Summary

| Severity | Count |
|---|---|
| Critical | X |
| High | X |
| Medium | X |
| Low | X |
| Informational | X |
| **Total** | **X** |

## Methodology

This audit was performed using a 6-phase methodology covering:
1. Scoping and protocol classification
2. Static analysis (Slither, Aderyn)
3. Manual review against the Cyfrin/Solodit checklist and SWC registry
4. Protocol-specific deep dive for: <list of protocol types>
5. MEV review
6. Cross-validation of every finding before inclusion

## Tools Used

- Slither vX.X.X
- Aderyn vX.X.X
- Solodit MCP <queried / not queried>
- Manual review

---

## Findings

### Critical

#### [C-01] <Concise title describing the issue>

**Severity:** Critical
**Impact:** High
**Likelihood:** High
**Location:** `<file>:<line-range>`

**Description:**
<2-4 paragraphs. What's wrong, why it's wrong, what state/inputs trigger it.>

**Proof of Concept:**
<Either pseudo-code attack sequence or, if executable, a Foundry test sketch.>
1. Attacker calls `foo()` with parameter X
2. This causes state Y to be set to Z
3. Attacker then calls `bar()` which now passes the check incorrectly
4. Result: <impact, e.g. "attacker drains the vault">

**Recommendation:**
<Specific code-level fix. Show the corrected pattern if helpful.>

**References:**
- <Solodit finding link if precedent exists>
- <SWC ID if applicable>
- <External writeup if relevant>

---

#### [C-02] <Next critical>
...

### High

#### [H-01] <Title>
<Same format>

### Medium

#### [M-01] <Title>
<Same format>

### Low

#### [L-01] <Title>
<Same format>

### Informational

#### [I-01] <Title>
<Same format — usually shorter>

---

## Disclaimer

This audit is an opinion-based review of the smart contract code at the specified commit. It does not guarantee the absence of vulnerabilities or constitute a warranty. Smart contract security is a continuous process; this audit reflects findings at a single point in time. Users and developers should not rely solely on this report for production deployment decisions and are encouraged to obtain additional independent reviews, formal verification where applicable, and a comprehensive testing regime.
```

## Severity definitions (re-stated for the writer)

- **Critical:** Direct loss of funds or complete protocol takeover, no preconditions, anyone can trigger. Examples: unprotected `selfdestruct`, missing access control on `mint`, reentrancy draining the vault.
- **High:** Loss of funds with achievable preconditions, or compromise of a privileged role's expected guarantees. Examples: oracle manipulation under specific market conditions, signature replay across chains, liquidation of healthy positions.
- **Medium:** Loss of funds in unlikely scenarios, denial of service of a critical function, significant griefing. Examples: DoS of withdrawals via gas exhaustion, rounding errors that accumulate, frontrunnable approvals.
- **Low:** Edge-case griefing, minor accounting errors, missing input validation without direct exploit, gas inefficiencies that affect UX. Examples: off-by-one in display logic, missing event emission on critical state change.
- **Informational:** Code quality, missing NatSpec, gas optimizations, deprecated patterns, style. Examples: floating pragma, unused variables, magic numbers.

## Format rules

- **Title:** Must describe the bug in <12 words. Bad: "Reentrancy". Good: "Reentrancy in `withdraw()` allows draining via ERC777 callback".
- **Location:** Use `path/to/File.sol:42-58` format. Multiple locations allowed if same root cause spans them.
- **PoC:** Either an executable test or a numbered attack sequence. Vague descriptions like "an attacker could potentially..." are not acceptable.
- **Recommendation:** Must include the actual fix, not just "add a check" — show the corrected code or pattern. Verify the fix doesn't introduce a new issue.
- **References:** Always include if Solodit MCP was queried and found precedent. Include SWC ID if a classical category. External writeups are optional.

## Numbering

Use `[<Severity-Letter>-<Number>]` format:
- Critical: C-01, C-02, ...
- High: H-01, H-02, ...
- Medium: M-01, M-02, ...
- Low: L-01, L-02, ...
- Informational: I-01, I-02, ...

Number within severity, restart at 01 for each severity level.

## Things to never do

- Don't inflate severity to look thorough. An audit with 3 verified Highs beats one with 12 questionable Mediums.
- Don't include findings that didn't survive Phase 5 verification. They are deleted, not demoted.
- Don't use phrases like "an attacker could potentially" without describing the actual sequence.
- Don't write findings in passive voice. Direct: "Function `foo` allows reentrancy because state X is updated after the external call."
- Don't recommend fixes you haven't reasoned through. If you say "use ReentrancyGuard", confirm it doesn't break a legitimate cross-function call pattern.
