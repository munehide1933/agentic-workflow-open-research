# Action/Tools 系统契约

## 1. 范围

本文定义公开的 action/tools runtime 契约。
用于统一工具调用信封、执行门禁、隔离挂钩与失败映射。

不在范围内：

- 私有工具实现代码
- 供应商凭据与密钥分发细节
- 非公开基础设施插件接线

## 2. 问题定义

工具执行是 runtime 里风险最高的表面。
典型失败模式：

- 无界重试导致队列放大
- 无幂等键的副作用调用
- 隐式路由触发未授权工具执行
- 工具输出泄漏到用户正文流

## 3. 契约 / 数据模型

### 3.1 工具调用契约

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `tool_name` | string | 白名单公开工具标识 |
| `call_id` | string | 调用追踪唯一 ID |
| `idempotency_key` | string | 回放与去重的确定性键 |
| `input_schema_version` | string | 版本化输入契约键 |
| `timeout_ms` | integer | 调用超时预算 |
| `max_retries` | integer | 最大重试次数 |
| `sandbox_profile` | string | 执行隔离 profile 引用 |
| `output_channel` | string | `internal | artifact` |

### 3.2 工具结果契约

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `call_id` | string | 与请求 call ID 对齐 |
| `status` | string | `ok | timeout | rejected | failed` |
| `error_class` | string | 非 `ok` 时失败分类 |
| `artifact_ref` | string | 工具输出产物 ID |
| `latency_ms` | integer | 工具耗时 |
| `replay_source` | string | `live | checkpoint` |

## 4. 决策逻辑

```python
def execute_tool_call(request, boundary, quotas, checkpoint_store):
    if request.tool_name not in boundary.allowlisted_tools:
        return reject_tool_call(request, "guard_violation_failure")

    if quotas.tool_calls_used >= boundary.budget.tool_call_budget:
        return reject_tool_call(request, "systemic_failure")

    cached = checkpoint_store.lookup_tool_result(request.idempotency_key)
    if cached is not None:
        return cached.with_replay_source("checkpoint")

    result = run_in_sandbox(request)
    checkpoint_store.save_tool_result(request.idempotency_key, result)
    return result.with_replay_source("live")
```

## 5. 失败与降级

1. 白名单违规 -> `guard_violation_failure`，立即拒绝。
2. 超时且仍有重试预算 -> `retryable_failure`，重试同工具。
3. 超时且重试预算耗尽 -> 降级为 `tool_skipped` 产物。
4. 缺少幂等键的副作用调用 -> `policy_failure`，阻断执行。
5. 未知工具异常 -> `tool_failure`，返回脱敏错误产物。

降级优先级：

1. replay-safe 缓存结果
2. 确定性 fallback 工具
3. 无工具数据的有界部分输出

## 6. 验收场景

1. 白名单工具且输入 schema 合法：
   - 预期：执行一次并持久化结果产物。
2. 回放运行且幂等键相同：
   - 预期：从 checkpoint 返回，不进行 live 调用。
3. 工具超时但有剩余重试：
   - 预期：分类 `retryable_failure`，并在预算内重试。
4. 工具超时且重试预算耗尽：
   - 预期：进入 `tool_skipped` 降级路径。
5. 模型请求调用未授权工具：
   - 预期：阻断并分类 `guard_violation_failure`。
6. 工具输出标记为 `internal`：
   - 预期：不得进入用户正文流。
7. 负例：缺少 `idempotency_key`：
   - 预期：阻断并分类 `policy_failure`。

## 7. 兼容与版本

- 工具名在每个 major 版本线内保持稳定。
- 结果新增可选字段属于 minor 兼容。
- 幂等语义调整属于 major 契约变更。
- 输入 schema 升级必须在工具文档给出迁移说明。

## 8. 交叉引用

- [Runtime 能力地图](./runtime-capability-map.zh.md)
- [Execution Safety Envelope Runtime](./execution-safety-envelope-runtime.zh.md)
- [Agent Pipeline 契约 Profile](./agent-pipeline-contract-profile.zh.md)
- [Runtime 可靠性机制](./runtime-reliability-mechanisms.zh.md)
