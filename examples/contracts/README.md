# Public Contract Index

## Scope

This directory contains public JSON contracts for the open research edition.
Schema files are versioned when behavior-affecting changes are introduced.

## Version Matrix

| Contract | Current | Previous | Compatibility Notes |
|---|---|---|---|
| Diagnosis Structure | `diagnosis-structure.schema.json` | - | Current public baseline |
| Second-Pass Audit | `second-pass-audit.schema.v2.json` | `second-pass-audit.schema.json` (v1) | v2 adds `audit_completeness` and allows empty `counter_hypotheses` |
| SSE Event Envelope | `sse-event.schema.v1.json` | - | First formal stream schema |

## Migration Notes

### Second-Pass Audit v1 -> v2

1. v1 keeps read compatibility for existing producers.
2. Effective **March 4, 2026**, producers SHOULD emit v2 by default.
3. v1 has a historical constraint: `counter_hypotheses.minItems=1`.
4. Partial audit that needs empty `counter_hypotheses` MUST use v2.
5. v1 payload with empty `counter_hypotheses` is schema-invalid and treated as `invalid`.

## Validation Guidance

- Validate payloads against matching schema version at ingress.
- Reject unknown required fields in strict mode.
- Keep additive optional-field changes backward compatible in minor revisions.
