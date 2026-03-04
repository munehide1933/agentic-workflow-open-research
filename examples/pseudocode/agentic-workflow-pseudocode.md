# Agentic Workflow Pseudocode (Public)

```python
def run_agent(query: str, context: dict) -> dict:
    state = normalize_input(query, context)

    understanding = understand(state)
    state["understanding"] = understanding

    if not understanding.requires_diagnosis:
        draft = generate_direct_answer(state)
        return finalize_and_render(draft, state)

    diagnosis = build_diagnosis_structure(state)
    state["diagnosis"] = diagnosis

    if diagnosis.insufficient_evidence:
        draft = build_verification_first_draft(state)
    else:
        draft = synthesize_draft(state)

    if should_apply_anchor_guard(state):
        draft = enforce_anchor_guard(draft, state)

    if should_run_second_pass(state):
        audit = run_second_pass_audit(draft, diagnosis, state)
        if is_valid_audit(audit):
            final_text = merge_draft_with_audit(draft, audit, state)
        else:
            final_text = safe_degrade(draft, reason="invalid_or_partial_audit")
    else:
        final_text = draft

    return render_with_contract(final_text, state)
```

## Notes

- The public pseudocode intentionally omits production policy constants.
- Runtime operators and local execution internals are excluded.
- The goal is to show engineering method, not private implementation.

