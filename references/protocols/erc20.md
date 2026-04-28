# ERC20 Audit Reference

Load when the contract is or interacts with ERC20 tokens. Most "DeFi" contracts qualify. The non-standard token landscape is the source of countless real bugs — see d-xo/weird-erc20 for canonical examples.

## Non-standard ERC20 behaviors to handle

### Fee-on-transfer (FoT) tokens
Tokens like SAFEMOON, some forks of REFLECT, and many memecoins charge a fee on transfer. `token.transfer(to, 100)` may result in `to` receiving 95.

**Audit checks:**
- After `transferFrom`, does the protocol assume the full amount arrived? Compare `balanceAfter - balanceBefore` to expected.
- Does the protocol use the user-supplied `amount` in subsequent accounting, or the actual delta?
- Are deposit functions reentrant-safe given that FoT can interact with custom logic on transfer?

### Rebasing tokens (stETH, AMPL, OHM v1)
Balances change without a transfer. If the protocol caches a balance, it goes stale.

**Audit checks:**
- Is `balanceOf` called fresh whenever needed, or is a cached value reused?
- For accounting in shares, are share/asset conversions stable across rebases?
- Is there a "hidden" rebasing token via wrapping (e.g., wstETH/stETH confusion)?

### No-return-value tokens (USDT)
USDT's `transfer` returns nothing on mainnet. Calls expecting `bool` return revert because the ABI mismatches.

**Audit checks:**
- Is SafeERC20 (or equivalent) used, which handles both styles?
- Are direct `transfer` / `transferFrom` calls present? Flag all of them.

### Tokens with blacklist (USDC, USDT, BUSD)
Issuer can blacklist an address, breaking flows that depend on transferring to/from that address.

**Audit checks:**
- If a fixed recipient (treasury, yield collector) gets blacklisted, does the protocol continue to function?
- Can a user be locked out by being blacklisted mid-flow?
- For pull-pattern, is blacklist a per-user issue (acceptable) or systemic (DoS)?

### Tokens with hooks (ERC777, ERC1363)
Calls to recipient before/after transfer enable reentrancy.

**Audit checks:**
- Treat any token transfer as a potential external call.
- Apply CEI even if the token is "supposed to" be standard ERC20 — at deployment time the token list may include ERC777-compatible ones.

### Pause-able tokens
Token can be paused mid-flow.

**Audit checks:**
- Does the protocol survive a paused token? Are user funds locked indefinitely or rescuable?

### Multiple-address tokens (proxied/upgradeable tokens)
The token's logic can change. A protocol that hardcoded a quirk now has different behavior.

**Audit checks:**
- Are upgradeable tokens treated as untrusted external code? Each call is a potential reentrancy.

### Tokens that revert on zero-amount transfers
Some tokens revert on `transfer(to, 0)`. Code that doesn't guard against zero-amount transfers will DoS.

**Audit checks:**
- Are all transfers guarded with `if (amount > 0)` or do they intentionally tolerate failure?

### Tokens with > or < 18 decimals
USDC: 6. WBTC: 8. Most ERC20: 18. Some have 0 (NFT-like) or 24+ (rare).

**Audit checks:**
- Are decimal assumptions hardcoded as 18?
- When normalizing for math, is decimal scaling done correctly without overflow?
- For oracle prices that come in 8-decimal Chainlink format, is the conversion correct?

### Tokens with extreme supply
Some tokens have supply close to or exceeding `uint256.max / 1e18` (intentional, like SHIB).

**Audit checks:**
- Does any multiplication (e.g., `balance * price`) overflow even in 0.8.x for high-supply tokens?
- Use FullMath / mulDiv or downscale before multiplying.

### Permit (EIP-2612) issues
- Anyone can call permit on behalf of a signer (the relayer) — is this desired?
- Permit signature replay across forks (no chainid in signature on old impls)
- Front-running permit + transferFrom (DAI's permit allowance race)

## Approval patterns

- `approve(spender, max)` is a standard pattern but increases blast radius if spender is compromised.
- `approve(0)` then `approve(n)` is required for tokens like USDT that don't allow direct overwriting.
- `increaseAllowance` / `decreaseAllowance` mitigate the race where attacker spends old allowance after seeing new one.
- Permit-based flows should validate the deadline server-side.

## ERC20 in protocol code

When a protocol accepts arbitrary ERC20s (e.g., a generic vault), assume the worst case for every check above. When a protocol whitelists tokens, verify the whitelist mechanism is admin-controlled and that the whitelist matches the assumptions in the code.

## References
- d-xo/weird-erc20 — canonical list of weird tokens
- OpenZeppelin SafeERC20 — wraps the common issues
- Solodit findings on "fee-on-transfer", "rebasing", "blacklist" — many real exploits
