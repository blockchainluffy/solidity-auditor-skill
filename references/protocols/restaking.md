# Restaking Audit Reference

Load when the contract is a restaking protocol (EigenLayer, Symbiotic, Karak, Cosmos restaking, custom AVSs and operator contracts). Restaking is a 2024-26 trend with a still-evolving security model and many novel risks.

## The restaking model

Stakers deposit assets (LSTs, ETH, or other) → delegate to operators → operators run AVSs (Actively Validated Services) → each AVS can slash for misbehavior.

**Audit checks at architecture level:**
- What is the slashing scope? Per AVS? Per operator? Across all of operator's stake?
- What is the slashing trigger? Cryptographic proof? Optimistic challenge? Operator multisig?
- Stake double-counting: is the same stake committing to multiple AVSs simultaneously? If yes, what's the risk amplification?

## Operator opt-in / opt-out

Operators register, opt into AVSs, and (eventually) exit.

**Audit checks:**
- Opt-in confirmation: does the AVS confirm operator? Is the AVS allowed to reject?
- Opt-out delay: how long before operator's stake is no longer slashable? Long enough for slow slashing windows?
- Forced opt-out: can operator unilaterally exit, leaving AVS without stake backing?
- Slashing during opt-out: operator still slashable for misbehavior before opt-out completes?

## Delegation

Stakers delegate to operators.

**Audit checks:**
- Delegation accounting: per-staker, per-operator. Slashing reduces delegated stake pro-rata?
- Undelegation delay: typical 7-30 days. During delay, still slashable?
- Re-delegation: can a staker move to a new operator without full undelegation? Potential to escape slashing window.
- Operator exit while stakers are delegated: stakers stuck or auto-undelegated?

## Slashing

The big risk. Stakers and operators can lose value.

**Audit checks:**
- Slashing authority: who can slash? AVS contract directly? AVS + middleware? Governance committee?
- Slashing veto: any party with a veto creates centralization risk.
- Slashing magnitude: capped per event? Per epoch? Or unbounded?
- Slashing grace period: time between trigger and execution for review/dispute?
- Burn vs redirect: slashed stake burned (deflationary) or redirected (to AVS, to insurance)?
- Slashing on operator misbehavior vs AVS bug: does AVS-level bug cause unfair slashing? Mitigation?

## Withdrawals

Withdrawals from restaking are slow by design (must be slashable for some period).

**Audit checks:**
- Withdrawal delay enforced (typically 7+ days)?
- Withdrawal slashable during delay?
- Pending withdrawals during operator slash: bear pro-rata loss or escape?
- Queue ordering: FIFO?
- Cancellation and re-staking: allowed?

## Strategy / asset accounting

Restaking handles many underlying assets (ETH via beacon chain, LSTs, custom tokens).

**Audit checks:**
- Per-strategy accounting (e.g., EigenLayer's Strategy contracts): each strategy has its own deposit/withdraw and share/asset math.
- Strategy share inflation attacks (similar to ERC4626 first-depositor issue).
- Strategy whitelist: who can register a new strategy? Centralization risk if permissionless without controls.
- LST handling: rebasing tokens (stETH) cause balance changes; non-rebasing (rETH, sfrxETH) need exchange rate queries.

## AVS interactions

AVSs are external contracts that operators commit to.

**Audit checks:**
- AVS can call into restaking contract: what functions? Can a malicious AVS slash unjustly?
- AVS registration: who approves? What's the trust model?
- AVS code upgrade: does it affect already-committed operators?
- AVS-to-operator messaging: replay-safe? Cross-chain AVSs especially risky.

## Reward distribution

Operators earn fees from running AVSs; rewards split among delegators.

**Audit checks:**
- Reward token: AVS-specific or canonical? Multiple reward tokens accumulating?
- Distribution math: pro-rata across delegators based on snapshot? Or live balance (manipulable)?
- Operator commission: capped, transparent, mutable with delay?
- Reward harvest: permissionless or operator-only?
- Unclaimed rewards on withdrawal: forfeited or claimed?

## Cross-chain restaking

Some restaking protocols allow operators to commit to cross-chain AVSs.

**Audit checks:**
- Cross-chain message authentication (see bridge-crosschain.md).
- Slashing trigger via cross-chain message: how is replay prevented?
- Finality assumptions on the other chain.

## Liquid restaking tokens (LRTs)

LRTs (eETH, ezETH, rsETH, weETH, etc.) wrap restaked positions.

**Audit checks:**
- LRT exchange rate: based on what (sum of strategies + accrued rewards - slashing)?
- Mint / redeem mechanics: instant or queued?
- Slashing reflected in LRT price: immediately, with delay, or socialized differently?
- Peg risk: LRT can depeg from underlying staked asset; lending markets accepting LRT as collateral inherit this risk.
- Multi-LST inputs: an LRT may accept stETH, rETH, etc. — exchange rate per input must be correct.

## Specific patterns and concerns

- **Restaking compounding risk**: same ETH committed to many AVSs; each new AVS adds risk to all stakers.
- **Operator concentration**: top operators control disproportionate stake; their compromise / collusion is a systemic risk.
- **AVS pricing**: a low-quality AVS that pays high yield attracts stake; low-quality slashing logic puts that stake at risk.
- **Slashing socialization**: how is a single AVS slash event distributed among delegators? Edge cases when delegator just deposited.

## References
- EigenLayer whitepaper, docs
- Symbiotic, Karak design docs
- Sigma Prime "Liquid Restaking Tokens" article
- Solodit findings on "restaking", "EigenLayer", "AVS", "operator"
