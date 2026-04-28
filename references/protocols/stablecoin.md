# Stablecoin Audit Reference

Load when the contract issues, redeems, or stabilizes a stablecoin (DAI/MakerDAO, FRAX, LUSD/Liquity, GHO, crvUSD, sUSDe, custom). Load with `lending.md` if CDP-style; with `amm.md` if peg-defended via swaps.

## Stablecoin types and their unique risks

### Fiat-backed (USDC, USDT, BUSD)
Custodial; on-chain contract concerns are limited to mint/burn and blacklist. Generally not the type being audited unless the project is building one.

### Crypto-collateralized CDP (DAI, LUSD, MIM)
User locks collateral, mints stablecoin against it. Liquidation if collateral value falls.

### Algorithmic / partially algorithmic (FRAX original v1, UST historical)
Mints against a partial-collateral basket or via pure algorithm.

### Yield-bearing (sUSDe, sDAI)
Stablecoin that accrues yield to holders.

### LST-backed (eUSD-style)
Stablecoin backed by liquid staking tokens.

## Mint mechanics

**Audit checks:**
- Mint authorization: only authorized minters (CDP module, market module, etc.)?
- Mint cap: per minter, global, per asset?
- Mint fee: BPS basis points; correctly calculated, going to right destination?
- Mint atomicity: collateral lock and stablecoin mint happen in same tx, no partial state.
- Mint without collateral (algorithmic component): bounded? Trigger conditions correct?

## Redemption / burn mechanics

How stablecoin returns to underlying value or backing.

**Audit checks:**
- Redemption function: permissioned, permissionless, or rate-limited?
- Redemption price: at oracle, at peg, at CDP-defined price?
- Redemption fee: structure (flat, BPS, dynamic based on system health)?
- LUSD-style redemptions: anyone can redeem against the riskiest CDPs at face value, paying down their debt. Verify the queue ordering (lowest collateralization ratio first), the redemption fee adjusts dynamically, and CDPs at risk of redemption are aware.
- Atomic burn: burn-then-collateral-release, no partial state.

## Stability mechanism

How the peg is maintained.

**Audit checks:**
- Mint above peg, redeem below peg → arbitrage closes the gap. Verify both directions are permissionless and atomically executable.
- PSM (Peg Stability Module): swap stablecoin <-> external stablecoin (USDC) at 1:1 with cap. Cap correctly enforced? Fee on swap?
- Stability fee / interest rate on borrowed stablecoin: accrues per second, captured on every interaction?
- Savings rate (DSR-style): correctly distributed to holders without inflating supply?

## CDP-specific (Maker/Liquity-style)

**Audit checks:**
- Collateral types: each has its own risk parameters (liquidation ratio, fee, debt ceiling).
- Per-vault accounting: separate from global so one bad vault can't taint others.
- Liquidation: see `lending.md` — applies fully here.
- Bad debt absorption: socialized via dilution, taken by a stability pool (Liquity), or absorbed by protocol surplus (Maker)?
- Emergency shutdown / global settlement: if the system needs to wind down, every CDP holder can claim collateral pro-rata. Correctly implemented?

## Oracle dependencies

Stablecoins lean heavily on oracles for collateral pricing.

**Audit checks (also see general oracle list):**
- Single oracle vs aggregate: one oracle compromise = total compromise.
- Price freshness: if oracle is stale, do mints/liquidations halt?
- Manipulation cost vs attack profit: especially relevant if collateral has thin liquidity.
- For stablecoin pricing itself (in PSM, in lending): is "the stablecoin = $1" assumed? Then a depeg breaks all integrations.

## Yield-bearing stablecoins (sDAI, sUSDe)

**Audit checks:**
- Yield source: where does it come from? Treasury bills, lending, basis trade?
- Distribution: ERC4626 share-style or rebasing?
- Yield manipulation: can a flash deposit JIT the yield distribution?
- Backstop for yield-source loss: who absorbs (e.g., funding rate goes negative on basis trade)?
- Withdrawal: instant or queued? If queued, can users escape before bad news propagates?

## Depeg handling

What happens when the peg breaks.

**Audit checks:**
- Below peg: mint disabled? Liquidations on stablecoin-collateralized loans cascade?
- Above peg: redemption capped to prevent supply collapse?
- Recovery mode (Liquity-style): heightened requirements during stress?
- Lending markets accepting the stablecoin as collateral: does the depeg cascade into them?

## Algorithmic / hybrid risks

Algorithmic components are inherently fragile.

**Audit checks:**
- Backing ratio: how is it measured? Can it be temporarily inflated?
- Death spiral conditions: if peg breaks, does the algorithmic component reduce backing further (UST/LUNA)?
- Backstop reserves: how much, controlled by whom?
- Circuit breakers: pause mint when backing < threshold?

## LST-backed stablecoins

**Audit checks:**
- LST exchange rate query: manipulation-resistant, fresh, used correctly?
- LST slashing exposure: directly reduces backing.
- LST de-peg: if stETH:ETH falls, the stablecoin's collateralization drops.
- Composability: lending against this stablecoin where the stablecoin is backed by an LST you also accept as collateral creates correlation risk.

## Specific past events to internalize

- **UST (May 2022, $40B)**: algorithmic depeg → terra death spiral.
- **DAI (March 2020 "Black Thursday")**: Ethereum congestion + price drop → underwater liquidations bid at zero → bad debt.
- **MIM (2022)**: bad debt from CRV positions, recovery via governance.
- **USDC (March 2023)**: SVB exposure → temporary depeg to $0.88; multiple stablecoin protocols accepting USDC as backing depegged in turn.
- **FRAX, others**: governance-controlled minter risk.

## References
- Maker docs, Liquity whitepaper, FRAX docs
- crvUSD design docs (LLAMMA)
- sUSDe / Ethena docs
- Solodit findings on "stablecoin", "peg", "CDP", "redemption", "PSM", "depeg"
