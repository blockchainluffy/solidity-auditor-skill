# Perpetuals (Perps) Audit Reference

Load when the contract is a perpetual futures DEX (GMX, Synthetix Perps, dYdX v3 contracts, Hyperliquid contracts, Drift, vAMM-based perps, custom). Perpetuals combine the complexity of derivatives, oracles, AMMs, and lending — the bug surface is enormous.

## The core invariant

A perp DEX must maintain: `sum(longPositions) - sum(shortPositions) ≈ 0` (open interest), and the protocol must be able to pay all profitable positions.

**Audit checks:**
- Is OI tracked correctly per market and per side?
- Is the protocol's solvency check accurate (sum of unrealized PnL across all positions)?
- Can a position be opened that the protocol cannot close (insufficient counterparty depth)?

## Mark price vs index price

- **Index price**: the "fair" price, typically from oracles (Chainlink, Pyth).
- **Mark price**: used for PnL and liquidation calculation. Often a function of index price ± funding adjustment, or a TWAP.

**Audit checks:**
- Is mark price manipulation-resistant?
- Divergence between mark and index: bounded? Can a manipulator profit from creating divergence?
- For vAMM perps: mark price comes from the vAMM curve. Manipulating vAMM = manipulating mark price = manipulating own PnL.
- Liquidation uses mark or index? Each has tradeoffs.
- Funding is paid based on mark-vs-index difference; if calculation is wrong, funding becomes a value-extraction vector.

## Funding rate

Funding is paid between longs and shorts to keep mark close to index.

**Audit checks:**
- Funding rate formula: typically `clamp(premium / interval, -maxFundingRate, +maxFundingRate)` where premium = (mark - index) / index.
- Is the rate clamped to prevent extreme values?
- Funding interval: 1 hour, 8 hours, continuous? Continuous is less gameable.
- Funding payment timing: paid on every interaction or accrued?
- Can a position avoid funding by closing and reopening at the right moment?
- Can someone repeatedly trigger funding accruals to exploit precision loss?

## Liquidations

Positions liquidate when margin ratio falls below maintenance.

**Audit checks:**
- Maintenance margin formula: includes funding accrued? Includes pending fees?
- Health calculation: uses mark price. Manipulating mark price → unfair liquidations.
- Liquidation incentive: paid from position's collateral. If too small, no liquidator shows up; if too big, healthy positions get liquidated for the bonus.
- Partial liquidations: position should remain healthy after partial liq. Verify the math doesn't over-liquidate.
- Liquidation cascades: high-leverage positions liquidate during volatility, moving mark, liquidating more positions. Stress-test scenario.

## ADL (Auto-Deleveraging)

When the insurance fund is depleted, profitable positions on the opposite side may be force-closed (ADL).

**Audit checks:**
- ADL trigger condition: insurance fund <= threshold? Or specific solvency check?
- ADL ordering: highest-PnL or highest-leverage positions first? Document the ordering.
- ADL price: at mark? Can the deleveraged trader claim more?
- Can ADL be triggered maliciously to force-close someone's position?

## Insurance fund

Absorbs bad debt from underwater liquidations.

**Audit checks:**
- Funded by: liquidation fees, trading fees, deposits?
- Withdrawal authority: governance only?
- Solvency check: insurance fund + position margins >= sum of all profitable PnL?
- If insurance fund is empty, what's the fallback (ADL, socialized loss, protocol pays)?

## Position limits

Limits prevent any single trader from being too large to liquidate.

**Audit checks:**
- Per-account max position size enforced?
- Per-market max OI enforced?
- Position size in notional or token amount? (Different implications.)
- Can a trader bypass via multiple accounts?

## Leverage

Higher leverage = lower margin = more profitable for protocol but more risky.

**Audit checks:**
- Maximum leverage enforced at open and on increases?
- Leverage calculation: position notional / margin? Including or excluding unrealized PnL?
- Cross-margin vs isolated: each position with own margin, or shared pool?
- Cross-margin: one losing position can crater all your positions.

## Oracle latency vs funding

If oracle updates lag and funding accrues continuously, there's a window for arbitrage at protocol's expense.

**Audit checks:**
- How often is oracle price updated? How often does funding accrue?
- Can someone open a position right after a stale oracle update and front-run the next one?
- For Pyth or push-style oracles, who decides when to push? Delayed pushes = arbitrage.

## Cross-margin / collateral types

Many perps accept multiple collaterals.

**Audit checks:**
- Each collateral has its own price; must be aggregated for margin calc.
- Discount per collateral type (haircut for volatile collaterals).
- Liquidation order across collaterals: which sells first?
- Bad debt allocation when collateral price drops to zero.

## vAMM-specific (dYdX v1, Drift, GMX V1)

Virtual AMM: no real liquidity, just a math curve.

**Audit checks:**
- Funding rate must aggressively rebalance vAMM to track index, otherwise vAMM diverges and creates arb against protocol.
- K (constant product) adjustments: who can adjust, when?
- Slippage on entry: vAMM has slippage even though there's no "real" liquidity. Misaligned with index → entry at unfair price.

## GMX-style (real LP backing)

LPs provide liquidity that pays out winning traders.

**Audit checks:**
- LP token price (GLP, GM): manipulation-resistant?
- LP composition: single asset or basket? Basket has rebalancing logic.
- Trader's net PnL is paid from LP. If LP is undercollateralized, trader can't withdraw.
- Open interest skew: if all longs and few shorts, LP is short-biased and exposed.
- Maximum global PnL allowed before halting new positions.

## Specific past exploits

- **Mango Markets (2022, $114M)**: oracle manipulation via thin perp liquidity → over-borrow against inflated collateral.
- **GMX (2022)**: AVAX price manipulation extracted $565K from GLP.
- **Drift (Solana, but pattern applies)**: oracle update timing exploited.
- **Various vAMM forks**: K manipulation, funding rate gaming.
- **Hyperliquid (2024)**: JELLY incident — large position forced HLP losses, ADL deployed.

## References
- GMX docs, dYdX v4 design docs, Synthetix Perps V2 specs
- Sigma Prime "Perpetuals security considerations"
- Solodit findings on "perpetual", "funding", "liquidation", "vAMM", "mark price"
