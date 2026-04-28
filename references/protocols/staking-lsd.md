# Staking & LSD (Liquid Staking Derivatives) Audit Reference

Load when the contract handles native ETH staking, LSDs (stETH, rETH, sfrxETH), or yield-bearing staked tokens. Restaking specifics are in `restaking.md`.

## Reward accounting

Stakers earn rewards over time. Accounting must be precise across deposits/withdrawals.

**Audit checks:**
- Per-share reward index pattern: `userPending = (rewardPerToken - userRewardPerTokenPaid[user]) * userBalance`. Is the math precise (decimals)?
- Off-by-one in checkpointing: when does balance update relative to reward calculation?
- Rewards on behalf of address(0) or contract itself: who gets them?
- Boost / multiplier mechanisms: are boost calculations atomic with stake changes?

## JIT staking attacks

Deposit right before reward distribution, claim, withdraw.

**Audit checks:**
- Are rewards distributed continuously (per-block) or in discrete events (per-epoch)?
- Discrete events are JIT-attackable. Mitigation: cooldown periods, vesting, snapshot-based eligibility.
- For snapshot-based: when is the snapshot taken? Front-runnable?

## Withdrawal queue / unstaking delays

Many staking protocols have a withdrawal delay.

**Audit checks:**
- Queue ordering: FIFO, LIFO, or pro-rata? FIFO is most common.
- Can the queue be DoSed by submitting many small requests?
- Liquidity check at withdrawal time: what if reserves are insufficient (slashed, malicious operator)?
- Can a withdrawal be cancelled? Can cancellation race finalization?

## Slashing

In native ETH staking and similar, validators can be slashed for misbehavior.

**Audit checks:**
- Who absorbs slashing losses? Pro-rata across all stakers? Specific stakers tied to specific validators?
- Insurance fund mechanism: capitalized correctly, used correctly during slash?
- Can slashing be triggered maliciously (operator betrays stakers)?

## LSD-specific (stETH, rETH, sfrxETH, etc.)

LSDs are tokens representing staked positions. Behaviors vary.

**Audit checks:**
- Rebasing (stETH) vs non-rebasing (wstETH, rETH, sfrxETH)? Each has different integration needs.
- For rebasing tokens: protocols that cache `balanceOf` will have stale data after rebase.
- Exchange rate updates (rETH `getExchangeRate`, sfrxETH per-share assets): can these be manipulated within a transaction? Most update only on epoch.
- Depeg risk: stETH:ETH peg has wandered before. If a protocol assumes 1:1, any deviation is exploitable.
- Oracle for LSD prices: must use price feed, not market spot, for lending/liquidations.

## Validator key management (if relevant)

If the contract handles validator keys or signs deposit_data:

**Audit checks:**
- Front-running deposits: is the validator pubkey committed atomically with the deposit?
- Key rotation: who can rotate, what's the impact on existing stake?
- Withdrawal credentials: locked to the protocol contract, or can they be changed?

## Operator marketplaces

Some protocols (Rocket Pool, Lido, SSV) have operator marketplaces.

**Audit checks:**
- Operator registration: permissioned, permissionless with bond, governance-gated?
- Bond slashing: covers what types of misbehavior?
- Operator selection algorithm: gameable to capture more stake?
- Exit assistance: when an operator exits, who pays (sequencer, stakers, operator's bond)?

## Ether handling

Native ETH is involved.

**Audit checks:**
- `msg.value` usage: matches `amount` parameter where applicable?
- Send vs call: `transfer` (2300 gas) is risky, use `call{value:}("")` with check.
- Balance reconciliation: `address(this).balance` is donatable; track expected vs actual.
- Fallback / receive functions: correctly reject non-protocol ether or accept it intentionally?

## Withdrawals and Pectra (post-Shanghai)

Post-Shanghai (April 2023), validator withdrawals are possible. Some staking protocols still have legacy withdrawal logic.

**Audit checks:**
- Withdrawal credentials type 0x01 (execution-layer): correctly set?
- Compounding (Pectra EIP-7251): is the contract aware of MaxEffectiveBalance changes?
- Partial withdrawals (skim) vs full exits: handled separately and correctly?

## Specific past exploits

- **Lido governance attacks (theoretical)**: governance token concentration concerns.
- **Ankr aETHc (2022)**: private-key compromise, infinite mint, $5M.
- **Stake Finance (2023)**: validator key manipulation.
- **Various LSD JIT attacks**: deposit-before-rebase, withdraw-after.

## References
- Lido whitepaper, Rocket Pool docs, Frax sfrxETH design
- EIP-4895 (withdrawals), EIP-7251 (compounding)
- Solodit findings on "staking", "LSD", "stETH", "withdrawal", "slashing"
