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
- `request_id`
- `trace_id`
- `run_id`
- `session_id`

## 4. Structured Logging Contract

Required log fields:

- `ts`
- `level`
- `request_id`
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
2. `request_id` is required at HTTP boundaries and must be returned in the response header `X-Request-ID`.
3. `trace_id` can span multiple service components.
4. All stage logs and SSE events for a run must share `trace_id` and `run_id`.
5. Retries must create new `run_id` but retain the same `trace_id`.

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

Rollout and parity governance metrics:

- `quality_kernel_rollout_calls_total{source,surface}`
- `quality_kernel_rollout_fallback_total{source,surface,reason}`
- `quality_kernel_compare_requests_total{source,surface}`
- `quality_kernel_compare_request_mismatch_total{source,surface}`
- `quality_kernel_parity_mismatch_total{field}`
- `quality_kernel_parity_mismatch_by_source_total{source,surface,field}`
- `ui_stream_frame_builder_eligible_events_total{source,event_type}`
- `ui_stream_frame_builder_encoded_events_total{source,event_type,engine}`
- `ui_stream_frame_builder_rust_encoded_events_total{source,event_type}`
- `ui_stream_frame_builder_fallback_events_total{source,event_type,reason}`
- `ui_stream_rust_frame_builder_fallback_total{reason}`
- `first_meaningful_content_ms` (histogram)
- `idempotency_cleanup_run_total`
- `idempotency_cleanup_expired_total`
- `idempotency_cleanup_deleted_total`
- `idempotency_cleanup_lock_skip_total`
- `idempotency_cleanup_error_total`

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
- `runtime_quality.performance.runtime_timeline[*]` includes `event`, `stage`, `phase`, `status`, `reason_code`, `ts_ms`, and `details`
- `runtime_quality.performance.transition_records[*]` includes `from_state`, `to_state`, `event`, `action`, `reason_code`, `ts_ms`, and `details`
- `runtime_quality.arbitration_ledger` includes deterministic decision projection and signal snapshot
- `runtime_quality.arbitration_summary` includes user-facing arbitration summary fields
- `runtime_quality.performance.general_latency_flags_effective.ttft_v2_enabled` indicates TTFT v2 effective profile
- `runtime_quality.performance.first_meaningful_content_ms` records first meaningful non-preview content latency

### 8.1 Runtime Guardrail Severity Contract

Runtime guardrail evaluation output uses four severity classes:

- `blocker`
- `high`
- `warning`
- `spike_alerts`

Guardrail output shape:

- `blocker[]`: immediate release stop conditions
- `high[]`: release-blocking quality/reliability regressions
- `warning[]`: non-blocking regressions that require follow-up
- `spike_alerts[]`: acute spike signals compared with baseline snapshot
- `signals{...}`: computed ratio payload used by gates
- `rollout_primary_sources[]`: rollout sources under enforcement (default includes `prod_mirror`)

Coverage-aware gate rule:

- SSE fallback high severity is enforced only when rollout coverage is above configured minimum (`sse_fallback_eval_min_coverage`).
- If coverage is below minimum, emit warning (`sse_fallback_rate_not_enforced_low_coverage`) instead of high.

### 8.2 Regex Cache Diagnostic Surface (Optional)

When Rust quality kernel extension is available, regex cache diagnostics may expose:

- `hit_total`
- `miss_total`
- `eviction_total`
- `failure_cache_hit_total`
- `entry_count`
- `schema_version`
- `max_entries`

This surface is diagnostic-only and must not be used as a behavioral input for runtime decisions.

## 9. Acceptance Scenarios

1. Model timeout emits `E_TIMEOUT_STAGE_*` and complete trace tuple.
2. Schema parsing failure emits `E_SCHEMA_INVALID_PAYLOAD`.
3. Same-session concurrency conflict emits `E_CONCURRENCY_CONFLICT`.
4. All error events can be joined by `trace_id` and `run_id`.
5. Final metadata payload includes `runtime_boundary`, `failure_event`, `output_contract`, and `second_pass.timeout_profile`.
6. Metrics backend reports latency quantiles (`p50/p95/p99`) per stage.
7. HTTP error responses always include `request_id` and `X-Request-ID`.
8. Runtime quality performance payload includes `runtime_timeline` and `transition_records`.
9. Arbitration-triggered runs include both `arbitration_ledger` and `arbitration_summary`.
10. Compare-mode request mismatch rate uses compare-request denominator, not per-field mismatch counter denominator.
11. Guardrail SSE fallback high severity is suppressed when coverage is below minimum threshold.
12. Idempotency cleanup run reports run/expired/deleted counters with deterministic monotonic updates.
