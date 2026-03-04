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

## 3. 基线组

- `prompt_only`：无 diagnosis 结构、无 second pass、无 guard 系统
- `diagnosis_only`：有 diagnosis 结构，无 second pass，Anchor/Quality 不联动
- `full_pipeline`：diagnosis + second pass + anchor guard + quality gate + 状态机治理

## 4. 指标定义

1. Evidence Quality Rate

`anchored_facts / total_facts`

2. Non-Echo Ratio

`non_echo_audits / valid_audits`

3. Unsafe Output Suppression

`blocked_or_degraded_under_missing_anchors / risky_code_requests_with_missing_anchors`

4. Degradation Correctness

`correct_fallback_runs / runs_that_should_degrade`

其中 `runs_that_should_degrade = 计数(满足 degrade_oracle.should_degrade=true 的 run)`。

5. Final Consistency

`runs_with_contract_consistent_final / total_runs`

## 5. Degrade Oracle（可机械执行）

定义：

`should_degrade = (diagnosis.insufficient_evidence) OR (requires_executable AND anchor_score < 0.80) OR (audit_invalid_or_echo_or_weak) OR (quality_gate in {soft_fail, hard_fail}) OR (state in {S_FAIL_RETRYABLE, S_FAIL_TERMINAL})`

`oracle_reason` 为多标签集合，取值：

- `insufficient_evidence`
- `missing_anchor`
- `invalid_audit`
- `weak_audit`
- `quality_gate_fail`
- `fail_state`

每个 run 的 oracle 输出字段：

- `oracle_should_degrade`：布尔值
- `oracle_reason`：标签数组

## 6. 评测流程

1. 固化数据集切分与输入提示。
2. 三组基线使用同一请求集合运行。
3. 持久化原始事件、diagnosis 结构、audit 载荷、final 输出。
4. 仅基于持久化产物计算指标与 oracle 标签。
5. 样本量允许时报告置信区间。

## 7. 数据集规范

最小列定义与样例见 [`examples/contracts/benchmark-dataset-spec.md`](../../examples/contracts/benchmark-dataset-spec.md)。

## 8. 报告模板

最低报告内容：

- 数据集定义与采样方法
- 基线配置说明
- 带公式的指标表
- degrade oracle 规则与原因分布
- 失败模式样例
- 复现检查清单

## 9. 验收标准

1. 指标公式可机器校验。
2. `runs_that_should_degrade` 由确定性 oracle 逻辑计算。
3. 数据集与切分具备版本管理。
4. 其他团队复跑可得到一致指标逻辑与可比趋势。
