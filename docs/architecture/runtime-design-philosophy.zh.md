# Runtime 设计哲学

## 1. 范围

本文定义 runtime 行为治理与架构决策发布所使用的公开设计哲学。
该规范对架构文档、契约 schema 与策略更新具有约束性。
IAR 默认采用 `Two-Stage Contract-Driven Delivery`（双阶段契约驱动交付模式）作为交付纪律。

不在范围内：

- 私有模型 prompt 细节
- 私有部署调参常量
- 实现侧密钥处理细节

## 2. 问题定义

当系统优先追求“生成速度”而非“控制平面纪律”时，Agent 在生产环境会失稳。
典型失败模式：

- 功能增长脱离契约边界
- 子系统策略冲突但未显式暴露
- 架构主张无法测试验证
- 降级路径隐式化，导致 fail-open

## 3. 契约 / 数据模型

设计哲学通过可执行原则集合表达。

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `principle_id` | string | 稳定原则标识（如 `P_DETERMINISM_FIRST`） |
| `statement` | string | 规范性原则文本 |
| `enforcement_layer` | string | `design | orchestration | runtime | output` |
| `observable_signal` | string | 可度量的运行时或文档信号 |
| `violation_effect` | string | 违规时必须执行的动作 |
| `test_reference` | string | 对应契约测试或验收场景 ID |

基线原则集：

1. `P_CONTRACT_BEFORE_CODE`
2. `P_DETERMINISM_FIRST`
3. `P_EVIDENCE_BEFORE_ASSERTION`
4. `P_SAFETY_BEFORE_EXECUTION`
5. `P_DEGRADE_BEFORE_FAIL_OPEN`
6. `P_SINGLE_WRITER_FINAL_OUTPUT`

## 4. 决策逻辑

所有新增 runtime 行为在发布前都必须通过原则门禁。

```python
def evaluate_design_change(change, principles):
    violations = []
    for principle in principles:
        if not satisfies(change, principle):
            violations.append(principle.principle_id)

    if not violations:
        return {"decision": "accept", "violations": []}

    if "P_SAFETY_BEFORE_EXECUTION" in violations:
        return {
            "decision": "reject",
            "action": "block_release",
            "violations": violations,
        }

    return {
        "decision": "revise",
        "action": "add_mitigation_and_tests",
        "violations": violations,
    }
```

## 5. 失败与降级

当原则在运行时发生冲突：

1. 执行更严格的安全约束动作
2. 保持确定性输出契约
3. 发射结构化违规元数据
4. 输出有界降级指引，禁止 fail-open 执行

冲突优先级：

1. 安全
2. 确定性
3. 证据完整性
4. 输出质量
5. 成本优化

## 6. 验收场景

1. 新功能无 schema 契约：
   - 预期：被 `P_CONTRACT_BEFORE_CODE` 拒绝。
2. 优化导致同输入异输出：
   - 预期：被 `P_DETERMINISM_FIRST` 阻断。
3. 回答在无证据下断言根因：
   - 预期：被 `P_EVIDENCE_BEFORE_ASSERTION` 降级。
4. 缺锚点时请求可执行代码：
   - 预期：被 `P_SAFETY_BEFORE_EXECUTION` 阻断可执行输出。
5. second-pass 失败且无可信补丁：
   - 预期：按 `P_DEGRADE_BEFORE_FAIL_OPEN` 输出有界 summary。
6. 多模块竞争覆盖最终答案：
   - 预期：按 `P_SINGLE_WRITER_FINAL_OUTPUT` 保留 first-writer 结果。

## 7. 兼容与版本

- Principle ID 在 minor 版本中保持稳定。
- minor 版本可新增可选原则。
- 删除或重定义已有原则属于 major 变更。
- 原则变更必须同步更新验收场景与交叉引用。

## 8. 交叉引用

- [Runtime 能力地图](./runtime-capability-map.zh.md)
- [Agent Pipeline 契约 Profile](./agent-pipeline-contract-profile.zh.md)
- [Execution Safety Envelope Runtime](./execution-safety-envelope-runtime.zh.md)
- [Runtime 可靠性机制](./runtime-reliability-mechanisms.zh.md)
