# Intent-Based Protocol Audit Reference

Load when the contract handles intents — user-signed orders fulfilled by solvers (UniswapX, CoW Swap, 1inch Fusion, Across, custom RFQ systems). The pattern: user signs an off-chain order describing desired outcome → solver competes to fulfill on-chain → settlement contract verifies and pays.

## Order signing and verification

Intents are signed structured data, typically EIP-712.

**Audit checks:**
- EIP-712 domain separator: includes chainId, verifying contract? Per-chain replay-safe?
- Order struct: complete enough to prevent malicious filling? Includes deadline, nonce, recipient?
- Signature verification: ECDSA + EIP-1271 for smart wallet support?
- Permit / SignatureTransfer (Permit2) integration: correct deadline + nonce handling?
- Nonce scheme: monotonic, bitmap (parallel orders), or unordered (canceled by hash)?

## Replay protection

Orders signed once should be filled at most once.

**Audit checks:**
- On-chain `filled` mapping per order hash?
- Partial fills: tracked correctly per-order?
- Cross-chain replay: order signed for chain A executable on chain B? Domain separator must include chainId.
- Replay across protocol versions: contract migration / upgrade — old orders replayable on new contract?

## Cancellation

Users may cancel orders before they're filled.

**Audit checks:**
- Cancellation method: on-chain (gas cost) or off-chain (relayer-coordinated)?
- On-chain cancellation: marks order as cancelled in storage; verify cancellation is permissioned to signer.
- Race: solver fills order in same block as user cancels — who wins?
- Cancellation cost: solver could grief by forcing user to spend gas to cancel.

## Solver execution

Solvers compete to fulfill orders, typically with a custom callback.

**Audit checks:**
- Solver authentication: anyone can solve, whitelisted, or auctioned (CoW)?
- Solver's flexibility: can they fulfill via any path (DEX aggregation), or is execution constrained?
- Solver MEV: solver may extract value from the user's order (sub-optimal execution); is there a guarantee of best execution?
- Reentrancy via solver callback: does the settlement contract assume state is consistent during the callback?

## Settlement and price guarantee

The user's signed order specifies a min-out (or similar). Settlement enforces it.

**Audit checks:**
- Min-out check: enforced after solver execution, before paying solver?
- Token transfers: pulled from user via Permit2 or ERC20 allowance?
- User receives output: directly or via the solver?
- Slippage and oracle price: if order specifies "up to oracle price", oracle must be manipulation-resistant.

## Auction and solver selection

Some protocols (CoW, UniswapX) run an auction.

**Audit checks:**
- Dutch auction: starting price, decay, end price — chosen correctly to prevent backruns at start?
- Sealed-bid: commit-reveal? Reveal phase manipulable?
- Multi-order batch: solver fulfills many orders together; how is per-order satisfaction verified?
- Solver reputation / staking: incentivizes good behavior?

## Fees

Fees can be paid in multiple ways: protocol fee on output, solver tip, gas refund.

**Audit checks:**
- Fee calculation: from input or output? Pre-slippage or post?
- Protocol fee receiver: hardcoded or governance-mutable?
- Solver compensation: skimmed from output (reduces user's receive) or paid by protocol (increases protocol cost)?

## Cross-chain intents

UniswapX cross-chain, Across, etc., extend intents across chains.

**Audit checks:**
- Source chain: user locks funds; destination chain: filler delivers; reconciliation: filler claims locked funds.
- Authentication of "delivered" event from destination to source: see `bridge-crosschain.md`.
- Filler bond / collateral: covers failure or dispute?
- Dispute mechanism: who can challenge a claim of delivery?

## Permit2 integration

Many intent protocols use Uniswap's Permit2 for token transfer.

**Audit checks:**
- `permitTransferFrom` vs `permitWitnessTransferFrom`: latter binds permit to a specific witness (the order data).
- Witness type-string: matches the order's type-string exactly?
- Nonce scheme: Permit2's bitmap nonces — caller must manage them.
- Expiration: deadline on Permit2 signature shorter than implementation deadline?

## Specific patterns and pitfalls

- **Order parameter not in signature**: any field not signed can be manipulated by solver.
- **Recipient not in signature**: solver fills to themselves, user gets nothing.
- **Loose deadline**: order valid for too long → executable at unfavorable prices.
- **Insufficient slippage**: user's `minOut` is way below market → MEV-vulnerable.
- **Re-quotability**: same order partially-filled, then re-quoted at worse price.
- **Cross-block fills**: order fills are split across blocks at different prices, accumulated incorrectly.

## Specific past issues

- **CoW Swap solver bugs**: various, mostly accounting.
- **0x exchange exploits (early)**: signature verification edge cases.
- **Permit2 integrations**: protocols not properly using witness, allowing solver to swap order parameters.
- **UniswapX issues**: discussed in audits — JIT solver behavior, gas griefing.

## References
- UniswapX whitepaper
- CoW Protocol docs
- Permit2 (Uniswap)
- Across docs
- Solodit findings on "intent", "solver", "Permit2", "RFQ", "UniswapX", "CoW"
