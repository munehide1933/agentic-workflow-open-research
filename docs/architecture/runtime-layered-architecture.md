# Runtime Layered Architecture

This diagram focuses on runtime control-plane layering and ownership boundaries.

![IAR Layered Runtime View](./assets/runtime-diagrams/runtime-layered-view.png)

The image reflects the latest layered view; the Mermaid block stays as the text-auditable counterpart.

```mermaid
flowchart TB
    U[Client / SDK / UI] --> I[Ingress / Request Normalization]

    subgraph L1[Ingress Layer]
      I
      I1[Auth + Rate Limit]
      I2[Schema Validate + Language / Mode Normalize]
      I --> I1 --> I2
    end

    I2 --> R[Router]

    subgraph L2[Routing Layer]
      R
      R1[Mode Selection]
      R2[Policy + Domain Route]
      R --> R1 --> R2
    end

    R2 --> E

    subgraph L3[Execution Stages]
      E[Execution Stages Orchestrator]
      E1[Understand]
      E2[Initial Analysis]
      E3[Reflection / Detailed Analysis / Codegen]
      E4[Synthesis Draft]
      E --> E1 --> E2 --> E3 --> E4
    end

    E4 --> A

    subgraph L4[Audit / Validation]
      A[Audit / Validation]
      A1[Second-Pass Signals]
      A2[Invariant Gate]
      A --> A1 --> A2
    end

    A2 --> O

    subgraph L5[Output Contract Gate]
      O[Output Contract Gate]
      O1[Single Writer Finalize]
      O2[Source/Phase Allowlist]
      O3[Final Consistency Check]
      O --> O1 --> O2 --> O3
    end

    O3 --> RESP[Final Response / SSE Stream]

    subgraph L6[State & Memory]
      S[State Store]
      M[Memory Store]
      C[Checkpoint / Artifact Chain]
      S <--> M
      S <--> C
    end

    subgraph L7[Replay / Recovery]
      P[Replay Planner]
      J[Replay Journal]
      RS[Step Snapshot Apply]
      P --> J --> RS
    end

    subgraph L8[Telemetry / Diagnosis]
      T[Telemetry Bus]
      T1[Structured Logs]
      T2[Metrics]
      T3[Trace / Runtime Quality]
      T --> T1
      T --> T2
      T --> T3
    end

    E -. read/write .-> S
    A -. read/write .-> S
    O -. read/write .-> S
    E -. retrieve .-> M
    E -. checkpoint .-> C
    A -. checkpoint .-> C

    P -. fingerprint .-> E
    P -. replay metadata .-> S
    RS -. authoritative/advisory patch .-> S

    I -. emit .-> T
    R -. emit .-> T
    E -. emit .-> T
    A -. emit .-> T
    O -. emit .-> T
    P -. emit .-> T

    T3 -. drives diagnosis dashboards .-> D[Diagnosis / Ops Console]
```

## Ownership Notes

- `Ingress / Router` owns request admission, normalization, and mode/domain routing.
- `Execution + Audit` owns content generation and correction signals.
- `Output Contract Gate` owns user-surface safety, single-writer finalize, and final consistency.
- `State & Memory + Replay` owns determinism, recovery, and traceable artifact history.
- `Telemetry / Diagnosis` owns observability contract and runtime diagnosis input.
