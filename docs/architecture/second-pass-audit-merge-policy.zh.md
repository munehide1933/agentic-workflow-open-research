# Second-Pass Audit 合并策略

## 1. 范围

本文定义 draft 与 second-pass audit 的规范化合并策略。

## 2. 输入

- `draft`：一阶段候选回答
- `diagnosis`：诊断结构（`facts`、`hypotheses`、`excluded_hypotheses`、`insufficient_evidence`、`required_fields`）
- `audit`：二阶段审计对象（v1 或 v2）
- `timeout_profile`：second-pass 解析后的超时 profile 元数据

## 3. 审计契约版本

- v1：[`examples/contracts/second-pass-audit.schema.json`](../../examples/contracts/second-pass-audit.schema.json)
- v2：[`examples/contracts/second-pass-audit.schema.v2.json`](../../examples/contracts/second-pass-audit.schema.v2.json)

### 3.1 v1 历史约束

v1 schema 中 `counter_hypotheses.minItems = 1` 是历史兼容约束。
因此 v1 不能表达“`counter_hypotheses` 为空”的 partial audit。

### 3.2 生产/消费兼容规则（生效日期：March 4, 2026）

1. producer 默认应输出 v2。
2. v1 仅保留读取兼容。
3. 该生效日期是本开源研究发布线的最终日期。
4. 若 partial audit 需要空的 `counter_hypotheses`，必须使用 v2。
5. v1 中空 `counter_hypotheses` 会 schema 失败并判为 `invalid`。

### 3.3 Second-Pass Timeout Profile 契约（v1）

runtime 公开的解析后超时元数据字段：

- `level`
- `score`
- `base_seconds`
- `resolved_seconds`
- `max_seconds`
- `factors[]`

契约 schema：[`examples/contracts/second-pass-timeout-profile.schema.v1.json`](../../examples/contracts/second-pass-timeout-profile.schema.v1.json)

## 4. 完整度推断

当 v1 不含 `audit_completeness` 时，按内容质量推断：

1. `full`：schema 合法且挑战信号充分。
2. `partial`：schema 合法但挑战强度偏弱。
3. `invalid`：schema 校验失败。

## 5. `is_valid_audit()` 判定

`is_valid_audit()` 仅在以下三类检查都通过时返回 true：

1. schema 合法性检查。
2. non-echo（非回声）检查。
3. challenge quality（挑战质量）检查。

### 5.1 non-echo 检查

公开默认阈值：

- 词面重叠率 `< 0.85`
- 语义相似度 `< 0.92`

#### 5.1.1 词面重叠计算方法

- 文本转小写
- 去除标点
- 按空白分词
- 在 token 集上计算 Jaccard 重叠

#### 5.1.2 语义相似度计算方法

默认可复现后端：

- 嵌入模型：`sentence-transformers/all-MiniLM-L6-v2`
- 向量：模型默认句向量
- 相似度：L2 归一后余弦相似度
- draft 对比文本：归一化后的 `draft` 主体答案
- audit 对比文本：`counter_hypotheses`、`missing_evidence`、`unsafe_recommendations`、`structure_inconsistencies` 归一化后拼接

语义输入归一化与词面方法一致（小写化 + 去标点 + 空白折叠）。

若使用其他嵌入模型：

1. 在 benchmark 元数据中声明模型 ID
2. 基于固定校准集重标定语义阈值
3. 随结果公开标定后的阈值

若词面和语义两项阈值均不满足，则判定为 echo，拒绝合并。

### 5.2 挑战质量检查

满足以下任一条件可视为挑战质量达标：

1. `missing_evidence` 给出可执行的缺失观察项。
2. `unsafe_recommendations` 指向具体风险建议。
3. `structure_inconsistencies` 指出诊断与草稿不一致。
4. `counter_hypotheses` 提供非重复替代假设。

## 6. 合并动作

### 6.1 `audit_completeness=full`

- 应用审计挑战后的修订。
- 保持 diagnosis 不变量。
- 在证据支持下允许修正结论。

### 6.2 `audit_completeness=partial`

允许 partial salvage 的字段：

- `missing_evidence`
- `unsafe_recommendations`
- `structure_inconsistencies`

partial salvage 明确禁止：

- 提升主根因确定性
- 无新增证据时提高置信等级

### 6.3 `audit_completeness=invalid`

- 拒绝合并。
- 进入安全降级路径（`invalid_or_partial_audit`）。

### 6.4 确定性合并契约

合并操作必须满足确定性：

`merged = merge(draft, challenge, rules)`

当 `draft`、`challenge`、`rules` 相同，`merged` 必须相同。

### 6.5 用户面展示模式契约

当前 runtime 支持三种用户面展示模式：

- `hidden`（默认）：不向用户答案渲染审计区块
- `summary`：仅展示简短复核说明
- `full`：仅在审计可信时展示显式审计区块

当启用 safe patch 且审计可信时，runtime 只追加最小补丁行，并保持 draft 主体为前缀。

## 7. 安全降级行为

当合并被拒绝时：

1. 保留可用 draft 信息。
2. 补充不确定性声明与验证步骤。
3. 不引入新的高风险可执行指令。

## 8. 参考伪代码

```python
def resolve_second_pass(draft, diagnosis, audit, timeout_profile):
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

## 9. 验收场景

1. full + non-echo + 高质量挑战 => 合并。
2. full + echo => 拒绝。
3. partial + non-echo => 仅 partial salvage。
4. schema 无效 => 安全降级。
5. v1 且 `counter_hypotheses` 为空 => `invalid`。
6. 无 counter_hypothesis 的 partial audit => 必须使用 v2。
7. timeout profile 命中上限（`resolved_seconds == max_seconds`）=> 合并路径遵守封顶预算。
8. 同一 `draft + challenge + rules` 回放 => 产出完全一致的 merged 结果。
