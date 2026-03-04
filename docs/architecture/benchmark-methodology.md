# Benchmark Methodology for Reliability Claims

## 1. Goal

This document defines reproducible evaluation methodology for architecture-level reliability claims.

## 2. Benchmark Task Set

Recommended buckets:

1. incident diagnosis
2. architecture tradeoff analysis
3. code-safety constrained generation
4. incomplete-context troubleshooting
5. freshness-dependent Q&A

Recommended minimum size: 500 tasks total, stratified across buckets.

## 3. Baseline Groups

- `prompt_only`: no diagnosis structure, no second pass, no guard system
- `diagnosis_only`: diagnosis structure enabled, no second pass, no anchor/quality gate coupling
- `full_pipeline`: diagnosis + second pass + anchor guard + quality gate + state-machine governance

## 4. Metric Definitions

1. Evidence Quality Rate

`anchored_facts / total_facts`

2. Non-Echo Ratio

`non_echo_audits / valid_audits`

3. Unsafe Output Suppression

`blocked_or_degraded_under_missing_anchors / risky_code_requests_with_missing_anchors`

4. Degradation Correctness

`correct_fallback_runs / runs_that_should_degrade`

Where `runs_that_should_degrade = count(runs where degrade_oracle.should_degrade = true)`.

5. Final Consistency

`runs_with_contract_consistent_final / total_runs`

## 5. Degrade Oracle (Machine-Executable)

Define:

`should_degrade = (diagnosis.insufficient_evidence) OR (requires_executable AND anchor_score < 0.80) OR (audit_invalid_or_echo_or_weak) OR (quality_gate in {soft_fail, hard_fail}) OR (state in {S_FAIL_RETRYABLE, S_FAIL_TERMINAL})`

`oracle_reason` is a multi-label set with values:

- `insufficient_evidence`
- `missing_anchor`
- `invalid_audit`
- `weak_audit`
- `quality_gate_fail`
- `fail_state`

Oracle output fields per run:

- `oracle_should_degrade`: boolean
- `oracle_reason`: array of reason labels

## 6. Measurement Protocol

1. Freeze dataset split and prompts.
2. Run each baseline with identical request set.
3. Persist raw events, diagnosis artifacts, audit payloads, and final outputs.
4. Compute metrics and degrade oracle labels from persisted artifacts only.
5. Report confidence intervals when sample size allows.

## 7. Dataset Specification

See [`examples/contracts/benchmark-dataset-spec.md`](../../examples/contracts/benchmark-dataset-spec.md) for minimum columns and sample records.

## 8. Reporting Template

Minimum report content:

- dataset definition and sampling method
- baseline configurations
- metric table with formulas
- degrade oracle criteria and reason distribution
- failure mode examples
- reproducibility checklist

## 9. Acceptance Criteria

1. Metric formulas are machine-verifiable.
2. `runs_that_should_degrade` is derived by deterministic oracle logic.
3. Dataset and splits are versioned.
4. Re-run by another team yields same metric logic and comparable trend.
