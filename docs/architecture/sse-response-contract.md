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
- `artifact_id`: identifier when `channel=artifact`

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

## 4. Ordering and Timeout Semantics

Allowed event order:

`status* -> content* -> (final | error)`

Additional rules:

1. `status` can appear before and between `content` events.
2. `content` is optional for immediate fail-fast responses.
3. A stage timeout should emit `status` with `code=timeout_warning` first when possible.
4. Terminal timeout must emit `error` with `error_code=E_TIMEOUT_STAGE_*`.

## 5. Validation and Rejection Rules

Consumers should reject or quarantine a stream when any of the following occurs:

1. `seq` is duplicated or non-monotonic.
2. Non-terminal event has `terminal=true`.
3. Multiple terminal events appear.
4. Event payload does not match its declared `event_type`.
5. Event appears after terminal.

## 6. Compatibility and Versioning

- Version: `v1`
- JSON Schema: [`examples/contracts/sse-event.schema.v1.json`](../../examples/contracts/sse-event.schema.v1.json)
- Backward-compatibility rule: additive optional fields are allowed in minor updates.

## 7. Acceptance Scenarios

1. Normal stream: `status -> content -> content -> final`.
2. Timeout stream: `status(timeout_warning) -> error(E_TIMEOUT_STAGE_AUDIT)`.
3. Early schema failure: `status -> error(E_SCHEMA_INVALID_PAYLOAD)`.
4. Invalid case (for negative test): duplicate terminal event.
