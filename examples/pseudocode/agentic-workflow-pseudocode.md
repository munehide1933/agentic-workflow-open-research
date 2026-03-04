# Agentic Workflow Pseudocode (Public)

Assumption: second-pass payload follows audit schema v2 (`audit_completeness`).
If a v1 payload is received, completeness inference follows merge-policy rules.

```python
def run_agent(query: str, context: dict) -> dict:
    if is_session_inflight(context["session_id"]):
        return render_error(
            code="E_CONCURRENCY_CONFLICT",
            retryable=True,
            state="S_FAIL_RETRYABLE",
        )

    state = normalize_input(query, context)  # S0

    understanding = understand(state)  # S1
    state["understanding"] = understanding

    memory_hits = retrieve_cross_session_memory(state)
    state["memory_context"] = filter_memory_hits(memory_hits, min_score=0.72)

    if not understanding.requires_diagnosis:
        draft = generate_direct_answer(state)  # S3
    else:
        diagnosis = build_diagnosis_structure(
            state,
            external_context=state.get("memory_context", []),
        )  # S2
        state["diagnosis"] = diagnosis

        if diagnosis.insufficient_evidence:
            draft = build_verification_first_draft(
                state,
                must_include=[
                    "uncertainty_statement",
                    "bounded_claims",
                    "verification_checklist",
                    "required_fields",
                ],
                must_exclude=[
                    "irreversible_actions",
                    "unsupported_root_cause_certainty",
                ],
            )
        else:
            draft = synthesize_draft(state)  # S3

    anchor_score = compute_anchor_score(state)
    draft = enforce_anchor_guard_by_score(draft, anchor_score)

    if should_run_second_pass(state):
        audit = run_second_pass_audit(draft, state.get("diagnosis"), state)  # S4
        audit_valid = is_valid_audit(audit)

        if audit_valid and audit.get("audit_completeness") == "full":
            final_text = merge_draft_with_audit(draft, audit, state)  # S5
        elif audit_valid and audit.get("audit_completeness") == "partial":
            final_text = merge_partial_salvage(draft, audit, state)  # S5
        else:
            final_text = safe_degrade(draft, reason="invalid_or_partial_audit")
    else:
        final_text = draft  # S5

    gated = apply_quality_gate(final_text, state)
    return render_with_contract(gated, state)  # S6
```

## Notes

- Modes are `basic`, `deep_thinking`, and `web_search`.
- Fail states are split into `S_FAIL_RETRYABLE` and `S_FAIL_TERMINAL`.
- `should_run_second_pass()` uses `second_pass_eligible` guard from state-machine matrix.
- Public pseudocode omits private policy constants and local execution internals.
