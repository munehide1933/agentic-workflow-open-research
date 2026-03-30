# AgenticAI 与 Open-Source 能力对齐（2026-03）

## 1. 范围

本文用于将 AgenticAI 当前实现基线，与本仓库公开的 open-research 架构文档做能力对齐。

对齐对象仅包含公开控制平面行为与契约级语义。

不在范围内：

- 私有 prompt 内部细节
- 部署拓扑与私有基础设施细节
- 本地执行算子与非公开运行时内部实现

## 2. 基线与证据来源

对齐基线日期：`2026-03-23`

实现侧证据来源：

- 运行时模块（`backend/core`, `backend/app`, `backend/database`, `backend/services`）
- API 面（`backend/app/main.py`）
- `backend/tests` 下的契约测试

本次对齐使用的行为证据：

1. `test_runtime_boundary_contract_v1.py`
2. `test_unified_step_runner_contract.py`
3. `test_chat_streaming_contract_v1.py`
4. `test_ui_message_stream_parts_mapping.py`
5. `test_pipeline_metadata_ssot_contract.py`
6. `test_second_pass_timeout_profile_contract.py`
7. `test_second_pass_confirmation_contract.py`
8. `test_chat_idempotency_contract.py`
9. `test_deleted_session_access_contract.py`
10. `test_request_context_contract.py`
11. `test_health_contract.py`
12. `test_runtime_timeline_metadata_contract.py`
13. `test_arbitration_ledger_decision_projection.py`
14. `test_sync_executor_backpressure_contract.py`
15. `test_sync_executor_timeout_observability_contract.py`
16. `test_ops_runtime_metrics_contract.py`
17. `test_artifact_diff_contract.py`
18. `test_artifact_api_list_detail_download.py`
19. `test_quality_kernel_adapter_contract.py`
20. `test_quality_kernel_review_batch_adapter_contract.py`
21. `test_quality_kernel_regex_cache_contract.py`
22. `test_quality_kernel_rust_helpers_contract.py`
23. `test_ui_message_stream_rust_frame_builder_contract.py`
24. `test_ttft_v2_flag_gated_contract.py`
25. `test_idempotency_cleanup_contract.py`
26. `test_runtime_guardrails_script_contract.py`
27. `test_runtime_guardrail_release_flow_contract.py`

## 3. 能力对齐矩阵

| 能力线 | AgenticAI 实现证据 | 当前 Open-Source 覆盖度 | 对齐决策 |
| --- | --- | --- | --- |
| 流式输出契约与用户面隔离 | pipeline 流式事件 + UI message stream adapter + streaming 测试 | SSE 契约已存在，但 adapter 级 replay/final-override 细节未完全显式 | 同步 SSE profile，补 replay 头、终态回放规则与 final-override 行为 |
| Runtime boundary 与失败分类转移 | `runtime_contract.py`、`step_runner.py`、runtime boundary 测试 | reliability 与 error taxonomy 已有 runtime boundary metadata | 保持对齐，继续使用确定性转移映射 |
| second-pass 执行与脱敏 | second-pass mode/timeout/trust/no-effect/error-sanitize 测试 | merge policy 已存在，timeout profile schema 已存在 | 保持对齐，显式保留 signals-only 正文规则 |
| API 幂等回放（sync + stream） | chat 路由的 idempotency 预留/回放/409 冲突测试 | 当前仅在 tool 侧提到 idempotency，缺 API 级回放契约 | 在 runtime reliability 中补 `Idempotency-Key` 回放契约 |
| request 关联与公开错误信封 | request context middleware + exception handler 契约 | error/observability 文档缺 `request_id` 强约束 | 增加 `request_id` 作为公开关联必填字段 |
| runtime timeline 与转移诊断 | runtime timeline metadata 测试 + transition projection 测试 | runtime quality 基线存在，但缺 timeline/transition 字段 | 增加 `runtime_quality.performance.runtime_timeline` 与 `transition_records` |
| 仲裁决策可见性 | arbitration ledger projection 测试 + UI `data-arbitration` part | pipeline 文档提到路由，但仲裁 payload 结构未显式 | 在 observability 基线补 `arbitration_ledger` 与 `arbitration_summary` |
| 背压与超时可观测性 | sync executor 背压/超时测试 + ops metrics 载荷 | reliability 文档只做概念描述 | 增加 sync executor snapshot 字段语义，纳入 runtime ops 可见性 |
| Rust quality kernel rollout 与一致性治理 | Rust adapter fallback/compare-mode 测试 + rollout source 标签 + mismatch 指标 | 公开文档未定义 rollout 标签、compare 分母语义与 fallback 原因集合 | 在 observability/reliability 中补 rollout source、fallback taxonomy、request 级 mismatch rate 契约 |
| Rust SSE frame builder rollout | `status`/`text-delta` 的 Rust 编码 parity/fallback 测试 | SSE 文档已有投影规则，但缺引擎级 parity/fallback 约束 | 在 SSE 契约补“字节等价 + 自动回退 + 指标面”规则 |
| TTFT v2 flag-gated 延迟配置 | `TTFT_V2_ENABLED` 与 `first_meaningful_content_ms` 测试 | 现有文档未明确 TTFT v2 下的强制有效配置 | 在 reliability/observability 中补 v2 有效 flag 与延迟指标约束 |
| 幂等清理生命周期 | cleanup scheduler + 清理契约测试（`in_progress` 过期与终态保留清理） | 已有 API 幂等回放契约，但缺周期清理语义 | 在 reliability 中补 stale reclaim、状态转移与 cleanup 指标 |
| Runtime guardrail 发布闸门 | 规则检查测试（`blocker/high/warning/spike`）+ 预发布流程测试 | 现有文档缺发布闸门分级和 rollout spike 采集语义 | 在 observability 基线补分级模型与信号映射 |
| 健康检查与启动契约 | `/api/health` 载荷契约 + lifespan 启动测试 | 公开文档未固定 health 字段集合 | 增加 health 契约说明与验收场景 |
| 确定性 replay 与事务 checkpoint 恢复 | 已有 replay guardrails，但事务化 replay 日志仍未完整落地 | vNext hardening 中已列为缺口 | 继续作为 roadmap 缺口，待实现后再升级契约 |

## 4. 本轮已同步的公开契约增量

1. `SSE response contract`：
   - 传输 profile 头（`x-vercel-ai-ui-message-stream: v1`、`X-Idempotent-Replay`）
   - 相同 `Idempotency-Key` 回放规则：回放权威终态载荷，不重复执行 pipeline
   - 当流式正文与权威终态不一致时，使用 `data-final-override` 投影
2. `Observability/error taxonomy`：
   - `request_id` 作为公开错误与结构化日志的必填关联字段
   - runtime quality 新增：`performance.runtime_timeline`、`performance.transition_records`
   - 仲裁可见性基线：`runtime_quality.arbitration_ledger`、`runtime_quality.arbitration_summary`
3. `Runtime reliability`：
   - sync/stream 的 API 级幂等契约
   - 冲突语义：同 key 不同 hash -> `409`；同 key 且 in-progress -> `409`
   - 会话删除语义：不存在会话 `404`，已删除会话生命周期 `410`
4. `Runtime ops 可见性`：
   - sync executor snapshot 字段（`inflight`、`max_inflight`、timeout/backpressure 计数）
   - `/api/ops/runtime-metrics` 基线字段（`settings_fingerprint`、`settings_reload_count`）
5. `Rust rollout 治理`：
   - quality kernel rollout source 契约（`staging_replay`、`prod_mirror`、`unknown`）
   - compare-mode 请求分母契约（`quality_kernel_compare_requests_total` 及 mismatch 指标）
   - quality kernel / UI stream frame builder 的 fallback 原因集合（`disabled`、`import_error`、`runtime_error` 等）
6. `幂等清理生命周期`：
   - 带单机场景锁的周期清理调度器
   - stale `in_progress` 记录转为 `expired`
   - 终态记录按保留期删除
7. `TTFT v2 runtime profile`：
   - `TTFT_V2_ENABLED=true` 时，stream-first/chunked/early-flush 与 early-preview 有效开关会被强制开启
   - runtime quality performance 显式包含 `first_meaningful_content_ms`
8. `Runtime guardrail 发布闸门`：
   - 分级：`blocker | high | warning | spike`
   - rollout 质量/SSE fallback rate 仅在覆盖率达标时执行强约束

## 5. 边界与发布规则

将实现行为同步到 open-research 文档时，遵循：

1. 仅发布控制平面行为与公开契约
2. 不包含私有 prompt、密钥材料、私有基础设施细节
3. 将实现行为表达为可确定、可测试规则
4. 契约字段扩展时保留兼容性说明

## 6. 验收场景

1. Streaming 白名单与顺序：
   - 输入：混合 source/phase 分片（`answer`、`quote`、`audit_delta`、`final_delta`）
   - 预期：仅白名单用户面内容发射
2. stream 幂等回放：
   - 输入：`/api/chat/stream` 使用相同 `Idempotency-Key` + 相同请求 hash
   - 预期：只回放终态事件，响应头含 `X-Idempotent-Replay: true`
3. sync 幂等回放：
   - 输入：`/api/chat` 使用相同 `Idempotency-Key` + 相同请求 hash
   - 预期：返回缓存结果，`idempotency_replay=true`
4. 幂等冲突：
   - 输入：相同 `Idempotency-Key`，但请求 hash 不同
   - 预期：`409` 冲突，且不会重复执行 pipeline
5. request 关联：
   - 输入：有/无合法 `X-Request-ID` 的请求
   - 预期：响应始终包含 `X-Request-ID`；非法或超长值会被重建
6. 已删除会话访问：
   - 输入：删除后的 session 调用 chat/messages/rollback API
   - 预期：返回 `410`，错误码 `SESSION_GONE`
7. runtime quality timeline：
   - 输入：启用 timeline/transition 记录的运行
   - 预期：终态 metadata 含 `runtime_quality.performance.runtime_timeline` 与 `transition_records`
8. 仲裁投影：
   - 输入：触发模式冲突仲裁的请求
   - 预期：终态 metadata 与 UI stream 均含仲裁决策载荷
9. health 端点契约：
   - 输入：`GET /api/health`
   - 预期：字段稳定（`service_id`、`service_name`、`api_version`、`time`）
10. Rust quality kernel compare 模式：
   - 输入：开启 rollout 且命中 compare 采样
   - 预期：主响应契约不变；mismatch 仅写入可观测性指标
11. Rust SSE frame builder 运行时回退：
   - 输入：Rust frame 编码器抛出 runtime 异常
   - 预期：stream 协议保持有效，fallback 计数递增
12. 幂等清理扫描：
   - 输入：存在 stale `in_progress` 与超过保留期的 `completed`
   - 预期：`in_progress` -> `expired`；过期终态记录删除
13. TTFT v2 flag-gated 运行：
   - 输入：`TTFT_V2_ENABLED=true`
   - 预期：运行时有效开关进入 v2 路径，`first_meaningful_content_ms` 被填充
14. Runtime guardrail 高等级触发：
   - 输入：`quality_fallback_rate[prod_mirror]` 在覆盖率达标时超过阈值
   - 预期：guardrail 报告包含 `high`，并阻断发布流程

## 7. 后续工作项

`P0`：

1. 新增 request-context 与公开错误信封补充规范
2. 新增 runtime-ops metrics 与 guardrail release 流程补充规范
3. 在 `examples/contracts` 增加 idempotency replay 载荷示例 schema
4. 新增 quality kernel 与 SSE frame builder rollout 闸门指标补充规范

`P1`：

1. 发布独立的 UI message stream mapping 补充规范（part type 矩阵）
2. 扩展 artifact lifecycle 规范，补 replay 载荷可见性约束

`Roadmap`：

1. 事务化 checkpointing
2. 确定性 replay 日志契约
3. 压测场景下的多租户调度公平性证明

## 8. 交叉引用

- [SSE Response Contract](./sse-response-contract.md)
- [Error Taxonomy and Observability](./error-taxonomy-observability.md)
- [Runtime Reliability Mechanisms](./runtime-reliability-mechanisms.md)
- [Second-Pass Audit Merge Policy](./second-pass-audit-merge-policy.md)
- [Memory Architecture](./memory-architecture.md)
- [State Machine Transition Matrix](./state-machine-transition-matrix.md)
- [Runtime vNext Iteration Plan and Primary Design Goals](./runtime-vnext-iteration-plan.md)
