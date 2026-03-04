# State-Machine Governance for Enterprise Agents

## Thesis

In enterprise environments, uncontrolled dialogue systems are operationally unsafe.
A reliable agent must be governed by explicit states, transitions, and downgrade rules.

## State Set

- `S0_INPUT_NORMALIZED`
- `S1_UNDERSTANDING_READY`
- `S2_DIAGNOSIS_READY`
- `S3_DRAFT_READY`
- `S4_AUDIT_READY`
- `S5_FINAL_READY`
- `S6_RENDERED`
- `S_FAIL_SAFE`

## Transition Guards

- `S1 -> S2`: only if problem requires diagnosis and minimum observability exists.
- `S2 -> S3`: only if diagnosis schema is parseable.
- `S3 -> S4`: only for eligible domains or high-risk requests.
- `S4 -> S5`: only with valid audit payload.
- Any state -> `S_FAIL_SAFE`: on schema failure, timeout, missing anchors, or policy violations.

## Degradation Strategy

When confidence is unproven:

1. reduce answer specificity
2. expose missing evidence
3. prohibit executable high-risk code
4. output verification-first guidance

This is not "less intelligent."
It is deliberate reliability engineering.

