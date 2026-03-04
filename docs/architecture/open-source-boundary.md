# Open-Source Boundary

This document defines what is public, partially public, and private in the open research edition.

## Public (100%)

- Architecture docs and state-machine flow
- Evidence-First Diagnosis data model and schema contracts
- Second-Pass Audit contract and merge strategy description
- Anchor Guard decision policy at abstract level
- Pseudocode and non-executable examples

## Partially Public (Redacted)

- Quality gate design goals (without full rule sets)
- Routing principles (without proprietary thresholds)
- Memory interface contracts (without private indexing strategies)

## Private (Not Published)

- Local execution layer (shell/filesystem/system calls)
- Production policy constants and anti-abuse heuristics
- Prompt internals with sensitive behavior tuning
- Private deployment topology and infrastructure details
- Secrets, keys, private endpoints, real tenant metadata

## Release Guard Checklist

1. No `.env`, key material, or endpoint credentials in history.
2. No local absolute paths from development machines.
3. No logs containing request payloads with private user data.
4. No executable operators for local host control.
5. No private policy rulebooks used for production defense.

