# Error Taxonomy and Observability Specification

## 1. Scope

This specification defines public error namespaces, required log fields, and trace linkage rules.

## 2. Error Code Namespaces

Public prefixes:

- `E_MODEL_*`: model provider/runtime errors
- `E_SCHEMA_*`: schema validation and parsing errors
- `E_TIMEOUT_*`: stage timeout errors
- `E_POLICY_*`: policy and guard violations
- `E_ROUTER_*`: routing decision failures
- `E_MEMORY_*`: memory read/write/search failures
- `E_CONCURRENCY_*`: session concurrency conflicts

Required public code:

- `E_CONCURRENCY_CONFLICT` for same-session concurrent run rejection.

## 3. Canonical Error Fields

Every terminal error must carry:

- `error_code`
- `error_message`
- `retryable`
- `phase`
- `trace_id`
- `run_id`
- `session_id`

## 4. Structured Logging Contract

Required log fields:

- `ts`
- `level`
- `trace_id`
- `run_id`
- `session_id`
- `phase`
- `state`
- `event`
- `error_code` (if present)
- `latency_ms`

Optional log fields:

- `mode`
- `rule_id`
- `fallback_path`
- `quality_gate_decision`
- `anchor_score`

## 5. Trace Linkage Rules

1. A single user request maps to one `run_id`.
2. `trace_id` can span multiple service components.
3. All stage logs and SSE events for a run must share `trace_id` and `run_id`.
4. Retries must create new `run_id` but retain the same `trace_id`.

## 6. SSE Error Mapping

`error` SSE payload should include public fields only; no secrets or private prompts.

## 7. Runtime Final Metadata Contract

The final runtime metadata object must expose the following public fields:

- `runtime_boundary`
- `failure_event`
- `output_contract`
- `second_pass.timeout_profile`

These fields are additive-compatible and must not remove legacy public fields in minor revisions.

## 8. Metrics and Trace Baseline

Required metric dimensions:

- `step_latency_ms` (`p50`, `p95`, `p99`)
- `token_input`, `token_output`
- `model_cost`
- `audit_time`
- `guard_rejection_count`
- `retry_count`
- `failure_type_distribution`

Trace hierarchy baseline:

- `agent_run_id`
- `step_id`
- `model_call_span`
- `tool_call_span`
- `audit_span`
- `merge_span`

Runtime quality payload baseline:

- `runtime_quality.stage_snapshots[*]` includes `stage`, `model_deployment`, `estimated_tokens_in`, `estimated_tokens_out`, `duration_ms`, and `flags`
- `runtime_quality.invariant_gate` includes `passed`, `reason_codes`, `metrics`, and `fallback`
- `runtime_quality.degradation_flags` tracks run-level degrade markers

## 9. Acceptance Scenarios

1. Model timeout emits `E_TIMEOUT_STAGE_*` and complete trace tuple.
2. Schema parsing failure emits `E_SCHEMA_INVALID_PAYLOAD`.
3. Same-session concurrency conflict emits `E_CONCURRENCY_CONFLICT`.
4. All error events can be joined by `trace_id` and `run_id`.
5. Final metadata payload includes `runtime_boundary`, `failure_event`, `output_contract`, and `second_pass.timeout_profile`.
6. Metrics backend reports latency quantiles (`p50/p95/p99`) per stage.
