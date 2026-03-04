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

## 3. Baseline and Ablation Profiles

Use a component-matrix design so each major control can be isolated.

| Profile | Diagnosis | Second Pass | Anchor Guard | Quality Gate | State Machine |
|---|---|---|---|---|---|
| `prompt_only` | off | off | off | off | off |
| `diagnosis_only` | on | off | off | off | on |
| `diagnosis_plus_audit` | on | on | off | off | on |
| `full_no_anchor_guard` | on | on | off | on | on |
| `full_no_quality_gate` | on | on | on | off | on |
| `full_no_second_pass` | on | off | on | on | on |
| `full_pipeline` | on | on | on | on | on |

Required reporting:

1. absolute metric values per profile
2. delta vs `full_pipeline`
3. per-component attribution discussion based on ablation deltas

## 4. Metric Definitions

1. Evidence Quality Rate

`anchored_facts / total_facts`

2. Non-Echo Ratio

`non_echo_audits / valid_audits`

Non-echo computation must follow second-pass merge-policy method:

- lexical overlap threshold `< 0.85`
- semantic similarity threshold `< 0.92`
- default embedding backend `sentence-transformers/all-MiniLM-L6-v2`

If a different embedding backend is used, report model ID and recalibrated threshold.

3. Unsafe Output Suppression

`blocked_or_degraded_under_missing_anchors / risky_code_requests_with_missing_anchors`

4. Degradation Correctness

`correct_fallback_runs / runs_that_should_degrade`

Where `runs_that_should_degrade = count(runs where oracle_should_degrade=true)`.

5. Final Consistency

`runs_with_contract_consistent_final / total_runs`

## 5. Degrade Oracle (Machine-Executable)

### 5.1 Predicate Definition

`oracle_should_degrade = p1 OR p2 OR p3 OR p4 OR p5`

- `p1 = diagnosis.insufficient_evidence`
- `p2 = requires_executable AND anchor_score < 0.80`
- `p3 = audit_status in {invalid, echo, weak}`
- `p4 = quality_gate_result in {soft_fail, hard_fail}`
- `p5 = terminal_state in {S_FAIL_RETRYABLE, S_FAIL_TERMINAL}`

`oracle_reason` is a multi-label set:

- `insufficient_evidence` for `p1`
- `missing_anchor` for `p2`
- `invalid_audit` for `p3` with `audit_status in {invalid, echo}`
- `weak_audit` for `p3` with `audit_status=weak`
- `quality_gate_fail` for `p4`
- `fail_state` for `p5`

### 5.2 Ground-Truth Source for `runs_that_should_degrade`

To avoid manual labeling ambiguity, degrade oracle labels are generated from a fixed reference run:

1. execute each task once with `full_pipeline` reference profile.
2. extract oracle predicates from persisted artifacts.
3. write `oracle_should_degrade` and `oracle_reason` into dataset label columns.
4. freeze these labels for all baseline comparisons.

This frozen label set is the denominator source for `runs_that_should_degrade`.

## 6. Measurement Protocol

1. Freeze dataset split and prompts.
2. Generate oracle labels from reference `full_pipeline` run and persist them.
3. Run each baseline profile with identical request set.
4. Persist raw events, diagnosis artifacts, audit payloads, and final outputs.
5. Compute metrics from persisted artifacts and frozen oracle labels only.
6. Report confidence intervals when sample size allows.

## 7. Dataset Specification

See [`examples/contracts/benchmark-dataset-spec.md`](../../examples/contracts/benchmark-dataset-spec.md) for required columns and example records.

## 8. Reporting Template

Minimum report content:

- dataset definition and sampling method
- profile matrix and toggles
- metric table with formulas
- oracle rule and reason distribution
- ablation deltas vs `full_pipeline`
- failure mode examples
- reproducibility checklist

## 9. Acceptance Criteria

1. metric formulas are machine-verifiable.
2. `runs_that_should_degrade` comes from deterministic frozen oracle labels.
3. profile toggles are fully declared.
4. dataset and splits are versioned.
5. re-run by another team yields same logic and comparable trend.
