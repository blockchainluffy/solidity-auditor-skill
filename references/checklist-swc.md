# SWC Registry Summary

The Smart Contract Weakness Classification registry is older (last updated 2020) but its taxonomy still covers fundamental EVM/Solidity weaknesses. Use this as a quick-pass after the Cyfrin checklist to catch classical issues. For the live registry: https://swcregistry.io/

This table covers the most important entries. For full detail on any item, search `SWC-XXX` on the registry site.

| ID | Title | What to check |
|---|---|---|
| SWC-100 | Function Default Visibility | All functions have explicit visibility (modern Solidity enforces this, but check older code) |
| SWC-101 | Integer Overflow/Underflow | Pre-0.8.x: SafeMath used? 0.8.x+: any `unchecked` blocks justified? |
| SWC-102 | Outdated Compiler Version | Pragma uses a recent, security-patched compiler |
| SWC-103 | Floating Pragma | Pragma is fixed (`pragma solidity 0.8.20;`) not floating (`^0.8.0`) for production |
| SWC-104 | Unchecked Call Return Value | Low-level `call`/`send`/`transfer` return values checked |
| SWC-105 | Unprotected Ether Withdrawal | Withdraw functions have proper access control |
| SWC-106 | Unprotected SELFDESTRUCT | No callable selfdestruct, or it's strictly access-controlled |
| SWC-107 | Reentrancy | CEI pattern (Checks-Effects-Interactions), or ReentrancyGuard |
| SWC-108 | State Variable Default Visibility | Explicit visibility on state vars |
| SWC-109 | Uninitialized Storage Pointer | Solidity 0.5+ catches this, but check struct usage in older code |
| SWC-110 | Assert Violation | `assert` used only for invariants, not input validation |
| SWC-111 | Use of Deprecated Functions | No `suicide`, `sha3`, `throw`, `block.blockhash`, etc. |
| SWC-112 | Delegatecall to Untrusted Callee | `delegatecall` target is fixed/trusted |
| SWC-113 | DoS with Failed Call | Pull pattern over push for refunds; loops don't fail on single recipient |
| SWC-114 | Transaction Order Dependence | Frontrunning protection (covered more deeply in mev.md) |
| SWC-115 | Authorization through tx.origin | Use `msg.sender`, never `tx.origin` for auth |
| SWC-116 | Block Values as Time Proxy | `block.timestamp` not used for short windows or randomness |
| SWC-117 | Signature Malleability | Use OpenZeppelin ECDSA, reject high-S signatures |
| SWC-118 | Incorrect Constructor Name | N/A in modern Solidity (uses `constructor` keyword) |
| SWC-119 | Shadowing State Variables | No state vars shadowed in inheriting contracts |
| SWC-120 | Weak Source of Randomness | No `block.timestamp`, `blockhash`, or `block.difficulty` for randomness; use VRF |
| SWC-121 | Missing Protection against Signature Replay | Nonces or unique message hashes for signed messages |
| SWC-122 | Lack of Proper Signature Verification | EIP-712 used correctly; `ecrecover` checked against zero address |
| SWC-123 | Requirement Violation | `require` conditions are correct and use external inputs |
| SWC-124 | Write to Arbitrary Storage Location | No unchecked storage writes via assembly or proxy delegatecall |
| SWC-125 | Incorrect Inheritance Order | Linearization order correct (most-base-like first) |
| SWC-126 | Insufficient Gas Griefing | Forwarded gas accounted for in relay/meta-tx contracts |
| SWC-127 | Arbitrary Jump with Function Type Variable | No assembly jumps based on user input |
| SWC-128 | DoS With Block Gas Limit | Loops over unbounded arrays, especially over user-controlled data |
| SWC-129 | Typographical Error | `+=` vs `=+`, similar variable names that could be confused |
| SWC-130 | Right-To-Left-Override control character | No invisible Unicode in source |
| SWC-131 | Presence of unused variables | Informational |
| SWC-132 | Unexpected Ether balance | Don't use `address(this).balance` for accounting (anyone can `selfdestruct`-send) |
| SWC-133 | Hash Collisions With Multiple Variable Length Arguments | `abi.encodePacked` with multiple dynamic types is collision-prone — use `abi.encode` |
| SWC-134 | Message call with hardcoded gas amount | `transfer`/`send`'s 2300 gas limit can break with gas repricing — use `call` with checked return |
| SWC-135 | Code With No Effects | Statements that do nothing — usually a bug |
| SWC-136 | Unencrypted Private Data On-Chain | "Private" only means Solidity-private, not blockchain-private |

## Quick-pass approach

Walk this list after the Cyfrin checklist. Most modern code passes 100-119 trivially because newer Solidity catches them at compile time. Spend most time on:

- **SWC-107** (reentrancy) — still the #1 cause of real exploits
- **SWC-114** (TOD/frontrunning) — covered in MEV review
- **SWC-120** (weak randomness) — common in NFT mints, lotteries
- **SWC-121, SWC-122** (signature issues) — relevant for any signed-message protocol
- **SWC-128** (gas limit DoS) — common in distribution/refund logic
- **SWC-132** (unexpected balance) — common bug in protocols that use `address(this).balance` for share calculations
- **SWC-133** (encodePacked collisions) — common in signature schemes
