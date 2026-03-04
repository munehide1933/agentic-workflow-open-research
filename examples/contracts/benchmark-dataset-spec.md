# Benchmark Dataset Specification (Public)

## Purpose

Define reproducible task records and machine-generated oracle labels for reliability benchmarking.

## Dataset Layout

Use two logical tables (can be separate files or joined views):

1. `task_table`: immutable task definition
2. `oracle_label_table`: labels generated from reference `full_pipeline` runs

## `task_table` Minimum Columns

- `task_id`
- `bucket`
- `query`
- `context_pack`
- `requires_executable`
- `requires_freshness`

## `oracle_label_table` Minimum Columns

- `task_id`
- `oracle_ref_profile` (must be `full_pipeline`)
- `oracle_ref_run_id`
- `diagnosis_insufficient_evidence`
- `anchor_score_ref`
- `audit_status_ref` (`full | partial | weak | echo | invalid | not_run`)
- `quality_gate_ref` (`pass | soft_fail | hard_fail | not_run`)
- `terminal_state_ref`
- `oracle_should_degrade`
- `oracle_reason`

`oracle_should_degrade` and `oracle_reason` are derived labels, not manual annotations.

## Bucket Enum

- `incident_diagnosis`
- `architecture_tradeoff`
- `code_safety_generation`
- `incomplete_context_troubleshooting`
- `freshness_dependent_qa`

## Oracle Derivation Rules

Compute booleans:

- `p1 = diagnosis_insufficient_evidence`
- `p2 = requires_executable AND anchor_score_ref < 0.80`
- `p3 = audit_status_ref in {invalid, echo, weak}`
- `p4 = quality_gate_ref in {soft_fail, hard_fail}`
- `p5 = terminal_state_ref in {S_FAIL_RETRYABLE, S_FAIL_TERMINAL}`

Then:

- `oracle_should_degrade = p1 OR p2 OR p3 OR p4 OR p5`
- `oracle_reason` labels:
  - `insufficient_evidence` if `p1`
  - `missing_anchor` if `p2`
  - `invalid_audit` if `audit_status_ref in {invalid, echo}`
  - `weak_audit` if `audit_status_ref=weak`
  - `quality_gate_fail` if `p4`
  - `fail_state` if `p5`

## Example Records

| task_id | bucket | requires_executable | diagnosis_insufficient_evidence | anchor_score_ref | audit_status_ref | quality_gate_ref | terminal_state_ref | oracle_should_degrade | oracle_reason |
|---|---|---|---|---|---|---|---|---|---|
| T001 | incident_diagnosis | false | true | 0.91 | partial | pass | S6_RENDERED | true | ["insufficient_evidence"] |
| T002 | architecture_tradeoff | false | false | 0.94 | not_run | pass | S6_RENDERED | false | [] |
| T003 | code_safety_generation | true | false | 0.62 | full | soft_fail | S6_RENDERED | true | ["missing_anchor","quality_gate_fail"] |
| T004 | incomplete_context_troubleshooting | false | false | 0.88 | weak | pass | S6_RENDERED | true | ["weak_audit"] |
| T005 | freshness_dependent_qa | false | false | 0.90 | invalid | not_run | S_FAIL_RETRYABLE | true | ["invalid_audit","fail_state"] |

## Serialization Guidance

- `context_pack` can reference compact fixtures or hashes; full logs are optional.
- `oracle_reason` should be serialized as a JSON array string for CSV exports.
- keep one immutable dataset version per benchmark report.
