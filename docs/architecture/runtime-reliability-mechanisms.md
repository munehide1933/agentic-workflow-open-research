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

- target steps default: `detailed_analysis`, `synthesis_draft`, `synthesis_merge`
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
