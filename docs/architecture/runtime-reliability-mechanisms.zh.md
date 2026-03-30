# Runtime 可靠性机制

## 1. 范围

本文定义 runtime 控制平面的生产级可靠性机制。
覆盖确定性编排、checkpoint、可重放一致性、工作负载治理与面向 SLA 的失败处理。

不在范围内：

- 私有告警路由与值班升级细节
- 私有基础设施自动扩缩容内部实现
- 供应商部署拓扑细节

## 2. 问题定义

“只跑通一次”的 runtime 不是生产级。
典型失败模式：

- 崩溃恢复时重复调用模型导致结果漂移
- 重试路径破坏确定性契约
- 队列压力引发级联超时
- 多租户流量导致资源饥饿与不公平

## 3. 契约 / 数据模型

### 3.1 确定性编排记录

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `state_version` | string | 状态 schema 版本 |
| `state_hash` | string | 序列化状态哈希 |
| `step_id` | string | 确定性 pipeline step 标识 |
| `transition_event` | string | 状态机转移事件 |
| `checkpoint_id` | string | 不可变 checkpoint 产物 ID |
| `replay_safe` | boolean | 可重放一致性保证标记 |

### 3.2 Runtime 最终 Metadata 字段集

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `runtime_boundary` | object | 本次 run 的边界契约快照 |
| `failure_event` | object | 规范化失败分类载荷 |
| `output_contract` | object | 最终输出一致性元数据 |
| `second_pass.timeout_profile` | object | second-pass 的解析后超时配置 |
| `runtime_quality.stage_snapshots` | array | 分阶段模型/token/耗时快照 |
| `runtime_quality.invariant_gate` | object | merge 守卫结果（`passed`、`reason_codes`、`metrics`、`fallback`） |
| `runtime_quality.degradation_flags` | array | run 级降级标记 |
| `runtime_quality.performance.general_latency_flags_effective.ttft_v2_enabled` | boolean | TTFT v2 有效配置标记 |
| `runtime_quality.performance.first_meaningful_content_ms` | integer | 首个非 preview 有意义正文延迟 |

### 3.3 Failure Event 契约

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `failure_type` | string | retryable/model/audit/guard/tool/policy/systemic |
| `stage_id` | string | 失败发生阶段 |
| `transition_to` | string | 确定性下一状态 |
| `retryable` | boolean | 是否允许重试 |
| `degradation_path` | string | 已选择降级路径键 |

### 3.4 Artifact 与 Evidence 链契约

artifact/evidence 版本链通过以下不可变字段追踪：

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `logical_key` | string | 跨版本逻辑标识 |
| `version_no` | integer | 单调递增版本号 |
| `parent_artifact_id` | string or null | 父版本指针 |
| `sha1` | string | 不可变内容摘要 |
| `trace_id` | string | 审计回放追踪绑定 |
| `message_id` | string | 当产物用户可见时必填 |

### 3.5 Request-Scoped Partial Replay 契约

当前 runtime 的 replay 采用 request 作用域，并只覆盖指定步骤：

- 默认目标步骤：`synthesis_draft`、`synthesis_merge`
- 每个目标步骤都有重放次数上限
- replay journal 仅用于可观测性，不允许驱动行为分支

封闭 replay reason-code 枚举：

- `timeout`
- `token_overflow`
- `context_length`
- `transient_failure`
- `not_in_target_scope`
- `max_attempts_exceeded`
- `unsupported_executor`

snapshot 应用规则：

- authoritative 键可以覆盖状态
- advisory 键仅限 warning/error/degrade 诊断字段
- 非 owned 键（如 `query`）禁止被 replay snapshot 覆盖

### 3.6 API 幂等与会话生命周期契约

API 边界的公开可靠性契约：

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `Idempotency-Key` | string | `/api/chat` 与 `/api/chat/stream` 的客户端去重键 |
| `request_hash` | string | 端点 + 规范化请求载荷的确定性哈希 |
| `idempotency_replay` | boolean | sync 回放时的响应体标记 |
| `X-Idempotent-Replay` | string | stream 回放响应头（回放时为 `true`） |
| `idempotency_status` | enum | `in_progress | completed | failed | expired` |
| `response_payload` | object | 用于回放的缓存权威终态载荷 |

确定性冲突规则：

1. 同 key + 同 hash + completed -> 回放缓存载荷
2. 同 key + 同 hash + in-progress -> `409`
3. 同 key + 不同 hash -> `409`

会话生命周期可见性规则：

1. session 不存在 -> `404`（`SESSION_NOT_FOUND`）
2. session 已删除/失效 -> `410`（`SESSION_GONE`）

### 3.7 幂等清理调度器契约

幂等清理由应用生命周期中的周期调度器执行，负责 stale 记录卫生治理。

契约行为：

1. 仅当 `IDEMPOTENCY_CLEANUP_ENABLED=true` 时启用调度器。
2. 每次清理周期采用单机锁语义。
3. stale `in_progress` 记录按端点 TTL 转为 `expired`：
   - sync 端点使用 `IDEMPOTENCY_SYNC_IN_PROGRESS_TTL_SECONDS`
   - stream 端点使用 `IDEMPOTENCY_STREAM_IN_PROGRESS_TTL_SECONDS`
4. 超过 `IDEMPOTENCY_RETENTION_DAYS` 的终态记录会被删除。
5. 清理计数器满足单调递增：
   - `idempotency_cleanup_run_total`
   - `idempotency_cleanup_expired_total`
   - `idempotency_cleanup_deleted_total`
   - `idempotency_cleanup_lock_skip_total`
   - `idempotency_cleanup_error_total`

### 3.8 Runtime Guardrail 发布闸门契约

发布闸门消费 runtime 快照与可选 baseline 快照，并输出分级结果：

- `blocker`：立即阻断
- `high`：阻断发布的回归
- `warning`：不阻断但需跟踪
- `spike_alerts`：相对基线的突发漂移告警

关键约束点：

1. quality fallback rate 与 compare mismatch rate 按 rollout source 判定（默认包含 `prod_mirror`）。
2. SSE fallback 的 `high` 仅在覆盖率超过最小阈值时生效。
3. idempotency payload 损坏与 raw error 泄漏属于 `blocker`。
4. sync executor 的 full-timeout 三元组（`utilization`、`timeout_count`、`still_running_ratio`）属于 `blocker`。
5. 为保证可审计性，闸门输出必须包含计算后的 `signals` 载荷。

## 4. 决策逻辑

```python
def worker_loop(queue, scheduler, checkpoint_store):
    while True:
        if scheduler.backpressure_active():
            queue.defer_low_priority()

        task = queue.pop_next()
        if not task:
            continue

        quota = scheduler.reserve(task.tenant_id, task.workflow_id)
        if not quota.granted:
            queue.requeue(task, reason="quota_exceeded")
            continue

        state = checkpoint_store.load_or_init(task.run_id)
        result = run_state_machine_step(task, state)
        checkpoint_store.commit(task.run_id, result.checkpoint)

        if result.failure_event:
            apply_failure_transition(task.run_id, result.failure_event)


def replay_run(run_id, checkpoint_store):
    checkpoints = checkpoint_store.load_all(run_id)
    return deterministic_replay(checkpoints)
```

## 5. 失败与降级

1. `retryable_failure` -> 在同一 trace 内按指数退避进行有界重试。
2. `model_uncertainty_failure` -> fallback 模型或有界模板输出。
3. `audit_rejection_failure` -> 保留 draft 并标注不确定性。
4. `guard_violation_failure` -> 进入安全恢复分支并阻断可执行输出。
5. `tool_failure` -> 使用确定性降级路径（`mock` 或 `skip`）。
6. `policy_failure` -> 直接阻断并返回公开策略错误。
7. `systemic_failure` -> 负载卸载并返回 SLA 安全降级输出。

runtime 负载治理控制：

- 基于租户配额的队列优先级
- 租户与 workflow 两级并发上限
- 基于延迟和队列深度触发背压
- 按 token、内存、执行槽进行资源调度
- sync executor snapshot 暴露背压/超时计数，用于 runtime guardrail 发布检查
- 发布前必须消费 guardrail 分级输出（`blocker/high/warning/spike_alerts`）再决定是否放行

## 6. 验收场景

1. checkpoint 提交后 worker 崩溃：
   - 预期：从最后一次提交恢复，不重复模型调用。
2. 恢复后对同一输入回放：
   - 预期：最终输出与 state hash 链一致。
3. 队列深度超过背压阈值：
   - 预期：延后低优先级任务，保障高优先级 SLA。
4. 租户 token 配额超限：
   - 预期：按配额策略重排队或拒绝。
5. second-pass timeout profile 命中上限：
   - 预期：metadata 中 `resolved_seconds == max_seconds`。
6. required 阶段发生 tool_failure：
   - 预期：确定性失败转移并执行配置降级路径。
7. second-pass 发生 audit 拒绝：
   - 预期：保留 draft，challenge 不泄露到正文流。
8. 负例：回放缺失 checkpoint：
   - 预期：拒绝回放并返回显式完整性错误。
9. replay 输入仅存在可观测噪声差异：
   - 预期：fingerprint 保持稳定。
10. replay 标记为 unsupported：
   - 预期：replay metadata 返回全零计数与空 journal。
11. replay snapshot 含非 owned 键：
   - 预期：应用阶段忽略这些键。
12. sync 幂等回放（同 key/同 hash）：
   - 预期：返回缓存载荷，且 `idempotency_replay=true`。
13. stream 幂等回放（同 key/同 hash）：
   - 预期：返回终态回放，并携带 `X-Idempotent-Replay: true`。
14. 幂等键与请求 hash 冲突：
   - 预期：返回 `409`，且不重复执行 pipeline。
15. 删除态会话访问 API：
   - 预期：返回 `410`，错误码 `SESSION_GONE`。
16. 周期幂等清理：
   - 预期：stale `in_progress` 转 `expired`，超保留期终态记录被删除。
17. TTFT v2 flag-gated 配置：
   - 预期：stream 延迟相关有效开关被强制开启，`first_meaningful_content_ms` 被记录。
18. Runtime guardrail 覆盖率感知 SSE 闸门：
   - 预期：覆盖率不足时抑制 SSE fallback 的 `high`，改为 `warning`。

## 7. 兼容与版本

- checkpoint 记录新增可选字段属于 minor 兼容。
- 状态序列化格式变化必须升级版本。
- 失败类型重命名属于 major 兼容破坏。
- metadata 新增字段向后兼容；删除字段需要 major 升级。

## 8. 交叉引用

- [Runtime 能力地图](./runtime-capability-map.zh.md)
- [Execution Safety Envelope Runtime](./execution-safety-envelope-runtime.zh.md)
- [错误分类与可观测性规范](./error-taxonomy-observability.zh.md)
- [Second-Pass Audit 合并策略](./second-pass-audit-merge-policy.zh.md)
- [Runtime Boundary Schema v1](../../examples/contracts/runtime-boundary.schema.v1.json)
- [Artifact Lifecycle Schema v1](../../examples/contracts/artifact-lifecycle.schema.v1.json)
- [Second-Pass Timeout Profile Schema v1](../../examples/contracts/second-pass-timeout-profile.schema.v1.json)
