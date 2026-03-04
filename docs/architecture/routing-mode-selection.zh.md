# 路由与模式选择规范

## 1. 范围

本规范定义请求如何路由到 `basic`、`deep_thinking` 或 `web_search`。

## 2. 输入特征

路由使用如下特征向量：

- `intent_type`：`qa | diagnosis | codegen | architecture | ops`
- `complexity_score`：`[0,1]` 浮点数
- `freshness_need`：`[0,1]` 浮点数
- `external_lookup_required`：布尔值
- `risk_level`：`low | medium | high`
- `requires_executable`：布尔值

## 3. 特征计算（公开默认）

`complexity_score` 与 `freshness_need` 必须在路由决策前计算。

### 3.1 `complexity_score`

`complexity_score = 0.35*s1 + 0.25*s2 + 0.20*s3 + 0.20*s4`

- `s1` 多步骤需求：`min(1.0, estimated_steps / 4)`
- `s2` 约束密度：`min(1.0, explicit_constraints_count / 6)`
- `s3` 产物需求：需要代码/配置/操作流程输出时为 `1.0`，否则 `0.0`
- `s4` 歧义惩罚：关键实体缺失为 `1.0`，部分缺失为 `0.5`，否则 `0.0`

### 3.2 `freshness_need`

`freshness_need = 0.50*f1 + 0.30*f2 + 0.20*f3`

- `f1` 显式时效意图：query 含 `latest`、`today`、`this week` 或版本/日期敏感诉求时为 `1.0`
- `f2` 易变域信号：价格、发布、事故状态、政策更新等易变主题为 `1.0`，否则 `0.0`
- `f3` 校验意图：用户明确要求 check/search/verify sources 时为 `1.0`，否则 `0.0`

若实现替换该特征提取器，必须公开：

1. 提取器 ID/版本
2. 校准数据集摘要
3. 用于可比路由的等效阈值

## 4. 决策规则

公开默认规则：

1. 若 `external_lookup_required=true` 或 `freshness_need >= 0.70` => `web_search`。
2. 否则若 `complexity_score >= 0.65` 或 `risk_level=high` => `deep_thinking`。
3. 其余 => `basic`。

## 5. 回退规则

1. `web_search` 超时/失败 => 回退到 `deep_thinking`，并设置 `insufficient_evidence=true`。
2. `deep_thinking` 超时 => 回退到 `basic` 的 verification-first 输出。
3. `basic` 仅在循环保护允许时可升级为 `deep_thinking`。

## 6. 循环保护（强制）

为避免 `basic -> deep_thinking -> basic` 循环：

1. `max_deep_escalations_per_run = 1`。
2. 同一 run 内若已发生 `deep_thinking` 超时，禁止 `basic -> deep_thinking` 再升级。
3. 回退次数达到 `2` 后，将模式锁定为 `basic` 直至 run 结束。
4. 模式锁定时输出必须为 verification-first。

必需的 route-state 标记：

- `deep_timeout_seen`：布尔值
- `deep_escalation_count`：整数
- `mode_lock`：`none | basic`

## 7. `web_search` 证据回流

置信度标签由系统侧 `web_search_evidence_ranker` 赋值，不直接使用搜索提供方原始字段。

单条证据置信度分数：

`evidence_confidence_score = 0.50*r1 + 0.30*r2 + 0.20*r3`

- `r1` 来源可靠性（`official_docs=1.0`、`major_publisher=0.8`、`community_source=0.6`、`unknown=0.4`）
- `r2` 跨源一致性（独立来源间主张重合度）
- `r3` 时效匹配度（发布时间与 query 时效窗口匹配）

标签映射：

- `high`：`score >= 0.80`（权重 `1.0`）
- `medium`：`0.55 <= score < 0.80`（权重 `0.6`）
- `low`：`score < 0.55`（权重 `0.3`）

回流影响：

1. 聚合置信度偏低可触发 `insufficient_evidence=true`。
2. 假设排序必须吸收证据权重。
3. 缺失时效证据应追加到 `required_fields`。

## 8. 确定性与日志

每次 run 的路由层必须持久化：

- 最终模式
- 特征值
- 命中规则 ID
- 回退路径（若有）
- 循环保护标记（`deep_timeout_seen`、`deep_escalation_count`、`mode_lock`）
- 使用 `web_search` 时的证据置信度标签及分量分数（`r1`、`r2`、`r3`）

## 9. 验收场景

1. 高时效需求 => `web_search`。
2. 高复杂度且无时效需求 => `deep_thinking`。
3. 低复杂度低风险 => `basic`。
4. `web_search` 失败 => 回退且不确定性标记生效。
5. `deep_thinking` 超时后 `basic` 不确定性升高 => 不发生再升级循环。
6. 相同 query 在相同特征提取器下路由结果稳定。
