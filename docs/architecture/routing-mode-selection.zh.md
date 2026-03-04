# 路由与模式选择规范

## 1. 范围

本规范定义请求如何路由到 `basic`、`deep_thinking`、`web_search`。

## 2. 输入特征

路由使用以下特征向量：

- `intent_type`：`qa | diagnosis | codegen | architecture | ops`
- `complexity_score`：`[0, 1]` 浮点值
- `freshness_need`：`[0, 1]` 浮点值
- `external_lookup_required`：布尔值
- `risk_level`：`low | medium | high`

## 3. 决策规则

公开默认规则：

1. 若 `external_lookup_required=true` 或 `freshness_need >= 0.70`，路由到 `web_search`。
2. 否则，若 `complexity_score >= 0.65` 或 `risk_level=high`，路由到 `deep_thinking`。
3. 否则，路由到 `basic`。

## 4. 回退规则

1. `web_search` 超时/失败时，回退到 `deep_thinking`，并设置 `insufficient_evidence=true`。
2. `deep_thinking` 超时时，回退到 `basic` 的 verification-first 输出。
3. `basic` 在不确定性过高时可升级到 `deep_thinking`。

## 5. `web_search` 证据回流

外部检索证据置信度标签：

- `high` -> 权重 `1.0`
- `medium` -> 权重 `0.6`
- `low` -> 权重 `0.3`

回流影响：

1. 聚合证据置信度过低时可触发 `insufficient_evidence=true`。
2. 假设排序必须考虑证据权重。
3. 缺失时效证据需写入 `required_fields`。

## 6. 可追踪性要求

每次运行必须记录：

- 选中模式
- 特征值
- 命中规则 ID
- 回退路径（若发生）

## 7. 验收场景

1. 高时效需求 => `web_search`。
2. 高复杂度且无时效需求 => `deep_thinking`。
3. 低复杂度低风险 => `basic`。
4. `web_search` 失败 => 回退且不确定性置位。
