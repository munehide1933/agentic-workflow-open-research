# Quality Gate 规则框架

## 1. 范围

Quality Gate 在 Anchor Guard 之后评估可执行产物。
Anchor Guard 与 Quality Gate 冲突时，取更严格结果。

## 2. 处理顺序

1. Anchor Guard 先判断可执行资格。
2. 若仍可执行，再由 Quality Gate 评估产物质量。
3. 输出等级为 `pass`、`soft_fail`、`hard_fail`。

## 3. 检查维度

- `syntax_check`：语法解析/校验器是否通过
- `risky_pattern_scan`：静态危险模式扫描
- `semantic_safety_check`：策略与意图一致性

## 4. `risky_pattern_scan` 分类框架（公开）

公开分类框架（具体规则体可保持私有）：

- `RISK_FS_MUTATION`：破坏性文件系统操作
- `RISK_NETWORK_EGRESS`：向外部端点发起网络出站请求
- `RISK_PRIVILEGE_ESCALATION`：提权或安全边界绕过
- `RISK_PROCESS_EXEC`：进程拉起或 shell 执行
- `RISK_CREDENTIAL_HANDLING`：密钥/令牌暴露或不安全处理
- `RISK_DATA_EXFIL`：大范围数据导出或非预期泄露模式

最小 finding 结构：

- `pattern_id`
- `category`
- `severity`：`low | medium | high | critical`
- `evidence_span`

## 5. `semantic_safety_check` 操作化方法

`semantic_safety_check` 由“确定性规则 + 可选模型复核”组成：

1. 规则匹配器（强制）
: 检查禁止操作、前置条件缺失、权限/作用域违规。
2. 意图一致性检查（强制）
: 检查生成动作是否超出用户声明意图。
3. 复核模型（可选）
: 次级模型评估潜在不安全含义；不可用时允许仅规则路径。

必需输出字段：

- `semantic_findings[]`：`{rule_id, severity, rationale}`
- `intent_drift`：布尔值

## 6. 风险等级

- `R0`：未检测到风险
- `R1`：低风险提醒
- `R2`：中风险，需降级交付
- `R3`：高风险，阻断可执行输出

## 7. 决策规则

公开默认映射：

1. `syntax_check=fail` => `hard_fail`
2. 任一 risky-pattern finding 为 `critical` => `R3`
3. 任一 `semantic_findings.severity=critical` => `R3`
4. `intent_drift=true` 且无 critical finding => 至少 `R2`
5. 最大风险等级为 `R0-R1` => `pass`
6. 最大风险等级为 `R2` => `soft_fail`
7. 最大风险等级为 `R3` => `hard_fail`

## 8. 输出契约

`quality_gate_result` 对象：

- `decision`：`pass | soft_fail | hard_fail`
- `risk_classes`：命中风险等级列表
- `blocked_rules`：触发规则 ID 列表
- `risky_pattern_findings`：危险模式命中列表
- `semantic_findings`：语义安全命中列表
- `remediation`：安全替代方案或验证步骤

## 9. 与 Anchor Guard 的关系

1. Anchor Guard 阻断后，Quality Gate 不能重新放行可执行输出。
2. Anchor Guard 放行后，Quality Gate 仍可降级或阻断。
3. 最终结果必须取两者中更严格者。

## 10. 验收场景

1. 语法通过 + 无危险模式 + 无语义命中 => `pass`。
2. 语法通过 + 中风险危险模式 => `soft_fail`。
3. 意图漂移且非 critical => 至少 `soft_fail`。
4. critical 危险模式或语义违规 => `hard_fail`。
5. Anchor Guard 阻断 + Quality Gate 通过 => 最终仍阻断可执行交付。
