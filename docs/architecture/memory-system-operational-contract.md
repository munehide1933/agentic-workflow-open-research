# Memory System Operational Contract

## 1. Scope

This specification defines runtime memory behavior as an operational contract.
It standardizes memory injection, retrieval limits, summary checkpoints, and visibility constraints.

Out of scope:

- private index topology and shard placement
- private embedding tuning and ranking internals
- infrastructure-specific storage replication details

## 2. Problem Statement

Memory behavior without a contract creates hidden nondeterminism.
Common failure modes:

- unbounded memory injection inflates prompt cost and latency
- stale memory contaminates current reasoning
- retrieval failures collapse into silent empty context
- session visibility rules are violated across tenants

## 3. Contract / Data Model

### 3.1 Memory Policy Contract

| Field | Type | Meaning |
| --- | --- | --- |
| `memory_scope` | string | `session | tenant | global` |
| `max_injected_items` | integer | max memory entries injected per step |
| `retrieval_timeout_ms` | integer | timeout budget for memory retrieval |
| `summary_checkpoint_interval` | integer | steps between summary checkpoints |
| `min_relevance_score` | number | minimum score for retrieval inclusion |
| `fallback_mode` | string | `sqlite_only | summary_only | no_memory` |
| `visibility_rule` | string | session/tenant visibility contract key |

### 3.2 Memory Event Record

| Field | Type | Meaning |
| --- | --- | --- |
| `run_id` | string | runtime execution ID |
| `step_id` | string | pipeline step ID |
| `retrieval_query` | string | normalized retrieval query |
| `retrieved_count` | integer | returned memory item count |
| `injected_keys` | array[string] | memory keys injected into prompt |
| `checkpoint_id` | string | summary checkpoint artifact ID |
| `degradation_path` | string | applied fallback path if any |

## 4. Decision Logic

```python
def resolve_memory_context(state, policy, stores):
    records = stores.primary.search(
        query=state.memory_query,
        timeout_ms=policy.retrieval_timeout_ms,
        min_score=policy.min_relevance_score,
        limit=policy.max_injected_items,
    )

    if not records:
        return {"items": [], "degradation": "summary_only"}

    visible = [r for r in records if check_visibility(r, state.session_id, state.tenant_id)]
    return {"items": visible[: policy.max_injected_items], "degradation": None}


def maybe_write_summary_checkpoint(state, policy, stores):
    if state.step_index % policy.summary_checkpoint_interval != 0:
        return None

    summary = build_summary_snapshot(state)
    checkpoint = stores.primary.write_summary(state.session_id, summary)
    return checkpoint.checkpoint_id
```

## 5. Failure and Degradation

1. primary memory backend timeout -> degrade to `summary_only`.
2. summary backend unavailable -> degrade to `no_memory` with explicit metadata.
3. visibility mismatch detected -> classify `policy_failure` and discard record.
4. retrieval overflow beyond `max_injected_items` -> deterministic truncation by rank.
5. checkpoint write failure -> keep run active with warning and retry budget.

## 6. Acceptance Scenarios

1. Session run with healthy retrieval backend:
   - Expected: top scored visible records injected.
2. Retrieval timeout on vector backend:
   - Expected: degrade to summary context only.
3. No qualified records above relevance threshold:
   - Expected: empty injection with `summary_only` marker.
4. Cross-tenant record appears in retrieval result:
   - Expected: blocked by visibility rule, not injected.
5. Checkpoint interval reached:
   - Expected: summary checkpoint artifact created.
6. Checkpoint write transient failure:
   - Expected: non-terminal warning, retry under budget.
7. Negative case, memory injection exceeds item cap:
   - Expected: deterministic truncation and metric increment.

## 7. Compatibility and Versioning

- Memory policy keys are additive-minor compatible.
- Changing `visibility_rule` semantics is a major change.
- New fallback modes require acceptance scenario updates.
- Memory event fields added as optional are backward compatible.

## 8. Cross References

- [Runtime Capability Map](./runtime-capability-map.md)
- [Agent Pipeline Contract Profile](./agent-pipeline-contract-profile.md)
- [Memory Architecture](./memory-architecture.md)
- [Runtime Reliability Mechanisms](./runtime-reliability-mechanisms.md)
