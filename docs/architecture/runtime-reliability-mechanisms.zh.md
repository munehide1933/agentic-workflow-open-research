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
