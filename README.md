# Intelligent Agent Runtime (Open Research Edition)

This repository is a public, documentation-first release of an enterprise-grade agentic workflow.
It focuses on engineering methods for reliability, observability, and controllability without exposing private runtime internals.

## Position

Most production failures in enterprise agents are not model IQ failures.
They are control-plane failures:

- no explicit evidence boundary
- no post-generation audit
- no deterministic safety gate for code suggestions
- no state machine to constrain behavior

This release documents a practical alternative:

1. Evidence-First Diagnosis (`facts -> hypotheses -> tests`)
2. Second-Pass Audit (`draft -> independent challenge -> merge`)
3. Anchor Guard (blocks unsafe or under-anchored code output)
4. State-Machine-Driven orchestration (predictable transitions, explicit degradation)

## What Is Included

- Architecture documents and workflow contracts
- Deep technical papers in English and Japanese
- Mermaid diagrams for diagnosis and audit flow
- Public schemas (diagnosis and audit JSON contracts)
- Pseudocode for implementation guidance

## What Is Intentionally Excluded

- Local execution layer (filesystem/shell/system-level operators)
- Proprietary policy heuristics and production tuning constants
- Sensitive prompt templates and private deployment settings
- Internal memory/indexing strategies tied to private infrastructure

See [Open-Source Boundary](./docs/architecture/open-source-boundary.md) for details.

## Repository Layout

```text
docs/
  architecture/
  diagrams/
  papers/
examples/
  contracts/
  pseudocode/
README.md
README.ja.md
README.zh.md
LICENSE
```

## Core Diagram

See [Diagnosis Flow Diagram](./docs/diagrams/diagnosis-structure-flow.mmd).

## Papers

- English: [Beyond Prompt Engineering](./docs/papers/beyond-prompt-engineering.en.md)
- Japanese: [Beyond Prompt Engineering（日本語版）](./docs/papers/beyond-prompt-engineering.ja.md)

## License

This open research edition is released under Apache-2.0.

