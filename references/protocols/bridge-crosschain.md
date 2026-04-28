# Bridge & Cross-Chain Audit Reference

Load when the contract is or interacts with a bridge (LayerZero, CCIP, Wormhole, Axelar, Hyperlane, native L1↔L2 bridges, custom). Bridges have lost more value than any other DeFi category — Ronin ($625M), Wormhole ($325M), Nomad ($190M), BNB Bridge ($586M).

## Message authentication

Every cross-chain message must be authenticated. Forging messages = total compromise.

**Audit checks:**
- Verifier set: multisig, MPC, light client, ZK, optimistic? What's the trust model?
- Signature validation: are all required signatures checked? Off-by-one in threshold?
- Replay protection: is each message identified uniquely (nonce, message hash, source chain ID)?
- Domain separator: messages from chain A to chain B must not be replayable on chain C → B.

## Specific authentication failures to check

### Wormhole-style: signature verification bypass
- Are all guardians' signatures checked, or just first N?
- Is the order of signatures enforced?
- Can a malicious guardian double-sign?

### Optimistic bridges (Nomad)
- Initial state of message acceptance: empty merkle tree had a vacuous root, accepting any message.
- Fraud proof window: long enough for watchers to act?
- Fraud proof submitter incentive: enough to attract watchers?

### Light client bridges
- Sync committee / validator set: how is it bootstrapped, how is it rotated?
- Finality assumptions: does the bridge wait for L1 finality? How many epochs?
- Reorg handling: if source chain reorgs after a message is sent, what happens?

### MPC / Multisig bridges
- Key management: where do keys live? Threshold sufficient?
- Key rotation: process documented? Prevented from being malicious?
- Insider risk: is one entity controlling enough to compromise?

## Token bridge specifics

For token bridges (lock-and-mint, burn-and-release):

**Audit checks:**
- Lock/burn on source matches mint/release on destination atomically (across chains).
- Total supply invariant: tokens locked on source = tokens minted on destination. Always.
- Mint/burn permissioned to bridge only?
- Is the bridge itself the only minter, or can multiple minters cause inflation?
- Decimal handling across chains: the same token may have different decimals on different chains.
- Wrapped representations: is there only one canonical wrapped version per asset, or can attackers create fake wrapped versions?

## Replay attacks

A message executed twice = double-spend.

**Audit checks:**
- Nonce per source chain → tracked in destination contract?
- Replay across versions: if the bridge upgrades, can old messages be replayed against new contract?
- Replay across chains: message intended for chain B replayed on chain C if domain separator weak.

## Message ordering

Some protocols depend on message ordering (e.g., governance proposals across chains).

**Audit checks:**
- Are messages strictly ordered (sequential nonces)?
- Out-of-order delivery: does the destination handle gracefully or revert?
- DoS by stalling one message: does it block all subsequent messages (head-of-line blocking)?

## Fee handling

Cross-chain messaging has fees on both ends.

**Audit checks:**
- Who pays the destination gas? User, sender contract, relayer?
- Refund logic: if execution fails on destination, are funds returned to sender?
- Fee manipulation: can a low-fee message DoS the relay queue?
- Fee donation: can someone donate excess fees to the bridge contract and break accounting?

## Source-chain finality

Bridges that act before L1 finality are vulnerable to reorgs.

**Audit checks:**
- L1 → L2 (e.g., to Optimistic rollups): typically 1 block is insecure on Ethereum (reorg risk). Most bridges wait for finality (~12.8 min on PoS).
- L2 → L1: depends on the rollup. Optimistic: 7-day fraud proof window. ZK: depends on proof submission cadence.
- Custom bridges: specify and verify the finality assumption.

## LayerZero specifics

LayerZero V1: ULN (Ultra Light Node). V2: changed model.

**Audit checks:**
- DVN (Decentralized Verifier Network) configuration: which DVNs verify messages?
- Default vs custom configurations: default uses LayerZero Labs as relayer + oracle (single point of trust).
- Are application owners configuring custom DVNs for security?
- Pre-crime checks: are they bypassable?

## CCIP specifics

Chainlink's Cross-Chain Interoperability Protocol.

**Audit checks:**
- Risk Management Network (RMN) — additional layer that can pause.
- Token transfer config: which tokens supported, rate-limited per token?
- Manual execution: who can trigger when automated execution fails?

## Cross-chain governance

Governance on chain A executes actions on chain B.

**Audit checks:**
- Atomic execution? Or can chain A pass but chain B fail?
- Replay if message is delivered twice → action executed twice.
- Source authentication: chain B verifies the message came from chain A's governance, not anyone else.

## Specific past exploits to internalize

- **Ronin (2022, $625M)**: 5 of 9 validators compromised; all signed.
- **Wormhole (2022, $325M)**: signature verification bug allowed forging guardian signatures.
- **Nomad (2022, $190M)**: empty merkle root accepted any message.
- **BNB Bridge (2022, $586M)**: IAVL proof verification bug.
- **Multichain (2023, $130M)**: alleged insider; key control compromised.
- **Harmony Horizon (2022, $100M)**: 2-of-5 multisig compromised.
- **Poly Network (2021, $611M)**: keeper role manipulation.

## References
- LayerZero docs, Wormhole docs, Chainlink CCIP docs
- L2BEAT for bridge risk assessments
- Spearbit's cross-chain bridge checklist
- Solodit findings on "bridge", "cross-chain", "LayerZero", "CCIP", "Wormhole", "replay"
