# 错误分类与可观测性规范

## 1. 范围

本规范定义公开错误码命名空间、日志必填字段与链路追踪规则。

## 2. 错误码命名空间

公开前缀：

- `E_MODEL_*`：模型服务或运行时错误
- `E_SCHEMA_*`：schema 校验与解析错误
- `E_TIMEOUT_*`：阶段超时错误
- `E_POLICY_*`：策略与守卫违规
- `E_ROUTER_*`：路由决策失败
- `E_MEMORY_*`：记忆读写检索失败
- `E_CONCURRENCY_*`：会话并发冲突

必须公开的关键错误码：

- `E_CONCURRENCY_CONFLICT`：同会话并发请求被拒绝。

## 3. 终止错误字段

所有终止错误必须包含：

- `error_code`
- `error_message`
- `retryable`
- `phase`
- `trace_id`
- `run_id`
- `session_id`

## 4. 结构化日志契约

日志必填字段：

- `ts`
- `level`
- `trace_id`
- `run_id`
- `session_id`
- `phase`
- `state`
- `event`
- `error_code`（若有）
- `latency_ms`

日志选填字段：

- `mode`
- `rule_id`
- `fallback_path`
- `quality_gate_decision`
- `anchor_score`

## 5. 追踪链路规则

1. 单次用户请求映射一个 `run_id`。
2. `trace_id` 可跨多个服务组件。
3. 同一次 run 的阶段日志和 SSE 事件必须共享 `trace_id` 与 `run_id`。
4. 重试必须生成新的 `run_id`，但保留同一 `trace_id`。

## 6. SSE 错误映射

SSE `error` 负载仅允许公开字段，不得包含密钥或私有 prompt 细节。

## 7. 验收场景

1. 模型超时输出 `E_TIMEOUT_STAGE_*` 且追踪字段齐全。
2. schema 解析失败输出 `E_SCHEMA_INVALID_PAYLOAD`。
3. 同会话并发冲突输出 `E_CONCURRENCY_CONFLICT`。
4. 全部错误事件可通过 `trace_id` 与 `run_id` 聚合。
