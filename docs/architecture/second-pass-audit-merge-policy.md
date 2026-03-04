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

Compatibility rule:

1. If `audit_completeness` is absent (v1), infer as:
2. `full` when all required keys parse and at least one challenge field is populated.
3. `partial` when parseable but challenge content is weak.
4. `invalid` when schema validation fails.

## 4. `is_valid_audit()` Decision

`is_valid_audit()` returns true only if all checks pass:

1. Schema validity check.
2. Non-echo check.
3. Challenge quality check.

### 4.1 Non-echo Check

Default open thresholds (replaceable in private deployments):

- lexical overlap ratio `< 0.85`
- semantic similarity `< 0.92`

If both thresholds fail, audit is treated as echo and merge is rejected.

### 4.2 Challenge Quality Check

Audit challenge quality is valid when one or more of the following is true:

1. `missing_evidence` contains actionable missing observations.
2. `unsafe_recommendations` identifies concrete risky behavior.
3. `structure_inconsistencies` points to diagnosis-draft mismatch.
4. `counter_hypotheses` adds non-duplicate alternatives.

## 5. Merge Actions

### 5.1 `audit_completeness=full`

- Apply challenge-guided edits.
- Keep diagnosis invariants unchanged.
- Allow conclusion revision when evidence supports it.

### 5.2 `audit_completeness=partial`

Partial salvage is allowed for:

- `missing_evidence`
- `unsafe_recommendations`
- `structure_inconsistencies`

Partial salvage is NOT allowed to:

- promote certainty of primary root cause
- upgrade confidence rank without new evidence

### 5.3 `audit_completeness=invalid`

- Reject audit merge.
- Trigger safe degrade path (`invalid_or_partial_audit`).

## 6. Safe Degrade Behavior

When merge is rejected:

1. preserve useful draft content
2. append uncertainty and verification steps
3. avoid introducing new executable high-risk instructions

## 7. Reference Pseudocode

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

## 8. Acceptance Scenarios

1. Full + non-echo + high quality => merge accepted.
2. Full + echo => rejected.
3. Partial + non-echo => partial salvage only.
4. Invalid schema => safe degrade.
