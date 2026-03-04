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

## 4. Risk Classes

- `R0`: no detectable risk
- `R1`: low-risk caution
- `R2`: medium risk; requires degraded delivery
- `R3`: high risk; executable output blocked

## 5. Decision Rules

Default mapping:

1. `syntax_check=fail` => `hard_fail`
2. max risk class `R0-R1` => `pass`
3. max risk class `R2` => `soft_fail`
4. max risk class `R3` => `hard_fail`

## 6. Output Contract

`quality_gate_result` object:

- `decision`: `pass | soft_fail | hard_fail`
- `risk_classes`: list of matched risk classes
- `blocked_rules`: list of triggered rule IDs
- `remediation`: safe alternatives or verification steps

## 7. Interaction with Anchor Guard

1. If Anchor Guard blocks executable output, Quality Gate cannot re-enable it.
2. If Anchor Guard allows executable output, Quality Gate may still downgrade/block.
3. Final decision must be the stricter of both components.

## 8. Acceptance Scenarios

1. Syntax pass + no risky pattern => `pass`.
2. Syntax pass + medium risky pattern => `soft_fail`.
3. Syntax fail => `hard_fail`.
4. Anchor Guard block + Quality Gate pass => final `hard_fail` equivalent for executable delivery.
