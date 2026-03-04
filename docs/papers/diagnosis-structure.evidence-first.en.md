# Diagnosis Structure: An Evidence-First Reasoning Paradigm for High-Reliability Agents

## Abstract

Complex engineering troubleshooting requires more than fluent language generation.
In production settings, a useful agent must produce testable reasoning artifacts, not persuasive narratives.
This paper describes a practical diagnosis pattern built around four explicit fields:
`facts`, `hypotheses`, `excluded_hypotheses`, and `insufficient_evidence`.
Combined with second-pass audit and state-machine orchestration, this pattern improves controllability and auditability while avoiding overconfident recommendations.

## 1. Introduction: Why Chain-of-Thought Alone Breaks in Engineering Diagnosis

Chain-of-thought style outputs often fail under operational pressure because:

- evidence and inference are mixed in one narrative
- missing evidence is hidden by confident language
- alternative causes are not explicitly tracked
- failure handling is implicit and non-reproducible

In enterprise incidents, this is not a stylistic problem.
It is an operational risk problem.

## 2. Paradigm Shift: From Conversation Generation to State-Machine Diagnosis

The key shift is architectural.
Instead of treating the model as a free-form answer generator, we treat it as a stage in a constrained diagnosis workflow:

```text
Input -> Signal Detection -> Diagnosis Structure -> Draft -> Second-Pass Audit -> Finalize
```

Each stage has a contract and a fallback policy.
If a contract is not satisfied, the workflow degrades safely rather than fabricating certainty.

## 3. Core Architecture

### 3.1 Evidence-First Principle

`facts` must be established before `hypotheses`.
A hypothesis without anchorable observations is not promoted as a primary conclusion.

### 3.2 The Quad-Structure

#### `facts`

- observable statements
- linked to evidence spans or evidence keys
- include source attribution (`log`, `user_text`, `system_state`)

#### `hypotheses`

- causal candidates
- confidence label (`low/medium/high`)
- executable test steps
- ranking for downstream synthesis

#### `excluded_hypotheses`

- alternatives intentionally ruled out
- prevents silent disappearance of possible causes

#### `insufficient_evidence`

- hard uncertainty flag
- forces bounded output mode
- blocks definitive root-cause claims

This structure forms a closed reasoning loop rather than a one-pass narrative.

## 4. Second-Pass Audit as Independent Critic

After draft synthesis, an independent pass evaluates logical robustness using structured outputs:

- `counter_hypotheses`
- `missing_evidence`
- `unsafe_recommendations`
- `structure_inconsistencies`

Merge is conditional:

- valid shape
- non-echo challenge quality
- policy-safe content

If these checks fail, the system chooses safe degrade or partial salvage.

## 5. Implementation Pattern Without Exposing Core Source

A practical implementation can remain private while still publishing the engineering pattern:

1. publish JSON schema contracts for diagnosis and audit
2. publish state transitions and guard conditions
3. publish pseudocode merge policy
4. keep private prompt internals and threshold tuning confidential

This allows open technical review without leaking commercialization-sensitive internals.

## 6. Flow Diagram

See [Diagnosis Structure Flow](../diagrams/diagnosis-structure-flow.md) for the full `facts -> hypotheses -> second_pass_audit` data path.

## 7. Enterprise Discussion: Why Uncontrolled Conversation Is Operationally Useless

In enterprise contexts, unconstrained dialogue tends to create:

- non-reproducible recommendations
- weak postmortem traceability
- accidental unsafe guidance under context gaps

From a delivery standpoint, this is low-signal output.
State-machine diagnosis is more suitable because it introduces explicit transition logic, bounded failure semantics, and measurable quality criteria.

## 8. Evaluation Guidance

Do not claim success from readability alone.
Evaluate using operational metrics such as:

1. evidence coverage in `facts`
2. novelty/quality of counter-hypotheses
3. downgrade correctness under missing evidence
4. final output consistency under stream contracts

If a numeric improvement claim is made, it should be tied to a reproducible benchmark protocol and dataset definition.

## 9. Conclusion

Diagnosis quality in enterprise agents depends less on "better prompting" and more on reasoning structure, audit discipline, and transition governance.
Evidence-First Diagnosis provides a practical way to convert model output from conversational prose into engineering-grade decision artifacts.

