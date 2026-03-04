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
2. Diagnose: build structured evidence and ranked hypotheses.
3. Draft: generate a candidate response under explicit mode constraints.
4. Second Pass: independently challenge the draft.
5. Finalize: merge only validated audit signals.
6. Render: output under strict response contracts.

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

## Why State Machine Instead of Free-Form Chat

Free-form chat has no hard boundary between "reasoning", "speculation", and "execution advice".
This creates non-deterministic production risk.
State-machine orchestration enforces:

- explicit transitions
- observability per stage
- bounded failure behavior
- reviewable postmortems

