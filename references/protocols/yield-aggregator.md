# Yield Aggregator Audit Reference

Load when the contract is a yield aggregator / vault that deploys to strategies (Yearn V2/V3, Beefy, Convex/Aura, custom auto-compounders). Often combines with `erc4626.md` (most modern aggregators are 4626).

## Strategy interface

Vaults delegate yield generation to strategies.

**Audit checks:**
- Trust model: strategy is fully trusted, partially trusted, or untrusted?
- If trusted: strategy upgrades, who controls?
- If untrusted: how does the vault verify reported balances? Is the strategy's `estimatedTotalAssets` manipulable?
- Strategy can lose funds (impermanent loss, exploit). Does the vault socialize losses pro-rata or absorb them?

## Harvest / compound mechanics

Strategies periodically harvest rewards, swap, redeposit.

**Audit checks:**
- Harvest function permissioning: keeper-only, governance-only, permissionless?
- Permissionless harvest: front-runnable for sandwich attacks on swap legs.
- Harvest swap path: hardcoded or admin-set? If hardcoded, AMM liquidity changes can move slippage.
- Slippage protection on harvest swaps: parameter-controlled or algorithmic?
- Profit unlocking: instant (JIT-attackable) or vested over time (e.g., Yearn's lockedProfit)?
- Harvest fee / performance fee: deducted at harvest, sent to treasury — calculation correct?

## JIT deposit attacks on harvests

Classic attack: deposit just before harvest, withdraw just after.

**Audit checks:**
- Is profit added to `totalAssets()` instantly, or vested?
- Vesting period: long enough to deter JIT? Yearn uses 6 hours; depending on protocol size, may need more.
- Front-running protection: commit-reveal on deposits, deposit windows?
- Is deposit/withdraw paused during harvest?

## Multi-strategy vaults

Yearn V2/V3 vaults may have multiple strategies with allocation weights.

**Audit checks:**
- Allocation logic: who decides? How is rebalancing triggered?
- During rebalance: vault total assets accuracy maintained?
- Strategy migration (one strategy replaced by another): all funds transferred? No loss in migration?
- Underflow when withdrawing: if user requests more than one strategy holds, does vault correctly draw from multiple?
- Strategy "loss" reporting: strategy can report a loss to vault. Cap on accepted loss per harvest, otherwise rogue strategy can drain.

## Withdrawal from strategies

When user withdraws, vault may need to pull from strategies.

**Audit checks:**
- Withdrawal queue: order of strategies to withdraw from?
- Liquidation slippage on emergency withdraw: does the vault accept a loss to fulfill the withdraw, or revert?
- Per-block withdrawal limits: prevent bank runs but bound DoS surface.
- Loose accounting: if strategy has 100 but reports 90, vault thinks 90 — withdrawal of 95 fails despite available funds.

## Asset selection and risk

Aggregators put user funds into strategies that take various risks.

**Audit checks (mostly informational, but real risks):**
- Each strategy's underlying protocol(s): risk level disclosed?
- Strategy code reviewed separately?
- Strategy deployment: who deploys, who can change parameters?
- Risk caps: max deposit per strategy?

## Performance fee mechanics

Aggregators usually take a cut of profits.

**Audit checks:**
- Performance fee calculation: high water mark, simple percentage, or vesting?
- Without HWM: user can be charged on profit they never benefited from (deposit in loss, withdraw at original price).
- Fee collection: when (per harvest, per deposit, per withdraw)?
- Fee receiver: governance-set, immutable, or per-strategy?

## Reward token claiming

Strategies often claim reward tokens (CRV, COMP, PENDLE, etc.) and swap.

**Audit checks:**
- Claim function permissions: who can call, when?
- Claim race: can a non-strategy contract claim before strategy?
- Reward token list: hardcoded, admin-set?
- Claim fees: some protocols charge for claiming; are these accounted for?
- Reward distribution timing: rewards arriving in the middle of a harvest can confuse accounting.

## Migrations and upgrades

Vaults often need to migrate (e.g., to a new strategy version).

**Audit checks:**
- Migration authority: governance only?
- Atomic migration: no funds lost mid-flight?
- User opt-in: do users get a chance to exit before migration?
- Rollback: if new strategy fails, can we revert?

## Specific past exploits

- **Yearn yDAI v1 (2021)**: dForce flash loan exploit, $11M.
- **Cream Iron Bank (2021)**: protocol abuse via Yearn oracle.
- **Beefy / various (multiple)**: strategy-specific issues, often around Convex or Aura integration.
- **Pickle Finance jar (2020)**: $19M lost via swap manipulation.
- **Inverse cvxFXS (2022)**: oracle issue in vault pricing.

## Specific patterns to watch

- **Donation attacks** (covered in erc4626.md) — relevant here since aggregators are usually ERC4626.
- **Slippage in compound swaps**: harvest swap with no slippage = sandwich-able.
- **Compound paths through low-liquidity pairs**: harvested rewards swapped through thin pools = high slippage = MEV bait.
- **Unbounded reward array**: list of reward tokens grows without bound, gas DoS on harvest.

## References
- Yearn V3 docs (the modern reference impl)
- Beefy docs
- Solodit findings on "yield", "aggregator", "harvest", "strategy", "compound"
