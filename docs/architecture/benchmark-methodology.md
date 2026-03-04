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

5. Final Consistency

`runs_with_contract_consistent_final / total_runs`

## 5. Measurement Protocol

1. Freeze dataset split and prompts.
2. Run each baseline with identical request set.
3. Persist raw events, diagnosis artifacts, audit payloads, and final outputs.
4. Compute metrics from persisted artifacts only.
5. Report confidence intervals when sample size allows.

## 6. Reporting Template

Minimum report content:

- dataset definition and sampling method
- baseline configurations
- metric table with formulas
- failure mode examples
- reproducibility checklist

## 7. Acceptance Criteria

1. Metric formulas are machine-verifiable.
2. Dataset and splits are versioned.
3. Re-run by another team yields same metric logic and comparable trend.
