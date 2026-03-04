# Agentic Workflow Architecture

## Problem Statement

LLM quality alone is insufficient for enterprise reliability.
A production agent needs explicit control over:

- evidence quality
- output safety
- error recovery
- response determinism

## Control Plane

The workflow is modeled as a state machine, not as unconstrained chat generation.

Core stages:

1. Understand: classify intent, domain, and execution scope.
2. Retrieve Memory (sidecar): fetch cross-session context after understanding, before diagnosis.
3. Diagnose: build structured evidence and ranked hypotheses.
4. Draft: generate a candidate response under explicit mode constraints.
5. Second Pass: independently challenge the draft.
6. Finalize: merge only validated audit signals.
7. Render: output under strict response contracts.

## Reliability Primitives

- Evidence-First Diagnosis:
  - facts must point to observable evidence
  - hypotheses must carry executable tests
  - insufficient evidence explicitly disables overconfident conclusions
- Second-Pass Audit:
  - draft is challenged by an independent pass
  - merge is conditional, not blind overwrite
- Anchor Guard:
  - code output is blocked or downgraded when runtime anchors are incomplete
- Degradation Policy:
  - if strict quality cannot be proven, output safe fallback

## Memory Injection Contract

Memory retrieval is a contextual assist, not a fact source.

Rules:

1. retrieval happens between understanding and diagnosis.
2. retrieved entries are passed as `memory_context` into diagnosis builder.
3. memory-only statements cannot be promoted to diagnosis facts without current-run corroboration.
4. low-confidence memory retrieval increases `required_fields` rather than certainty.

## Verification-First Draft Contract

When `insufficient_evidence=true`, draft output must be constrained.

Required content:

1. explicit uncertainty statement
2. bounded claims with no root-cause certainty promotion
3. ordered verification checklist using observable signals
4. missing observations from `required_fields`

Forbidden content:

1. irreversible executable actions
2. high-confidence root-cause conclusions unsupported by evidence
3. stack-specific production code when anchor/quality conditions are not met

## Why State Machine Instead of Free-Form Chat

Free-form chat has no hard boundary between "reasoning", "speculation", and "execution advice".
This creates non-deterministic production risk.
State-machine orchestration enforces:

- explicit transitions
- observability per stage
- bounded failure behavior
- reviewable postmortems
