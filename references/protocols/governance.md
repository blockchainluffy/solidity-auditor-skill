# Governance Audit Reference

Load when the contract is a governance system (Compound Governor, OpenZeppelin Governor, Aragon, Snapshot+executors, custom DAO). Governance bugs let attackers seize protocol control.

## Voting power source

Vote weight comes from somewhere — token balance, locked tokens, reputation, or delegation graph.

**Audit checks:**
- Is voting power read from a checkpoint or current balance?
- Current balance is flash-loan-attackable. Always use checkpoints.
- When is the checkpoint taken: at proposal creation, at vote start, at vote end? Each has different attack surface.
  - **At creation**: attacker can move tokens after creation but before vote start.
  - **At vote start**: best practice, with a delay between creation and start to prevent JIT acquisition.
  - **At vote end**: vulnerable to flash loans on the last block.
- Does vote weight include delegated power? Is delegation tracked at the checkpoint?
- Is there a minimum holding period before voting (anti-flash-acquisition)?

## Proposal creation

Who can propose, and what can a proposal do?

**Audit checks:**
- Proposal threshold: how much voting power required? Too low → spam; too high → only whales propose.
- Proposal payload: arbitrary `(target, value, calldata)[]`? Then anything is possible if proposal passes.
- Are there restrictions on what proposals can do (e.g., not call self-destruct, not change quorum)?
- Can a proposer cancel their own proposal? When?
- Can proposals be amended after creation (usually no, but check)?

## Voting

How votes are cast.

**Audit checks:**
- Vote types: For / Against / Abstain. Are abstain votes counted toward quorum?
- Voting via signatures (off-chain signatures, on-chain tally): replay protection? Chain ID, nonce, deadline?
- Voting period length: long enough for participation, short enough for responsive governance?
- Can votes be changed during the voting period? (Usually no.)
- Vote-counting precision: BPS, raw token units, or scaled?

## Quorum

Minimum participation for a proposal to pass.

**Audit checks:**
- Quorum measured against what supply: total, circulating, "votable" (non-locked)?
- Static or dynamic? Dynamic quorum mitigates whale control but adds complexity.
- Can quorum be gamed by burning tokens to reduce the denominator?
- Are abstain votes counted toward quorum (yes per OZ standard, no in some other systems)?

## Execution

After a proposal succeeds, how is it executed?

**Audit checks:**
- Timelock: required between vote success and execution. Length appropriate for the action's severity?
- Can timelock be bypassed (e.g., via emergency multisig)?
- Execution permissioned to anyone (typical) or restricted? Permissionless is preferred for decentralization.
- Execution cancellation: who can cancel a queued proposal? Guardian, governance itself?
- Execution failure: if one of the calls reverts, is the whole proposal aborted? Atomic execution is standard.

## Timelock

The delay between governance approval and execution.

**Audit checks:**
- Minimum delay: hardcoded floor or governance-mutable? Mutable timelock is dangerous.
- Admin of the timelock: must be the governance contract itself, not an EOA / multisig.
- Pending transactions: queued correctly? Indexable for transparency?
- Cancel function: who can call?
- Grace period: if a queued tx isn't executed in time, does it expire? (Compound Bravo: 14 days.)

## Delegation

Token holders delegate voting power to others.

**Audit checks:**
- Delegation atomicity: when a holder delegates, does the delegate's voting power update at the right block?
- Self-delegation: required to vote, or implicit?
- Delegation cycles or chains: prevented or allowed (typically only one hop)?
- Delegation via signature: replay protection?
- Transfers update both delegator's and delegate's voting power correctly?

## Flash loan / sandwich attacks on governance

Attacker borrows governance tokens, votes, returns them.

**Audit checks:**
- Checkpoint taken at vote start (not vote end), with a sufficient delay from proposal creation.
- Snapshot ≠ vote start in some systems — verify.
- Timelock between proposal pass and execution: gives time for community response.
- Voting power must be held over a duration, not just at a moment (hard to enforce on-chain).

## Multi-sig / committee overrides

Many protocols have admin multisigs alongside governance.

**Audit checks:**
- What can the multisig do unilaterally? Pause, upgrade, or only emergency response?
- Is the multisig set decentralized enough (member count, threshold)?
- Multisig timelock: same as governance, or different?

## Governance attacks to verify against

- **Beanstalk (2022)**: flash-loan governance attack, $182M. Single-block proposal + execution = death.
- **Compound (2023)**: cETH proposal almost-bug discovered in audit.
- **Various low-quorum DAOs**: hostile takeover by acquiring tokens cheaply.
- **Mango Markets (2022)**: oracle manipulation funded a governance proposal that paid the attacker.

## Specific patterns to look for

- **Single-block proposal + execution**: catastrophic. Always require timelock.
- **No checkpoint, current balance voting**: catastrophic.
- **No quorum**: low-turnout proposals pass with attacker's votes only.
- **Mutable critical parameters via simple proposal**: e.g., changing collateralFactor of a major asset to 100% via 2-day governance vote.
- **Veto / guardian role with no time limit**: censorship risk.
- **Upgrade authority not behind timelock**: instant rugpull capability.

## References
- OpenZeppelin Governor docs
- Compound Bravo whitepaper
- Sigma Prime "DAO governance vulnerabilities"
- Solodit findings on "governance", "voting", "timelock", "delegation"
