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

### 2.1 传输头与回放 Profile

当前 runtime 的流式传输会暴露以下响应头：

- `x-vercel-ai-ui-message-stream: v1`：UI message stream 投影 profile
- `X-Idempotent-Replay: true`：同一 `Idempotency-Key` 命中缓存回放时设置

回放规则：

1. 回放必须返回权威终态载荷（`final` 或脱敏后的 `error`），且不重复执行 pipeline 阶段。
2. 回放流不应发射中间 processing status 分片。
3. sync 端点回放时，响应体应包含 `idempotency_replay=true`。

### 2.2 Frame Builder 引擎兼容 Profile

runtime 在编码 UI stream 的 `status` 与 `text-delta` 分片时，可以使用默认 Python 编码器或 Rust frame builder。

契约规则：

1. 相同输入下，两种引擎输出的 frame 文本必须字节级等价。
2. 引擎切换不得改变流协议形状（`start`、`text-start`、`text-delta`、`text-end`、`finish-step`、`finish`、`[DONE]`）。
3. Rust 路径失败时，必须自动回退到 Python 编码，且不能破坏流终止语义。
4. 回退原因必须按封闭标签可观测：
   - `disabled`
   - `import_error`
   - `runtime_error`
   - `invalid_output`
5. rollout source 标签规范化为：
   - `staging_replay`
   - `prod_mirror`
   - `unknown`

可观测计数器：

- `ui_stream_frame_builder_eligible_events_total{source,event_type}`
- `ui_stream_frame_builder_encoded_events_total{source,event_type,engine}`
- `ui_stream_frame_builder_rust_encoded_events_total{source,event_type}`
- `ui_stream_frame_builder_fallback_events_total{source,event_type,reason}`
- `ui_stream_rust_frame_builder_fallback_total{reason}`

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
- `source`：用户正文片段来源（`answer | quote`）
- `phase`：流式阶段标签（例如 `draft_delta`、`answer_delta`、`quote_delta`）
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

### 5.1 用户面顺序与一致性约束

在首个用户可见 `content` 分片发射前，必须先满足如下 `status.payload.code` 顺序：

`mode_selected -> language_locked -> style_mode_locked`

用户正文流 source 白名单：

- 允许：`answer`、`quote`
- 禁止进入用户正文流：其他任何 source 值

用户正文流的 phase 白名单：

- 允许：`draft_delta`、`answer_delta`、`quote_delta`
- 禁止：`final_delta` 以及所有非白名单 phase

流式说明：

- `initial_analysis` 的流式内容可用于内部状态拼接，但不能转发到用户正文流

终态一致性约束：

`final.content`（等价于 `final.payload.answer`）`== final_answer_text == persisted_answer`

### 5.2 UI Message 投影说明

当内部 pipeline 事件被投影到 UI message stream 协议时：

1. 仅白名单 phase 会映射为用户可见 `text-delta`
2. 若流式正文是终态正文的严格前缀，则将缺失后缀补发为额外 `text-delta`
3. 若流式正文与终态权威正文发生分歧，则发射 `data-final-override`，携带权威终态文本

## 6. 校验与拒收规则

出现以下任一情况，消费端应拒收或隔离该流：

1. `seq` 重复或不递增。
2. 非终止事件却设置 `terminal=true`。
3. 出现多个终止事件。
4. `payload` 与 `event_type` 不匹配。
5. 终止事件后仍有新事件。
6. `content.channel=artifact` 但缺少 `artifact_id`。
7. 流式 `artifact_id` 未在 `final.payload.artifacts` 回收。
8. 用户可见正文分片的 `content.payload.source` 不在白名单内。
9. `final` 答案与持久化终态答案不一致。
10. 引擎切换导致 frame 编码破坏协议形状或终态闭合语义。

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
6. stream 幂等回放（同 key + 同 hash）：
   - 预期：仅回放终态事件，且响应头含 `X-Idempotent-Replay: true`。
7. sync 幂等回放（同 key + 同 hash）：
   - 预期：响应体包含 `idempotency_replay=true`。
8. UI 投影中的终态文本分歧：
   - 预期：发射 `data-final-override`，携带权威终态文本。
9. Rust frame builder 一致性：
   - 预期：相同输入下，Rust 与 Python 生成的 `status` / `text-delta` frame 字节级一致。
10. Rust frame builder 运行时回退：
   - 预期：编码异常时 stream 仍满足协议，且 fallback 计数递增。
