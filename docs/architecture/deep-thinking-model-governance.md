# Deep Thinking Model Governance

## 1. Scope

This specification defines the control-plane governance contract for deep-thinking model execution.
It standardizes profile selection, fallback sequencing, timeout policy binding, and replay-safe execution rules.

Out of scope:

- private model provider negotiation and commercial terms
- private system prompts and prompt templates
- vendor-specific safety implementation details

## 2. Problem Statement

Deep-thinking behavior becomes unstable in production when model selection is implicit.
Common failure modes:

- model routing changes silently across releases
- fallback paths bypass policy controls
- timeout behavior differs between primary and auditor calls
- replay cannot reproduce prior model decisions

## 3. Contract / Data Model

### 3.1 Model Profile Contract

| Field | Type | Meaning |
| --- | --- | --- |
| `profile_id` | string | stable public model profile identifier |
| `role` | string | `primary | auditor | fallback` |
| `mode_allowlist` | array[string] | allowed runtime modes (`basic`, `deep_thinking`, `web_search`) |
| `determinism_mode` | string | `live | replay` |
| `max_input_tokens` | integer | max input token budget for this profile |
| `max_output_tokens` | integer | max output token budget for this profile |
| `temperature` | number | generation temperature used by policy |
| `timeout_profile_id` | string | reference to timeout profile contract |
| `cost_tier` | string | `low | medium | high` |
| `safety_class` | string | policy safety class label |

### 3.2 Model Decision Record

| Field | Type | Meaning |
| --- | --- | --- |
| `run_id` | string | runtime execution ID |
| `step_id` | string | pipeline step ID |
| `selected_profile_id` | string | selected profile for this step |
| `auditor_profile_id` | string | selected audit profile if enabled |
| `fallback_chain` | array[string] | ordered fallback profile IDs |
| `selection_reason` | array[string] | deterministic reason tags |
| `checkpoint_ref` | string | checkpoint pointer for replay |

## 4. Decision Logic

```python
def build_model_plan(request, policy, boundary, profiles):
    candidates = [
        p for p in profiles
        if request.mode in p.mode_allowlist and p.safety_class == boundary.safety_class
    ]

    ordered = sort_profiles(candidates, request.priority, policy.cost_cap_tier)
    primary = ordered[0]
    auditor = select_auditor_profile(ordered, policy.audit_enabled)
    fallback_chain = ordered[1 : 1 + policy.max_fallback_depth]

    return {
        "primary_profile_id": primary.profile_id,
        "auditor_profile_id": auditor.profile_id if auditor else None,
        "fallback_chain": [p.profile_id for p in fallback_chain],
        "timeout_profile_id": primary.timeout_profile_id,
    }


def execute_model_step(step_input, plan, checkpoint_store, replay_mode=False):
    if replay_mode:
        return checkpoint_store.load_model_output(step_input.run_id, step_input.step_id)

    output = call_model(plan["primary_profile_id"], step_input)
    checkpoint_store.save_model_output(step_input.run_id, step_input.step_id, output)
    return output
```

## 5. Failure and Degradation

1. `retryable_failure`: provider timeout or transient API error -> retry primary profile under retry budget.
2. `model_uncertainty_failure`: output confidence below policy floor -> route to auditor profile.
3. `audit_rejection_failure`: auditor rejects draft -> keep draft with bounded uncertainty output.
4. `policy_failure`: profile violates policy constraints -> skip profile and continue fallback chain.
5. `systemic_failure`: all fallback profiles exhausted -> emit bounded failure artifact.

Degradation priority:

1. deterministic replay guarantee
2. safety policy integrity
3. user-visible answer continuity
4. cost optimization

## 6. Acceptance Scenarios

1. Deep-thinking request with healthy primary profile:
   - Expected: primary profile selected; auditor optional by policy.
2. Primary provider timeout with fallback available:
   - Expected: classify `retryable_failure`; fallback profile executes.
3. Output confidence below threshold:
   - Expected: classify `model_uncertainty_failure`; auditor path triggered.
4. Replay mode execution:
   - Expected: model is not called; output loaded from checkpoint.
5. Policy-disallowed profile appears in registry:
   - Expected: classify `policy_failure`; profile excluded.
6. Fallback chain exhausted:
   - Expected: classify `systemic_failure`; bounded degrade artifact returned.
7. Negative case, private provider strategy leak in output:
   - Expected: blocked by output contract and sanitized metadata only.

## 7. Compatibility and Versioning

- `profile_id` is stable within a major governance line.
- Adding optional profile fields is minor-compatible.
- Changing role semantics (`primary/auditor/fallback`) is a major change.
- Any timeout profile reference change must update timeout schema compatibility notes.

## 8. Cross References

- [Runtime Capability Map](./runtime-capability-map.md)
- [Agent Pipeline Contract Profile](./agent-pipeline-contract-profile.md)
- [Second-Pass Audit Merge Policy](./second-pass-audit-merge-policy.md)
- [Runtime Reliability Mechanisms](./runtime-reliability-mechanisms.md)
