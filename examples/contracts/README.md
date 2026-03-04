# Public Contract Index

## Scope

This directory contains public JSON contracts for the open research edition.
Schema files are versioned when behavior-affecting changes are introduced.

## Version Matrix

| Contract | Current | Previous | Compatibility Notes |
|---|---|---|---|
| Diagnosis Structure | `diagnosis-structure.schema.json` | - | Current public baseline |
| Second-Pass Audit | `second-pass-audit.schema.v2.json` | `second-pass-audit.schema.json` (v1) | v2 adds `audit_completeness` and allows `counter_hypotheses` to be empty |
| SSE Event Envelope | `sse-event.schema.v1.json` | - | First formal stream schema |

## Migration Notes

### Second-Pass Audit v1 -> v2

1. Keep existing v1 producer compatible.
2. Prefer emitting `audit_completeness` for deterministic merge behavior.
3. If only v1 is present, runtime may infer completeness (`full/partial/invalid`) using merge policy rules.

## Validation Guidance

- Validate payloads against matching schema version at ingress.
- Reject unknown required fields in strict mode.
- Keep additive optional-field changes backward compatible in minor revisions.
