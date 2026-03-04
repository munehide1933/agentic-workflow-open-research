# Intelligent Agent Runtime（开源研究版）

这个仓库是文档优先的公开版本，重点展示 Agentic Workflow 的工程方法，而非公开完整运行时代码。

## 核心观点

企业场景下，不可控的对话系统不可用。
可生产化的智能体必须具备：

1. Evidence-First Diagnosis（证据优先诊断）
2. Second-Pass Audit（二阶段审计）
3. Anchor Guard（代码输出安全收口）
4. 状态机驱动（可预测、可降级、可审计）

## 本仓库公开内容

- 架构与流程设计文档
- 诊断/审计契约 schema
- 流程图（Mermaid）
- 英文与日文深度技术文章
- 可复现的伪代码

## 刻意不公开的内容

- 本地执行层（shell / 文件系统 / 系统调用）
- 私有策略参数、敏感 prompt、生产环境配置
- 与内部基础设施强耦合的实现细节

边界说明见 [Open-Source Boundary](./docs/architecture/open-source-boundary.md)。

## 我实际已经实现的能力（不夸大）

1. 多模式对话：`basic / deep_thinking / web_search`
2. SSE 流式输出契约：区分 `status/content/final/error`，并保证最终答案一致性
3. 诊断结构化：`facts / hypotheses / excluded_hypotheses / insufficient_evidence`
4. 二阶段审计：对草稿做独立复核，并在超时或异常时安全降级
5. Anchor Guard：锚点不完整时禁止输出高风险单栈可执行代码
6. 代码产物质量门：语法检查、危险模式扫描、分级降级
7. 记忆与会话：SQLite（短期）+ Qdrant（可选长期）+ 会话回滚
8. 工程稳定性：WAL、重试、日志、限流、可选自动备份

## 这些能力能解决的客户问题

- 线上故障定位时，回答“看起来合理但不可验证”
- 模型在证据不足时仍给出强结论
- 代码建议缺少运行时前提，交付后难落地
- 回答流程不可审计，复盘成本高
- 输出格式不稳定，前端和下游系统难对接

## 更完整说明

- [框架设计、思考方式与客户价值映射（中文）](./docs/architecture/framework-design-thinking-and-customer-value.zh.md)
- [Framework Design, Engineering Thinking, and Customer Problem Fit (EN)](./docs/architecture/framework-design-thinking-and-customer-value.en.md)
