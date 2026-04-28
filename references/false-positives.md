# False Positive Pattern Library

A library of concrete FP patterns for static analysis tools (Slither, Aderyn). Use this in Phase 2 triage to recognize FPs faster and avoid dismissing real bugs that look like FPs.

**How to use this file:** When the static analyzer reports a finding, look up the detector here. Each pattern has:
- **Recognition signal** — the syntactic/contextual pattern that suggests FP
- **Why it's FP** — the reason the tool over-fires
- **NOT FP when** — inversion cases where the same pattern is real

If the finding matches "Recognition signal" AND none of the "NOT FP when" conditions apply → mark FP in triage.
If any "NOT FP when" condition applies → mark Real or Investigate.
If neither — the pattern doesn't match this entry — fall through to general reasoning.

---

## Slither detectors

### `reentrancy-eth` / `reentrancy-no-eth`

**Pattern 1: External call to constant/immutable trusted address**
- Recognition: the called address is `immutable`, set in constructor from a constructor argument, AND is a known protocol contract (not user-controllable).
- Why FP: the receiving contract cannot reenter unless it's also part of the protocol with malicious code, which is a much bigger problem than reentrancy.
- NOT FP when:
  - The "trusted" address is upgradeable (proxy) — upgrade authority becomes a reentrancy vector.
  - The address is set via a setter callable post-deployment.
  - The protocol accepts arbitrary tokens, and the call is `token.transfer(...)` where token is one of those.

**Pattern 2: Reentrancy on view-only path**
- Recognition: Slither flags reentrancy because of an external call, but the external call is to a `view`/`staticcall` function and no state is read after.
- Why FP: a view call cannot reenter and modify state; even if it could, no subsequent code reads state.
- NOT FP when:
  - The "view" function is on an upgradeable contract (could become non-view in next upgrade).
  - There's a subsequent state read whose value is consumed in a security-critical decision (read-only reentrancy à la Curve).

**Pattern 3: CEI followed correctly, no actual state read after call**
- Recognition: state changes happen before the external call AND no state is read or written after the call returns.
- Why FP: Slither flags any external call followed by code, but if the post-call code doesn't depend on state that could be manipulated by reentrancy, there's no exploit.
- NOT FP when:
  - Post-call code emits an event whose values came from pre-call state — usually fine, but verify the event values aren't security-critical.
  - There's a `return` of a value computed from state read after the call — this is read-only reentrancy.

**Pattern 4: ReentrancyGuard already applied**
- Recognition: the function has `nonReentrant` modifier (or equivalent custom guard).
- Why FP: the guard prevents reentrancy by definition.
- NOT FP when:
  - The guard is on the wrong function (cross-function reentrancy not blocked because guard is per-function and the reentry target isn't guarded).
  - The guard contract has its own bugs (uncommon but possible).
  - The contract uses multiple guards and they're not unified (e.g., two separate `ReentrancyGuard` instances on different facets of a Diamond).

### `reentrancy-benign`

Almost always FP unless there's a hook-supporting token in the call path. Default: dismiss with reason "no security-relevant state changes after external call." Investigate if:
- The call is to an arbitrary token that could be ERC777/ERC1363/ERC1155 with hooks.
- The contract is generic and accepts any token.

### `arbitrary-send-eth`

**Pattern 1: Send to fixed admin/owner role**
- Recognition: `payable(owner).transfer(...)` or `payable(treasury).call{value: x}("")` where target is admin-controlled and not user-controllable.
- Why FP: not "arbitrary" — admin role is presumed trusted.
- NOT FP when:
  - The role can be granted to anyone (e.g., via a permissionless function).
  - The role is owned by an EOA without timelock — flag as centralization risk in Informational.

**Pattern 2: Send to msg.sender after authorization check**
- Recognition: function does `require(authorized[msg.sender])` then sends to msg.sender.
- Why FP: only authorized callers can trigger; "arbitrary" doesn't apply.
- NOT FP when:
  - The authorization check is bypassable.
  - The amount sent is user-controlled and uncapped.

### `unchecked-transfer` / `unchecked-lowlevel`

**Pattern 1: Intentional fire-and-forget**
- Recognition: comment says "intentionally ignore failure" or pattern is fee distribution where one recipient failing shouldn't break the whole flow.
- Why FP (sometimes): griefing-resistant pull pattern is sometimes implemented via push-with-tolerance.
- NOT FP when:
  - The call is `token.transferFrom(user, ...)` and the protocol assumes the transfer succeeded (most common real bug).
  - Subsequent logic depends on the transfer having succeeded.

**Pattern 2: Standard ERC20 known-good token**
- Recognition: token is a hardcoded protocol token with standard `transfer`/`transferFrom` returning bool.
- Why FP: technically the return is unchecked, but the token always returns true.
- NOT FP when:
  - The token is upgradeable.
  - The token is one of multiple supported tokens (one might be USDT-style or non-conformant).
  - **Default:** still recommend SafeERC20 in Informational, even when not Real.

### `incorrect-equality`

**Pattern 1: Equality on owner-set immutable values**
- Recognition: `if (caller == admin)` or comparison to a constant.
- Why FP: equality is correct here.
- NOT FP when:
  - The equality is on `balanceOf(this) == expected` — direct token transfer can break this.
  - The equality is on an oracle-derived or user-derived value.

**Pattern 2: Strict equality on token balances**
- Recognition: `require(balanceOf(this) == X)` or similar.
- Why FP: rarely. Almost always Real because anyone can `transfer` directly to the contract.
- NOT FP when: never assume FP without strong justification.

### `divide-before-multiply`

**Pattern 1: Intentional fixed-point arithmetic**
- Recognition: division by a precision constant (1e18, 1e27 RAY, 1e6) followed by multiplication.
- Why FP: the precision constant is large enough that intermediate truncation is acceptable; the alternative (multiply first) would overflow.
- NOT FP when:
  - The values are small enough that truncation is significant (e.g., USDC with 6 decimals, small balance).
  - The order can be swapped without overflow risk — recommend swapping anyway.

### `weak-prng`

**Pattern 1: Used for non-security-critical purpose**
- Recognition: `block.timestamp` used as a nonce, ID seed, or jitter.
- Why FP: predictability doesn't grant exploit advantage.
- NOT FP when:
  - Used for prize distribution, NFT trait reveal, lottery — always Real.
  - Used as a tiebreaker in any value-affecting decision.

### `timestamp`

**Pattern 1: Long-window time check**
- Recognition: `block.timestamp + 7 days`, deadline checks where window >> miner manipulation (~12 sec).
- Why FP: miner can shift timestamp by a few seconds, irrelevant for day-scale logic.
- NOT FP when:
  - Window is < 1 minute.
  - Used for randomness (see weak-prng).
  - Used in a way where a few-second shift changes outcome (e.g., auction tiebreaker).

### `solc-version` / `pragma`

Almost always Informational, never Real. Mark FP for the candidate list and include in Informational section of report only if the version is known-buggy.

### `naming-convention`

Always Informational, never a finding. Skip.

### `dead-code`

**Pattern 1: Unused inheritance interface**
- Recognition: function in an inherited interface not used by the deriving contract.
- Why FP: contract is interface-compliant; the function may be used by external integrators.
- NOT FP when:
  - The dead code is a function that *should* be called (e.g., a hook that's defined but never invoked from the path it's supposed to fire on).

### `external-function`

Optimization-level suggestion. Skip.

### `uninitialized-state` / `uninitialized-storage`

Almost always Real. The few FPs are when Slither doesn't trace the initialize function correctly (proxy patterns).

**Pattern 1: Initialized via initialize() in upgradeable contract**
- Recognition: state variable set in `initialize()` not constructor; Slither doesn't always recognize this.
- Why FP: variable is initialized in proxy deployment.
- NOT FP when:
  - The `initialize()` is callable post-deployment by anyone (initializer race).
  - The variable is never set by any path.

### `controlled-delegatecall`

Almost always Critical. The only FP case: the target is a fixed immutable trusted library set in constructor. Even then, audit the library carefully.

### `tx-origin`

Always Real. No FP exception.

---

## Aderyn detectors

### `centralization-risk` / `admin-functions-with-large-impact`

Aderyn flags this on every `onlyOwner` / `onlyRole` function. Most are intentional.

**Pattern 1: Standard admin function with timelock**
- Recognition: function is `onlyOwner` or `onlyRole(ADMIN)` AND owner is a timelock or governance contract.
- Why FP: standard governance pattern, not a vulnerability.
- NOT FP when:
  - Owner is an EOA with no timelock.
  - Owner is a 1/N or 2/N multisig (low threshold).
  - Function can drain all funds with no delay.
  - **In all cases:** include as Informational with centralization disclosure, even when not Real.

### `missing-events` / `events-not-emitted-on-state-change`

Almost always Informational, not a security issue. Include in Informational section only if event would be useful for monitoring (state changes affecting user funds).

### `block-timestamp-deadline`

Aderyn flags `block.timestamp + N` in deadline contexts. See Slither `timestamp` patterns above — same logic.

### `loops-over-unbounded-arrays`

**Pattern 1: Array bounded by protocol-controlled write**
- Recognition: array is only appended to by `onlyOwner` / governance function with a hardcoded cap.
- Why FP: gas DoS not reachable by attacker.
- NOT FP when:
  - Array is appended to by any user (e.g., one entry per user) — Real.
  - The cap can be raised by admin without bound — flag as Low.

### `boolean-equality`

`x == true` instead of `x` — style issue. Always Informational. Skip.

---

## Common patterns across both tools

### Cross-tool duplicates

When Slither and Aderyn both flag the same line for the same root cause:
- Pick the higher-severity classification.
- Pick the more specific detector name in the triage record.
- Count as one finding, not two.

Recognition: same `(file, line_range)`, same vulnerability description in essence. Slither's `reentrancy-eth` and Aderyn's `state-change-after-external-call` are often the same finding.

### "FP-shaped" Real bugs to watch for

Sometimes a finding looks textbook-FP but is actually Real because of context. Don't auto-dismiss these patterns:

1. **Reentrancy on what looks like a trusted token** — but the token is upgradeable or accepts hooks.
2. **`unchecked-transfer` on "standard" ERC20** — but the token list includes USDT or fee-on-transfer tokens.
3. **`block.timestamp` in a multi-day window** — but it's used for randomness or short-window logic that an attacker controls.
4. **Centralization on `onlyOwner`** — but the owner is an EOA with no timelock, no multisig, and the function can rugpull.
5. **`incorrect-equality` on integer math** — but the integers are user-controllable and the equality is exploited via direct transfer.

When in doubt, mark **Investigate** and resolve in Phase 3 manual review with full context.

---

## When to update this file

This is a living reference. Add patterns when:
- A real audit surfaces a recurring FP not yet documented.
- A pattern previously thought FP turns out to have a real-bug variant.
- A new tool is added to the static analysis pipeline.

Each addition should follow the same format: Recognition signal, Why FP, NOT FP when.
