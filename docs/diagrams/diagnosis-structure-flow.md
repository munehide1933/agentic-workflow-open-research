# Diagnosis Structure Flow

```mermaid
flowchart LR
    A["User Query + Runtime Context"] --> U["Understanding (S1)"]
    U --> R["Memory Retrieval Sidecar<br/>top_k + min_score"]
    U --> B["Signal Detection"]
    R -->|Inject memory_context (external context only)| B
    B --> C["Evidence Extractor"]
    C --> D["facts[]<br/>source + evidence_span/keys"]
    D --> E["Hypothesis Builder"]
    E --> F["hypotheses[]<br/>confidence + executable test"]
    F --> G["Diagnosis Structure"]
    D --> G
    G --> G1["excluded_hypotheses[]"]
    G --> G2["insufficient_evidence (bool)"]
    G --> H{"Evidence sufficient?"}
    H -- "No" --> I["Verification-First Draft<br/>(bounded claims)"]
    H -- "Yes" --> J["Primary Draft Synthesis"]
    I --> K["Second-Pass Audit"]
    J --> K["Second-Pass Audit"]
    K --> K1["counter_hypotheses[]"]
    K --> K2["missing_evidence[]"]
    K --> K3["unsafe_recommendations[]"]
    K --> K4["structure_inconsistencies[]"]
    K1 --> L["Merge Policy"]
    K2 --> L
    K3 --> L
    K4 --> L
    L --> M{"Audit valid + non-echo?"}
    M -- "Yes" --> N["Finalize Candidate"]
    M -- "No" --> O["Safe Degrade / Partial Salvage"]
    N --> Q["Quality Gate<br/>(executable artifacts only)"]
    O --> Q
    Q --> P["Render: status/content/final contract"]
```
