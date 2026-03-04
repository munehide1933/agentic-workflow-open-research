# Memory Architecture Specification

## 1. Scope

This specification defines the public memory behavior for:

- SQLite short-term memory
- optional Qdrant long-term memory

## 2. Short-Term Memory (SQLite)

Primary responsibilities:

1. session continuity
2. run-level state snapshots
3. rollback support

Default public retention:

- `session_ttl_days = 30`
- `run_ttl_days = 14`

Eviction rules:

1. Daily sweep removes expired runs first.
2. Session is evicted when no active runs remain and TTL is exceeded.
3. Eviction must be logged with `trace_id/run_id/session_id` when available.

## 3. Long-Term Memory (Qdrant, Optional)

Write timing policy:

1. write only at finalize stage
2. skip write when output is `hard_fail`
3. skip write when policy marks response as sensitive

## 4. Retrieval Trigger and Pipeline Injection

Retrieval is evaluated after `S1_UNDERSTANDING_READY` and before diagnosis build (`S2_DIAGNOSIS_READY`).

Pipeline contract:

1. `retrieve_cross_session_memory()` runs only when retrieval is enabled and query intent is not explicitly memory-isolated.
2. Hits are filtered by `min_score` and stored in `state.memory_context[]`.
3. `build_diagnosis_structure()` receives `memory_context` as external context input.

`memory_context` item fields (public minimum):

- `memory_id`
- `score`
- `snippet`
- `source_session_id`

## 5. Cross-Session Retrieval Semantics

Default retrieval settings:

- `top_k = 8`
- relevance threshold `min_score = 0.72`

Behavior rules:

1. below-threshold items are excluded.
2. retrieved memory is context, not standalone fact.
3. diagnosis may use memory to propose hypotheses or verification steps.
4. a memory-only claim cannot be promoted to `facts` without current-run evidence.
5. low-confidence retrieval should increase `required_fields`.

## 6. Verification-First Binding

If `diagnosis.insufficient_evidence=true`, draft generation MUST follow verification-first constraints:

1. include explicit uncertainty statement.
2. include bounded claims and disallow root-cause certainty upgrades.
3. include ordered verification checklist from observable signals.
4. include missing observations from `required_fields`.
5. block irreversible executable actions.

## 7. Rollback Semantics

Rollback granularity: run-level.

Rollback triggers:

- terminal schema violation
- terminal policy violation
- unrecoverable finalize failure

Rollback behavior:

1. restore last committed run snapshot
2. keep immutable trace record of rollback reason
3. never rewrite historical completed run payloads

## 8. Acceptance Scenarios

1. TTL expiration evicts run data predictably.
2. finalize success writes to long-term memory.
3. hard fail skips long-term write.
4. retrieval hits are injected before diagnosis.
5. memory-only claims do not enter facts without corroboration.
6. insufficient evidence path emits verification-first constrained draft.
7. rollback trigger restores previous committed run state.
