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
- `requires_executable`: boolean

## 3. Feature Derivation (Operational Defaults)

`complexity_score` and `freshness_need` MUST be computed before route decision.

### 3.1 `complexity_score`

`complexity_score = 0.35*s1 + 0.25*s2 + 0.20*s3 + 0.20*s4`

- `s1` multi-step demand: `min(1.0, estimated_steps / 4)`
- `s2` constraint density: `min(1.0, explicit_constraints_count / 6)`
- `s3` artifact demand: `1.0` when code/config/procedure output is required, else `0.0`
- `s4` ambiguity penalty: `1.0` when key entities are missing, `0.5` when partially specified, else `0.0`

### 3.2 `freshness_need`

`freshness_need = 0.50*f1 + 0.30*f2 + 0.20*f3`

- `f1` explicit recency intent: `1.0` when query includes terms like `latest`, `today`, `this week`, version/date-sensitive intent
- `f2` mutable-domain signal: `1.0` for known volatile domains (prices, releases, incident status, policy updates), else `0.0`
- `f3` verification intent: `1.0` when user explicitly asks to check/search/verify sources, else `0.0`

If an implementation replaces this feature extractor, it MUST publish:

1. extractor ID/version
2. calibration dataset summary
3. equivalent thresholds used for route comparability

## 4. Decision Rules

Default public rules:

1. If `external_lookup_required=true` or `freshness_need >= 0.70` => `web_search`.
2. Else if `complexity_score >= 0.65` or `risk_level=high` => `deep_thinking`.
3. Else => `basic`.

## 5. Fallback Rules

1. `web_search` timeout/failure => fallback to `deep_thinking` with `insufficient_evidence=true`.
2. `deep_thinking` timeout => fallback to `basic` verification-first output.
3. `basic` may escalate to `deep_thinking` only when loop guard permits.

## 6. Loop Guard (Mandatory)

To prevent `basic -> deep_thinking -> basic` cycles:

1. `max_deep_escalations_per_run = 1`.
2. If `deep_thinking` has already timed out in the same run, `basic -> deep_thinking` escalation is forbidden.
3. If route fallbacks count reaches `2`, lock mode to `basic` for remainder of run.
4. When lock is active, output must be verification-first.

Required route-state flags:

- `deep_timeout_seen`: boolean
- `deep_escalation_count`: integer
- `mode_lock`: `none | basic`

## 7. Evidence Feedback from `web_search`

Confidence labels are assigned by system-side `web_search_evidence_ranker`, not by search provider raw fields.

Per-evidence confidence score:

`evidence_confidence_score = 0.50*r1 + 0.30*r2 + 0.20*r3`

- `r1` source reliability (`official_docs=1.0`, `major_publisher=0.8`, `community_source=0.6`, `unknown=0.4`)
- `r2` cross-source agreement (claim overlap across independent sources)
- `r3` recency fitness (date fit against query freshness window)

Label mapping:

- `high`: `score >= 0.80` (weight `1.0`)
- `medium`: `0.55 <= score < 0.80` (weight `0.6`)
- `low`: `score < 0.55` (weight `0.3`)

Feedback effects:

1. Low aggregate evidence confidence may set `insufficient_evidence=true`.
2. Hypothesis ranking must account for evidence weights.
3. Missing freshness evidence should be appended to `required_fields`.

## 8. Determinism and Logging

For each run, routing must persist:

- selected mode
- feature values
- matched rule id
- fallback path (if any)
- loop guard flags (`deep_timeout_seen`, `deep_escalation_count`, `mode_lock`)
- evidence confidence labels and raw component scores (`r1`, `r2`, `r3`) when `web_search` is used

## 9. Acceptance Scenarios

1. High freshness need => `web_search`.
2. High complexity without freshness need => `deep_thinking`.
3. Low complexity and low risk => `basic`.
4. `web_search` failure => fallback and uncertainty flag set.
5. `deep_thinking` timeout then `basic` uncertainty spike => no re-escalation loop.
6. Same query under same feature extractor yields stable mode selection.
