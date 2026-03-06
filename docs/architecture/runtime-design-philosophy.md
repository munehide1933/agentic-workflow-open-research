# Runtime Design Philosophy

## 1. Scope

This specification defines the public design philosophy used to govern runtime behavior and document decisions.
It is normative for architecture specs, contract schemas, and policy updates.
IAR adopts the `Two-Stage Contract-Driven Delivery` pattern as its default delivery discipline.

Out of scope:

- private model prompt internals
- private deployment-specific tuning constants
- implementation-specific secret handling

## 2. Problem Statement

Agent systems fail in production when they optimize for output speed before control-plane discipline.
Common failure modes:

- uncontrolled feature growth without contract boundaries
- hidden policy conflicts across subsystems
- untestable architecture claims
- fallback behavior that is implicit instead of explicit

## 3. Contract / Data Model

The philosophy contract is represented as a set of enforceable principles.

| Field | Type | Meaning |
| --- | --- | --- |
| `principle_id` | string | stable identifier (for example `P_DETERMINISM_FIRST`) |
| `statement` | string | normative principle text |
| `enforcement_layer` | string | `design | orchestration | runtime | output` |
| `observable_signal` | string | measurable runtime or document signal |
| `violation_effect` | string | required behavior on violation |
| `test_reference` | string | contract test or acceptance scenario ID |

Baseline principle set:

1. `P_CONTRACT_BEFORE_CODE`
2. `P_DETERMINISM_FIRST`
3. `P_EVIDENCE_BEFORE_ASSERTION`
4. `P_SAFETY_BEFORE_EXECUTION`
5. `P_DEGRADE_BEFORE_FAIL_OPEN`
6. `P_SINGLE_WRITER_FINAL_OUTPUT`

## 4. Decision Logic

Any new runtime behavior must pass a principle gate before publication.

```python
def evaluate_design_change(change, principles):
    violations = []
    for principle in principles:
        if not satisfies(change, principle):
            violations.append(principle.principle_id)

    if not violations:
        return {"decision": "accept", "violations": []}

    if "P_SAFETY_BEFORE_EXECUTION" in violations:
        return {
            "decision": "reject",
            "action": "block_release",
            "violations": violations,
        }

    return {
        "decision": "revise",
        "action": "add_mitigation_and_tests",
        "violations": violations,
    }
```

## 5. Failure and Degradation

If principles conflict at runtime:

1. apply stricter safety-constrained action
2. preserve deterministic output contract
3. emit structured violation metadata
4. degrade to bounded guidance instead of fail-open execution

Priority order for conflicts:

1. Safety
2. Determinism
3. Evidence integrity
4. Output quality
5. Cost optimization

## 6. Acceptance Scenarios

1. New feature without schema contract:
   - Expected: rejected by `P_CONTRACT_BEFORE_CODE`.
2. Optimization changes output with same input:
   - Expected: blocked by `P_DETERMINISM_FIRST`.
3. Draft response asserts root cause without evidence:
   - Expected: downgraded by `P_EVIDENCE_BEFORE_ASSERTION`.
4. Code generation request with missing anchor data:
   - Expected: executable output blocked by `P_SAFETY_BEFORE_EXECUTION`.
5. Second-pass failure with no trusted patch:
   - Expected: fallback to bounded summary by `P_DEGRADE_BEFORE_FAIL_OPEN`.
6. Multiple modules attempt final output overwrite:
   - Expected: first-writer result preserved by `P_SINGLE_WRITER_FINAL_OUTPUT`.

## 7. Compatibility and Versioning

- Principle IDs are stable across minor versions.
- New principles may be added as optional in minor updates.
- Removing or redefining an existing principle is a major change.
- Any principle change requires updated acceptance scenarios and cross-document references.

## 8. Cross References

- [Runtime Capability Map](./runtime-capability-map.md)
- [Agent Pipeline Contract Profile](./agent-pipeline-contract-profile.md)
- [Execution Safety Envelope Runtime](./execution-safety-envelope-runtime.md)
- [Runtime Reliability Mechanisms](./runtime-reliability-mechanisms.md)
