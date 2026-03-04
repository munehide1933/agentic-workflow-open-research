# Evidence-First Diagnosis Structure

## Goal

Convert free-text problem statements into a diagnosis artifact that is testable and auditable.

## Schema Elements

- `facts`: observed statements tied to evidence spans or keys
- `hypotheses`: ranked causal candidates with confidence and executable tests
- `excluded_hypotheses`: alternatives that are ruled out
- `insufficient_evidence`: explicit uncertainty signal
- `required_fields`: minimum missing observations to proceed confidently

## Invariants

1. Facts must not be fabricated.
2. Every hypothesis must include a concrete test.
3. If evidence is insufficient, primary-candidate certainty is prohibited.
4. Excluded hypotheses must be explainable via available evidence.

## Engineering Value

- improves consistency in incident-oriented reasoning
- enables deterministic audit checks
- creates clear handoff between diagnosis and final synthesis

