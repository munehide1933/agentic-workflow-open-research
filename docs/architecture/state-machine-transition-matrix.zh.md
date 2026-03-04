# 状态机完整转移矩阵

## 1. 状态集合

- `S0_INPUT_NORMALIZED`
- `S1_UNDERSTANDING_READY`
- `S2_DIAGNOSIS_READY`
- `S3_DRAFT_READY`
- `S4_AUDIT_READY`
- `S5_FINAL_READY`
- `S6_RENDERED`
- `S_FAIL_RETRYABLE`
- `S_FAIL_TERMINAL`

## 2. 并发规则

同一会话必须单飞（single-flight）。
同会话存在活跃 run 时，直接返回 `E_CONCURRENCY_CONFLICT`。

## 3. 转移矩阵

| From | To | Guard | Notes |
|---|---|---|---|
| `S0_INPUT_NORMALIZED` | `S1_UNDERSTANDING_READY` | 输入解析并归一化成功 | 控制流起点 |
| `S1_UNDERSTANDING_READY` | `S2_DIAGNOSIS_READY` | 需要诊断且满足最小可观测性 | 不需要诊断时走直答 |
| `S1_UNDERSTANDING_READY` | `S3_DRAFT_READY` | 选择直答路径 | 跳过诊断分支 |
| `S2_DIAGNOSIS_READY` | `S3_DRAFT_READY` | diagnosis schema 合法 | 允许草稿合成 |
| `S3_DRAFT_READY` | `S4_AUDIT_READY` | 需要 second pass | 高风险或命中审计域 |
| `S3_DRAFT_READY` | `S5_FINAL_READY` | 不需要 second pass | 直接 finalize |
| `S4_AUDIT_READY` | `S5_FINAL_READY` | 审计有效（或允许 partial salvage） | 应用合并策略 |
| `S5_FINAL_READY` | `S6_RENDERED` | 输出满足契约 | 渲染完成 |
| `S6_RENDERED` | `S0_INPUT_NORMALIZED` | 同会话新输入重入 | 会话连续 |
| `ANY_NON_TERMINAL` | `S_FAIL_RETRYABLE` | 超时或上游瞬时故障 | 安全降级，可重试 |
| `ANY_NON_TERMINAL` | `S_FAIL_TERMINAL` | schema 违规、策略硬阻断、不可恢复错误 | 终止当前 run |

## 4. 禁止转移（示例）

1. 未经过理解阶段直接 `S0 -> S3`。
2. 跳过草稿阶段直接 `S2 -> S5`。
3. 渲染后直接 `S6 -> S4`。
4. 同一 run 内从 `S_FAIL_TERMINAL` 再次转出。

## 5. Fail 分类

- `S_FAIL_RETRYABLE`：策略允许重试，输出需明确不确定性边界。
- `S_FAIL_TERMINAL`：当前 run 不可恢复，需新 run 重新开始。

## 6. 验收场景

1. 每条合法边至少 1 个正例。
2. 每条禁止边至少 1 个反例。
3. 同会话并发 run 返回 `E_CONCURRENCY_CONFLICT`。
4. `S6 -> S0` 会话重入可正常工作。
