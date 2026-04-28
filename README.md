# solidity-auditor

A Claude Code / Claude Agent SDK **skill** that drives a structured security audit of Solidity smart contracts. Combines automated static analysis (Slither, Aderyn) with manual review guided by the Cyfrin/Solodit checklist, protocol-specific knowledge, and MEV considerations, and produces a verified markdown findings report.

## What this skill does

When invoked, the agent runs a fixed 6-phase audit loop:

| Phase | Purpose |
|------:|---------|
| 1. Scope     | Enumerate contracts, identify protocol type(s), trust assumptions, entry points. |
| 2. Static    | Run Slither + Aderyn, triage output against a curated false-positive library. |
| 3. Manual    | Walk the Cyfrin/Solodit checklist and MEV review module. |
| 4. Protocol  | Load and apply the protocol-specific reference module(s) that match the codebase. |
| 5. Verify    | Cross-check every candidate finding; drop false positives. |
| 6. Report    | Write the final markdown findings report. |

## When it triggers

The skill is designed to fire on any request to audit, review, security-check, or "look at" Solidity / EVM contract code — including casual phrasings like *"is this safe to deploy?"* or *"anything sketchy here?"*.

It does **not** trigger for: general Solidity coding help, gas optimization without a security framing, Solidity tutorials, or non-EVM chains (Solana, Move, Cairo, etc.).

## Repository layout

```
solidity-auditor/
├── SKILL.md                       # Skill entrypoint + 6-phase methodology
├── scripts/
│   ├── scope_contracts.sh         # Phase 1 — enumerate .sol files, LOC, imports
│   └── run_static_analysis.sh     # Phase 2 — run Slither + Aderyn, capture output
└── references/
    ├── tooling.md                 # How to read Slither / Aderyn output
    ├── false-positives.md         # Per-detector FP recognition library
    ├── checklist-cyfrin.json      # Cyfrin / Solodit manual-review checklist
    ├── checklist-swc.md           # SWC registry quick reference
    ├── mev.md                     # MEV review module
    ├── findings-template.md       # Final report template
    └── protocols/                 # Protocol-specific review modules
        ├── erc20.md
        ├── erc721-1155.md
        ├── erc4626.md
        ├── amm.md
        ├── lending.md
        ├── perpetuals.md
        ├── stablecoin.md
        ├── staking-lsd.md
        ├── restaking.md
        ├── yield-aggregator.md
        ├── governance.md
        ├── bridge-crosschain.md
        ├── account-abstraction.md
        └── intent-based.md
```

## Installation

### As a Claude Code skill

Drop the `solidity-auditor` directory into a skills location Claude Code reads:

```bash
# user-level
mkdir -p ~/.claude/skills
cp -r solidity-auditor ~/.claude/skills/

# or project-level
mkdir -p .claude/skills
cp -r solidity-auditor .claude/skills/
```

Then invoke it from a Claude Code session by asking for a Solidity audit.

### Tooling prerequisites

The Phase 2 scripts assume the following CLIs are on `PATH`:

- [`slither`](https://github.com/crytic/slither) — `pip install slither-analyzer`
- [`aderyn`](https://github.com/Cyfrin/aderyn) — `cargo install aderyn` (or download a release binary)
- A Solidity compiler resolvable by Slither (typically via `solc-select` or Foundry).

Without these, Phase 2 produces no automated findings and the agent falls back to manual review only.

## Usage example

Inside Claude Code:

> *Audit the contracts in `./src/`.*

The agent will:
1. Run `scripts/scope_contracts.sh ./src` to map the codebase.
2. Run `scripts/run_static_analysis.sh ./src`, write raw output to `/tmp/audit-static-output/`, and triage every detector hit using `references/false-positives.md`.
3. Walk the manual checklist + MEV module against the entry points from Phase 1.
4. Load the matching `references/protocols/*.md` modules (e.g. `lending.md` + `erc20.md`).
5. Verify each candidate finding by re-reading the source.
6. Emit a final report following `references/findings-template.md`.

## License

[MIT](LICENSE).

## Contributing

Issues and PRs welcome — particularly new false-positive patterns, additional protocol modules, and corrections to the checklist.
