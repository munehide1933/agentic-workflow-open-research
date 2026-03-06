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
| Runtime Boundary | `runtime-boundary.schema.v1.json` | - | Initial public boundary contract |
| Artifact Lifecycle | `artifact-lifecycle.schema.v1.json` | - | Initial public artifact version-chain contract |
| Second-Pass Timeout Profile | `second-pass-timeout-profile.schema.v1.json` | - | Initial public second-pass timeout contract |

## Migration Notes

### Second-Pass Audit v1 -> v2

1. v1 keeps read compatibility for existing producers.
2. Effective **March 4, 2026**, producers SHOULD emit v2 by default.
3. The effective date above is final for this open-research release line.
4. v1 has a historical constraint: `counter_hypotheses.minItems=1`.
5. Partial audit that needs empty `counter_hypotheses` MUST use v2.
6. v1 payload with empty `counter_hypotheses` is schema-invalid and treated as `invalid`.

### Runtime Boundary v1 (Initial Release)

1. Initial public version published on **March 6, 2026**.
2. Additive optional fields are backward compatible.
3. Required field removal or semantic redefinition requires a major version.

### Artifact Lifecycle v1 (Initial Release)

1. Initial public version published on **March 6, 2026**.
2. `message_id` is conditionally required when `visibility=user`.
3. Artifact version chain integrity is represented by `logical_key + version_no + parent_artifact_id`.

### Second-Pass Timeout Profile v1 (Initial Release)

1. Initial public version published on **March 6, 2026**.
2. Producers MUST emit all required fields: `level`, `score`, `base_seconds`, `resolved_seconds`, `max_seconds`, `factors`.
3. Resolver behavior MUST enforce `resolved_seconds <= max_seconds`.

## Runtime Metadata Coverage

Final runtime metadata aligns to the following contracts:

- `runtime_boundary` -> `runtime-boundary.schema.v1.json`
- `second_pass.timeout_profile` -> `second-pass-timeout-profile.schema.v1.json`
- artifact chain payloads -> `artifact-lifecycle.schema.v1.json`

## Validation Guidance

- Validate payloads against matching schema version at ingress.
- Reject unknown required fields in strict mode.
- Keep additive optional-field changes backward compatible in minor revisions.
