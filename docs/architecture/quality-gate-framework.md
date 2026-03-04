# Quality Gate Framework

## 1. Scope

Quality Gate evaluates executable artifacts after Anchor Guard.
The stricter decision between Anchor Guard and Quality Gate always wins.

## 2. Processing Order

1. Anchor Guard decides executable eligibility.
2. If executable output is still eligible, Quality Gate evaluates artifact quality.
3. Output class is `pass`, `soft_fail`, or `hard_fail`.

## 3. Check Dimensions

- `syntax_check`: parser/validator success
- `risky_pattern_scan`: static pattern checks
- `semantic_safety_check`: policy and intent consistency

## 4. `semantic_safety_check` Operational Method

`semantic_safety_check` combines deterministic rules with optional model critique:

1. Rule-based policy matcher (mandatory)
: checks prohibited operations, missing prerequisites, privilege/scope violations.
2. Intent-consistency checker (mandatory)
: checks whether generated actions exceed declared user intent.
3. Verifier-model critique (optional)
: secondary model assesses unsafe implications; if unavailable, rule-only path is valid.

Required output fields:

- `semantic_findings[]`: `{rule_id, severity, rationale}`
- `intent_drift`: boolean

## 5. Risk Classes

- `R0`: no detectable risk
- `R1`: low-risk caution
- `R2`: medium risk; requires degraded delivery
- `R3`: high risk; executable output blocked

## 6. Decision Rules

Default mapping:

1. `syntax_check=fail` => `hard_fail`
2. Any `semantic_findings.severity=critical` => `R3`
3. `intent_drift=true` with no critical finding => at least `R2`
4. max risk class `R0-R1` => `pass`
5. max risk class `R2` => `soft_fail`
6. max risk class `R3` => `hard_fail`

## 7. Output Contract

`quality_gate_result` object:

- `decision`: `pass | soft_fail | hard_fail`
- `risk_classes`: list of matched risk classes
- `blocked_rules`: list of triggered rule IDs
- `semantic_findings`: list of semantic safety findings
- `remediation`: safe alternatives or verification steps

## 8. Interaction with Anchor Guard

1. If Anchor Guard blocks executable output, Quality Gate cannot re-enable it.
2. If Anchor Guard allows executable output, Quality Gate may still downgrade/block.
3. Final decision must be the stricter of both components.

## 9. Acceptance Scenarios

1. Syntax pass + no risky pattern + no semantic findings => `pass`.
2. Syntax pass + medium risky pattern => `soft_fail`.
3. Intent drift with non-critical finding => at least `soft_fail`.
4. Critical semantic violation => `hard_fail`.
5. Anchor Guard block + Quality Gate pass => final block for executable delivery.
