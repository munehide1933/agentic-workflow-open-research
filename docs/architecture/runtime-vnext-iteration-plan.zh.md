# Runtime vNext 迭代计划与主要设计目标（Production Hardening）

## 1. 文档定位

这份文档用于对外说明 Runtime 下一阶段的工程计划。
重点不是展示功能清单，而是说明系统如何在可靠性、安全性、可审计性和运行治理上达到 production-grade。

## 2. 目标读者

- 平台/基础设施工程师
- 架构评审与技术负责人
- SRE 与运维治理团队
- 需要评估系统可上线性的合作方

## 3. 本阶段结束后的目标状态

本阶段结束时，Runtime 应具备以下可验证能力：

- 执行行为可被严格约束并隔离
- 工作流可重放、可恢复、可审计
- 关键路径具备完整可观测性
- 失败可分类、可自动转移、可自动降级
- 多租户下具备背压、配额与资源治理

## 4. 当前基线与关键缺口

当前已具备：

- Anchor Guard + Quality Gate（安全收口基础）
- Evidence/Audit schema（证据与审计结构化）
- 状态机驱动流程（确定性雏形）

仍需补齐：

- execution isolation
- deterministic replay
- production observability
- runtime-level backpressure
- multi-tenant safety
- resource quota & scheduling
- 端到端 SLA 与 failure handling

## 5. 范围与非目标

In Scope：

- SO2AFR 六层能力补齐（Safety / Orchestration / Observability / Auditability / Failure / Runtime Ops）
- 契约化 schema 与版本治理
- 自动化发布门禁与回归验证

Out of Scope：

- 新业务功能扩展
- 私有基础设施细节公开
- 与生产稳定性无关的实验功能

## 6. SO2AFR 主要设计目标（目标-机制-验收信号）

| Layer | 目标 | 关键机制 | 验收信号 |
| --- | --- | --- | --- |
| S | 执行安全边界可强制执行 | 白名单闭集、step 沙箱、五维预算（token/tool/latency/memory/output） | 所有请求可判定 allow/deny；超限必终止并产生日志证据 |
| O | 编排确定性与可恢复 | FSM 作为 SSOT；事务 checkpoint；side-effect 幂等键 | 同输入 replay 一致；崩溃可从 checkpoint 恢复且不重调模型 |
| O2 | 可观测性成为契约 | 指标/日志/追踪强制字段；run-step-span 链路 | 关键路径 trace 完整；终态错误可由 trace_id+run_id 关联 |
| A | 审计链可独立验证 | evidence version/diff/hash；独立审计模型链路；确定性 merge | hash 可复算；审计可重放；merge 在同证据下稳定一致 |
| F | 失败系统可操作 | failure taxonomy；状态机事件化；降级策略图 | 所有失败可归类并自动转移/降级，不依赖人工临场决策 |
| R | 运行时治理可规模化 | queue + worker + priority；backpressure；多租户配额 | 高峰无级联雪崩；租户隔离可观测；SLA 违约可自动告警 |

## 7. 迭代路线图（8-10 周）

### Sprint 1（周 1-2）: Contract First + Safety Baseline

重点：先锁定契约与安全底线。

交付：

- 六大 schema v1：execution/state/checkpoint/failure/observability/audit
- 行为白名单与预算 enforcement
- 基线 sandbox 执行路径

Exit Criteria：

- schema conformance tests 全通过
- 非白名单行为被拒绝且审计记录完整

### Sprint 2（周 3-5）: Deterministic Core

重点：把“可运行”升级为“可重放、可恢复”。

交付：

- 事务化 checkpoint pipeline
- replay engine（恢复时禁止模型重调）
- crash recovery + side-effect idempotency contract

Exit Criteria：

- replay consistency 测试通过
- 故障注入下可从 checkpoint 持续执行

### Sprint 3（周 6-7）: Observability + Failure System

重点：把运行行为变成可度量、可诊断、可自动处理。

交付：

- metrics/tracing/JSON logs 全链路接入
- failure taxonomy + transition matrix 固化
- degradation policy engine

Exit Criteria：

- 关键 workflow trace 拓扑完整
- 各 failure class 均可自动转移并执行降级路径

### Sprint 4（周 8-10）: Runtime Ops + Audit Strengthening

重点：实现生产运行治理与审计闭环。

交付：

- backpressure、队列优先级、配额治理
- 多租户并发与资源调度策略
- evidence version/hash/diff + independent auditor path
- SLA/SLO 演练与压测报告

Exit Criteria：

- 压测下系统稳定，队列可控，无级联雪崩
- 审计链支持独立重放验证

## 8. 对外持续输出计划（高级设计模式）

为保证外部能够持续看见设计演化，本阶段按节奏发布以下模式文档：

1. Execution Safety Envelope Pattern
2. Deterministic Log Replay Pattern
3. Observability-as-Contract Pattern
4. Independent Auditor Chain Pattern
5. Failure-Class + Degradation Graph Pattern
6. Quota-Driven Multi-Tenant Scheduler Pattern

每个模式文档固定包含：

- 问题背景与约束
- 契约定义与状态转移
- 失败处理与降级策略
- 验收用例与反例

发布节奏：

- 每 2 周发布一篇模式文档或更新稿
- 每月发布一次架构决策记录汇总（ADR Snapshot）
- 每个 Sprint 结束发布一次里程碑验证结果

## 9. 契约与版本治理

- API contract versioning（显式版本号 + 兼容窗口）
- backward compatibility rule（新增字段向后兼容；删除字段触发 major）
- error schema contract（稳定最小字段与错误语义）
- checkpoint schema evolution（旧版可读取与迁移）

## 10. 发布门禁（Release Gates）

以下任一项未满足，禁止 production rollout：

1. replay-safe 不成立，或 replay 结果不一致
2. failure class 不完整，或自动转移链路缺失
3. 关键路径存在 trace/log/metrics 观测盲区
4. evidence hash 不可复算，或审计链不可独立验证
5. 背压与配额机制在压测中失效
6. SLA 指标无稳定基线或告警规则未生效

## 11. 交付物清单

- `runtime-vnext architecture spec`（总览 + 子规范）
- `schema bundle v1`（六大契约与版本说明）
- `transition & degradation matrix`
- `checkpoint/replay conformance tests`
- `observability dashboard & alert rules`
- `SLA/SLO baseline & stress report`
- `audit replay evidence report`
- `ADR snapshot series`

## 12. 完成定义（Definition of Done）

vNext 仅在以下条件全部满足时视为完成：

1. SO2AFR 六层能力有实现、测试、运行证据
2. 同输入可稳定重放，恢复过程不重调模型
3. 失败处理可自动降级，不依赖人工临场决策
4. 多租户资源边界可观测、可治理、可审计
5. 对外发布的模式文档与验证报告可复核
