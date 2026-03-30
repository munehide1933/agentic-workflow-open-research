# Runtime Reliability Mechanisms

## 1. Scope

This specification defines production reliability mechanisms for the runtime control plane.
It covers deterministic orchestration, checkpointing, replay safety, workload governance, and SLA-oriented failure handling.

Out of scope:

- private on-call alert routing and escalation policy details
- private infrastructure autoscaling internals
- vendor-specific deployment topology

## 2. Problem Statement

A runtime that only "works once" is not production-grade.
Common failure modes:

- crash recovery re-executes model calls and changes output
- retries violate deterministic contracts
- queue pressure causes cascading timeouts
- multi-tenant traffic causes unfair resource starvation

## 3. Contract / Data Model

### 3.1 Deterministic Orchestration Records

| Field | Type | Meaning |
| --- | --- | --- |
| `state_version` | string | state schema version |
| `state_hash` | string | hash of serialized state |
| `step_id` | string | deterministic pipeline step identifier |
| `transition_event` | string | state-machine transition event |
| `checkpoint_id` | string | immutable checkpoint artifact ID |
| `replay_safe` | boolean | replay consistency guarantee flag |

### 3.2 Runtime Final Metadata Field Set

| Field | Type | Meaning |
| --- | --- | --- |
| `runtime_boundary` | object | boundary contract snapshot for the run |
| `failure_event` | object | canonical failure classification payload |
| `output_contract` | object | final output consistency metadata |
| `second_pass.timeout_profile` | object | resolved timeout profile for second-pass behavior |
| `runtime_quality.stage_snapshots` | array | per-stage model/token/latency snapshot |
| `runtime_quality.invariant_gate` | object | merge guard result (`passed`, `reason_codes`, `metrics`, `fallback`) |
| `runtime_quality.degradation_flags` | array | run-level degradation markers |
| `runtime_quality.performance.general_latency_flags_effective.ttft_v2_enabled` | boolean | effective TTFT v2 profile flag |
| `runtime_quality.performance.first_meaningful_content_ms` | integer | first non-preview meaningful output latency |

### 3.3 Failure Event Contract

| Field | Type | Meaning |
| --- | --- | --- |
| `failure_type` | string | retryable/model/audit/guard/tool/policy/systemic |
| `stage_id` | string | stage where failure occurred |
| `transition_to` | string | deterministic next state |
| `retryable` | boolean | retry eligibility |
| `degradation_path` | string | selected degrade path key |

### 3.4 Artifact and Evidence Chain Contract

Artifact/evidence lineage is tracked with immutable version-chain fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `logical_key` | string | logical artifact identity across versions |
| `version_no` | integer | monotonically increasing artifact version |
| `parent_artifact_id` | string or null | parent version pointer |
| `sha1` | string | immutable content digest |
| `trace_id` | string | trace binding for audit replay |
| `message_id` | string | required when artifact visibility is user-facing |

### 3.5 Request-Scoped Partial Replay Contract

Current runtime behavior uses request-scoped replay for selected steps:

- target steps default: `synthesis_draft`, `synthesis_merge`
- each target step has bounded replay attempts
- replay journal is metadata-only and not used as behavior input

Closed replay reason-code enum:

- `timeout`
- `token_overflow`
- `context_length`
- `transient_failure`
- `not_in_target_scope`
- `max_attempts_exceeded`
- `unsupported_executor`

Snapshot apply rule:

- authoritative keys may overwrite state
- advisory keys are limited to warning/error/degrade diagnostics
- non-owned keys (for example `query`) must never be overwritten by replay snapshot

### 3.6 API Idempotency and Session Lifecycle Contract

Public reliability contract at API boundary:

| Field | Type | Meaning |
| --- | --- | --- |
| `Idempotency-Key` | string | client-provided deduplication key for `/api/chat` and `/api/chat/stream` |
| `request_hash` | string | deterministic hash of endpoint + normalized request payload |
| `idempotency_replay` | boolean | sync replay flag in response payload |
| `X-Idempotent-Replay` | string | stream replay response header (`true` when replayed) |
| `idempotency_status` | enum | `in_progress | completed | failed | expired` |
| `response_payload` | object | cached authoritative terminal payload used for replay |

Deterministic conflict rules:

1. same key + same hash + completed -> replay cached payload
2. same key + same hash + in-progress -> `409`
3. same key + different hash -> `409`

Session lifecycle visibility rules:

1. session not found -> `404` (`SESSION_NOT_FOUND`)
2. session deleted/gone -> `410` (`SESSION_GONE`)

### 3.7 Idempotency Cleanup Scheduler Contract

Periodic idempotency cleanup runs in application lifecycle and enforces stale-record hygiene.

Contract behavior:

1. scheduler runs only when `IDEMPOTENCY_CLEANUP_ENABLED=true`.
2. each cleanup cycle uses single-host lock semantics.
3. stale `in_progress` records transition to `expired` by endpoint-specific TTL:
   - sync endpoints use `IDEMPOTENCY_SYNC_IN_PROGRESS_TTL_SECONDS`
   - stream endpoints use `IDEMPOTENCY_STREAM_IN_PROGRESS_TTL_SECONDS`
4. terminal records are deleted when retention exceeds `IDEMPOTENCY_RETENTION_DAYS`.
5. cleanup counters are monotonic:
   - `idempotency_cleanup_run_total`
   - `idempotency_cleanup_expired_total`
   - `idempotency_cleanup_deleted_total`
   - `idempotency_cleanup_lock_skip_total`
   - `idempotency_cleanup_error_total`

### 3.8 Runtime Guardrail Release-Gate Contract

Release gate consumes runtime snapshot + optional baseline snapshot and reports severity classes:

- `blocker`: immediate stop
- `high`: release-blocking regression
- `warning`: non-blocking regression
- `spike_alerts`: acute baseline drift alerts

Key enforcement points:

1. quality fallback rate and compare mismatch rate are evaluated by rollout source (default includes `prod_mirror`).
2. SSE fallback high severity is enforced only when coverage is above minimum threshold.
3. idempotency payload corruption and raw error leaks are blocker-class conditions.
4. sync executor full-timeout triplet (`utilization`, `timeout_count`, `still_running_ratio`) is blocker-class.
5. release gate output must include computed `signals` payload for auditability.

## 4. Decision Logic

```python
def worker_loop(queue, scheduler, checkpoint_store):
    while True:
        if scheduler.backpressure_active():
            queue.defer_low_priority()

        task = queue.pop_next()
        if not task:
            continue

        quota = scheduler.reserve(task.tenant_id, task.workflow_id)
        if not quota.granted:
            queue.requeue(task, reason="quota_exceeded")
            continue

        state = checkpoint_store.load_or_init(task.run_id)
        result = run_state_machine_step(task, state)
        checkpoint_store.commit(task.run_id, result.checkpoint)

        if result.failure_event:
            apply_failure_transition(task.run_id, result.failure_event)


def replay_run(run_id, checkpoint_store):
    checkpoints = checkpoint_store.load_all(run_id)
    return deterministic_replay(checkpoints)
```

## 5. Failure and Degradation

1. `retryable_failure` -> bounded retry with exponential backoff and same trace.
2. `model_uncertainty_failure` -> fallback model or bounded template output.
3. `audit_rejection_failure` -> preserve draft and annotate uncertainty.
4. `guard_violation_failure` -> safe recovery branch with executable output blocked.
5. `tool_failure` -> deterministic degrade path (`mock` or `skip`).
6. `policy_failure` -> hard block with public policy error.
7. `systemic_failure` -> shed load and return SLA-safe degraded response.

Runtime workload controls:

- queue priority with tenant quotas
- concurrency caps per tenant and per workflow
- runtime backpressure triggered by latency and queue depth
- resource scheduling by token, memory, and execution slot budgets
- sync executor snapshot exposes backpressure/timeout counters for runtime guardrail release checks
- release flow consumes guardrail severity output (`blocker/high/warning/spike_alerts`) before promotion

## 6. Acceptance Scenarios

1. Worker crash after checkpoint commit:
   - Expected: run resumes from last committed checkpoint with no model re-call.
2. Same input replayed after recovery:
   - Expected: identical final output and state hash chain.
3. Queue depth crosses backpressure threshold:
   - Expected: low-priority tasks deferred; high-priority SLA preserved.
4. Tenant exceeds token quota:
   - Expected: task requeued or rejected by quota policy.
5. Second-pass timeout profile resolves to cap:
   - Expected: `resolved_seconds == max_seconds` in metadata.
6. Tool failure at required stage:
   - Expected: deterministic failure transition and configured degradation.
7. Audit rejection in second pass:
   - Expected: draft retained, challenge not leaked into body stream.
8. Negative case, checkpoint missing for replay:
   - Expected: replay refused with explicit integrity error.
9. Replay input fingerprint differs only by observability noise:
   - Expected: fingerprint remains stable.
10. Replay is marked unsupported:
   - Expected: replay metadata returns zero-state counters and empty journal.
11. Replay snapshot includes non-owned keys:
   - Expected: non-owned keys are ignored during apply.
12. Sync idempotent replay with same key/hash:
   - Expected: cached payload returned and `idempotency_replay=true`.
13. Stream idempotent replay with same key/hash:
   - Expected: terminal replay returned with `X-Idempotent-Replay: true`.
14. Idempotency key conflict with different payload hash:
   - Expected: `409` conflict without duplicate pipeline execution.
15. Deleted session API access:
   - Expected: request fails with `410` and `SESSION_GONE`.
16. Periodic idempotency cleanup:
   - Expected: stale `in_progress` records become `expired`; stale terminal records are deleted by retention.
17. TTFT v2 flag-gated profile:
   - Expected: effective stream latency flags are forced on and `first_meaningful_content_ms` is recorded.
18. Runtime guardrail coverage-aware SSE gate:
   - Expected: low coverage suppresses SSE fallback `high` and emits warning instead.

## 7. Compatibility and Versioning

- Checkpoint record additions are minor-compatible when optional.
- State serialization format changes require explicit version bump.
- Failure type renaming is a major compatibility break.
- Metadata field additions are backward compatible; removals require major revision.

## 8. Cross References

- [Runtime Capability Map](./runtime-capability-map.md)
- [Execution Safety Envelope Runtime](./execution-safety-envelope-runtime.md)
- [Error Taxonomy and Observability](./error-taxonomy-observability.md)
- [Second-Pass Audit Merge Policy](./second-pass-audit-merge-policy.md)
- [Runtime Boundary Schema v1](../../examples/contracts/runtime-boundary.schema.v1.json)
- [Artifact Lifecycle Schema v1](../../examples/contracts/artifact-lifecycle.schema.v1.json)
- [Second-Pass Timeout Profile Schema v1](../../examples/contracts/second-pass-timeout-profile.schema.v1.json)
