# Memory 层架构规范

## 1. 范围

本规范定义公开记忆行为：

- SQLite 短期记忆
- 可选 Qdrant 长期记忆

## 2. 短期记忆（SQLite）

核心职责：

1. 会话连续性
2. run 级状态快照
3. 回滚支撑

公开默认保留策略：

- `session_ttl_days = 30`
- `run_ttl_days = 14`

驱逐规则：

1. 每日清理先删除过期 run。
2. 当会话无活跃 run 且超过 TTL 时删除会话。
3. 驱逐动作应记录 `trace_id/run_id/session_id`（可用时）。

## 3. 长期记忆（Qdrant，可选）

写入时机策略：

1. 仅在 finalize 阶段写入。
2. 输出为 `hard_fail` 时不写入。
3. 策略标记为敏感内容时不写入。

## 4. 检索触发与管线接入点

检索在 `S1_UNDERSTANDING_READY` 之后、`S2_DIAGNOSIS_READY` 之前执行。

管线契约：

1. 仅当检索开关开启且请求非“记忆隔离”意图时执行 `retrieve_cross_session_memory()`。
2. 命中结果按 `min_score` 过滤后写入 `state.memory_context[]`。
3. `build_diagnosis_structure()` 接收 `memory_context` 作为外部上下文输入。

`memory_context` 的公开最小字段：

- `memory_id`
- `score`
- `snippet`
- `source_session_id`

## 5. 跨会话检索语义

默认检索参数：

- `top_k = 8`
- 相关性阈值 `min_score = 0.72`

行为规则：

1. 低于阈值的候选直接丢弃。
2. 检索记忆是上下文，不是独立事实。
3. diagnosis 可用检索记忆生成假设或验证步骤。
4. 仅由记忆支撑的结论不得直接进入 `facts`，除非有本轮证据佐证。
5. 低置信检索应提升 `required_fields`。

## 6. 与 Verification-First 的绑定

当 `diagnosis.insufficient_evidence=true` 时，草稿必须遵循 verification-first 约束：

1. 必须包含显式不确定性声明。
2. 必须限制结论边界，不得提升根因确定性。
3. 必须包含按可观测信号排序的验证清单。
4. 必须包含 `required_fields` 缺失观察项。
5. 必须阻断不可逆可执行动作。

## 7. 回滚语义

回滚粒度：run 级。

回滚触发条件：

- 终止型 schema 违规
- 终止型策略违规
- finalize 阶段不可恢复失败

回滚行为：

1. 恢复到最近一次已提交 run 快照。
2. 保留不可变回滚追踪记录。
3. 不重写历史已完成 run 负载。

## 8. 验收场景

1. TTL 到期后 run 数据按规则驱逐。
2. finalize 成功后写入长期记忆。
3. hard fail 不写入长期记忆。
4. 检索命中在 diagnosis 前注入。
5. 仅记忆支撑的结论不会直接进入 facts。
6. 证据不足路径输出满足 verification-first 约束。
7. 触发回滚后恢复到最近提交状态。
