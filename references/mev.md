# MEV Review (always-on)

Apply this checklist to every state-changing entry point during Phase 3c, regardless of protocol type. MEV bugs exist in nearly every protocol that touches value — including ones that don't look "DeFi" (NFT mints, governance, airdrops, even oracle pushes).

The core question for every external function: **what happens if a searcher orders this transaction adversarially relative to other pending transactions?**

## 1. Sandwich attacks

**Pattern:** Attacker sees user's swap in the mempool, frontruns to move price, lets user execute at worse price, backruns to revert price and pocket the difference.

**Where it appears:**
- Any swap function on an AMM
- Any function that buys/sells through a DEX (even indirectly — e.g., a vault that swaps reward tokens)
- Liquidations that swap collateral
- Treasury ops that trade

**Checks:**
- Is there a `minAmountOut` (slippage) parameter on every swap?
- Is the `minAmountOut` user-controlled and meaningful, or hardcoded to 0 or near-0?
- Are deadlines used and reasonable (single block, not days in the future)?
- For internal swaps (vault rebalance, harvest), is slippage protection set by an admin or pulled from a manipulable source?
- For functions that swap on user's behalf without a user-supplied min, where does the min come from? An oracle? Then the oracle is now a MEV vector.

## 2. Frontrunning state changes

**Pattern:** Attacker sees a profitable transaction in the mempool and submits theirs first.

**Where it appears:**
- Approval-then-action (classic ERC20 approve race)
- Auction bids (frontrun to underbid)
- First-claim flows (first to claim wins something)
- Initialization functions (`initialize()` on proxies — frontrun-deployment to seize ownership)
- Privileged role grants (set the role to attacker before the legitimate setter)
- Whitelisting (frontrun to be on the list, or to bypass it)

**Checks:**
- Are critical setup functions (`initialize`, role setup) called atomically in the deployment transaction?
- Are auctions / first-come flows protected (commit-reveal, sealed-bid, time delays, randomization)?
- For approval-based flows, is `increaseAllowance/decreaseAllowance` used or a permit?

## 3. Backrunning

**Pattern:** Attacker submits a transaction immediately after a profitable state change.

**Where it appears:**
- Oracle updates (backrun to liquidate, arb a stale-then-fresh price)
- Reward distributions (backrun the harvest to claim outsized share)
- Pool rebalances (backrun the rebalance for arb profit)
- Unpause events (backrun unpause to dump or buy)

**Checks:**
- Are oracle updates and dependent actions atomic (single tx) or split (vulnerable window)?
- After a `harvest()` / `compound()`, can a fresh deposit immediately claim a share of just-compounded rewards? Look for "JIT-deposit attacks."
- Are there cooldowns between deposit and claim?

## 4. JIT (Just-in-time) liquidity / deposits

**Pattern:** Deposit immediately before a value-distributing event, withdraw immediately after.

**Where it appears:**
- AMMs distributing fees pro-rata to LPs at a moment in time
- Vaults harvesting and immediately distributing yield to current depositors
- Staking contracts with reward checkpoints
- ERC4626 vaults during high-yield events

**Checks:**
- Does deposit-then-immediate-withdraw extract value from existing depositors?
- Are there minimum lock periods?
- Are rewards accrued continuously (per-second/per-block) rather than distributed at discrete events?
- Does the vault checkpoint user shares before allowing them to participate in the next reward?

## 5. Oracle update MEV

**Pattern:** Oracle price updates create predictable opportunities — frontrun the user transaction that depends on the old price, or backrun the update for liquidation/arb.

**Where it appears:**
- Lending: liquidations on oracle updates
- Stablecoins: redemption arbitrage
- Perps: funding rate updates, mark price changes
- Options: settlement at oracle prices

**Checks:**
- Is there a TWAP or commit-reveal between price updates and execution?
- Are liquidations open to anyone (and thus pure MEV) or routed through a keeper system?
- Can liquidations be partial-filled, allowing a searcher to leave the position barely solvent and re-liquidate later?
- What happens during oracle downtime — are stale prices accepted indefinitely?

## 6. Governance MEV

**Pattern:** Buy/borrow voting power right before a vote, vote, sell/repay.

**Where it appears:**
- Any governance using token balance for voting (without checkpoint)
- Flash-loan voting
- Snapshot/checkpoint timing manipulation

**Checks:**
- Does vote weight come from a checkpoint or current balance?
- Is the checkpoint at proposal creation, vote start, or vote end? Each has different attack surface.
- Can flash loans inflate voting power within a single block?
- Are delegations updated atomically with vote-weight reads?

## 7. NFT mint MEV

**Pattern:** Frontrun valuable mints; sandwich allowlist drops; pre-image attacks on randomness.

**Where it appears:**
- Public mints with no per-address limits or weak ones
- Whitelist mints with merkle proofs (proof discovery before mint)
- Reveal mechanisms (predict rare traits, then mint/skip)

**Checks:**
- Per-address mint limits enforced at the right level (not bypassable via multiple EOAs in one tx)
- Reveals use commit-reveal or VRF, not `block.timestamp` / `blockhash`
- Allowlist proofs aren't leaked publicly before mint opens

## 8. Liquidation MEV

**Pattern:** Liquidations are open auctions; whoever pays most gas wins. This is MEV-by-design but can become problematic.

**Checks:**
- Is liquidation reward proportional and reasonable, not winner-take-all in a way that creates priority gas auctions clogging the chain?
- Can liquidations be split or partial-filled to extract maximum value across multiple txs?
- Does the protocol have a backup keeper / private liquidation path for periods of network congestion?
- Are bad-debt scenarios handled when MEV searchers don't show up (low collateral, high gas)?

## 9. L2-specific MEV

**Pattern:** Sequencer ordering rules differ from L1 mempool dynamics.

**Checks:**
- Arbitrum: FCFS sequencer means timestamp-of-arrival matters, not gas. Time-based attacks shift.
- Optimism / Base: sequencer can theoretically reorder, though Optimism has committed to FIFO.
- zkSync, Starknet, Linea: each has its own ordering policy — verify before assuming L1-style mempool.
- All L2s: forced inclusion via L1 has different timing and cost than L2 inclusion. Some attacks only work via forced inclusion.

## 10. Cross-domain MEV

**Pattern:** Same protocol on multiple chains; price discrepancy or asynchronous state allows arbitrage that the protocol pays for.

**Checks:**
- Bridges: can a message be replayed or reordered across chains?
- Cross-chain governance: is execution on chain B atomically tied to vote on chain A?
- Protocols deployed on multiple chains: does state on one chain affect another (CCIP, LayerZero, Wormhole) in a way that can be raced?

## How to apply this in Phase 3c

For each external entry point identified in Phase 1:

1. Ask: does this function move value or change state that affects value?
2. If yes, walk the 10 categories above and ask "is this function vulnerable to <category>?"
3. For any "yes" or "maybe", add to candidate findings list with the specific attack sequence.
4. Note in the report whether the protocol uses any standard MEV mitigations (Flashbots, MEV-Boost private mempool, commit-reveal, slippage params, deadlines, TWAPs).

## What's not a MEV finding

- Pure arbitrage that doesn't cost protocol users anything (just price equalization across venues) — informational at most.
- Searchers liquidating bad positions efficiently — usually a feature.
- Frontrunning that the user could have avoided with a private mempool — note as informational unless the protocol's UX actively pushes users into the public mempool with no warning.
