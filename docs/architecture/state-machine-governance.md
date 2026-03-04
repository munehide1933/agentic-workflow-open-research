# State-Machine Governance for Enterprise Agents

## Thesis

In enterprise environments, uncontrolled dialogue systems are operationally unsafe.
A reliable agent must be governed by explicit states, transitions, concurrency semantics, and fail classes.

## State Set

- `S0_INPUT_NORMALIZED`
- `S1_UNDERSTANDING_READY`
- `S2_DIAGNOSIS_READY`
- `S3_DRAFT_READY`
- `S4_AUDIT_READY`
- `S5_FINAL_READY`
- `S6_RENDERED`
- `S_FAIL_RETRYABLE`
- `S_FAIL_TERMINAL`

## Core Guards

- `S1 -> S2`: diagnosis required and minimum observability exists.
- `S2 -> S3`: diagnosis schema is parseable.
- `S3 -> S4`: `second_pass_eligible=true`.
- `S4 -> S5`: audit valid or partial salvage allowed by policy.
- `S6 -> S0`: same-session re-entry on new user input.
- Any non-terminal state -> `S_FAIL_RETRYABLE`: timeout or transient upstream failure.
- Any non-terminal state -> `S_FAIL_TERMINAL`: schema violation, policy hard block, unrecoverable failure.

`second_pass_eligible` is deterministic and defined in transition matrix rules:

- `risk_level=high`, or
- `intent_type in {diagnosis, codegen, ops}`, or
- `requires_executable=true`

## Concurrency Rule

Single-flight per session is required.
Concurrent same-session requests must fail fast with `E_CONCURRENCY_CONFLICT`.

## Degradation Strategy

When confidence is unproven:

1. reduce answer specificity
2. expose missing evidence
3. prohibit executable high-risk code
4. output verification-first guidance

## Transition Matrix

See [State Machine Transition Matrix](./state-machine-transition-matrix.md) for exhaustive legal and forbidden edges.
