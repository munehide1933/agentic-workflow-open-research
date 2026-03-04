# State Machine Transition Matrix

## 1. State Set

- `S0_INPUT_NORMALIZED`
- `S1_UNDERSTANDING_READY`
- `S2_DIAGNOSIS_READY`
- `S3_DRAFT_READY`
- `S4_AUDIT_READY`
- `S5_FINAL_READY`
- `S6_RENDERED`
- `S_FAIL_RETRYABLE`
- `S_FAIL_TERMINAL`

## 2. Concurrency Rule

Single-flight per session is mandatory.
If another run is active in the same session, reject with `E_CONCURRENCY_CONFLICT`.

## 3. Second-Pass Eligibility Definition

`second_pass_eligible=true` when any condition holds:

1. `risk_level=high`
2. `intent_type in {diagnosis, codegen, ops}`
3. `requires_executable=true`

`second_pass_eligible=false` by default for low-risk `qa` and `architecture` requests with no executable output.

## 4. Transition Matrix

| From | To | Guard | Notes |
|---|---|---|---|
| `S0_INPUT_NORMALIZED` | `S1_UNDERSTANDING_READY` | input parsed and normalized | start of control flow |
| `S1_UNDERSTANDING_READY` | `S2_DIAGNOSIS_READY` | diagnosis required and observability minimum met | skip to draft path if not required |
| `S1_UNDERSTANDING_READY` | `S3_DRAFT_READY` | direct-answer path selected | no diagnosis branch |
| `S2_DIAGNOSIS_READY` | `S3_DRAFT_READY` | diagnosis schema valid | draft synthesis allowed |
| `S3_DRAFT_READY` | `S4_AUDIT_READY` | `second_pass_eligible=true` | deterministic eligibility guard matched |
| `S3_DRAFT_READY` | `S5_FINAL_READY` | `second_pass_eligible=false` | direct finalize path |
| `S4_AUDIT_READY` | `S5_FINAL_READY` | audit valid (or partial salvage allowed) | merge policy applied |
| `S5_FINAL_READY` | `S6_RENDERED` | output contract valid | render complete |
| `S6_RENDERED` | `S0_INPUT_NORMALIZED` | same session re-entry with new user input | session continuation |
| `ANY_NON_TERMINAL` | `S_FAIL_RETRYABLE` | timeout or transient upstream failure | safe degrade + retry possible |
| `ANY_NON_TERMINAL` | `S_FAIL_TERMINAL` | schema violation, policy hard block, unrecoverable error | stop run |

## 5. Forbidden Transitions (Examples)

1. `S0 -> S3` without understanding stage.
2. `S2 -> S5` bypassing draft generation.
3. `S6 -> S4` direct re-entry into audit stage.
4. Any transition out of `S_FAIL_TERMINAL` within same run.

## 6. Fail Classification

- `S_FAIL_RETRYABLE`: retryable by policy; response must expose bounded uncertainty.
- `S_FAIL_TERMINAL`: non-recoverable in current run; requires new run.

## 7. Acceptance Scenarios

1. Every legal edge has one positive test case.
2. Every forbidden edge has one negative test case.
3. Same-session concurrent run is rejected with `E_CONCURRENCY_CONFLICT`.
4. `S6 -> S0` re-entry works for next user turn.
5. `S3 -> S4` is reproducible from explicit eligibility rules.
