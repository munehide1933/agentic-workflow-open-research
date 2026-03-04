# Intelligent Agent Runtime（开源研究版）

这个仓库是文档优先的公开版本，重点展示企业级 Agentic Workflow 的可靠性工程方法，而非公开完整运行时代码。

## 核心定位

企业场景里最常见的失败不是模型智力不足，而是控制平面缺失：

- 缺少证据边界
- 缺少独立审计
- 缺少稳定输出契约
- 缺少可执行安全收口与降级路径

## 公开与非公开边界

公开内容：

- 架构规范与流程文档
- 公开 JSON 契约（diagnosis/audit/SSE）
- 三语文档（中/日/英）
- 流程图与伪代码

非公开内容：

- 本地执行层（shell/文件系统/系统调用）
- 私有阈值、私有 prompt、生产部署细节
- 与私有基础设施强耦合的记忆实现细节

边界说明见 [Open-Source Boundary](./docs/architecture/open-source-boundary.md)。

## 契约索引

- [公共契约索引](./examples/contracts/README.md)
- [Diagnosis Structure Schema](./examples/contracts/diagnosis-structure.schema.json)
- [Second-Pass Audit Schema v1](./examples/contracts/second-pass-audit.schema.json)
- [Second-Pass Audit Schema v2](./examples/contracts/second-pass-audit.schema.v2.json)
- [SSE Event Schema v1](./examples/contracts/sse-event.schema.v1.json)

## 已实现能力

1. 多模式路由：`basic / deep_thinking / web_search`
2. SSE 契约化输出：`status/content/final/error`
3. 结构化诊断与显式不确定性
4. 二阶段审计 + non-echo 检查 + safe degrade/partial salvage
5. Anchor Guard 锚点评分与分级收口
6. Quality Gate 三档决策：`pass/soft_fail/hard_fail`
7. 记忆体系：SQLite + 可选 Qdrant + run 级回滚
8. 状态机双终态：`S_FAIL_RETRYABLE / S_FAIL_TERMINAL`

## 架构规范文档（中/日/英同步）

- [SSE 响应契约（中文）](./docs/architecture/sse-response-contract.zh.md)
- [SSE Response Contract (EN)](./docs/architecture/sse-response-contract.md)
- [SSE レスポンス契約（日本語）](./docs/architecture/sse-response-contract.ja.md)
- [Second-Pass Audit 合并策略（中文）](./docs/architecture/second-pass-audit-merge-policy.zh.md)
- [Second-Pass Audit Merge Policy (EN)](./docs/architecture/second-pass-audit-merge-policy.md)
- [Second-Pass Audit マージポリシー（日本語）](./docs/architecture/second-pass-audit-merge-policy.ja.md)
- [Anchor Guard 设计规范（中文）](./docs/architecture/anchor-guard.zh.md)
- [Anchor Guard Design (EN)](./docs/architecture/anchor-guard.md)
- [Anchor Guard 設計仕様（日本語）](./docs/architecture/anchor-guard.ja.md)
- [路由与模式选择规范（中文）](./docs/architecture/routing-mode-selection.zh.md)
- [Routing and Mode Selection (EN)](./docs/architecture/routing-mode-selection.md)
- [ルーティングとモード選択仕様（日本語）](./docs/architecture/routing-mode-selection.ja.md)
- [Quality Gate 规则框架（中文）](./docs/architecture/quality-gate-framework.zh.md)
- [Quality Gate Framework (EN)](./docs/architecture/quality-gate-framework.md)
- [Quality Gate ルールフレームワーク（日本語）](./docs/architecture/quality-gate-framework.ja.md)
- [错误分类与可观测性规范（中文）](./docs/architecture/error-taxonomy-observability.zh.md)
- [Error Taxonomy and Observability (EN)](./docs/architecture/error-taxonomy-observability.md)
- [エラー分類と可観測性仕様（日本語）](./docs/architecture/error-taxonomy-observability.ja.md)
- [Memory 层架构规范（中文）](./docs/architecture/memory-architecture.zh.md)
- [Memory Architecture (EN)](./docs/architecture/memory-architecture.md)
- [Memory レイヤー仕様（日本語）](./docs/architecture/memory-architecture.ja.md)
- [状态机完整转移矩阵（中文）](./docs/architecture/state-machine-transition-matrix.zh.md)
- [State Machine Transition Matrix (EN)](./docs/architecture/state-machine-transition-matrix.md)
- [状態機械の完全遷移行列（日本語）](./docs/architecture/state-machine-transition-matrix.ja.md)
- [可靠性 Benchmark 方法论（中文）](./docs/architecture/benchmark-methodology.zh.md)
- [Benchmark Methodology (EN)](./docs/architecture/benchmark-methodology.md)
- [信頼性 Benchmark 方法論（日本語）](./docs/architecture/benchmark-methodology.ja.md)

## 其他说明

- [框架设计、思考方式与客户价值映射（中文）](./docs/architecture/framework-design-thinking-and-customer-value.zh.md)
- [Framework Design, Engineering Thinking, and Customer Problem Fit (EN)](./docs/architecture/framework-design-thinking-and-customer-value.en.md)
