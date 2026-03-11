# Runtime 能力地图（七主线扩展）

## 系统标识

- 系统名：`Intelligent Agent Runtime (IAR)`
- 设计模式：`Two-Stage Contract-Driven Delivery`（中文：`双阶段契约驱动交付模式`）

## 1. 范围

本文是七主线 runtime 扩展的统一入口地图。
用于定义主题边界、依赖顺序、发布节奏与契约产物。

不在范围内：

- 私有 prompt 内部细节
- 私有基础设施地址与部署拓扑
- 本地执行算子

## 2. 能力主线

公开 runtime 能力通过以下七条主线扩展：

1. `Design Philosophy`
2. `Agent Pipeline`
3. `Deep Thinking Model Governance`
4. `Memory System`
5. `Action/Tools System`
6. `Execution Safety Envelope`
7. `Reliability Mechanisms`

每条主线都以 EN/ZH/JA 三语独立规范发布。

## 3. 依赖关系图

| 主线 | 依赖 | 主要输出 |
| --- | --- | --- |
| Design Philosophy | - | 决策原则与边界规则 |
| Agent Pipeline | Design Philosophy | 阶段契约与转移 profile |
| Deep Thinking Model Governance | Design Philosophy, Agent Pipeline | 模型路由与降级策略 |
| Memory System | Agent Pipeline | 记忆注入与 checkpoint 语义 |
| Action/Tools System | Agent Pipeline, Safety Envelope | 工具调用契约与工具失败策略 |
| Execution Safety Envelope | Design Philosophy | 白名单、守卫、预算、输出控制 |
| Reliability Mechanisms | Pipeline, Safety, Deep Thinking | runtime boundary、超时转移、failover profile |

## 3.1 系统分层映射（IAR 设计图）

本映射与当前 IAR 系统设计图对齐，并将组件绑定到公开能力主线。

![IAR Full System View](./assets/runtime-diagrams/runtime-full-system-view.png)

该系统图作为当前公开结构的主可视化入口；下表保留为契约化文本视图，便于评审与比对。

| 分层 | 代表组件 | 主要绑定主线 |
| --- | --- | --- |
| Frontend | Next.js `Composer`、`Conversation View`、`useAgentChat/useArtifactLibrary` hooks、Web UI 开关 | Agent Pipeline、Reliability |
| API Gateway | FastAPI 路由、安全中间件、SSE 流端点 | Safety Envelope、Observability |
| Agent Orchestration | `AgentPipeline`、阶段转移、`Output Contract Gate v3.0`、final 单写者路径 | Agent Pipeline、Reliability |
| Platform Services | `Vision Extract`、`Language Rewriter`、`Long-term Memory`、流适配器 | Deep Thinking、Memory、Action/Tools |
| Data Layer | SQLite 产物/摘要、Qdrant 集合、备份调度器 | Memory、Reliability |
| Observability | runtime 事件流、结构化日志、延迟/token budget/trace 指标 | 可观测性契约、Reliability |
| External Dependencies | 模型 API、可选 web search 提供方 | Deep Thinking 治理、Action/Tools 策略 |

## 4. 文档与契约产物

### 4.1 架构文档

- `runtime-design-philosophy.*`
- `agent-pipeline-contract-profile.*`
- `deep-thinking-model-governance.*`
- `memory-system-operational-contract.*`
- `action-tools-system-contract.*`
- `execution-safety-envelope-runtime.*`
- `runtime-reliability-mechanisms.*`

### 4.2 JSON Schema 契约

- `examples/contracts/runtime-boundary.schema.v1.json`
- `examples/contracts/artifact-lifecycle.schema.v1.json`
- `examples/contracts/second-pass-timeout-profile.schema.v1.json`

## 5. 发布与评审节奏

- 每两周发布一次增量更新
- 每月发布一次 ADR 快照
- 每次发布标签前执行三语同步检查
- 任何契约变更都必须更新 schema 版本矩阵

## 6. 发布门禁

若任一条件不满足，候选版本不得发布：

1. EN/ZH/JA 章节编号不一致
2. 契约字段与现有公开 schema 冲突
3. 验收场景不可机器验证
4. schema 变更缺少迁移说明
5. 交叉引用链接失效
6. 边界规则泄露私有实现细节

## 7. 版本矩阵规则

1. 新增可选字段属于 minor 兼容
2. 必填字段变更必须发布新 schema 版本文件
3. 字段删除属于 breaking change，必须提供迁移说明
4. 文档行为变化必须显式列出需同步更新的文件

## 8. 交叉引用

- [Runtime 设计哲学](./runtime-design-philosophy.zh.md)
- [Agent Pipeline 契约 Profile](./agent-pipeline-contract-profile.zh.md)
- [Deep Thinking 模型治理](./deep-thinking-model-governance.zh.md)
- [Memory 系统运行契约](./memory-system-operational-contract.zh.md)
- [Action/Tools 系统契约](./action-tools-system-contract.zh.md)
- [Execution Safety Envelope Runtime](./execution-safety-envelope-runtime.zh.md)
- [Runtime 可靠性机制](./runtime-reliability-mechanisms.zh.md)
- [AgenticAI 与 Open-Source 能力对齐](./agenticai-opensource-alignment.zh.md)
- [Runtime vNext 迭代计划与主要设计目标](./runtime-vnext-iteration-plan.zh.md)
- [Runtime 分层架构图（EN）](./runtime-layered-architecture.md)
- [SSE 响应契约](./sse-response-contract.zh.md)
- [错误分类与可观测性规范](./error-taxonomy-observability.zh.md)
- [Second-Pass Audit 合并策略](./second-pass-audit-merge-policy.zh.md)
