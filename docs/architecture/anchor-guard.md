# Anchor Guard Design

## Purpose

Prevent unsafe or misleading executable guidance when environmental anchors are incomplete.

## Anchor Set (Public)

- runtime
- deployment context
- client SDK
- HTTP client (when stack-specific details are required)

## Scoring Model (Weighted + Conditional Normalization)

### Weights

- `runtime = 0.35`
- `deployment_context = 0.30`
- `client_sdk = 0.25`
- `http_client = 0.10`

### Dimension Status Values

- `present = 1.0`
- `partial = 0.5`
- `missing = 0.0`
- `not_applicable = exclude` (removed from denominator)

### Score Formula

`anchor_score = sum(weight_i * value_i) / sum(active_weights)`

Where `active_weights` include only dimensions not marked `not_applicable`.

## HTTP Applicability Rule (Operational)

`http_client` is included only when `http_dimension_applicable=true`.
This flag MUST be computed during understanding stage and persisted in route-state.

Default deterministic rule:

`http_dimension_applicable = requires_executable AND (intent_type in {codegen, ops, diagnosis}) AND has_http_scope_signal`

`has_http_scope_signal=true` when any condition holds:

1. request asks to generate or modify external API call logic.
2. request asks for stack-specific HTTP behavior (`headers`, `status`, `retry`, `timeout`, `proxy`, `auth signing`, `TLS`).
3. deployment context includes API gateway/webhook/service-integration constraints.

If none hold, set `http_client=not_applicable` and exclude its weight from denominator.

### Applicability Examples

- `intent_type=codegen`, `requires_executable=true`, task is "implement webhook retry client" -> applicable.
- `intent_type=architecture`, `requires_executable=false`, task is "compare pub/sub patterns" -> not applicable.

## Dimension Rubric (Public Default)

### Runtime

- `present`: explicit runtime family and version scope are known.
- `partial`: runtime family known but version/scope unclear.
- `missing`: runtime family unknown.

### Deployment Context

- `present`: deployment target/stage constraints are explicit.
- `partial`: generic environment hint exists, but target constraints are incomplete.
- `missing`: no deployment context.

### Client SDK

- `present`: SDK family and usable package identity/version scope are explicit.
- `partial`: SDK family known but package/version scope unclear.
- `missing`: SDK not identified.

### HTTP Client

- `present`: stack-specific HTTP client is explicit when required.
- `partial`: HTTP usage implied but concrete client not fixed.
- `missing`: required HTTP client unknown.
- `not_applicable`: request does not require stack-specific HTTP details.

## Threshold Policy (Unchanged)

- `score < 0.50`: block executable code
- `0.50 <= score < 0.80`: allow pseudocode only
- `score >= 0.80`: executable output eligible (must still pass Quality Gate)

## Guard Application Contract

`enforce_anchor_guard_by_score()` public contract:

Input:

- `draft_candidate`: structured draft object (`answer_text`, optional `artifacts[]`, optional metadata)
- `anchor_score`: float `[0, 1]`
- `route_state.http_dimension_applicable`: boolean

Output:

- `guarded_candidate`: new candidate object (no in-place mutation requirement)
- `anchor_guard_result`: `{mode, score, missing_anchors[], reasons[]}`

Mode mapping:

1. `anchor_score < 0.50` -> `mode=blocked`
2. `0.50 <= anchor_score < 0.80` -> `mode=pseudocode_only`
3. `anchor_score >= 0.80` -> `mode=executable_eligible`

Required behavior by mode:

1. `blocked`: remove executable artifacts and replace with verification-first guidance.
2. `pseudocode_only`: strip executable operators, preserve non-executable pseudocode.
3. `executable_eligible`: preserve executable artifacts for subsequent Quality Gate.

## Deterministic Examples

### Example A: High confidence, HTTP not applicable

- runtime=`present`, deployment=`present`, sdk=`present`, http=`not_applicable`
- numerator = `0.35*1.0 + 0.30*1.0 + 0.25*1.0 = 0.90`
- denominator = `0.35 + 0.30 + 0.25 = 0.90`
- `anchor_score = 1.00` -> executable eligible

### Example B: Borderline

- runtime=`present`, deployment=`partial`, sdk=`missing`, http=`missing` (required)
- numerator = `0.35*1.0 + 0.30*0.5 + 0.25*0.0 + 0.10*0.0 = 0.50`
- denominator = `1.00`
- `anchor_score = 0.50` -> pseudocode only

### Example C: Low confidence

- runtime=`missing`, deployment=`partial`, sdk=`missing`, http=`missing` (required)
- numerator = `0.35*0.0 + 0.30*0.5 + 0.25*0.0 + 0.10*0.0 = 0.15`
- denominator = `1.00`
- `anchor_score = 0.15` -> block executable code

## Policy

If a request implies executable code under diagnostic uncertainty and anchors are incomplete:

1. block single-stack executable code
2. emit stack-agnostic guidance or pseudocode
3. expose missing anchors as explicit prerequisites

## Priority with Quality Gate

1. Anchor Guard runs first.
2. Quality Gate runs only after executable eligibility.
3. On conflict, stricter decision wins.

## Why It Matters

LLM systems can produce syntactically valid but operationally dangerous code.
Anchor Guard converts this risk into an explicit and auditable output policy.
