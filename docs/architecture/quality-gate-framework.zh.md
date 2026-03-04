# Quality Gate 规则框架

## 1. 范围

Quality Gate 在 Anchor Guard 之后评估可执行产物。
当两者结论冲突时，必须采用更严格结果。

## 2. 处理顺序

1. Anchor Guard 先判断是否允许可执行输出。
2. 若仍允许可执行输出，再进入 Quality Gate。
3. 产出分级为 `pass`、`soft_fail`、`hard_fail`。

## 3. 检查维度

- `syntax_check`：语法/解析器校验
- `risky_pattern_scan`：危险模式扫描
- `semantic_safety_check`：语义安全与策略一致性

## 4. 风险等级

- `R0`：未检测到风险
- `R1`：低风险提示
- `R2`：中风险，需要降级交付
- `R3`：高风险，禁止可执行输出

## 5. 判定规则

公开默认映射：

1. `syntax_check=fail` => `hard_fail`
2. 最大风险为 `R0-R1` => `pass`
3. 最大风险为 `R2` => `soft_fail`
4. 最大风险为 `R3` => `hard_fail`

## 6. 输出契约

`quality_gate_result` 对象字段：

- `decision`：`pass | soft_fail | hard_fail`
- `risk_classes`：命中的风险等级列表
- `blocked_rules`：触发规则 ID 列表
- `remediation`：安全替代与验证步骤

## 7. 与 Anchor Guard 的关系

1. Anchor Guard 一旦阻断，可执行输出不可被 Quality Gate 重新放行。
2. Anchor Guard 放行后，Quality Gate 仍可降级或阻断。
3. 最终决策取两者中更严格者。

## 8. 验收场景

1. 语法通过且无危险模式 => `pass`。
2. 语法通过且中风险模式 => `soft_fail`。
3. 语法失败 => `hard_fail`。
4. Anchor Guard 阻断 + Quality Gate 通过 => 最终仍按阻断处理。
