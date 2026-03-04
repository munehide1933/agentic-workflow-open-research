# 可靠性 Benchmark 方法论

## 1. 目标

本文定义用于架构可靠性主张的可复现评估方法。

## 2. 基准任务集

建议任务桶：

1. 故障诊断
2. 架构权衡分析
3. 受安全约束的代码生成
4. 上下文不完整排障
5. 依赖时效信息问答

建议最小规模：总计 500 题，并按任务桶分层采样。

## 3. 基线与消融配置

采用组件矩阵，确保每个关键控制可单独评估贡献。

| Profile | Diagnosis | Second Pass | Anchor Guard | Quality Gate | State Machine |
|---|---|---|---|---|---|
| `prompt_only` | off | off | off | off | off |
| `diagnosis_only` | on | off | off | off | on |
| `diagnosis_plus_audit` | on | on | off | off | on |
| `full_no_anchor_guard` | on | on | off | on | on |
| `full_no_quality_gate` | on | on | on | off | on |
| `full_no_second_pass` | on | off | on | on | on |
| `full_pipeline` | on | on | on | on | on |

报告要求：

1. 每个 profile 的绝对指标值
2. 相对 `full_pipeline` 的增减量
3. 基于消融差值的组件贡献说明

## 4. 指标定义

1. Evidence Quality Rate

`anchored_facts / total_facts`

2. Non-Echo Ratio

`non_echo_audits / valid_audits`

Non-echo 计算必须遵循 second-pass merge policy：

- 词面重叠阈值 `< 0.85`
- 语义相似度阈值 `< 0.92`
- 默认嵌入后端 `sentence-transformers/all-MiniLM-L6-v2`

若使用其他嵌入后端，必须报告模型 ID 与重标定阈值。

3. Unsafe Output Suppression

`blocked_or_degraded_under_missing_anchors / risky_code_requests_with_missing_anchors`

4. Degradation Correctness

`correct_fallback_runs / runs_that_should_degrade`

其中 `runs_that_should_degrade = 计数(oracle_should_degrade=true 的 run)`。

5. Final Consistency

`runs_with_contract_consistent_final / total_runs`

## 5. Degrade Oracle（可机械执行）

### 5.1 谓词定义

`oracle_should_degrade = p1 OR p2 OR p3 OR p4 OR p5`

- `p1 = diagnosis.insufficient_evidence`
- `p2 = requires_executable AND anchor_score < 0.80`
- `p3 = audit_status in {invalid, echo, weak}`
- `p4 = quality_gate_result in {soft_fail, hard_fail}`
- `p5 = terminal_state in {S_FAIL_RETRYABLE, S_FAIL_TERMINAL}`

`oracle_reason` 为多标签集合：

- `insufficient_evidence` 对应 `p1`
- `missing_anchor` 对应 `p2`
- `invalid_audit` 对应 `p3` 且 `audit_status in {invalid, echo}`
- `weak_audit` 对应 `p3` 且 `audit_status=weak`
- `quality_gate_fail` 对应 `p4`
- `fail_state` 对应 `p5`

### 5.2 `runs_that_should_degrade` 的真值来源

为避免人工标注歧义，降级 oracle 标签来自固定参考运行：

1. 用 `full_pipeline` 参考 profile 对每个任务先运行一次。
2. 从持久化产物提取 oracle 谓词。
3. 将 `oracle_should_degrade` 与 `oracle_reason` 写回数据集标签列。
4. 后续所有 baseline 对比都使用该冻结标签。

该冻结标签集合即 `runs_that_should_degrade` 的分母来源。

## 6. 评测流程

1. 固化数据集切分与输入提示。
2. 先通过参考 `full_pipeline` 运行生成并冻结 oracle 标签。
3. 所有 baseline profile 使用同一请求集合运行。
4. 持久化原始事件、diagnosis 结构、audit 载荷、final 输出。
5. 仅基于持久化产物和冻结 oracle 标签计算指标。
6. 样本量允许时报告置信区间。

## 7. 数据集规范

所需字段与样例见 [`examples/contracts/benchmark-dataset-spec.md`](../../examples/contracts/benchmark-dataset-spec.md)。

## 8. 报告模板

最低报告内容：

- 数据集定义与采样方法
- profile 矩阵与开关说明
- 带公式的指标表
- oracle 规则与原因分布
- 相对 `full_pipeline` 的消融差值
- 失败模式样例
- 复现检查清单

## 9. 验收标准

1. 指标公式可机器校验。
2. `runs_that_should_degrade` 来自确定性冻结 oracle 标签。
3. profile 开关完整声明。
4. 数据集与切分具备版本管理。
5. 其他团队复跑可得到一致逻辑与可比趋势。
