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
- `request_id`
- `trace_id`
- `run_id`
- `session_id`

## 4. 结构化日志契约

日志必填字段：

- `ts`
- `level`
- `request_id`
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
2. HTTP 边界必须保留 `request_id`，并通过响应头 `X-Request-ID` 返回。
3. `trace_id` 可跨多个服务组件。
4. 同一次 run 的阶段日志和 SSE 事件必须共享 `trace_id` 与 `run_id`。
5. 重试必须生成新的 `run_id`，但保留同一 `trace_id`。

## 6. SSE 错误映射

SSE `error` 负载仅允许公开字段，不得包含密钥或私有 prompt 细节。

## 7. Runtime 最终 Metadata 契约

runtime 终态 metadata 必须公开以下字段：

- `runtime_boundary`
- `failure_event`
- `output_contract`
- `second_pass.timeout_profile`

这些字段遵循“新增可选字段向后兼容”，minor 版本不得删除既有公开字段。

## 8. 指标与追踪基线

必备指标维度：

- `step_latency_ms`（`p50`、`p95`、`p99`）
- `token_input`、`token_output`
- `model_cost`
- `audit_time`
- `guard_rejection_count`
- `retry_count`
- `failure_type_distribution`

rollout 与一致性治理指标：

- `quality_kernel_rollout_calls_total{source,surface}`
- `quality_kernel_rollout_fallback_total{source,surface,reason}`
- `quality_kernel_compare_requests_total{source,surface}`
- `quality_kernel_compare_request_mismatch_total{source,surface}`
- `quality_kernel_parity_mismatch_total{field}`
- `quality_kernel_parity_mismatch_by_source_total{source,surface,field}`
- `ui_stream_frame_builder_eligible_events_total{source,event_type}`
- `ui_stream_frame_builder_encoded_events_total{source,event_type,engine}`
- `ui_stream_frame_builder_rust_encoded_events_total{source,event_type}`
- `ui_stream_frame_builder_fallback_events_total{source,event_type,reason}`
- `ui_stream_rust_frame_builder_fallback_total{reason}`
- `first_meaningful_content_ms`（直方图）
- `idempotency_cleanup_run_total`
- `idempotency_cleanup_expired_total`
- `idempotency_cleanup_deleted_total`
- `idempotency_cleanup_lock_skip_total`
- `idempotency_cleanup_error_total`

追踪层级基线：

- `agent_run_id`
- `step_id`
- `model_call_span`
- `tool_call_span`
- `audit_span`
- `merge_span`

runtime quality 载荷基线：

- `runtime_quality.stage_snapshots[*]` 至少包含 `stage`、`model_deployment`、`estimated_tokens_in`、`estimated_tokens_out`、`duration_ms`、`flags`
- `runtime_quality.invariant_gate` 至少包含 `passed`、`reason_codes`、`metrics`、`fallback`
- `runtime_quality.degradation_flags` 用于记录 run 级降级标记
- `runtime_quality.performance.runtime_timeline[*]` 至少包含 `event`、`stage`、`phase`、`status`、`reason_code`、`ts_ms`、`details`
- `runtime_quality.performance.transition_records[*]` 至少包含 `from_state`、`to_state`、`event`、`action`、`reason_code`、`ts_ms`、`details`
- `runtime_quality.arbitration_ledger` 包含确定性仲裁决策投影与信号快照
- `runtime_quality.arbitration_summary` 包含用户可见仲裁摘要字段
- `runtime_quality.performance.general_latency_flags_effective.ttft_v2_enabled` 表示 TTFT v2 的有效配置状态
- `runtime_quality.performance.first_meaningful_content_ms` 记录首个非 preview 有意义正文延迟

### 8.1 Runtime Guardrail 分级契约

runtime guardrail 判定输出使用四个等级：

- `blocker`
- `high`
- `warning`
- `spike_alerts`

guardrail 输出结构：

- `blocker[]`：立即阻断发布的条件
- `high[]`：阻断发布的质量/可靠性回归
- `warning[]`：不阻断但必须跟踪的回归
- `spike_alerts[]`：相对基线快照的突发信号
- `signals{...}`：用于判定的比率信号载荷
- `rollout_primary_sources[]`：执行强约束的 rollout source（默认包含 `prod_mirror`）

覆盖率约束规则：

- 仅当 rollout 覆盖率达到阈值（`sse_fallback_eval_min_coverage`）时，才对 SSE fallback 触发 `high`。
- 覆盖率不足时，输出 `warning`（`sse_fallback_rate_not_enforced_low_coverage`），不升级为 `high`。

### 8.2 Regex Cache 诊断面（可选）

当 Rust quality kernel 扩展可用时，可暴露以下 regex cache 诊断字段：

- `hit_total`
- `miss_total`
- `eviction_total`
- `failure_cache_hit_total`
- `entry_count`
- `schema_version`
- `max_entries`

该诊断面仅用于观测，不能作为 runtime 行为决策输入。

## 9. 验收场景

1. 模型超时输出 `E_TIMEOUT_STAGE_*` 且追踪字段齐全。
2. schema 解析失败输出 `E_SCHEMA_INVALID_PAYLOAD`。
3. 同会话并发冲突输出 `E_CONCURRENCY_CONFLICT`。
4. 全部错误事件可通过 `trace_id` 与 `run_id` 聚合。
5. 终态 metadata 同时包含 `runtime_boundary`、`failure_event`、`output_contract`、`second_pass.timeout_profile`。
6. 指标系统能按阶段输出延迟分位（`p50/p95/p99`）。
7. HTTP 错误响应始终包含 `request_id` 与 `X-Request-ID`。
8. runtime quality 的 performance 载荷包含 `runtime_timeline` 与 `transition_records`。
9. 仲裁触发的运行同时包含 `arbitration_ledger` 与 `arbitration_summary`。
10. compare 模式下的 request mismatch rate 必须以 compare request 总量为分母，而不是字段级 mismatch 计数。
11. 当覆盖率低于最小阈值时，guardrail 必须抑制 SSE fallback 的 `high` 升级。
12. 幂等清理运行必须输出 run/expired/deleted 计数，且计数更新满足单调语义。
