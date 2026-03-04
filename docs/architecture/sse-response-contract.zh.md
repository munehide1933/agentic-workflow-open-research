# SSE 响应契约（v1）

## 1. 范围

本文定义智能体响应的公开流式契约。
该契约与实现无关，适用于全部模式：`basic`、`deep_thinking`、`web_search`。

## 2. 事件信封（Envelope）

所有 SSE 事件必须满足以下统一字段：

- `event_type`：`status | content | final | error`
- `trace_id`：全链路追踪 ID
- `run_id`：单次 `run_agent` 执行 ID
- `session_id`：会话 ID
- `seq`：单调递增序号，起始为 `1`
- `ts`：RFC 3339（UTC）时间戳
- `payload`：事件类型对应的负载对象
- `terminal`：终止标记（布尔）

契约规则：

1. 同一 `run_id` 下，`seq` 必须严格递增。
2. 仅 `final` 或 `error` 允许 `terminal=true`。
3. 每个 `run_id` 只能出现一个终止事件。
4. 终止事件之后不得再发送任何事件。

## 3. 事件类型

### 3.1 `status`

`status` 用于阶段状态和进度通知。

`payload` 必填：

- `phase`：`understand | diagnose | draft | audit | finalize | render`
- `code`：状态码字符串（例如 `phase_enter`、`timeout_warning`）
- `message`：简短状态描述

`payload` 选填：

- `progress`：`[0, 1]` 范围数值
- `retryable`：布尔值

`status` 必须为非终止事件（`terminal=false`）。

### 3.2 `content`

`content` 用于增量正文输出。

`payload` 必填：

- `delta`：流式文本片段

`payload` 选填：

- `channel`：`text | artifact`
- `artifact_id`：当 `channel=artifact` 时的产物 ID（该场景必填）
- `chunk_index`：artifact 分片序号

`content` 必须为非终止事件（`terminal=false`）。

### 3.3 `final`

`final` 用于最终答案输出。

`payload` 必填：

- `answer`：最终答案文本

`payload` 选填：

- `artifacts`：产物元数据数组
- `quality_gate_result`：`pass | soft_fail | hard_fail`
- `degraded`：布尔值

`final` 必须为终止事件（`terminal=true`）。

### 3.4 `error`

`error` 用于终止失败输出。

`payload` 必填：

- `error_code`：命名空间错误码（`E_*`）
- `error_message`：简短错误信息
- `retryable`：布尔值

`payload` 选填：

- `phase`：失败阶段
- `details`：脱敏诊断对象

`error` 必须为终止事件（`terminal=true`）。

## 4. Artifact 通道语义

当 `content.payload.channel=artifact` 时：

1. `artifact_id` 必填。
2. 消费端应按 `artifact_id` 缓存分片。
3. 若存在 `chunk_index`，需在同一 `artifact_id` 下单调递增。

当 `final.payload.artifacts` 存在时：

1. 每个条目必须包含 `artifact_id`。
2. 所有流式出现过的 `artifact_id` 必须在 `final.payload.artifacts` 中且仅出现一次。
3. 每个条目应给出终态 `status`（`complete | partial | blocked`）。

消费端集成规则：

- `content` 用于增量接收 artifact 内容。
- `final.payload.artifacts` 是权威元数据与完成信号。

## 5. 顺序与超时语义

允许顺序：

`status* -> content* -> (final | error)`

补充规则：

1. `status` 可以出现在 `content` 之前和过程中。
2. 允许无 `content` 的快速失败。
3. 阶段超时时，若可发送，应先发 `status(code=timeout_warning)`。
4. 终止超时必须发 `error(error_code=E_TIMEOUT_STAGE_*)`。

## 6. 校验与拒收规则

出现以下任一情况，消费端应拒收或隔离该流：

1. `seq` 重复或不递增。
2. 非终止事件却设置 `terminal=true`。
3. 出现多个终止事件。
4. `payload` 与 `event_type` 不匹配。
5. 终止事件后仍有新事件。
6. `content.channel=artifact` 但缺少 `artifact_id`。
7. 流式 `artifact_id` 未在 `final.payload.artifacts` 回收。

## 7. 版本与兼容

- 版本：`v1`
- JSON Schema：[`examples/contracts/sse-event.schema.v1.json`](../../examples/contracts/sse-event.schema.v1.json)
- 向后兼容规则：小版本仅允许新增可选字段。

## 8. 验收场景

1. 正常流：`status -> content -> content -> final`。
2. 超时流：`status(timeout_warning) -> error(E_TIMEOUT_STAGE_AUDIT)`。
3. 早期 schema 失败：`status -> error(E_SCHEMA_INVALID_PAYLOAD)`。
4. artifact 流：`content(channel=artifact,artifact_id=A1)* -> final(artifacts 含 A1)`。
5. 负例：重复终止事件。
