# Action and Tools System Contract

## 1. Scope

This specification defines the public action/tools runtime contract.
It standardizes tool invocation envelopes, execution gating, isolation hooks, and failure mapping.

Out of scope:

- private tool implementation code
- provider-specific credentials and secret distribution
- non-public infrastructure plugin wiring

## 2. Problem Statement

Tool execution is the highest-risk runtime surface when contracts are weak.
Common failure modes:

- unbounded tool retries causing queue amplification
- tool side effects without idempotency keys
- unauthorized tool execution via implicit routing
- tool output leakage into user-visible answer stream

## 3. Contract / Data Model

### 3.1 Tool Invocation Contract

| Field | Type | Meaning |
| --- | --- | --- |
| `tool_name` | string | allowlisted public tool identifier |
| `call_id` | string | unique call ID for tracing |
| `idempotency_key` | string | deterministic key for replay and dedup |
| `input_schema_version` | string | versioned input contract key |
| `timeout_ms` | integer | execution timeout budget |
| `max_retries` | integer | bounded retry count |
| `sandbox_profile` | string | execution isolation profile reference |
| `output_channel` | string | `internal | artifact` |

### 3.2 Tool Result Contract

| Field | Type | Meaning |
| --- | --- | --- |
| `call_id` | string | matches request call ID |
| `status` | string | `ok | timeout | rejected | failed` |
| `error_class` | string | failure class when not `ok` |
| `artifact_ref` | string | artifact ID for tool output |
| `latency_ms` | integer | observed tool latency |
| `replay_source` | string | `live | checkpoint` |

## 4. Decision Logic

```python
def execute_tool_call(request, boundary, quotas, checkpoint_store):
    if request.tool_name not in boundary.allowlisted_tools:
        return reject_tool_call(request, "guard_violation_failure")

    if quotas.tool_calls_used >= boundary.budget.tool_call_budget:
        return reject_tool_call(request, "systemic_failure")

    cached = checkpoint_store.lookup_tool_result(request.idempotency_key)
    if cached is not None:
        return cached.with_replay_source("checkpoint")

    result = run_in_sandbox(request)
    checkpoint_store.save_tool_result(request.idempotency_key, result)
    return result.with_replay_source("live")
```

## 5. Failure and Degradation

1. allowlist violation -> `guard_violation_failure`, immediate reject.
2. timeout with remaining retry budget -> `retryable_failure`, retry same tool.
3. timeout without retry budget -> degrade to `tool_skipped` artifact.
4. non-idempotent call attempt without key -> `policy_failure`, block execution.
5. unknown tool runtime exception -> `tool_failure`, emit sanitized error artifact.

Degrade order:

1. replay-safe cached result
2. deterministic fallback tool
3. bounded partial output without tool data

## 6. Acceptance Scenarios

1. Allowlisted tool call with valid schema:
   - Expected: executes once and persists result artifact.
2. Replay run with same idempotency key:
   - Expected: result served from checkpoint, no live tool call.
3. Tool timeout with retries remaining:
   - Expected: classified `retryable_failure`, retried within budget.
4. Tool timeout with retry budget exhausted:
   - Expected: fallback to `tool_skipped` degrade path.
5. Disallowed tool requested by model output:
   - Expected: blocked as `guard_violation_failure`.
6. Tool output marked `internal`:
   - Expected: hidden from user body stream.
7. Negative case, missing idempotency key:
   - Expected: blocked as `policy_failure`.

## 7. Compatibility and Versioning

- Tool names are stable public IDs in each major line.
- New optional result fields are minor-compatible.
- Changing idempotency semantics is a major contract change.
- Input schema version upgrades require migration notes in tool docs.

## 8. Cross References

- [Runtime Capability Map](./runtime-capability-map.md)
- [Execution Safety Envelope Runtime](./execution-safety-envelope-runtime.md)
- [Agent Pipeline Contract Profile](./agent-pipeline-contract-profile.md)
- [Runtime Reliability Mechanisms](./runtime-reliability-mechanisms.md)
