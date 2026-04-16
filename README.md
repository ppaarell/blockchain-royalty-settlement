# Reproducible Royalty Settlement Engine

A minimal rights-aware blockchain prototype for governed royalty settlement.

## Overview

This repository contains a proof-of-concept implementation of a blockchain-based royalty settlement workflow for creative assets. The system is designed to make core settlement steps more visible and reproducible through on-chain records, while keeping the operational flow simple and testable.

This version is intentionally scoped as a **minimal governed royalty settlement prototype**. It focuses on:

- asset registration
- license term proposal and validator approval
- royalty funding and payout execution
- audit bundle anchoring
- dispute and compliance recording

It does **not** yet implement multi-recipient royalty splits, batched recipient allocation, or advanced privacy proofs.

## Current System Scope

The current implementation supports a single-owner payout flow:

1. A creator registers a creative asset.
2. The creator proposes royalty terms.
3. A validator approves the terms.
4. An admin publishes the approved terms.
5. A DSP or reporter funds the royalty engine.
6. The DSP submits usage.
7. The engine calculates royalty and pays the current asset owner.
8. An audit bundle can be recorded.
9. Compliance can be marked and disputes can be opened or resolved.

## Contracts

### AssetRegistry.sol
ERC-721 registry for creative assets.

Main responsibilities:
- mint asset NFTs
- store immutable content-hash linkage
- maintain asset ownership
- expose `ownerOf()` for downstream royalty payout

Key functions:
- `mintAsset`
- `ownerOf`
- `grantRole`

### LicenseTerms.sol
Governed royalty-term lifecycle.

Main responsibilities:
- allow the token owner to propose terms
- require validator approval before activation
- track term versions
- reset approval state correctly for new term versions

Key functions:
- `proposeTerms`
- `approveTerms`
- `publishTerms`
- `rateOf`
- `isActive`
- `getTerms`

### RoyaltyEngine.sol
Single-recipient royalty execution engine.

Main responsibilities:
- receive reporter funding
- accept usage submission
- calculate royalty as `units × rate`
- transfer ERC-20 payout to the current asset owner
- reject duplicate usage submissions using a usage key

Key functions:
- `fund`
- `submitUsage`
- `quoteRoyalty`

### AuditCompliance.sol
Audit and dispute recording layer.

Main responsibilities:
- anchor audit bundles
- mark compliance
- open disputes
- resolve disputes

Key functions:
- `recordAuditBundle`
- `markCompliant`
- `openDispute`
- `resolveDispute`
- `getBundle`

### MintUSD.sol
Test ERC-20 token used for simulated royalty payments.

Deployed contract name:
- `TestUSD`

## What Was Fixed In This Version

This repository version includes targeted fixes while preserving the original flow:

- fixed validator approval state so new term versions can be approved cleanly
- added duplicate-usage rejection in `RoyaltyEngine`
- kept the overall settlement flow unchanged
- preserved the simple single-owner payout design

## What This Prototype Can Honestly Claim

This implementation can support claims about:

- governed royalty settlement flow
- approval-gated term activation
- single-owner royalty payout
- on-chain event-based traceability
- duplicate usage rejection
- audit bundle anchoring
- dispute and compliance workflow

## What This Prototype Does Not Yet Claim

This implementation should **not** be presented as supporting:

- multi-recipient payout splits
- large fan-out allocation vectors
- batch payout to hundreds or thousands of recipients
- zero-knowledge privacy proofs
- full DDEX or ISRC integration at the code level
- fully automated audit generation from settlement events

## Repository Structure

```text
contracts/
  AssetRegistry.sol
  LicenseTerms.sol
  RoyaltyEngine.sol
  AuditCompliance.sol
  MintUSD.sol

scripts/
  simulate.js
  validate_fixed.js

README.md
```

## Quick Validation Logic

The validation script checks the minimal end-to-end flow:

- deploy contracts
- assign roles
- mint asset
- propose and approve terms
- publish terms
- fund royalty engine
- submit usage
- confirm creator payout
- reject duplicate usage
- record audit bundle
- mark compliance
- open and resolve dispute

## Example Minimal Flow

1. Admin deploys contracts.
2. Admin grants creator, validator, and reporter roles.
3. Creator mints an asset.
4. Creator proposes terms.
5. Validator approves.
6. Admin publishes the terms.
7. Reporter funds the engine.
8. Reporter submits usage.
9. Royalty is paid to the current owner.
10. Reporter records audit bundle.
11. Regulator marks compliance.
12. Creator or reporter opens dispute if needed.
13. Arbiter resolves dispute.

## Suggested Positioning For GitHub

A safe repository description is:

> Minimal blockchain prototype for governed royalty settlement with approval-gated terms, single-owner payouts, audit records, and dispute handling.

That wording matches the current code much better than broader claims about large-scale multi-party royalty reconstruction.

## Limitations

This prototype is intentionally minimal.

Current limitations:
- payout goes to one current owner only
- no native split-recipient allocation
- audit recording is manual, not auto-triggered by payout
- no privacy-preserving proof layer yet
- not production-audited

## Future Extensions

Possible next steps:
- multi-recipient royalty splits
- batched payout execution
- better rights metadata integration
- automated settlement-to-audit linkage
- public testnet deployment scripts
- frontend dashboard for creator-facing visibility

## Research Use

This repository is suitable for:
- prototype demonstration
- controlled test scenarios
- research and educational use
- evidence for a minimal creator-facing governance artifact

It should not be treated as a production-ready royalty infrastructure.

## License

Recommended repository license: **MIT**

Reason:
- the Solidity files already use `SPDX-License-Identifier: MIT`
- MIT is simple and consistent with a research prototype
- it makes reuse terms clear for anyone who views the public repository
