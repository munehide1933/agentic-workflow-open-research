# Beyond Prompt Engineering: Engineering High-Reliability Agents with Evidence-First Diagnosis and Anchor Guard Systems

## Abstract

Prompt quality improves answer style, but it does not create production reliability.
Enterprise agent failures usually originate from missing control-plane guarantees:
no evidence contract, no independent audit, no deterministic output guard, and no explicit degradation policy.

This paper presents an engineering pattern for high-reliability agents:

1. Evidence-First Diagnosis for structured reasoning with observable anchors.
2. Second-Pass Audit for independent challenge and controlled merge.
3. Anchor Guard to block unsafe or under-anchored code output.
4. State-machine governance for deterministic transitions and fail-safe degradation.

The core claim is practical: in enterprise settings, uncontrolled dialogue is operational noise.
State-machine-driven agent workflows are a more credible path to production.

## 1. Why Prompt-Only Systems Fail in Production

Prompt tuning improves surface quality but leaves major risks unresolved:

- no guarantee that "facts" map to observable evidence
- no systematic handling of counter-hypotheses
- no explicit mechanism to prevent unsafe code suggestions
- no bounded failure mode under partial context

These gaps create brittle behavior in incident response, architecture guidance, and code generation tasks.

## 2. Design Goals

The proposed system optimizes for:

1. **Controllability**: every major stage has explicit inputs and outputs.
2. **Auditability**: reasoning artifacts are inspectable post hoc.
3. **Safety**: risky output is blocked or downgraded if prerequisites are missing.
4. **Graceful degradation**: uncertainty is surfaced, not hidden.

## 3. Workflow Model

The agent is an orchestrated pipeline rather than an unconstrained conversation loop.

```text
Input -> Understand -> Diagnosis -> Draft -> Second-Pass Audit -> Finalize -> Render
```

Each stage emits structured state that the next stage must satisfy.
When contracts are violated, execution transitions to a safe fallback path.

## 4. Evidence-First Diagnosis

Diagnosis is encoded as structured data:

- `facts`: observable signals with evidence spans/keys
- `hypotheses`: ranked candidates with confidence and executable tests
- `excluded_hypotheses`: alternatives intentionally ruled out
- `insufficient_evidence`: explicit uncertainty flag

### 4.1 Why This Matters

This representation separates:

- observed signals (what is known),
- candidate causes (what is inferred),
- and confidence limits (what is unknown).

Without this separation, model output tends to blend evidence and speculation into a persuasive but untestable narrative.

### 4.2 Operational Rule

If `insufficient_evidence=true`, the system must not present a definitive primary root cause.
Instead, it should output bounded hypotheses and next-step validation actions.

## 5. Second-Pass Audit

The second pass is not a rewrite step.
It is an independent challenger that evaluates the draft against diagnosis artifacts.

Audit payload:

- `counter_hypotheses`
- `missing_evidence`
- `unsafe_recommendations`
- `structure_inconsistencies`

### 5.1 Merge Policy

Audit output is merged only when validity conditions are met (format validity, non-echo behavior, minimum challenge quality).
If the audit is partial or invalid, the system degrades safely rather than forcing weak corrections.

### 5.2 Reliability Benefit

This pattern reduces one-pass overcommitment and catches internal inconsistency before user-visible finalization.

## 6. Anchor Guard for Code Safety

Code responses are high-risk outputs.
The system applies an Anchor Guard before generating executable detail.

Anchors include:

- runtime
- client SDK
- (when needed) explicit HTTP client assumptions

If anchors are incomplete in diagnostic code requests, the system blocks stack-specific executable output and returns stack-agnostic guidance or pseudocode.

## 7. State-Machine Governance

The key reliability upgrade is control by state transitions.

Example transition contract:

- `UNDERSTAND_READY -> DIAGNOSIS_READY` only when diagnosis prerequisites hold.
- `DRAFT_READY -> AUDIT_READY` only for eligible/high-risk tasks.
- Any stage -> `FAIL_SAFE` on timeout, schema invalidity, or policy violation.

This makes failure behavior explainable and bounded.

## 8. Diagnosis Structure Flow

See [Diagnosis Flow Diagram](../diagrams/diagnosis-structure-flow.md).

## 9. Enterprise Implications

### 9.1 "Uncontrolled Conversation" Is a Liability

In enterprise operations, unconstrained chat behavior causes:

- non-reproducible recommendations
- unsafe action leakage
- difficult incident postmortems

From an SRE and governance perspective, that output is low-value noise.

### 9.2 Why State-Machine Agents Fit Enterprise Better

State-machine-driven agents align with enterprise requirements:

- clear accountability per stage
- explicit fallback when confidence is insufficient
- measurable quality gates
- easier compliance and audit workflows

## 10. Evaluation Framework (Recommended)

Evaluate by behavior, not prose quality:

1. **Evidence quality rate**: ratio of facts with observable anchors.
2. **Counter-hypothesis novelty**: non-echo audit challenge ratio.
3. **Unsafe output suppression**: blocked risky code under missing anchors.
4. **Degradation correctness**: valid fallback under timeout/invalid audit.
5. **Final consistency**: match between finalized answer and persisted output contract.

## 11. Limitations

- This framework does not eliminate model uncertainty; it makes uncertainty governable.
- Policy tuning still requires domain-specific calibration.
- Additional work is needed for formal verification of transition coverage.

## Conclusion

Prompt engineering is necessary but not sufficient for reliable agents.
A production-grade architecture needs explicit evidence contracts, independent audit, and deterministic safety boundaries.

The practical lesson is direct:
if your agent is not state-machine-governed, it is difficult to trust at enterprise scale.

