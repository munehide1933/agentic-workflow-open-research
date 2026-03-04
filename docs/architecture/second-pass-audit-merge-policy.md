# Second-Pass Audit Merge Policy

## 1. Scope

This document defines the normative merge policy between draft output and second-pass audit output.

## 2. Inputs

- `draft`: first-pass response candidate
- `diagnosis`: diagnosis structure (`facts`, `hypotheses`, `excluded_hypotheses`, `insufficient_evidence`, `required_fields`)
- `audit`: second-pass object (v1 or v2)

## 3. Audit Contract Versions

- v1: [`examples/contracts/second-pass-audit.schema.json`](../../examples/contracts/second-pass-audit.schema.json)
- v2: [`examples/contracts/second-pass-audit.schema.v2.json`](../../examples/contracts/second-pass-audit.schema.v2.json)

### 3.1 Historical Constraint in v1

In v1 schema, `counter_hypotheses.minItems = 1` is a historical compatibility constraint.
This makes v1 unable to represent a partial audit with an empty `counter_hypotheses` list.

### 3.2 Producer/Consumer Compatibility (Effective March 4, 2026)

1. Producers SHOULD emit v2 by default.
2. v1 remains read-compatible for existing producers.
3. If partial audit needs empty `counter_hypotheses`, payload MUST use v2.
4. v1 payload with empty `counter_hypotheses` fails schema and is treated as `invalid`.

## 4. Completeness Inference

If `audit_completeness` is absent (v1), infer from content quality:

1. `full`: schema-valid audit with substantive challenge signals.
2. `partial`: schema-valid audit with weak but usable challenge signals.
3. `invalid`: schema validation failure.

## 5. `is_valid_audit()` Decision

`is_valid_audit()` returns true only if all checks pass:

1. Schema validity check.
2. Non-echo check.
3. Challenge quality check.

### 5.1 Non-echo Check

Default open thresholds (replaceable in private deployments):

- lexical overlap ratio `< 0.85`
- semantic similarity `< 0.92`

If both thresholds fail, audit is treated as echo and merge is rejected.

### 5.2 Challenge Quality Check

Audit challenge quality is valid when one or more of the following is true:

1. `missing_evidence` contains actionable missing observations.
2. `unsafe_recommendations` identifies concrete risky behavior.
3. `structure_inconsistencies` points to diagnosis-draft mismatch.
4. `counter_hypotheses` adds non-duplicate alternatives.

## 6. Merge Actions

### 6.1 `audit_completeness=full`

- Apply challenge-guided edits.
- Keep diagnosis invariants unchanged.
- Allow conclusion revision when evidence supports it.

### 6.2 `audit_completeness=partial`

Partial salvage is allowed for:

- `missing_evidence`
- `unsafe_recommendations`
- `structure_inconsistencies`

Partial salvage is NOT allowed to:

- promote certainty of primary root cause
- upgrade confidence rank without new evidence

### 6.3 `audit_completeness=invalid`

- Reject audit merge.
- Trigger safe degrade path (`invalid_or_partial_audit`).

## 7. Safe Degrade Behavior

When merge is rejected:

1. preserve useful draft content
2. append uncertainty and verification steps
3. avoid introducing new executable high-risk instructions

## 8. Reference Pseudocode

```python
def resolve_second_pass(draft, diagnosis, audit):
    completeness = get_audit_completeness(audit)

    if not schema_valid(audit):
        return safe_degrade(draft, "invalid_audit_schema")
    if is_echo(audit, draft):
        return safe_degrade(draft, "echo_audit")
    if not has_minimum_challenge_quality(audit):
        return safe_degrade(draft, "weak_audit")

    if completeness == "full":
        return merge_draft_with_audit(draft, audit, diagnosis)
    if completeness == "partial":
        return merge_partial_salvage(draft, audit, diagnosis)
    return safe_degrade(draft, "invalid_or_partial_audit")
```

## 9. Acceptance Scenarios

1. Full + non-echo + high quality => merge accepted.
2. Full + echo => rejected.
3. Partial + non-echo => partial salvage only.
4. Invalid schema => safe degrade.
5. v1 with empty `counter_hypotheses` => invalid.
6. Partial audit without counter hypothesis => must use v2.
