# AgenticAI and Open-Source Capability Alignment (2026-03)

## 1. Scope

This document aligns the current AgenticAI implementation baseline with the public open-research architecture documents in this repository.

It covers only public control-plane behavior and contract-level semantics.

Out of scope:

- private prompt internals
- deployment topology and private infrastructure details
- local execution operators and non-public runtime internals

## 2. Baseline and Evidence Sources

Alignment baseline date: `2026-03-06`

Implementation evidence is derived from:

- runtime modules (`backend/core`, `backend/app`, `backend/database`, `backend/services`)
- API surface (`backend/app/main.py`)
- contract tests under `backend/tests`

Behavioral evidence references used in this alignment:

1. `test_runtime_boundary_contract_v1.py`
2. `test_unified_step_runner_contract.py`
3. `test_chat_streaming_contract_v1.py`
4. `test_ui_message_stream_protocol_contract.py`
5. `test_pipeline_metadata_ssot_contract.py`
6. `test_second_pass_timeout_profile_contract.py`
7. `test_second_pass_confirmation_contract.py`
8. `test_anchor_guard_policy.py`
9. `test_guard_skips_codegen_and_gate.py`
10. `test_artifact_version_chain_contract.py`
11. `test_artifact_diff_contract.py`
12. `test_artifact_api_list_detail_download.py`

## 3. Capability Alignment Matrix

| Capability Line | AgenticAI Implementation Evidence | Current Open-Source Coverage | Alignment Decision |
| --- | --- | --- | --- |
| Streaming output contract and user-surface isolation | `chat_stream` + UI message stream adapter + streaming contract tests | Covered by `sse-response-contract.md`, but implementation profile details are not fully explicit | Keep base SSE spec; add implementation profile constraints in follow-up patch |
| Runtime boundary and failure-class transitions | `runtime_contract.py`, `step_runner.py`, runtime boundary tests | Partially covered by state-machine and error taxonomy docs | Add runtime-boundary metadata contract and transition mapping as a dedicated supplement |
| Second-pass audit execution policy | second-pass mode/timeout/trust/no-effect tests | Merge policy exists, execution-mode behavior is only partially documented | Extend second-pass policy with confirmation mode and timeout profile behavior |
| Code safety envelope (anchor + canonical + quality gate) | anchor guard tests, canonical output tests, quality gate hard-fail downgrade tests | Anchor/quality docs already exist | Mark as aligned; add canonical output mode and `skipped_guard` severity in next revision |
| Artifact lifecycle and version chain | artifact persistence/version/diff/API tests | No dedicated public architecture spec yet | Add an artifact lifecycle spec and public contract schema |
| Final metadata SSOT and observability payload | pipeline metadata builders + metadata tests | Observability doc exists, but runtime payload fields are incomplete | Extend observability spec with `runtime_boundary`, `failure_event`, `output_contract`, and second-pass timeout profile fields |
| Memory and safety middleware | summary checkpoint and long-memory behavior + token/rate-limit middleware | Memory architecture exists; runtime protection details are not fully surfaced | Add a runtime-ops supplement for summary checkpoints and API protection semantics |
| Deterministic replay and checkpoint recovery | partial deterministic safeguards exist; no transactional replay checkpoint contract in implementation | Already listed as missing in vNext hardening plan | Keep as roadmap gap until checkpoint/replay contract is implemented |

## 4. Public Contract Deltas for Synchronization

The following deltas are required to keep open-source docs aligned with implementation behavior:

1. `SSE response contract`:
   - pre-content status ordering (`mode_selected -> language_locked -> style_mode_locked`)
   - source whitelist for `content` emission (`answer|quote` only for user body)
   - equality constraint (`final.content == final_answer_text == persisted answer`)
2. `Observability/error taxonomy`:
   - standardized runtime payload fields (`runtime_boundary`, `failure_event`, `output_contract`)
   - timeout profile and optional-step timeout semantics
3. `Second-pass merge policy`:
   - trust-gated merge (`UNTRUSTED` never rewrites body)
   - auto-confirm behavior (`second_pass_mode=auto`)
   - adaptive timeout profile contract
   - no-effect summary behavior for second-pass-only mode
4. `Artifact contracts`:
   - version chain (`version_no`, `parent_artifact_id`, `logical_key`)
   - diff endpoint contract and session-scoped visibility rules
5. `Runtime governance`:
   - optional step skip on soft depth limits
   - required-step timeout escalation path

## 5. Boundary and Publication Rules

When synchronizing implementation behavior into open-research docs:

1. publish only control-plane behavior and public contracts
2. avoid private prompt content, secret material, and private infrastructure details
3. represent implementation behavior as deterministic, testable rules
4. maintain compatibility statements when contract fields are extended

## 6. Acceptance Scenarios

1. Streaming whitelist and ordering:
   - Input: status events plus mixed-source content (`answer`, `tool`, `audit`)
   - Expected: only allowed user-surface content is emitted; pre-content lock ordering is preserved
2. Optional step timeout:
   - Input: optional step timeout (`reflection`)
   - Expected: failure class becomes `retryable_failure`, transition action is `skip_optional_step`
3. Required step timeout:
   - Input: required step timeout (`synthesis_merge`)
   - Expected: failure class becomes `systemic_failure`, timeout is terminal for that step path
4. Artifact version chain:
   - Input: save same logical artifact twice and query details
   - Expected: version increments (`1 -> 2`), parent linkage is present, logical key is stable
5. Artifact diff:
   - Input: request unified diff between two versions
   - Expected: diff payload includes unified text and stats (`added`, `removed`, `changed`)
6. Second-pass auto confirmation:
   - Input: `second_pass_mode=auto`, normal chat flow (not second-pass-only)
   - Expected: second pass is not auto-executed; response contains `next_action=confirm_second_pass`

## 7. Follow-up Work Items

`P0`:

1. add SSE implementation profile supplement
2. add runtime-boundary payload supplement
3. add artifact lifecycle architecture spec

`P1`:

1. extend second-pass policy with execution-mode contract
2. extend observability spec with final metadata field set

`Roadmap`:

1. transactional checkpointing
2. deterministic replay contract
3. runtime backpressure and multi-tenant quota governance

## 8. Cross References

- [SSE Response Contract](./sse-response-contract.md)
- [Error Taxonomy and Observability](./error-taxonomy-observability.md)
- [Second-Pass Audit Merge Policy](./second-pass-audit-merge-policy.md)
- [Anchor Guard Design](./anchor-guard.md)
- [Quality Gate Framework](./quality-gate-framework.md)
- [Memory Architecture](./memory-architecture.md)
- [State Machine Transition Matrix](./state-machine-transition-matrix.md)
- [Runtime vNext Iteration Plan and Primary Design Goals](./runtime-vnext-iteration-plan.md)
