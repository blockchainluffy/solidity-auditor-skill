# Account Abstraction (ERC-4337) Audit Reference

Load when the contract is or interacts with ERC-4337 components: smart accounts, paymasters, bundlers, EntryPoint integrations, custom validators. The 4337 stack has subtle bugs because the validation/execution split has unusual constraints.

## ERC-4337 architecture (refresh)

A `UserOperation` is constructed off-chain, sent to a Bundler, which submits it to the `EntryPoint`. EntryPoint calls the wallet's `validateUserOp`, then optionally a Paymaster's `validatePaymasterUserOp`, then executes the user op. Validation must be deterministic and self-contained — that's where most bugs live.

## Validator (validateUserOp) constraints

`validateUserOp` runs in a restricted context. Many ops are forbidden.

**Audit checks:**
- The validator does not access storage of accounts other than itself, the sender, and (for paymasters) the paymaster.
- No banned opcodes: `BLOCKHASH`, `COINBASE`, `TIMESTAMP`, `NUMBER`, `PREVRANDAO`, `GASLIMIT`, `BASEFEE`, `BLOBHASH`, `BLOBBASEFEE`, `GAS`, `CREATE`, `CREATE2`, `SELFBALANCE`, `BALANCE`, `ORIGIN`, `GASPRICE`.
- No external calls to non-staked entities.
- Validation must not depend on external state beyond what's allowed.
- If banned ops are used, bundlers reject the userOp. But a malicious user could deploy a contract that *initially* obeys rules and *later* doesn't (storage write that flips behavior). Mitigation: staking + reputation.

## Signature validation

`validateUserOp` returns a `validationData` packed: `(authorizer, validUntil, validAfter)`.

**Audit checks:**
- `authorizer` should be `0` (success), `1` (signature failure), or a custom validator address. Returning `0` means valid; non-zero authorizer is interpreted as ERC-1271 verification.
- `validUntil`/`validAfter`: are they enforced and reasonable? Zero `validUntil` = "no expiration" — is that desired?
- Signature aggregation: if using `IAggregator`, both per-userOp and aggregated signature must be checked.
- ECDSA: malleability handled (use OZ ECDSA library)?
- Multi-sig wallets: threshold logic in validateUserOp must be deterministic and storage-bounded.

## Nonce management

EntryPoint manages a 2D nonce: `(key, sequence)`.

**Audit checks:**
- For sequential userOps, the nonce key is fixed and sequence increments.
- For parallel (independent) ops, different keys allow concurrent sequences.
- Replay protection: nonce + chainId + EntryPoint address in the userOp hash.
- Custom nonce schemes (in the wallet itself, beyond EntryPoint): must be replay-safe.

## Paymaster vulnerabilities

Paymasters sponsor gas. `validatePaymasterUserOp` can return context for `postOp`.

**Audit checks:**
- Paymaster's stake: sufficient? Stake required for storage access on userOp's behalf.
- `validatePaymasterUserOp` runs under same restricted rules as validator.
- Paymaster grief: a malicious userOp that always reverts in execution but succeeds validation drains paymaster gas. Mitigation: paymaster signature commits to expected execution, charges fee unconditionally.
- Whitelist paymasters: who can be sponsored? Check the whitelist mechanism.
- Token paymasters (user pays gas in ERC20): rate calculation, slippage, accept fee in advance.
- Postop refund logic: refund condition correct?

## Wallet upgrade / module patterns

Smart accounts are often upgradeable or modular.

**Audit checks:**
- Upgrade authority: behind a signature with sufficient delay?
- Module installation: module's storage doesn't collide with wallet's?
- Module callable functions: properly authenticated?
- Hook execution order (pre-validate, validate, post-validate): each step's failure handled?

## Initcode / wallet deployment

If the wallet doesn't exist, EntryPoint deploys it via `initCode`.

**Audit checks:**
- Factory contract: deterministic CREATE2 salt? Same address across chains?
- Initialization: wallet's initialize function callable only by factory or only once?
- Front-running deployment: if wallet address is predictable, attacker can deploy a malicious wallet at that address first. Mitigation: factory ownership baked into bytecode via CREATE2 salt that includes owner.
- Initial state: wallet starts with whose owner / which keys?

## Session keys and permissions

Many wallets implement session keys (limited-permission keys for dApps).

**Audit checks:**
- Session key permissions: function selectors, contracts, value caps, expiration.
- Permission storage: per-key, per-target?
- Revocation: can owner immediately revoke? On-chain or off-chain (EIP-1271)?
- Upgrade-safety: do permissions persist correctly across wallet upgrades?

## Bundler trust

Bundlers can include or exclude userOps.

**Audit checks (informational, since bundlers are off-chain):**
- Does the wallet rely on a specific bundler? That's a centralization vector.
- Is the userOp hash chain-bound (chainId in domain separator)?
- Frontrunning by bundler: bundler sees signed userOp before execution. Acceptable if userOp is self-contained, but issues if userOp's effect depends on prior state.

## EIP-7702 considerations

EIP-7702 lets EOAs temporarily delegate to contract code. Many AA flows now interact with 7702 accounts.

**Audit checks (if 7702 is in scope):**
- The contract being delegated to: does it trust `msg.sender` (the EOA) appropriately?
- Replay across delegations: signed authorization tuples include nonce + chainId?
- Storage: the EOA has its own storage now; layout collisions across different delegations possible.

## Specific past issues

- **Various paymaster griefing patterns**: drained paymaster balance via reverting userOps.
- **Module installation flaws**: misconfigured permissions led to bypass.
- **CREATE2 wallet front-running**: deploying first to seize an address.
- **Validator storage rule violations**: bundlers rejected ops; debugging was painful.

## References
- ERC-4337 spec: https://eips.ethereum.org/EIPS/eip-4337
- EIP-7702: https://eips.ethereum.org/EIPS/eip-7702
- ERC-7579 (modular accounts): https://eips.ethereum.org/EIPS/eip-7579
- ERC-6900 (modular accounts, alternative): https://eips.ethereum.org/EIPS/eip-6900
- Aviggiano's ERC4337 security checklist
- Solodit findings on "ERC-4337", "account abstraction", "paymaster", "validateUserOp"
