# Second-Pass Audit 合并策略

## 1. 范围

本文定义 draft 与 second-pass audit 的规范化合并策略。

## 2. 输入

- `draft`：一阶段候选回答
- `diagnosis`：诊断结构（`facts`、`hypotheses`、`excluded_hypotheses`、`insufficient_evidence`、`required_fields`）
- `audit`：二阶段审计对象（v1 或 v2）

## 3. 审计契约版本

- v1：[`examples/contracts/second-pass-audit.schema.json`](../../examples/contracts/second-pass-audit.schema.json)
- v2：[`examples/contracts/second-pass-audit.schema.v2.json`](../../examples/contracts/second-pass-audit.schema.v2.json)

兼容规则：

1. v1 不含 `audit_completeness` 时按规则推断。
2. 必填键可解析且挑战字段有效，推断为 `full`。
3. 可解析但挑战强度不足，推断为 `partial`。
4. schema 校验失败，推断为 `invalid`。

## 4. `is_valid_audit()` 判定

`is_valid_audit()` 仅在以下三类检查都通过时返回 true：

1. schema 合法性检查。
2. non-echo（非回声）检查。
3. challenge quality（挑战质量）检查。

### 4.1 non-echo 检查

公开默认阈值（可在私有部署替换）：

- 词面重叠率 `< 0.85`
- 语义相似度 `< 0.92`

若两项阈值均未通过，则判定为 echo，拒绝合并。

### 4.2 挑战质量检查

满足以下任一条件可视为挑战质量达标：

1. `missing_evidence` 给出可执行的缺失观察项。
2. `unsafe_recommendations` 指向具体风险建议。
3. `structure_inconsistencies` 指出诊断与草稿不一致。
4. `counter_hypotheses` 提供非重复替代假设。

## 5. 合并动作

### 5.1 `audit_completeness=full`

- 应用审计挑战后的修订。
- 保持 diagnosis 不变量。
- 在证据支持下允许修正结论。

### 5.2 `audit_completeness=partial`

允许 partial salvage 的字段：

- `missing_evidence`
- `unsafe_recommendations`
- `structure_inconsistencies`

partial salvage 明确禁止：

- 提升主根因确定性
- 无新增证据时提高置信等级

### 5.3 `audit_completeness=invalid`

- 拒绝合并。
- 进入安全降级路径（`invalid_or_partial_audit`）。

## 6. 安全降级行为

当合并被拒绝时：

1. 保留可用 draft 信息。
2. 补充不确定性声明与验证步骤。
3. 不引入新的高风险可执行指令。

## 7. 参考伪代码

```python
def resolve_second_pass(draft, diagnosis, audit):
    completeness = get_audit_completeness(audit)

    if not schema_valid(audit):
        return safe_degrade(draft, "invalid_audit_schema")
    if is_echo(audit, draft):
        return safe_degrade(draft, "echo_audit")
    if not has_minimum_challenge_quality(audit):
        return safe_degrade(draft, "weak_audit")

    if completeness == "full":
        return merge_draft_with_audit(draft, audit, diagnosis)
    if completeness == "partial":
        return merge_partial_salvage(draft, audit, diagnosis)
    return safe_degrade(draft, "invalid_or_partial_audit")
```

## 8. 验收场景

1. full + non-echo + 高质量挑战 => 合并。
2. full + echo => 拒绝。
3. partial + non-echo => 仅 partial salvage。
4. schema 无效 => 安全降级。
