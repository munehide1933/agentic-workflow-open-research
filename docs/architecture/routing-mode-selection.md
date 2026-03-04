# Routing and Mode Selection Specification

## 1. Scope

This specification defines how a request is routed into `basic`, `deep_thinking`, or `web_search`.

## 2. Inputs

Routing uses the following feature vector:

- `intent_type`: `qa | diagnosis | codegen | architecture | ops`
- `complexity_score`: float `[0, 1]`
- `freshness_need`: float `[0, 1]`
- `external_lookup_required`: boolean
- `risk_level`: `low | medium | high`

## 3. Decision Rules

Default public rules:

1. If `external_lookup_required=true` or `freshness_need >= 0.70` => `web_search`.
2. Else if `complexity_score >= 0.65` or `risk_level=high` => `deep_thinking`.
3. Else => `basic`.

## 4. Fallback Rules

1. `web_search` timeout/failure => fallback to `deep_thinking` with `insufficient_evidence=true`.
2. `deep_thinking` timeout => fallback to `basic` verification-first output.
3. `basic` may escalate to `deep_thinking` if uncertainty exceeds threshold.

## 5. Evidence Feedback from `web_search`

Web search evidence returns confidence labels:

- `high` -> weight `1.0`
- `medium` -> weight `0.6`
- `low` -> weight `0.3`

Feedback effects:

1. Low aggregate evidence confidence may set `insufficient_evidence=true`.
2. Hypothesis ranking must account for evidence weights.
3. Missing freshness evidence should be appended to `required_fields`.

## 6. Determinism and Logging

For each run, routing must persist:

- selected mode
- feature values
- matched rule id
- fallback path (if any)

## 7. Acceptance Scenarios

1. High freshness need => `web_search`.
2. High complexity without freshness need => `deep_thinking`.
3. Low complexity and low risk => `basic`.
4. `web_search` failure => fallback and uncertainty flag set.
