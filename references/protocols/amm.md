# AMM (Automated Market Maker) Audit Reference

Load when the contract is or interacts with an AMM (Uniswap V2/V3/V4, Curve, Balancer, custom). AMM bugs typically manifest as price manipulation, broken invariants, or LP value extraction.

## Invariant preservation

Every AMM has a core invariant: x*y=k for V2, concentrated-liquidity ticks for V3, stableswap A*sum(x)+prod(x)*D=... for Curve, weighted bands for Balancer.

**Audit checks:**
- After every swap, is the invariant satisfied (≥, in protocol's favor due to fees)?
- Are there paths that bypass the invariant check (e.g., admin functions, hooks)?
- For custom AMMs, is the math proven correct (formal proof, fuzzing, comparison to reference)?

## Price manipulation via pools

The classic flash-loan attack: borrow → swap to skew pool → trigger oracle/dependent contract reading skewed price → unskew → profit.

**Audit checks:**
- Does any external contract read this pool's spot price (slot0 / reserves)?
- Are integrators warned against spot-reading?
- For TWAP oracles: window length, manipulation cost analysis. A 30-min TWAP costs the manipulator gas+fees over 30 min — calculate if attack profit > cost.

## Slippage and deadlines

Every swap-like function should accept user-supplied minOut and deadline.

**Audit checks:**
- Is `amountOutMin` user-supplied, not calculated by the contract?
- Is `deadline` user-supplied, single-block-ish (not far in the future)?
- For aggregator routes, is each hop's slippage bounded, or does total slippage allow a sandwich on intermediate hops?
- Default slippage values in helper functions: zero is exploitable, "infinity" is exploitable.

## LP token mint / burn

When users add/remove liquidity, LP tokens are minted/burned proportionally.

**Audit checks:**
- First mint: how is initial price set? Inflation attack possible if first LPer can manipulate ratio (Uniswap V2 uses MINIMUM_LIQUIDITY=1000 burn to address(0)).
- Mint amount calculation: `min(amountA*supply/reserveA, amountB*supply/reserveB)` — is this correct? Is excess refunded?
- Burn: `min` direction (must round in protocol's favor, against burner)?
- Donations to the pool inflate LP value (intentional in V2 but can interact poorly with V3-style positions).

## Concentrated liquidity (V3-style)

Liquidity provided in price ranges. Many additional attack surfaces.

**Audit checks:**
- Tick spacing: is the position aligned correctly? Misaligned ticks revert or produce unexpected behavior.
- Out-of-range positions earn no fees but still hold inventory — can a malicious LP flip ranges to extract value?
- JIT liquidity: deposit a tight range right before a known swap, withdraw after. The protocol may need to handle this (some V3 forks add cooldowns).
- Fee accumulation: per-position fee growth is tracked via global accumulators. Off-by-one or rounding in fee accounting can let LPs claim more or less than earned.

## Hooks (Uniswap V4-style)

V4 introduces hooks: pre-swap, post-swap, etc. Custom hooks add attack surface.

**Audit checks:**
- Hook permissions: are they immutable per pool? Can a malicious hook be installed?
- Hook reentrancy: does the hook re-enter the pool manager?
- Hook accounting: if the hook claims fees or alters amounts, is the math correct?
- For custom hooks: every external call from the hook is potential reentrancy.

## Stableswap (Curve)

Stableswap allows nearly-1:1 swaps in tight bands, then transitions to constant-product at extremes.

**Audit checks:**
- A (amplification) parameter: ramping should be bounded and admin-only.
- Imbalance fees: applied correctly to discourage one-sided liquidity additions/removals?
- "Get virtual price" — is it manipulation-resistant? Curve had a real exploit on read-only reentrancy of `get_virtual_price` during a remove_liquidity.
- For metapools (a stable + an LP token), the LP token's pricing must be correct.

## Multi-token pools (Balancer)

Weighted pools with N tokens.

**Audit checks:**
- Weight changes (gradual weight updates) — can a manipulator profit by knowing the schedule?
- Single-token deposits/withdraws: can they imbalance the pool to manipulate spot price?
- Flash loan pools: are flash loan fees correctly tracked and accumulated?

## Fees

AMMs collect fees on swaps; LPs and/or protocol get them.

**Audit checks:**
- Fee math: is it taken from the input or output? Standard is from input. Off-by-one common.
- Fee tier changes: who can change, what's the delay, can a fee change be sandwiched?
- Fee distribution: protocol fees vs LP fees split correctly?
- Zero-fee paths: are any swap paths unintentionally fee-less?

## Flash swaps

V2/V3 allow callback-based flash swaps where you receive tokens before paying.

**Audit checks:**
- Is the post-swap balance check tight (must equal pre-swap + fee)?
- Can the callback re-enter the pool's swap function and manipulate state?
- Does the callback have access to admin functions on the pool?

## Past exploits to internalize

- **Curve read-only reentrancy (2022-2023)**: `get_virtual_price` returned stale value during `remove_liquidity`. Multiple integrating protocols exploited.
- **Uniswap V3 router slippage bypass (various)**: integrators forgetting `amountOutMinimum`.
- **Balancer batch-swap fee bug (2023)**: incorrect fee accumulation in specific paths.
- **Multiple V2-fork donation attacks**: first depositor can manipulate K.
- **JIT MEV (ongoing)**: extracting value from LPs via just-in-time positions.

## References
- Uniswap V2 whitepaper, V3 whitepaper
- Curve stableswap paper
- Balancer V2 docs
- Solodit findings on "AMM", "swap", "slippage", "TWAP", "concentrated liquidity"
