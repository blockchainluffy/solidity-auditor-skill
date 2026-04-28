# Lending Protocol Audit Reference

Load when the contract is a lending market (Aave/Compound-style, isolated markets, money markets, NFT lending). Lending bugs are typically the most catastrophic in DeFi (Cream, Inverse, Euler — all lending protocols).

## Collateral / debt accounting

The core invariant: `sum(collateralValue) >= sum(debtValue) * collateralFactor` for every account.

**Audit checks:**
- Can `collateralValue` be inflated (oracle manipulation, fake balance, donation)?
- Can `debtValue` be deflated (interest miscalculation, repayment without state update)?
- Edge cases: zero-debt account treated correctly; zero-collateral account; account with one of many supported assets.
- Cross-asset accounting: when a user has 5 collaterals and 3 debts, are all 8 priced and summed correctly?

## Oracle integration

Lending depends critically on oracles. Most lending exploits are oracle-related.

**Audit checks (in addition to general oracle checklist):**
- For volatile collaterals, is the oracle update frequency adequate (heartbeat short enough)?
- During market stress (depeg, sudden moves), does the oracle return believable values, or does it freeze?
- Is the oracle manipulation cost > attack profit? Document the threshold.
- Does the protocol use a single oracle or aggregate multiple?
- Fallback oracle behavior: does it fail safe (revert) or fail open (use stale)?

## Liquidations

Liquidations remove bad debt by selling collateral at a discount.

**Audit checks:**
- Liquidation incentive: high enough to attract liquidators in normal conditions, not so high that it incentivizes liquidating barely-unhealthy positions?
- Partial liquidations: limited correctly so position becomes healthy, not over-liquidated?
- Healthy positions: cannot be liquidated under any circumstances (verify the health check is correct).
- Self-liquidation: profitable? Allowed? (Some protocols disallow.)
- Liquidator's collateral receipt: in collateral token or in market shares? Each has different semantics.
- Bad debt: when collateral < debt, who eats the loss? Insurance fund, socialized, or protocol absorbs?

## Interest rate model

Borrow APY usually a function of utilization. Supply APY = borrow APY × utilization × (1 - reserve factor).

**Audit checks:**
- Is interest accrued on every interaction, or lazily?
- If lazily, can a state change happen between accruals causing miscounting?
- Can interest underflow/overflow at extreme utilization or after long inactivity?
- Reserve factor: applied at the right time? On accrued interest only, not principal?
- Kinked rate model: at the kink, is the rate continuous?
- Variable + stable rates (Aave): conversion paths between them, edge cases.

## cToken / aToken / shares accounting

Users hold a receipt token representing their deposit + accrued interest.

**Audit checks:**
- Exchange rate calculation: `(totalCash + totalBorrows - totalReserves) / totalSupply`. Is each component correct?
- Empty market: `totalSupply == 0` should not divide-by-zero; usually has an initial exchange rate.
- Donation to the market: does it inflate exchange rate harmfully? Compound's `redeemTokens` rounding lets this be a problem in empty markets (Hundred Finance exploit).
- Mint / redeem rounding: in protocol's favor.

## Flash loans

Most lending protocols offer flash loans; the loan must be repaid + fee in the same tx.

**Audit checks:**
- Repayment check: balance after >= balance before + fee. Is balance read freshly?
- Reentrancy during flash loan: can the borrower re-enter to take another flash loan? Does this matter?
- Flash loan fee accumulation to reserves: correct?
- Flash loans of the protocol's own debt (not just deposits) — possible? Implications?

## Collateral types

Each collateral type has unique risk.

**Audit checks:**
- LP tokens as collateral: pricing them requires careful math (V2 LP fair-pricing formula, V3 positions are non-fungible).
- Interest-bearing tokens (aToken, cToken) as collateral in another lending market: rebasing/exchange-rate behavior.
- Long-tail tokens: thin liquidity → liquidation can't sell collateral → bad debt.
- Tokens with > 18 decimals or extreme supply: math overflow.
- Pause-able collateral: paused mid-liquidation locks bad positions.

## Borrow caps and supply caps

Caps limit blast radius.

**Audit checks:**
- Caps enforced on every entry path (deposit, borrow, mint, transferFrom received as deposit)?
- Cap reached during liquidation: does it block liquidations?
- Cap interaction with rewards: legitimate users locked out, attackers got in early?

## Isolated vs cross-margin

Isolated markets cap risk per market; cross-margin lets one bad asset taint the whole portfolio.

**Audit checks:**
- For isolated markets, is each market's accounting independent?
- For cross-margin, is one asset's deval immediately reflected in all dependent positions?
- Mode switching (isolation → cross): atomic, or window for exploit?

## Supply / borrow side asymmetries

Supply rates depend on utilization; borrows can be capped.

**Audit checks:**
- Can a single attacker borrow enough to push utilization to 100%, locking suppliers? (Borrow cap mitigates.)
- Can supply be artificially deflated to spike rates?

## Specific past exploits

- **Cream Finance (2021)**: AMP/IRON oracle manipulation, $130M.
- **Inverse Finance (2022)**: yvDOLA price manipulation via Curve LP, $5.8M.
- **Euler (2023)**: donateToReserves logic bug, $197M.
- **Hundred Finance (2023)**: empty market + ERC4626-style inflation, $7M.
- **Mango Markets (2022)**: oracle manipulation via thin-liquidity perp.
- **Compound (2023)**: cETH redemption bug (caught in audit).
- **Lots of Compound forks**: bad collateral added without proper risk parameters.

## References
- Compound v2 docs (the canonical implementation)
- Aave v2/v3 docs
- Sigma Prime "DeFi Attack Vectors"
- Solodit findings on "lending", "liquidation", "oracle", "bad debt", "interest rate"
