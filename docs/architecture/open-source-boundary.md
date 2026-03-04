# Open-Source Boundary

This document defines what is public, partially public, and private in the open research edition.

## Public (100%)

- Architecture docs and state-machine flow
- Evidence-First Diagnosis data model and schema contracts
- Second-Pass Audit contract and merge strategy description
- Anchor Guard scoring defaults and public guard interface contract
- Routing mode thresholds and public default feature-derivation formulas
- Quality Gate decision framework and public risk-category taxonomy
- Memory interface contracts and public default retrieval threshold with recalibration method
- Pseudocode and non-executable examples

## Partially Public (Redacted)

- Full risky-pattern rule bodies (pattern implementation details)
- Proprietary anti-abuse heuristics and policy tuning weights
- Private calibration datasets and internal labeling guidelines
- Memory indexing internals and deployment-specific performance knobs

## Private (Not Published)

- Local execution layer (shell/filesystem/system calls)
- Production policy constants and anti-abuse heuristics not in public defaults
- Prompt internals with sensitive behavior tuning
- Private deployment topology and infrastructure details
- Secrets, keys, private endpoints, real tenant metadata

## Release Guard Checklist

1. No `.env`, key material, or endpoint credentials in history.
2. No local absolute paths from development machines.
3. No logs containing request payloads with private user data.
4. No executable operators for local host control.
5. No private policy rulebooks used for production defense.
