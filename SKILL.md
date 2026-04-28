---
name: solidity-auditor
description: Systematic security audit methodology for Solidity smart contracts. Use this skill whenever the user asks to audit, review, find vulnerabilities in, security-check, or perform a security assessment on Solidity code, smart contracts, .sol files, DeFi protocols, or any EVM-compatible contract code. Trigger this even for casual phrasings like "look at this contract", "is this safe", "find bugs in", or "what could go wrong with" when applied to Solidity code. Drives a 6-phase audit loop combining static analysis (Slither, Aderyn), the Cyfrin/Solodit checklist, protocol-specific review modules, MEV review, and cross-validated findings reporting.
---

# Solidity Auditor

A structured methodology for auditing Solidity smart contracts. Combines automated static analysis with manual review guided by the Cyfrin/Solodit checklist, protocol-specific knowledge, and MEV considerations. Produces a verified markdown findings report.

## When to invoke this skill

Trigger when the user asks for any kind of security review of Solidity / EVM contract code. The trigger should fire even when the user uses casual language ("can you look at this", "is this safe to deploy", "anything sketchy here") as long as the target is smart contract code.

**Do not** trigger for: general Solidity coding help, gas optimization without security framing, Solidity tutorials, or non-EVM chains (Solana, Move, etc.).

## The 6-phase audit loop

Run these in order. Do not skip phases. Each phase has a clear exit condition.

```
Phase 1: SCOPE      → understand what's being audited
Phase 2: STATIC     → run automated tools, triage output
Phase 3: MANUAL     → walk checklist + MEV review, consult Solodit MCP for precedent
Phase 4: PROTOCOL   → load and apply protocol-specific reference files
Phase 5: VERIFY     → cross-check every candidate finding, drop false positives
Phase 6: REPORT     → write the final markdown findings report
```

---

## Phase 1: Scope

**Goal:** Understand the codebase before reading line-by-line.

Steps:
1. Run `scripts/scope_contracts.sh <path>` to enumerate `.sol` files, line counts, and imports.
2. Identify the **protocol type(s)** at play. Look for telltale inheritance and naming:
   - `ERC20`, `ERC4626`, `ERC721`, `ERC1155` → token type
   - `Vault`, `Strategy`, `harvest()` → yield aggregator
   - `Pool`, `swap()`, reserves → AMM
   - `borrow()`, `liquidate()`, `cToken`/`aToken` → lending
   - `Perp`, `funding`, `mark price`, `position` → perpetuals
   - `stake()`, `withdraw()` with delays → staking/LSD or restaking
   - `propose()`, `execute()`, `Timelock` → governance
   - `bridge()`, `lzReceive`, `CCIP` → cross-chain
   - `EntryPoint`, `validateUserOp` → account abstraction (ERC-4337)
   - `solve()`, `fillOrder`, `Order` structs with signatures → intent-based
   - `mint()` against collateral, peg → stablecoin
3. Identify **trust assumptions** (admin roles, owner, multisig, oracle dependencies).
4. Identify **external integrations** (oracles, other protocols, tokens it accepts).
5. List **state-changing entry points** (external/public non-view functions).

**Exit condition:** You can answer "what does this protocol do, who controls what, and what touches it from outside?"

Record this in a scratchpad — you'll reference it through every later phase.

---

## Phase 2: Static analysis

**Goal:** Catch the obvious stuff and seed the manual review with hotspots — without flooding the candidate list with false positives.

### 2a. Run the tools

Run `scripts/run_static_analysis.sh <path>`. This invokes Slither and Aderyn, captures both outputs, and writes them to `/tmp/audit-static-output/`.

### 2b. Load the FP library

Before triaging, read `references/false-positives.md`. It contains concrete FP patterns per detector (Slither and Aderyn) — Recognition signal, Why FP, NOT FP when. This is the single most important resource for cutting noise.

Also read `references/tooling.md` for general detector interpretation if unfamiliar with the output format.

### 2c. Structured triage (required)

For **every** finding from Slither and Aderyn, produce a one-line triage record. Write all records to `/tmp/audit-static-output/triage.md` in this exact format:

```
[detector_name] @ file:line_range → CLASSIFICATION (one-line reason)
```

Where CLASSIFICATION is one of:

- **Real** — match against `false-positives.md` did not produce an FP match, or the finding does not fit any documented pattern but the vulnerability is reachable. Add to candidate findings list.
- **FP** — matches a Recognition signal in `false-positives.md` AND none of the "NOT FP when" inversions apply. The reason field MUST cite the specific FP pattern (e.g., "FP per false-positives.md reentrancy-eth Pattern 1: trusted immutable address").
- **Investigate** — uncertain after consulting the FP library; needs Phase 3 manual context to decide. The reason field states the question to answer.

Example triage record block:
```
reentrancy-eth @ Vault.sol:142-156 → FP (Pattern 1: external call is to immutable trusted oracle, set in constructor)
unchecked-transfer @ Strategy.sol:88 → Real (transferFrom return unchecked, protocol assumes success in subsequent accounting)
arbitrary-send-eth @ Treasury.sol:34 → FP (Pattern 1: send to immutable owner role)
divide-before-multiply @ InterestRate.sol:67 → Investigate (precision constant is 1e6 USDC-scale, not 1e18 — verify truncation impact)
centralization-risk @ Pool.sol:12 → FP (Pattern 1: onlyOwner with timelock, include in Informational)
naming-convention @ * → FP (always skipped per FP library)
```

### 2d. Cross-tool deduplication

After per-finding triage, deduplicate. Group by `(file, line_range)`:
- If Slither and Aderyn both flag the same root cause at the same location, count as **one** candidate.
- Pick the higher-severity classification and the more specific detector name.
- Note the duplication in the triage record: `→ Real (deduped: also flagged by aderyn as <name>)`.

### 2e. Hard rules — these cannot be FPs

The following detectors are never FP (or only FP in vanishingly rare cases). Default to **Real** unless extraordinary justification:
- `tx-origin` — always Real.
- `controlled-delegatecall` — almost always Critical Real.
- `uninitialized-storage` — Real unless explicitly initialized via verifiable proxy initialize().
- `weak-prng` used for value-affecting decisions — Real.
- Strict equality on `balanceOf(this)` — Real (donation-attackable).

### 2f. The "FP-shaped Real bug" check

Before marking anything FP, scan the "FP-shaped Real bugs" list at the bottom of `false-positives.md`. These are patterns that look textbook-FP but are actually Real in context. If any apply, change the classification to Investigate.

**Exit condition:** Every static finding has a triage record. Every Real and Investigate finding is in the candidate list. Every FP has a documented reason citing the FP library or a Hard Rules exception. The triage file at `/tmp/audit-static-output/triage.md` exists and is complete.

---

## Phase 3: Manual review

**Goal:** Walk the systematic checklist and apply MEV thinking. This is where most real findings come from.

### 3a. Load the Cyfrin/Solodit checklist

Read `references/checklist-cyfrin.json`. Filter items by category tags matching the protocol types identified in Phase 1. **Do not** try to walk all ~200 items — that wastes context. Walk only items relevant to what you're auditing, plus the universal ones (access control, reentrancy, arithmetic, etc.).

For each checklist item:
- Read the item's question and description
- Search the codebase for the relevant pattern
- Mark as: PASS / FAIL (candidate finding) / N/A

### 3b. SWC quick-pass

Skim `references/checklist-swc.md` for any classical weaknesses not covered by the Cyfrin checklist. The SWC registry is older but still catches edge cases.

### 3c. MEV review (always run, regardless of protocol)

Load `references/mev.md` and apply it to every state-changing entry point. MEV issues exist in nearly every protocol that touches value — even ones that don't look like they should have MEV exposure (governance voting, NFT mints, airdrops). Do not skip this even if the protocol "doesn't seem MEV-relevant."

### 3d. Consult the Solodit MCP — but only when justified

The Solodit MCP server (if available) searches 20,000+ historical audit findings. Use it when:
- You suspect a vulnerability pattern but want to confirm with precedent ("has this exact thing been found in other audits?")
- You need to calibrate severity ("how have other firms rated this?")
- You see an unusual construct and want to check if it's known-bad

**Do not** use it speculatively — every call costs context. One targeted query per suspicious pattern is the right rate, not one per checklist item.

If the Solodit MCP is not available in the current environment, that's fine — proceed with the checklist-driven review.

**Exit condition:** Every relevant checklist item walked, MEV review complete, candidate findings list updated.

---

## Phase 4: Protocol-specific deep dive

**Goal:** Apply the specialized knowledge for whatever protocol type(s) this is.

Based on Phase 1's classification, load the relevant files from `references/protocols/`. Examples:

| If contract is... | Load these files |
|---|---|
| ERC4626 vault | `erc4626.md`, plus base token type if non-standard |
| Lending market with cTokens + oracle | `lending.md`, `erc20.md` (for collateral edge cases) |
| Perpetuals DEX | `perpetuals.md`, `amm.md` (if uses vAMM) |
| Bridge | `bridge-crosschain.md` |
| Restaking operator contract | `restaking.md`, `staking-lsd.md` |
| Intent solver/filler | `intent-based.md` |
| Stablecoin with CDP | `stablecoin.md`, `lending.md` |
| ERC-4337 account or paymaster | `account-abstraction.md` |
| Yield aggregator with strategies | `yield-aggregator.md`, `erc4626.md` (usually) |
| Governance/timelock | `governance.md` |

Multiple files can apply. A perp DEX with an ERC4626 LP vault and a custom oracle should pull `perpetuals.md`, `erc4626.md`, and the oracle section of `lending.md`.

For each item in the loaded protocol files:
- Check if the pattern applies to the code
- If it does, verify the code handles it correctly
- If it doesn't handle it correctly, add to candidate findings

**Exit condition:** All applicable protocol-specific patterns have been checked against the code.

---

## Phase 5: Verification (cross-check pass)

**Goal:** Drop false positives before they make it to the report. This phase is non-optional.

For **every** candidate finding, re-walk this verification checklist:

1. **Reachability:** Can the vulnerable code path actually be reached given the modifiers, access control, and state preconditions? Trace from an external entry point. If only the owner can trigger it and the owner is a trusted multisig, downgrade or drop.

2. **Impact accuracy:** Is the claimed impact actually achievable? Don't claim "loss of all funds" if the worst case is "loss of a single user's pending rewards." Quantify wherever possible.

3. **PoC plausibility:** Sketch the attack as a sequence of transactions. If you can't write a coherent attack sequence, the finding is probably wrong or needs more investigation. Note: you don't need to write executable Foundry tests in this skill (that's a heavier agent), but the attack sequence must be logically sound.

4. **Recommendation soundness:** Does your proposed fix actually fix the issue? Does it introduce new issues (e.g., recommending a check that itself can be DOSed)?

5. **Duplication:** Is this the same root cause as another finding under a different name? Merge duplicates.

6. **Severity calibration:** Apply standard severity:
   - **Critical:** Direct loss of funds, no preconditions, anyone can trigger
   - **High:** Loss of funds with preconditions, or privileged role compromise
   - **Medium:** Loss of funds in unlikely scenarios, denial of service, or significant griefing
   - **Low:** Minor issues, edge-case griefing, missing input validation without exploit
   - **Informational:** Code quality, gas, best practices

**Drop any finding that fails verification.** It's better to have 8 verified findings than 15 with 7 false positives. The verification phase is what separates a useful audit from a noisy one.

**Exit condition:** Every surviving finding has passed all 6 verification checks.

---

## Phase 6: Report

**Goal:** Produce a clean, professional markdown findings report.

Read `references/findings-template.md` for the exact format. Write the report to `audit-report.md` in the working directory.

Report structure:
1. **Executive summary** — 2-3 sentences on what was audited and overall posture
2. **Scope** — files reviewed, commit hash if known, LOC
3. **Severity summary table** — count of findings by severity
4. **Findings** — grouped by severity (Critical → High → Medium → Low → Informational), each following the template format (Title, Severity, Impact, Likelihood, Description, Proof of Concept, Recommendation, References)
5. **Tools used** — Slither version, Aderyn version, Solodit (if used)
6. **Disclaimer** — standard audit disclaimer

After writing the report, present it to the user.

**Exit condition:** `audit-report.md` exists, contains all verified findings, and has been presented.

---

## Working principles

- **Skepticism over speed.** A wrong "Critical" finding destroys the audit's credibility. When in doubt, verify again.
- **Show your work.** Every finding must trace to specific lines of code and a clear attack path. "This looks unsafe" is never a finding.
- **Universal patterns first.** Reentrancy, access control, arithmetic, oracle manipulation, and MEV apply to nearly everything. Always check them, even on "simple" contracts.
- **Trust the checklist.** It exists because every item on it has caused real losses. Don't skip items because they "seem unlikely" — that's how real bugs ship.
- **Don't report what isn't a bug.** Style issues, gas optimizations, and "I would have written this differently" go in Informational at most, or are omitted entirely. Severity inflation is a tell of a bad audit.

## Reference files

- `references/checklist-cyfrin.json` — primary checklist (Phase 3a)
- `references/checklist-swc.md` — SWC registry summary (Phase 3b)
- `references/mev.md` — MEV review checklist, always loaded (Phase 3c)
- `references/tooling.md` — how to invoke and read Slither/Aderyn (Phase 2)
- `references/false-positives.md` — concrete FP patterns per detector, used in Phase 2 triage
- `references/findings-template.md` — finding format (Phase 6)
- `references/protocols/*.md` — protocol-specific deep dives (Phase 4)

## Scripts

- `scripts/scope_contracts.sh` — enumerate contracts, LOC, imports (Phase 1)
- `scripts/run_static_analysis.sh` — wrapper for Slither + Aderyn (Phase 2)
