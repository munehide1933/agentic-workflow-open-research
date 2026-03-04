# Anchor Guard 设计规范

## 目标

当环境锚点不完整时，阻断不安全或误导性的可执行建议。

## 公开锚点集合

- runtime
- deployment context
- client SDK
- HTTP client（当请求需要栈相关 HTTP 细节时）

## 评分模型（加权求和 + 条件归一）

### 权重

- `runtime = 0.35`
- `deployment_context = 0.30`
- `client_sdk = 0.25`
- `http_client = 0.10`

### 维度状态分值

- `present = 1.0`
- `partial = 0.5`
- `missing = 0.0`
- `not_applicable = exclude`（从分母剔除）

### 评分公式

`anchor_score = sum(weight_i * value_i) / sum(active_weights)`

其中 `active_weights` 仅包含不为 `not_applicable` 的维度。

## HTTP 维度触发规则（操作化）

仅当 `http_dimension_applicable=true` 时纳入 `http_client`。
该标记必须在理解阶段计算，并写入路由状态。

默认确定性规则：

`http_dimension_applicable = requires_executable AND (intent_type in {codegen, ops, diagnosis}) AND has_http_scope_signal`

当满足任一条件时，`has_http_scope_signal=true`：

1. 请求要求生成或修改外部 API 调用逻辑。
2. 请求要求栈相关 HTTP 行为（`headers`、`status`、`retry`、`timeout`、`proxy`、`auth signing`、`TLS`）。
3. 部署上下文包含 API gateway/webhook/service integration 约束。

若均不满足，应设 `http_client=not_applicable`，并从分母剔除该权重。

### 触发示例

- `intent_type=codegen`、`requires_executable=true`、任务为“实现 webhook 重试客户端” -> 触发。
- `intent_type=architecture`、`requires_executable=false`、任务为“比较 pub/sub 模式” -> 不触发。

## 维度判定标准（公开默认）

### Runtime

- `present`：运行时家族与版本范围明确。
- `partial`：仅知道运行时家族，版本/范围不明确。
- `missing`：运行时家族未知。

### Deployment Context

- `present`：部署目标/阶段约束明确。
- `partial`：有泛化环境提示，但目标约束不完整。
- `missing`：无部署上下文。

### Client SDK

- `present`：SDK 家族及可用包标识/版本范围明确。
- `partial`：仅知道 SDK 家族，包或版本范围不明确。
- `missing`：未识别 SDK。

### HTTP Client

- `present`：在需要时，具体 HTTP client 明确。
- `partial`：存在 HTTP 调用意图，但客户端未固定。
- `missing`：需要但未知。
- `not_applicable`：请求不需要栈相关 HTTP 细节。

## 阈值策略（保持不变）

- `score < 0.50`：阻断可执行代码
- `0.50 <= score < 0.80`：仅允许伪代码
- `score >= 0.80`：可进入代码生成（仍需通过 Quality Gate）

## 可复算示例

### 示例 A：高置信，HTTP 不适用

- runtime=`present`，deployment=`present`，sdk=`present`，http=`not_applicable`
- 分子 = `0.35*1.0 + 0.30*1.0 + 0.25*1.0 = 0.90`
- 分母 = `0.35 + 0.30 + 0.25 = 0.90`
- `anchor_score = 1.00` -> 可执行输出可放行

### 示例 B：临界档

- runtime=`present`，deployment=`partial`，sdk=`missing`，http=`missing`（需要）
- 分子 = `0.35*1.0 + 0.30*0.5 + 0.25*0.0 + 0.10*0.0 = 0.50`
- 分母 = `1.00`
- `anchor_score = 0.50` -> 仅伪代码

### 示例 C：低置信

- runtime=`missing`，deployment=`partial`，sdk=`missing`，http=`missing`（需要）
- 分子 = `0.35*0.0 + 0.30*0.5 + 0.25*0.0 + 0.10*0.0 = 0.15`
- 分母 = `1.00`
- `anchor_score = 0.15` -> 阻断可执行代码

## 策略动作

当请求在诊断不确定条件下要求可执行代码且锚点不完整时：

1. 阻断单栈可执行代码
2. 输出栈无关指导或伪代码
3. 显式列出缺失锚点

## 与 Quality Gate 的优先级

1. Anchor Guard 先执行。
2. 仅在可执行资格通过后再执行 Quality Gate。
3. 冲突时取更严格结论。

## 工程意义

LLM 可输出语法正确但运行风险极高的代码。
Anchor Guard 将该风险转化为可审计、可复盘的显式策略。
