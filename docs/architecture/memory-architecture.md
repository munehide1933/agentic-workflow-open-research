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

## 4. Cross-Session Retrieval

Default retrieval settings:

- `top_k = 8`
- relevance threshold `min_score = 0.72`

Retrieval behavior:

1. below-threshold items are excluded
2. retrieved memories are cited as external context, not facts
3. low-confidence retrieval should increase `required_fields`

## 5. Rollback Semantics

Rollback granularity: run-level.

Rollback triggers:

- terminal schema violation
- terminal policy violation
- unrecoverable finalize failure

Rollback behavior:

1. restore last committed run snapshot
2. keep immutable trace record of rollback reason
3. never rewrite historical completed run payloads

## 6. Acceptance Scenarios

1. TTL expiration evicts run data predictably.
2. finalize success writes to long-term memory.
3. hard fail skips long-term write.
4. rollback trigger restores previous committed run state.
