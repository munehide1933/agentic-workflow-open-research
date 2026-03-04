# Intelligent Agent Runtime（公開研究版）

このリポジトリは、エンタープライズ向け Agentic Workflow の信頼性設計を公開する文書中心版です。
機密ランタイム実装は含みません。

## 基本方針

本番障害の主要因はモデル能力不足ではなく制御面の欠落です。

- 証拠境界がない
- 独立監査がない
- 出力契約が不安定
- 安全ゲートと劣化経路が不明確

## 公開/非公開境界

公開：

- アーキテクチャ仕様とワークフロー文書
- JSON 契約（diagnosis/audit/SSE）
- 日中英の同期文書
- フローダイアグラムと擬似コード

非公開：

- ローカル実行層（shell/filesystem/system call）
- 私有閾値、秘密プロンプト、運用設定
- private infra 依存メモリ実装詳細

詳細は [Open-Source Boundary](./docs/architecture/open-source-boundary.md)。

## 契約インデックス

- [Public Contract Index](./examples/contracts/README.md)
- [Diagnosis Structure Schema](./examples/contracts/diagnosis-structure.schema.json)
- [Second-Pass Audit Schema v1](./examples/contracts/second-pass-audit.schema.json)
- [Second-Pass Audit Schema v2](./examples/contracts/second-pass-audit.schema.v2.json)
- [SSE Event Schema v1](./examples/contracts/sse-event.schema.v1.json)

## 実装済み能力

1. ルーティングモード：`basic / deep_thinking / web_search`
2. SSE 契約化出力：`status/content/final/error`
3. 構造化診断と明示的不確実性
4. second pass + non-echo 判定 + safe degrade/partial salvage
5. Anchor Guard のアンカースコアリング
6. Quality Gate の三段階判定：`pass/soft_fail/hard_fail`
7. メモリ層：SQLite + optional Qdrant + run 単位ロールバック
8. 状態機械 fail 分割：`S_FAIL_RETRYABLE / S_FAIL_TERMINAL`

## アーキテクチャ仕様（日中英同期）

- [SSE レスポンス契約（日本語）](./docs/architecture/sse-response-contract.ja.md)
- [SSE Response Contract (EN)](./docs/architecture/sse-response-contract.md)
- [SSE 响应契约（中文）](./docs/architecture/sse-response-contract.zh.md)
- [Second-Pass Audit マージポリシー（日本語）](./docs/architecture/second-pass-audit-merge-policy.ja.md)
- [Second-Pass Audit Merge Policy (EN)](./docs/architecture/second-pass-audit-merge-policy.md)
- [Second-Pass Audit 合并策略（中文）](./docs/architecture/second-pass-audit-merge-policy.zh.md)
- [Anchor Guard 設計仕様（日本語）](./docs/architecture/anchor-guard.ja.md)
- [Anchor Guard Design (EN)](./docs/architecture/anchor-guard.md)
- [Anchor Guard 设计规范（中文）](./docs/architecture/anchor-guard.zh.md)
- [ルーティングとモード選択仕様（日本語）](./docs/architecture/routing-mode-selection.ja.md)
- [Routing and Mode Selection (EN)](./docs/architecture/routing-mode-selection.md)
- [路由与模式选择规范（中文）](./docs/architecture/routing-mode-selection.zh.md)
- [Quality Gate ルールフレームワーク（日本語）](./docs/architecture/quality-gate-framework.ja.md)
- [Quality Gate Framework (EN)](./docs/architecture/quality-gate-framework.md)
- [Quality Gate 规则框架（中文）](./docs/architecture/quality-gate-framework.zh.md)
- [エラー分類と可観測性仕様（日本語）](./docs/architecture/error-taxonomy-observability.ja.md)
- [Error Taxonomy and Observability (EN)](./docs/architecture/error-taxonomy-observability.md)
- [错误分类与可观测性规范（中文）](./docs/architecture/error-taxonomy-observability.zh.md)
- [Memory レイヤー仕様（日本語）](./docs/architecture/memory-architecture.ja.md)
- [Memory Architecture (EN)](./docs/architecture/memory-architecture.md)
- [Memory 层架构规范（中文）](./docs/architecture/memory-architecture.zh.md)
- [状態機械の完全遷移行列（日本語）](./docs/architecture/state-machine-transition-matrix.ja.md)
- [State Machine Transition Matrix (EN)](./docs/architecture/state-machine-transition-matrix.md)
- [状态机完整转移矩阵（中文）](./docs/architecture/state-machine-transition-matrix.zh.md)
- [信頼性 Benchmark 方法論（日本語）](./docs/architecture/benchmark-methodology.ja.md)
- [Benchmark Methodology (EN)](./docs/architecture/benchmark-methodology.md)
- [可靠性 Benchmark 方法论（中文）](./docs/architecture/benchmark-methodology.zh.md)
- [Agentic Workflow Architecture (EN)](./docs/architecture/agentic-workflow.md)
- [State-Machine Governance (EN)](./docs/architecture/state-machine-governance.md)
- [Diagnosis Structure (EN)](./docs/architecture/diagnosis-structure.md)
- [Runtime vNext Iteration Plan and Primary Design Goals (EN)](./docs/architecture/runtime-vnext-iteration-plan.md)
- [Runtime vNext 迭代计划与主要设计目标（中文）](./docs/architecture/runtime-vnext-iteration-plan.zh.md)
- [Runtime vNext イテレーション計画と主要設計目標（日本語）](./docs/architecture/runtime-vnext-iteration-plan.ja.md)

## 補足

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

この公開研究版は Apache-2.0 ライセンスで提供されます。
