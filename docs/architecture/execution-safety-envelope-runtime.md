# Execution Safety Envelope Runtime

## 1. Scope

This specification defines enforceable runtime safety boundaries for executable behavior.
It standardizes allowlisted actions, sandbox isolation, budget enforcement, and deterministic guard outcomes.

Out of scope:

- private guard rule bodies and secret abuse signatures
- host-level operations outside the public runtime boundary
- internal infrastructure hardening runbooks

## 2. Problem Statement

Runtime safety fails when execution policy is advisory instead of enforceable.
Common failure modes:

- blacklisting approaches miss new attack surfaces
- step failures contaminate global process state
- token/tool/latency growth is unbounded
- loops and drift continue beyond policy limits

## 3. Contract / Data Model

### 3.1 Runtime Boundary Contract

| Field | Type | Meaning |
| --- | --- | --- |
| `boundary_id` | string | immutable boundary policy identifier |
| `boundary_version` | string | versioned runtime boundary contract |
| `sandbox_mode` | string | `process | container | microvm | isolate` |
| `isolation_scope` | string | `per_step | per_run` |
| `allowlisted_tools` | array[string] | tools allowed for this run |
| `denied_action_classes` | array[string] | explicit deny classes |
| `budget` | object | token/tool/latency/memory/output limits |
| `guard_policy_id` | string | deterministic guard policy reference |
| `termination_policy` | object | max loops and timeout termination behavior |

### 3.2 Budget Object

| Field | Type | Meaning |
| --- | --- | --- |
| `token_budget` | integer | max total tokens per run |
| `tool_call_budget` | integer | max tool calls per run |
| `latency_budget_ms` | integer | max wall clock runtime |
| `memory_quota_mb` | integer | max memory usage budget |
| `output_size_limit_bytes` | integer | max output payload size |

## 4. Decision Logic

```python
def enforce_execution_boundary(step_request, boundary, usage):
    if step_request.tool_name and step_request.tool_name not in boundary.allowlisted_tools:
        return fail("guard_violation_failure", "tool_not_allowlisted")

    if usage.tokens_used > boundary.budget.token_budget:
        return fail("systemic_failure", "token_budget_exhausted")

    if usage.tool_calls_used > boundary.budget.tool_call_budget:
        return fail("systemic_failure", "tool_call_budget_exhausted")

    if usage.latency_ms > boundary.budget.latency_budget_ms:
        return fail("retryable_failure", "latency_budget_exhausted")

    if usage.loop_count > boundary.termination_policy.max_loop_iterations:
        return fail("guard_violation_failure", "loop_limit_exceeded")

    return pass_boundary()


def execute_step_with_isolation(step_request, boundary):
    with start_sandbox(boundary.sandbox_mode, boundary.isolation_scope) as sandbox:
        return sandbox.run(step_request)
```

## 5. Failure and Degradation

1. guard violation -> transition to `safe_recovery` with no executable output.
2. budget exhaustion -> terminate branch and return bounded diagnostic artifact.
3. sandbox startup failure -> degrade to non-executable guidance output.
4. output size overflow -> truncate at policy boundary and mark `degraded=true`.
5. repeated timeout events -> open circuit for run and reject further execution.

## 6. Acceptance Scenarios

1. Allowlisted tool inside budget:
   - Expected: step executes in sandbox and continues.
2. Disallowed tool call:
   - Expected: `guard_violation_failure`, no execution.
3. Token budget exhausted before finalize:
   - Expected: `systemic_failure`, bounded response only.
4. Step enters loop beyond max iterations:
   - Expected: terminated by guard with recovery transition.
5. Sandbox crash during tool run:
   - Expected: isolated failure, global runtime state unchanged.
6. Output payload exceeds size limit:
   - Expected: deterministic truncation and degraded marker.
7. Negative case, blacklist-only policy configured:
   - Expected: rejected at boundary validation (allowlist required).

## 7. Compatibility and Versioning

- New deny classes and optional budget fields are minor-compatible.
- Changing default guard semantics is a major change.
- Budget unit changes (for example ms to s) require a new major schema version.
- Boundary version updates must be reflected in runtime metadata contracts.

## 8. Cross References

- [Runtime Capability Map](./runtime-capability-map.md)
- [Action and Tools System Contract](./action-tools-system-contract.md)
- [Error Taxonomy and Observability](./error-taxonomy-observability.md)
- [Runtime Reliability Mechanisms](./runtime-reliability-mechanisms.md)
