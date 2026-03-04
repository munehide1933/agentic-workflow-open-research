# Benchmark Dataset Specification (Public)

## Purpose

Define minimum dataset columns and reproducible oracle labels for reliability benchmarking.

## Minimum Columns

- `task_id`
- `bucket`
- `query`
- `context_pack`
- `requires_executable`
- `requires_freshness`
- `oracle_should_degrade`
- `oracle_reason`

## Bucket Enum

- `incident_diagnosis`
- `architecture_tradeoff`
- `code_safety_generation`
- `incomplete_context_troubleshooting`
- `freshness_dependent_qa`

## Oracle Label Rules

`oracle_should_degrade=true` when any of the following holds:

1. `diagnosis.insufficient_evidence=true`
2. `requires_executable=true` and `anchor_score < 0.80`
3. audit outcome is invalid, echo, or weak
4. `quality_gate_result in {soft_fail, hard_fail}`
5. state in `{S_FAIL_RETRYABLE, S_FAIL_TERMINAL}`

`oracle_reason` must use labels from:

- `insufficient_evidence`
- `missing_anchor`
- `invalid_audit`
- `weak_audit`
- `quality_gate_fail`
- `fail_state`

## Example Records

| task_id | bucket | query | context_pack | requires_executable | requires_freshness | oracle_should_degrade | oracle_reason |
|---|---|---|---|---|---|---|---|
| T001 | incident_diagnosis | API latency spiked after deploy, find likely root cause | logs:p95+deploy_ts | false | false | true | ["insufficient_evidence"] |
| T002 | architecture_tradeoff | Compare queue-based vs event-stream retry architecture | design_notes:v3 | false | false | false | [] |
| T003 | code_safety_generation | Generate production-ready SDK migration patch | runtime=node18;sdk=partial | true | false | true | ["missing_anchor","quality_gate_fail"] |
| T004 | incomplete_context_troubleshooting | Why does auth intermittently fail at night? | sparse_context:ticket_only | false | false | true | ["weak_audit"] |
| T005 | freshness_dependent_qa | What changed in vendor API this week? | web_lookup_timeout_case | false | true | true | ["fail_state"] |

## Serialization Guidance

- `context_pack` can reference compact fixtures or hashes; it does not need full raw logs inline.
- `oracle_reason` should be serialized as a JSON array string for CSV exports.
- Keep one immutable dataset version per benchmark report.
