# Deep Thinking 模型治理

## 1. 范围

本文定义 deep-thinking 模型执行的控制平面治理契约。
用于统一 profile 选择、fallback 序列、超时策略绑定与 replay-safe 执行规则。

不在范围内：

- 私有模型供应商商务策略
- 私有 system prompt 与 prompt 模板
- 供应商特定安全实现细节

## 2. 问题定义

当模型选择是隐式逻辑时，deep-thinking 在生产中会失稳。
典型失败模式：

- 模型路由在发布间静默漂移
- fallback 路径绕过策略约束
- primary 与 auditor 的超时策略不一致
- 回放时无法复现当时模型决策

## 3. 契约 / 数据模型

### 3.1 模型 Profile 契约

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `profile_id` | string | 稳定公开模型 profile 标识 |
| `role` | string | `primary | auditor | fallback` |
| `mode_allowlist` | array[string] | 允许模式（`basic`、`deep_thinking`、`web_search`） |
| `determinism_mode` | string | `live | replay` |
| `max_input_tokens` | integer | 该 profile 的输入 token 上限 |
| `max_output_tokens` | integer | 该 profile 的输出 token 上限 |
| `temperature` | number | 策略规定的生成温度 |
| `timeout_profile_id` | string | 超时 profile 契约引用 |
| `cost_tier` | string | `low | medium | high` |
| `safety_class` | string | 策略安全等级标签 |

### 3.2 模型决策记录

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `run_id` | string | 运行执行 ID |
| `step_id` | string | pipeline step ID |
| `selected_profile_id` | string | 本 step 选中的 profile |
| `auditor_profile_id` | string | 若启用审计，选中的 auditor profile |
| `fallback_chain` | array[string] | 有序 fallback profile ID |
| `selection_reason` | array[string] | 可确定性复现的原因标签 |
| `checkpoint_ref` | string | 回放使用的 checkpoint 指针 |

### 3.3 Second-Pass 超时 Profile 绑定

second-pass 治理会在 metadata 中公开解析后的超时 profile。当前 runtime 输出：

- `level`：`low | medium | high | extreme`
- `score`：归一化复杂度分数（`0..1`）
- `base_seconds` / `resolved_seconds` / `max_seconds`
- `factors[]`：紧凑解释字符串（例如 `token:1850`、`domain:DISTRIBUTED+0.20`）

## 4. 决策逻辑

```python
def build_model_plan(request, policy, boundary, profiles):
    candidates = [
        p for p in profiles
        if request.mode in p.mode_allowlist and p.safety_class == boundary.safety_class
    ]

    ordered = sort_profiles(candidates, request.priority, policy.cost_cap_tier)
    primary = ordered[0]
    auditor = select_auditor_profile(ordered, policy.audit_enabled)
    fallback_chain = ordered[1 : 1 + policy.max_fallback_depth]

    return {
        "primary_profile_id": primary.profile_id,
        "auditor_profile_id": auditor.profile_id if auditor else None,
        "fallback_chain": [p.profile_id for p in fallback_chain],
        "timeout_profile_id": primary.timeout_profile_id,
    }


def execute_model_step(step_input, plan, checkpoint_store, replay_mode=False):
    if replay_mode:
        return checkpoint_store.load_model_output(step_input.run_id, step_input.step_id)

    output = call_model(plan["primary_profile_id"], step_input)
    checkpoint_store.save_model_output(step_input.run_id, step_input.step_id, output)
    return output
```

## 5. 失败与降级

1. `retryable_failure`：供应商超时或瞬时 API 错误 -> 在重试预算内重试 primary。
2. `model_uncertainty_failure`：输出置信度低于策略下限 -> 转 auditor profile。
3. `audit_rejection_failure`：auditor 拒绝 draft -> 保留 draft 并输出有界不确定性说明。
4. `policy_failure`：profile 违反策略约束 -> 跳过并进入 fallback 链。
5. `systemic_failure`：fallback 链耗尽 -> 返回有界失败产物。

降级优先级：

1. replay 可重放保证
2. 安全策略完整性
3. 用户可见答案连续性
4. 成本优化

## 6. 验收场景

1. deep-thinking 请求且 primary 正常：
   - 预期：选择 primary；是否调用 auditor 由策略决定。
2. primary 超时且存在 fallback：
   - 预期：分类 `retryable_failure`，执行 fallback。
3. 输出置信度低于阈值：
   - 预期：分类 `model_uncertainty_failure`，触发 auditor 路径。
4. replay 模式执行：
   - 预期：不再调用模型，直接读取 checkpoint 输出。
5. 注册表出现策略不允许 profile：
   - 预期：分类 `policy_failure` 并排除该 profile。
6. fallback 链全部失败：
   - 预期：分类 `systemic_failure`，返回有界降级产物。
7. 负例：输出中泄露私有供应策略：
   - 预期：由 output contract 阻断，仅保留脱敏元数据。
8. 高复杂度 second-pass 请求：
   - 预期：超时 profile 解析为 `high` 或 `extreme`，并附带明确 factors。

## 7. 兼容与版本

- `profile_id` 在同一 major 治理线内保持稳定。
- 新增可选 profile 字段属于 minor 兼容。
- `primary/auditor/fallback` 语义变更属于 major。
- 超时 profile 引用策略变更必须同步更新超时 schema 兼容说明。

## 8. 交叉引用

- [Runtime 能力地图](./runtime-capability-map.zh.md)
- [Agent Pipeline 契约 Profile](./agent-pipeline-contract-profile.zh.md)
- [Second-Pass Audit 合并策略](./second-pass-audit-merge-policy.zh.md)
- [Runtime 可靠性机制](./runtime-reliability-mechanisms.zh.md)
