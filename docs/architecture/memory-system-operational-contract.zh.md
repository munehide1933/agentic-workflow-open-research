# Memory 系统运行契约

## 1. 范围

本文将 runtime memory 行为定义为运行契约。
用于统一 memory 注入、检索上限、摘要 checkpoint 与可见性约束。

不在范围内：

- 私有索引拓扑与分片布局
- 私有 embedding 调参与排序细节
- 基础设施特定的数据复制实现

## 2. 问题定义

没有契约的 memory 行为会引入隐式非确定性。
典型失败模式：

- memory 注入无上限导致成本与延迟失控
- 过期 memory 污染当前推理
- 检索失败被静默吞掉导致空上下文
- 跨租户可见性规则被破坏

## 3. 契约 / 数据模型

### 3.1 Memory 策略契约

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `memory_scope` | string | `session | tenant | global` |
| `max_injected_items` | integer | 每步最大注入 memory 条数 |
| `retrieval_timeout_ms` | integer | memory 检索超时预算 |
| `summary_checkpoint_interval` | integer | 摘要 checkpoint 的步长间隔 |
| `min_relevance_score` | number | 检索纳入的最低相关性 |
| `fallback_mode` | string | `sqlite_only | summary_only | no_memory` |
| `visibility_rule` | string | session/tenant 可见性规则键 |

### 3.2 Memory 事件记录

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `run_id` | string | 运行执行 ID |
| `step_id` | string | pipeline step ID |
| `retrieval_query` | string | 标准化检索查询 |
| `retrieved_count` | integer | 返回记录数 |
| `injected_keys` | array[string] | 注入 prompt 的 memory 键 |
| `checkpoint_id` | string | 摘要 checkpoint 产物 ID |
| `degradation_path` | string | 实际生效的降级路径 |

## 4. 决策逻辑

```python
def resolve_memory_context(state, policy, stores):
    records = stores.primary.search(
        query=state.memory_query,
        timeout_ms=policy.retrieval_timeout_ms,
        min_score=policy.min_relevance_score,
        limit=policy.max_injected_items,
    )

    if not records:
        return {"items": [], "degradation": "summary_only"}

    visible = [r for r in records if check_visibility(r, state.session_id, state.tenant_id)]
    return {"items": visible[: policy.max_injected_items], "degradation": None}


def maybe_write_summary_checkpoint(state, policy, stores):
    if state.step_index % policy.summary_checkpoint_interval != 0:
        return None

    summary = build_summary_snapshot(state)
    checkpoint = stores.primary.write_summary(state.session_id, summary)
    return checkpoint.checkpoint_id
```

## 5. 失败与降级

1. 主检索后端超时 -> 降级为 `summary_only`。
2. 摘要后端不可用 -> 降级为 `no_memory` 并写入显式元数据。
3. 发现可见性冲突 -> 分类 `policy_failure` 并丢弃该记录。
4. 检索结果超过 `max_injected_items` -> 按排序确定性截断。
5. checkpoint 写入失败 -> 流程继续，记 warning 并按预算重试。

## 6. 验收场景

1. session 运行且检索后端正常：
   - 预期：注入评分最高且可见的记录。
2. 向量后端检索超时：
   - 预期：降级到仅摘要上下文。
3. 无记录达到相关性阈值：
   - 预期：空注入并标记 `summary_only`。
4. 检索结果出现跨租户记录：
   - 预期：由可见性规则阻断，不注入。
5. 到达 checkpoint 间隔：
   - 预期：生成摘要 checkpoint 产物。
6. checkpoint 写入瞬时失败：
   - 预期：非终止 warning，并在预算内重试。
7. 负例：注入条数超过上限：
   - 预期：确定性截断并增加指标计数。

## 7. 兼容与版本

- Memory 策略键新增可选字段属于 minor 兼容。
- `visibility_rule` 语义变更属于 major 变更。
- 新增 fallback mode 必须补充验收场景。
- Memory 事件记录新增可选字段保持向后兼容。

## 8. 交叉引用

- [Runtime 能力地图](./runtime-capability-map.zh.md)
- [Agent Pipeline 契约 Profile](./agent-pipeline-contract-profile.zh.md)
- [Memory 层架构规范](./memory-architecture.zh.md)
- [Runtime 可靠性机制](./runtime-reliability-mechanisms.zh.md)
