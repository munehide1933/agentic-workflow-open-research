# Execution Safety Envelope Runtime

## 1. 范围

本文定义可强制执行的 runtime 安全边界。
用于统一执行白名单、sandbox 隔离、预算约束与确定性 guard 结果。

不在范围内：

- 私有 guard 规则体与秘密反滥用特征
- 公开 runtime boundary 之外的主机级操作
- 内部基础设施加固 runbook

## 2. 问题定义

当执行策略只是建议而非可执行约束时，runtime 安全会失效。
典型失败模式：

- 黑名单方案无法覆盖新攻击面
- 单步失败污染全局进程状态
- token/tool/latency 无上限增长
- 循环与偏航超出策略限制仍持续

## 3. 契约 / 数据模型

### 3.1 Runtime Boundary 契约

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `boundary_id` | string | 不可变边界策略 ID |
| `boundary_version` | string | 版本化 runtime boundary 契约 |
| `sandbox_mode` | string | `process | container | microvm | isolate` |
| `isolation_scope` | string | `per_step | per_run` |
| `allowlisted_tools` | array[string] | 当前 run 可调用工具白名单 |
| `denied_action_classes` | array[string] | 显式拒绝的动作类别 |
| `budget` | object | token/tool/latency/memory/output 限额 |
| `guard_policy_id` | string | 确定性 guard 策略引用 |
| `termination_policy` | object | 循环上限与超时终止策略 |

### 3.2 Budget 对象

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `token_budget` | integer | 单次 run 最大 token 总量 |
| `tool_call_budget` | integer | 单次 run 最大工具调用次数 |
| `latency_budget_ms` | integer | 最大墙钟时长 |
| `memory_quota_mb` | integer | 内存配额上限 |
| `output_size_limit_bytes` | integer | 输出载荷大小上限 |

## 4. 决策逻辑

```python
def enforce_execution_boundary(step_request, boundary, usage):
    if step_request.tool_name and step_request.tool_name not in boundary.allowlisted_tools:
        return fail("guard_violation_failure", "tool_not_allowlisted")

    if usage.tokens_used > boundary.budget.token_budget:
        return fail("systemic_failure", "token_budget_exhausted")

    if usage.tool_calls_used > boundary.budget.tool_call_budget:
        return fail("systemic_failure", "tool_call_budget_exhausted")

    if usage.latency_ms > boundary.budget.latency_budget_ms:
        return fail("retryable_failure", "latency_budget_exhausted")

    if usage.loop_count > boundary.termination_policy.max_loop_iterations:
        return fail("guard_violation_failure", "loop_limit_exceeded")

    return pass_boundary()


def execute_step_with_isolation(step_request, boundary):
    with start_sandbox(boundary.sandbox_mode, boundary.isolation_scope) as sandbox:
        return sandbox.run(step_request)
```

## 5. 失败与降级

1. guard 违规 -> 转移到 `safe_recovery`，不输出可执行内容。
2. 预算耗尽 -> 终止当前分支并返回有界诊断产物。
3. sandbox 启动失败 -> 降级为不可执行指引输出。
4. 输出超尺寸 -> 在策略边界处截断并标记 `degraded=true`。
5. 连续超时 -> 对当前 run 打开熔断并拒绝后续执行。

## 6. 验收场景

1. 白名单工具且预算充足：
   - 预期：在 sandbox 内执行并继续流程。
2. 调用未授权工具：
   - 预期：`guard_violation_failure`，不执行。
3. finalize 前 token 预算耗尽：
   - 预期：`systemic_failure`，仅输出有界结果。
4. step 循环超过上限：
   - 预期：被 guard 终止并进入恢复转移。
5. 工具执行期间 sandbox 崩溃：
   - 预期：故障被隔离，全局 runtime 状态不污染。
6. 输出载荷超过上限：
   - 预期：确定性截断并标记降级。
7. 负例：仅配置黑名单策略：
   - 预期：边界校验拒绝（必须有白名单）。

## 7. 兼容与版本

- 新增拒绝动作类别与可选预算字段属于 minor 兼容。
- 默认 guard 语义变更属于 major 变更。
- 预算单位变化（如 ms 改为 s）需要新 major schema 版本。
- boundary 版本更新必须同步到 runtime metadata 契约。

## 8. 交叉引用

- [Runtime 能力地图](./runtime-capability-map.zh.md)
- [Action/Tools 系统契约](./action-tools-system-contract.zh.md)
- [错误分类与可观测性规范](./error-taxonomy-observability.zh.md)
- [Runtime 可靠性机制](./runtime-reliability-mechanisms.zh.md)
