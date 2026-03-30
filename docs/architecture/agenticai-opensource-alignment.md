# AgenticAI and Open-Source Capability Alignment (2026-03)

## 1. Scope

This document aligns the current AgenticAI implementation baseline with the public open-research architecture documents in this repository.

It covers only public control-plane behavior and contract-level semantics.

Out of scope:

- private prompt internals
- deployment topology and private infrastructure details
- local execution operators and non-public runtime internals

## 2. Baseline and Evidence Sources

Alignment baseline date: `2026-03-23`

Implementation evidence is derived from:

- runtime modules (`backend/core`, `backend/app`, `backend/database`, `backend/services`)
- API surface (`backend/app/main.py`)
- contract tests under `backend/tests`

Behavioral evidence references used in this alignment:

1. `test_runtime_boundary_contract_v1.py`
2. `test_unified_step_runner_contract.py`
3. `test_chat_streaming_contract_v1.py`
4. `test_ui_message_stream_parts_mapping.py`
5. `test_pipeline_metadata_ssot_contract.py`
6. `test_second_pass_timeout_profile_contract.py`
7. `test_second_pass_confirmation_contract.py`
8. `test_chat_idempotency_contract.py`
9. `test_deleted_session_access_contract.py`
10. `test_request_context_contract.py`
11. `test_health_contract.py`
12. `test_runtime_timeline_metadata_contract.py`
13. `test_arbitration_ledger_decision_projection.py`
14. `test_sync_executor_backpressure_contract.py`
15. `test_sync_executor_timeout_observability_contract.py`
16. `test_ops_runtime_metrics_contract.py`
17. `test_artifact_diff_contract.py`
18. `test_artifact_api_list_detail_download.py`
19. `test_quality_kernel_adapter_contract.py`
20. `test_quality_kernel_review_batch_adapter_contract.py`
21. `test_quality_kernel_regex_cache_contract.py`
22. `test_quality_kernel_rust_helpers_contract.py`
23. `test_ui_message_stream_rust_frame_builder_contract.py`
24. `test_ttft_v2_flag_gated_contract.py`
25. `test_idempotency_cleanup_contract.py`
26. `test_runtime_guardrails_script_contract.py`
27. `test_runtime_guardrail_release_flow_contract.py`

## 3. Capability Alignment Matrix

| Capability Line | AgenticAI Implementation Evidence | Current Open-Source Coverage | Alignment Decision |
| --- | --- | --- | --- |
| Streaming output contract and user-surface isolation | pipeline stream events + UI message stream adapter + streaming tests | SSE contract exists; adapter-level replay/final-override details were under-specified | Synchronize SSE profile with replay header, terminal replay rule, and final-override behavior |
| Runtime boundary and failure-class transitions | `runtime_contract.py`, `step_runner.py`, runtime boundary tests | Reliability and error taxonomy docs already include runtime boundary metadata | Keep aligned; preserve deterministic transition mapping |
| Second-pass execution and sanitization | second-pass mode/timeout/trust/no-effect/error sanitization tests | Merge policy exists and timeout profile schema exists | Keep aligned; explicitly preserve signals-only body rule |
| API idempotency replay (sync + stream) | chat route idempotency reservation/replay/409 conflict tests | Mentioned only at tool-level idempotency, not API-level replay contract | Add runtime reliability contract for Idempotency-Key and replay behavior |
| Request correlation and public error envelope | request context middleware + exception handler contracts | Error/observability docs lacked explicit request_id requirement | Add `request_id` as mandatory public correlation field |
| Runtime timeline and transition diagnostics | runtime timeline metadata tests + transition projection tests | Runtime quality baseline exists but timeline/transition records were missing | Add `runtime_quality.performance.runtime_timeline` and `transition_records` baseline |
| Arbitration decision visibility | arbitration ledger projection tests + UI stream `data-arbitration` part | Pipeline docs mention mode routing, but arbitration payload structure is not explicit | Add observability baseline for `arbitration_ledger` and `arbitration_summary` |
| Runtime backpressure and timeout observability | sync executor backpressure/timeout tests + ops metrics payload | Reliability docs mention backpressure conceptually | Add explicit sync executor snapshot semantics for runtime ops visibility |
| Rust quality kernel rollout and parity governance | Rust adapter fallback/compare-mode tests + rollout source labels + parity mismatch counters | Open docs lacked rollout labels, compare denominator semantics, and fallback reason contract | Add observability/reliability contract for rollout source, fallback taxonomy, and request-level mismatch rate |
| Rust SSE frame builder rollout | Rust frame builder parity/fallback tests for `status` and `text-delta` | SSE docs had projection rules, but not engine-level parity/fallback semantics | Add SSE contract notes for byte-equivalent projection and fallback metric surface |
| TTFT v2 flag-gated latency profile | flag-gated tests for `TTFT_V2_ENABLED` and `first_meaningful_content_ms` | Existing docs did not specify forced runtime flag behavior under TTFT v2 | Add runtime reliability and observability notes for v2 effective flags and latency metric |
| Idempotency cleanup lifecycle | scheduler + cleanup contract tests (`in_progress` expiration and terminal record retention) | API idempotency replay contract existed, periodic cleanup semantics were undocumented | Add reliability contract for stale reclaim, cleanup status transition, and cleanup metrics |
| Runtime guardrail release gate | rules-driven checker tests (`blocker/high/warning/spike`) + preprod release flow tests | Existing docs lacked release gate severity model and rollout spike capture semantics | Add observability baseline for severity classes and guardrail signal mapping |
| Health and startup contract | `/api/health` payload contract + lifespan startup tests | Public docs do not pin health payload fields | Add alignment note and acceptance scenario for health response contract |
| Deterministic replay and transactional checkpoint recovery | replay safeguards exist, but full transactional replay log is not complete | Already tracked in vNext hardening roadmap | Keep as roadmap gap until transactional checkpoint/replay contract lands |

## 4. Public Contract Deltas Synchronized in This Revision

1. `SSE response contract`:
   - transport profile headers (`x-vercel-ai-ui-message-stream: v1`, `X-Idempotent-Replay`)
   - replay rule for same `Idempotency-Key`: replay authoritative terminal payload without re-running pipeline
   - final-override projection (`data-final-override`) when streamed text diverges from authoritative final text
2. `Observability/error taxonomy`:
   - `request_id` as a required correlation field for public error payloads and structured logs
   - runtime quality additions: `performance.runtime_timeline`, `performance.transition_records`
   - arbitration visibility baseline: `runtime_quality.arbitration_ledger`, `runtime_quality.arbitration_summary`
3. `Runtime reliability`:
   - API-level idempotency contract for sync/stream endpoints
   - conflict semantics: same key + different hash -> `409`, in-progress key -> `409`
   - deleted session semantics: `404` for missing, `410` for deleted session lifecycle state
4. `Runtime ops visibility`:
   - sync executor snapshot fields (`inflight`, `max_inflight`, timeout/backpressure counters)
   - `/api/ops/runtime-metrics` payload baseline (`settings_fingerprint`, `settings_reload_count`)
5. `Rust rollout governance`:
   - quality kernel rollout source contract (`staging_replay`, `prod_mirror`, `unknown`)
   - compare-mode request denominator contract (`quality_kernel_compare_requests_total` and mismatch counters)
   - fallback reason taxonomy for quality kernel / UI stream frame builder (`disabled`, `import_error`, `runtime_error`, etc.)
6. `Idempotency cleanup lifecycle`:
   - periodic scheduler with single-host lock
   - stale `in_progress` records transition to `expired`
   - stale terminal records are deleted by retention policy
7. `TTFT v2 runtime profile`:
   - when `TTFT_V2_ENABLED=true`, stream-first/chunked/early-flush and early-preview effective flags are forced on
   - runtime quality performance includes `first_meaningful_content_ms` as an explicit latency metric
8. `Runtime guardrail release gate`:
   - severity classes `blocker | high | warning | spike`
   - rollout quality/SSE fallback-rate checks are enforced only with minimum coverage

## 5. Boundary and Publication Rules

When synchronizing implementation behavior into open-research docs:

1. publish only control-plane behavior and public contracts
2. avoid private prompt content, secret material, and private infrastructure details
3. represent implementation behavior as deterministic, testable rules
4. maintain compatibility statements when contract fields are extended

## 6. Acceptance Scenarios

1. Streaming whitelist and ordering:
   - Input: mixed source/phase stream chunks (`answer`, `quote`, `audit_delta`, `final_delta`)
   - Expected: only allowlisted user-surface content is emitted
2. Stream idempotent replay:
   - Input: same `Idempotency-Key` and same request hash for `/api/chat/stream`
   - Expected: replay response is terminal-only, with `X-Idempotent-Replay: true`
3. Sync idempotent replay:
   - Input: same `Idempotency-Key` and same request hash for `/api/chat`
   - Expected: payload returns cached result with `idempotency_replay=true`
4. Idempotency conflict:
   - Input: same `Idempotency-Key` but different request hash
   - Expected: `409` conflict and no duplicate pipeline execution
5. Request correlation:
   - Input: request with and without valid `X-Request-ID`
   - Expected: response always includes `X-Request-ID`; invalid/oversized IDs are regenerated
6. Deleted session access:
   - Input: deleted session on chat/messages/rollback APIs
   - Expected: `410` with `SESSION_GONE`
7. Runtime quality timeline:
   - Input: run with timeline/transition recording enabled
   - Expected: final metadata contains `runtime_quality.performance.runtime_timeline` and `transition_records`
8. Arbitration projection:
   - Input: mode conflict case that triggers arbitration
   - Expected: final metadata and UI stream both contain arbitration decision payload
9. Health endpoint contract:
   - Input: `GET /api/health`
   - Expected: stable payload fields (`service_id`, `service_name`, `api_version`, `time`)
10. Rust quality kernel compare mode:
   - Input: rollout enabled + compare mode sampled request
   - Expected: primary response contract is preserved; mismatch counters update only in observability path
11. Rust SSE frame builder runtime fallback:
   - Input: rust frame encoder throws runtime exception
   - Expected: stream protocol remains valid and fallback counters increment
12. Idempotency cleanup sweep:
   - Input: stale `in_progress` + stale `completed` records beyond retention
   - Expected: `in_progress` -> `expired`; stale terminal rows removed
13. TTFT v2 flag-gated run:
   - Input: `TTFT_V2_ENABLED=true`
   - Expected: effective runtime flags force v2 path; `first_meaningful_content_ms` is populated
14. Runtime guardrail high severity:
   - Input: `quality_fallback_rate[prod_mirror]` exceeds threshold with sufficient coverage
   - Expected: guardrail report includes `high` issue and blocks release flow

## 7. Follow-up Work Items

`P0`:

1. add a dedicated request-context and public-error envelope supplement
2. add a runtime-ops metrics supplement for guardrail release flow
3. add idempotency replay payload schema example in `examples/contracts`
4. add a rollout metrics supplement for quality kernel and SSE frame builder migration gates

`P1`:

1. publish a standalone UI message stream mapping supplement (`part` type matrix)
2. extend artifact lifecycle spec with replay payload visibility constraints

`Roadmap`:

1. transactional checkpointing
2. deterministic replay log contract
3. multi-tenant scheduler fairness proofs under stress

## 8. Cross References

- [SSE Response Contract](./sse-response-contract.md)
- [Error Taxonomy and Observability](./error-taxonomy-observability.md)
- [Runtime Reliability Mechanisms](./runtime-reliability-mechanisms.md)
- [Second-Pass Audit Merge Policy](./second-pass-audit-merge-policy.md)
- [Memory Architecture](./memory-architecture.md)
- [State Machine Transition Matrix](./state-machine-transition-matrix.md)
- [Runtime vNext Iteration Plan and Primary Design Goals](./runtime-vnext-iteration-plan.md)
