# Intelligent Agent Runtime (Open Research Edition)

This repository is a documentation-first public release of an enterprise-grade agentic workflow.
It focuses on reliability, observability, and controllability patterns without exposing private runtime internals.

## Position

Most production failures in enterprise agents are control-plane failures:

- no explicit evidence boundary
- no independent audit challenge
- no deterministic output contract
- no enforceable safety and degradation gates

This release documents an engineering alternative:

1. Evidence-First Diagnosis (`facts -> hypotheses -> tests`)
2. Second-Pass Audit (`draft -> challenge -> conditional merge`)
3. Anchor Guard + Quality Gate (bounded code safety)
4. State-machine orchestration (deterministic transitions and fail classes)

## What Is Included

- Architecture and policy specifications
- Public JSON schema contracts (diagnosis, audit, SSE)
- Multi-language documentation (English, Chinese, Japanese)
- Mermaid flow diagrams
- Public pseudocode

## What Is Intentionally Excluded

- local execution operators (filesystem/shell/system calls)
- private tuning constants and anti-abuse heuristics
- sensitive prompt internals and deployment settings
- private infrastructure-specific memory/indexing internals

See [Open-Source Boundary](./docs/architecture/open-source-boundary.md).

## Contract Index

- [Public Contract Index](./examples/contracts/README.md)
- [Diagnosis Structure Schema](./examples/contracts/diagnosis-structure.schema.json)
- [Second-Pass Audit Schema v1](./examples/contracts/second-pass-audit.schema.json)
- [Second-Pass Audit Schema v2](./examples/contracts/second-pass-audit.schema.v2.json)
- [SSE Event Schema v1](./examples/contracts/sse-event.schema.v1.json)

## Implemented Capabilities

1. Multi-mode routing: `basic / deep_thinking / web_search`
2. Formal SSE stream contract: `status/content/final/error`
3. Structured diagnosis artifact with explicit uncertainty fields
4. Second-pass audit with non-echo checks and safe degrade/partial salvage
5. Anchor Guard with public anchor scoring thresholds
6. Quality Gate with `pass/soft_fail/hard_fail`
7. Session and memory stack: SQLite + optional Qdrant + rollback semantics
8. State machine with split fail classes: `S_FAIL_RETRYABLE / S_FAIL_TERMINAL`

## Architecture Specifications

- [SSE Response Contract (EN)](./docs/architecture/sse-response-contract.md)
- [SSE 响应契约（中文）](./docs/architecture/sse-response-contract.zh.md)
- [SSE レスポンス契約（日本語）](./docs/architecture/sse-response-contract.ja.md)
- [Second-Pass Audit Merge Policy (EN)](./docs/architecture/second-pass-audit-merge-policy.md)
- [Second-Pass Audit 合并策略（中文）](./docs/architecture/second-pass-audit-merge-policy.zh.md)
- [Second-Pass Audit マージポリシー（日本語）](./docs/architecture/second-pass-audit-merge-policy.ja.md)
- [Anchor Guard Design (EN)](./docs/architecture/anchor-guard.md)
- [Anchor Guard 设计规范（中文）](./docs/architecture/anchor-guard.zh.md)
- [Anchor Guard 設計仕様（日本語）](./docs/architecture/anchor-guard.ja.md)
- [Routing and Mode Selection (EN)](./docs/architecture/routing-mode-selection.md)
- [路由与模式选择规范（中文）](./docs/architecture/routing-mode-selection.zh.md)
- [ルーティングとモード選択仕様（日本語）](./docs/architecture/routing-mode-selection.ja.md)
- [Quality Gate Framework (EN)](./docs/architecture/quality-gate-framework.md)
- [Quality Gate 规则框架（中文）](./docs/architecture/quality-gate-framework.zh.md)
- [Quality Gate ルールフレームワーク（日本語）](./docs/architecture/quality-gate-framework.ja.md)
- [Error Taxonomy and Observability (EN)](./docs/architecture/error-taxonomy-observability.md)
- [错误分类与可观测性规范（中文）](./docs/architecture/error-taxonomy-observability.zh.md)
- [エラー分類と可観測性仕様（日本語）](./docs/architecture/error-taxonomy-observability.ja.md)
- [Memory Architecture (EN)](./docs/architecture/memory-architecture.md)
- [Memory 层架构规范（中文）](./docs/architecture/memory-architecture.zh.md)
- [Memory レイヤー仕様（日本語）](./docs/architecture/memory-architecture.ja.md)
- [State Machine Transition Matrix (EN)](./docs/architecture/state-machine-transition-matrix.md)
- [状态机完整转移矩阵（中文）](./docs/architecture/state-machine-transition-matrix.zh.md)
- [状態機械の完全遷移行列（日本語）](./docs/architecture/state-machine-transition-matrix.ja.md)
- [Benchmark Methodology (EN)](./docs/architecture/benchmark-methodology.md)
- [可靠性 Benchmark 方法论（中文）](./docs/architecture/benchmark-methodology.zh.md)
- [信頼性 Benchmark 方法論（日本語）](./docs/architecture/benchmark-methodology.ja.md)
- [Agentic Workflow Architecture (EN)](./docs/architecture/agentic-workflow.md)
- [State-Machine Governance (EN)](./docs/architecture/state-machine-governance.md)
- [Diagnosis Structure (EN)](./docs/architecture/diagnosis-structure.md)
- [Runtime vNext Iteration Plan and Primary Design Goals (EN)](./docs/architecture/runtime-vnext-iteration-plan.md)
- [Runtime vNext 迭代计划与主要设计目标（中文）](./docs/architecture/runtime-vnext-iteration-plan.zh.md)
- [Runtime vNext イテレーション計画と主要設計目標（日本語）](./docs/architecture/runtime-vnext-iteration-plan.ja.md)

## Framework Notes

- [Framework Design, Engineering Thinking, and Customer Problem Fit (EN)](./docs/architecture/framework-design-thinking-and-customer-value.en.md)
- [框架设计、思考方式与客户价值映射（中文）](./docs/architecture/framework-design-thinking-and-customer-value.zh.md)

## Papers

- [Beyond Prompt Engineering (EN)](./docs/papers/beyond-prompt-engineering.en.md)
- [Beyond Prompt Engineering（日本語版）](./docs/papers/beyond-prompt-engineering.ja.md)
- [Diagnosis Structure (EN)](./docs/papers/diagnosis-structure.evidence-first.en.md)
- [Diagnosis Structure（日本語版）](./docs/papers/diagnosis-structure.evidence-first.ja.md)
- [Anchor Guard (EN)](./docs/papers/anchor-guard.reliable-codegen.en.md)
- [Anchor Guard（日本語版）](./docs/papers/anchor-guard.reliable-codegen.ja.md)

## License

This open research edition is released under Apache-2.0.
