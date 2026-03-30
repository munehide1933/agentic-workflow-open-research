# SSE Response Contract (v1)

## 1. Scope

This document defines the public stream contract for agent responses.
It is implementation-agnostic and applies to all modes: `basic`, `deep_thinking`, `web_search`.

## 2. Event Envelope

All SSE events must conform to this envelope:

- `event_type`: `status | content | final | error`
- `trace_id`: global trace identifier for distributed diagnostics
- `run_id`: unique identifier for one `run_agent` execution
- `session_id`: conversation identifier
- `seq`: monotonic sequence number starting at `1`
- `ts`: RFC 3339 timestamp (UTC)
- `payload`: event-specific object
- `terminal`: boolean terminal flag

Contract rules:

1. `seq` is strictly increasing within the same `run_id`.
2. `terminal=true` is allowed only for `final` or `error`.
3. Exactly one terminal event is allowed per run.
4. After a terminal event, no further events may be emitted.

### 2.1 Transport Headers and Replay Profile

The current runtime stream transport exposes the following response headers:

- `x-vercel-ai-ui-message-stream: v1` for the UI message stream projection profile
- `X-Idempotent-Replay: true` when a cached stream result is replayed for the same `Idempotency-Key`

Replay rules:

1. Replay must return an authoritative terminal payload (`final` or sanitized `error`) without re-running pipeline stages.
2. Replay stream should not emit intermediate processing status frames.
3. Sync endpoint replay should include `idempotency_replay=true` in the response payload.

### 2.2 Frame Builder Engine Compatibility Profile

The runtime may encode `status` and `text-delta` UI stream frames with either the default Python encoder or the Rust frame builder.

Contract rules:

1. For equivalent inputs, emitted frame text must be byte-equivalent across encoder engines.
2. Engine switch must not change stream protocol shape (`start`, `text-start`, `text-delta`, `text-end`, `finish-step`, `finish`, `[DONE]`).
3. On Rust path failure, runtime must fallback to Python encoding without breaking stream completion semantics.
4. Fallback reasons must be observable with closed reason labels:
   - `disabled`
   - `import_error`
   - `runtime_error`
   - `invalid_output`
5. Rollout source labels are normalized to:
   - `staging_replay`
   - `prod_mirror`
   - `unknown`

Observability counters:

- `ui_stream_frame_builder_eligible_events_total{source,event_type}`
- `ui_stream_frame_builder_encoded_events_total{source,event_type,engine}`
- `ui_stream_frame_builder_rust_encoded_events_total{source,event_type}`
- `ui_stream_frame_builder_fallback_events_total{source,event_type,reason}`
- `ui_stream_rust_frame_builder_fallback_total{reason}`

## 3. Event Types

### 3.1 `status`

`status` reports phase and progress transitions.

Required payload fields:

- `phase`: `understand | diagnose | draft | audit | finalize | render`
- `code`: status code string (for example `phase_enter`, `timeout_warning`)
- `message`: short human-readable status

Optional payload fields:

- `progress`: number in `[0, 1]`
- `retryable`: boolean

`status` is non-terminal (`terminal=false`).

### 3.2 `content`

`content` carries incremental response output.

Required payload fields:

- `delta`: streamed text chunk

Optional payload fields:

- `channel`: `text | artifact`
- `source`: logical body source (`answer | quote`) for user-visible text chunks
- `phase`: stream phase label (for example `draft_delta`, `answer_delta`, `quote_delta`)
- `artifact_id`: identifier when `channel=artifact` (required in that case)
- `chunk_index`: integer chunk sequence for artifact stream

`content` is non-terminal (`terminal=false`).

### 3.3 `final`

`final` carries the finalized response artifact.

Required payload fields:

- `answer`: finalized answer text

Optional payload fields:

- `artifacts`: output artifacts metadata array
- `quality_gate_result`: `pass | soft_fail | hard_fail`
- `degraded`: boolean

`final` must be terminal (`terminal=true`).

### 3.4 `error`

`error` indicates terminal failure.

Required payload fields:

- `error_code`: namespaced code (`E_*`)
- `error_message`: concise failure description
- `retryable`: boolean

Optional payload fields:

- `phase`: phase where failure happened
- `details`: sanitized diagnostics object

`error` must be terminal (`terminal=true`).

## 4. Artifact Channel Semantics

When `content.payload.channel=artifact`:

1. `artifact_id` is mandatory.
2. Consumers should buffer chunks keyed by `artifact_id`.
3. `chunk_index` should be monotonic per `artifact_id` when present.

When `final.payload.artifacts` is present:

1. each entry must include `artifact_id`
2. each streamed `artifact_id` must appear exactly once in `final.payload.artifacts`
3. each artifact entry should include terminal status (`complete | partial | blocked`)

Consumer integration rule:

- `content` events provide incremental artifact payload.
- `final.payload.artifacts` is authoritative metadata and completion signal.

## 5. Ordering and Timeout Semantics

Allowed event order:

`status* -> content* -> (final | error)`

Additional rules:

1. `status` can appear before and between `content` events.
2. `content` is optional for immediate fail-fast responses.
3. A stage timeout should emit `status` with `code=timeout_warning` first when possible.
4. Terminal timeout must emit `error` with `error_code=E_TIMEOUT_STAGE_*`.

### 5.1 User-Surface Sequencing and Consistency

Before the first user-visible `content` chunk is emitted, the following `status.payload.code` sequence must be observed:

`mode_selected -> language_locked -> style_mode_locked`

User body stream source allowlist:

- allowed: `answer`, `quote`
- blocked from user body stream: any other source value

Phase-level allowlist for user body stream:

- allowed: `draft_delta`, `answer_delta`, `quote_delta`
- blocked: `final_delta` and all non-allowlisted phases

Streaming note:

- `initial_analysis` stream content may be collected internally for state, but is not forwarded to user-visible body stream

Terminal consistency rule:

`final.content` (alias of `final.payload.answer`) `== final_answer_text == persisted_answer`

### 5.2 UI Message Projection Notes

When internal pipeline events are projected to the UI message stream protocol:

1. only allowlisted content phases are converted to user-visible `text-delta`
2. if streamed text is a strict prefix of final text, the missing suffix is appended as extra `text-delta`
3. if streamed text diverges from final authoritative text, emit `data-final-override` with authoritative final text

## 6. Validation and Rejection Rules

Consumers should reject or quarantine a stream when any of the following occurs:

1. `seq` is duplicated or non-monotonic.
2. Non-terminal event has `terminal=true`.
3. Multiple terminal events appear.
4. Event payload does not match its declared `event_type`.
5. Event appears after terminal.
6. `content.channel=artifact` without `artifact_id`.
7. Streamed `artifact_id` missing from `final.payload.artifacts`.
8. `content.payload.source` not in allowlist for user-visible body stream.
9. final answer mismatch against persisted terminal answer contract.
10. Engine-specific frame encoding changes observable protocol shape or terminal closure behavior.

## 7. Compatibility and Versioning

- Version: `v1`
- JSON Schema: [`examples/contracts/sse-event.schema.v1.json`](../../examples/contracts/sse-event.schema.v1.json)
- Backward-compatibility rule: additive optional fields are allowed in minor updates.

## 8. Acceptance Scenarios

1. Normal stream: `status -> content -> content -> final`.
2. Timeout stream: `status(timeout_warning) -> error(E_TIMEOUT_STAGE_AUDIT)`.
3. Early schema failure: `status -> error(E_SCHEMA_INVALID_PAYLOAD)`.
4. Artifact stream: `content(channel=artifact,artifact_id=A1)* -> final(artifacts includes A1)`.
5. Invalid case (for negative test): duplicate terminal event.
6. Stream idempotent replay (same key + same hash):
   - Expected: terminal-only replay with `X-Idempotent-Replay: true`.
7. Sync idempotent replay (same key + same hash):
   - Expected: response payload includes `idempotency_replay=true`.
8. Final text divergence in UI projection:
   - Expected: `data-final-override` emitted with authoritative final text.
9. Rust frame builder parity:
   - Expected: for same inputs, Rust and Python encoded `status` / `text-delta` frames are byte-equivalent.
10. Rust frame builder runtime fallback:
   - Expected: on encoder runtime error, stream remains protocol-valid and fallback counters increase.
