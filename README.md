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

## What Is Implemented Today (No Overclaim)

1. Multi-mode conversation: `basic / deep_thinking / web_search`
2. SSE response contract with explicit `status/content/final/error` events
3. Structured diagnosis: `facts`, `hypotheses`, `excluded_hypotheses`, `insufficient_evidence`
4. Second-pass audit with timeout-aware safe degradation
5. Anchor Guard for under-anchored code requests
6. Code artifact quality gate (syntax checks + risky pattern scan + graded fallback)
7. Session and memory stack: SQLite short-term + optional Qdrant long-term
8. Reliability baseline: WAL, retries, logging, rate limiting, optional backup scheduler

## Customer Problems This Can Solve

- hard-to-audit troubleshooting conversations
- overconfident answers under weak evidence
- code guidance without runtime anchors
- unstable output shape for frontend/system integration
- high postmortem cost due to non-reproducible chat behavior

## Framework and Thinking Notes

- [Framework Design, Engineering Thinking, and Customer Problem Fit (EN)](./docs/architecture/framework-design-thinking-and-customer-value.en.md)
- [框架设计、思考方式与客户价值映射（中文）](./docs/architecture/framework-design-thinking-and-customer-value.zh.md)

## License

This open research edition is released under Apache-2.0.
