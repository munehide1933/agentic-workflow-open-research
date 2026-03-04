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

