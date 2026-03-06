# Runtime Capability Map (Seven-Track Expansion)

## System Identity

- System name: `Intelligent Agent Runtime (IAR)`
- Design pattern: `Two-Stage Contract-Driven Delivery`

## 1. Scope

This document is the entry map for the seven-track runtime expansion.
It defines topic boundaries, dependency order, publication rhythm, and contract artifacts.

Out of scope:

- private prompt internals
- private infrastructure addresses and deployment topology
- local execution operators

## 2. Capability Tracks

The public runtime model is expanded through seven tracks:

1. `Design Philosophy`
2. `Agent Pipeline`
3. `Deep Thinking Model Governance`
4. `Memory System`
5. `Action/Tools System`
6. `Execution Safety Envelope`
7. `Reliability Mechanisms`

Each track is published as a standalone architecture specification in EN/ZH/JA.

## 3. Dependency Graph

| Track | Depends On | Main Outputs |
| --- | --- | --- |
| Design Philosophy | - | decision principles and boundary rules |
| Agent Pipeline | Design Philosophy | stage contracts, transition profile |
| Deep Thinking Model Governance | Design Philosophy, Agent Pipeline | model routing and fallback policy |
| Memory System | Agent Pipeline | memory injection and checkpoint semantics |
| Action/Tools System | Agent Pipeline, Safety Envelope | tool invocation contract and tool failure policy |
| Execution Safety Envelope | Design Philosophy | allowlist, guard, budget, output controls |
| Reliability Mechanisms | Pipeline, Safety, Deep Thinking | runtime boundary, timeout transitions, failover profile |

## 3.1 System Layer Mapping (IAR Design Diagram)

This map aligns with the current IAR system diagram and binds components to public capability tracks.

| Layer | Representative Components | Primary Track Binding |
| --- | --- | --- |
| Frontend | Next.js `Composer`, `Conversation View`, `useAgentChat/useArtifactLibrary` hooks, Web UI toggles | Agent Pipeline, Reliability |
| API Gateway | FastAPI routes, security middleware, SSE stream endpoints | Safety Envelope, Observability |
| Agent Orchestration | `AgentPipeline`, stage transitions, `Output Contract Gate v3.0`, final single-writer path | Agent Pipeline, Reliability |
| Platform Services | `Vision Extract`, `Language Rewriter`, `Long-term Memory`, stream adapter | Deep Thinking, Memory, Action/Tools |
| Data Layer | SQLite artifacts/summaries, Qdrant collections, backup scheduler | Memory, Reliability |
| Observability | runtime event stream, structured logs, latency/token-budget/trace metrics | Observability contract, Reliability |
| External Dependencies | model provider API, optional web search provider | Deep Thinking governance, Action/Tools policy |

## 4. Document Set and Contract Artifacts

### 4.1 Architecture Documents

- `runtime-design-philosophy.*`
- `agent-pipeline-contract-profile.*`
- `deep-thinking-model-governance.*`
- `memory-system-operational-contract.*`
- `action-tools-system-contract.*`
- `execution-safety-envelope-runtime.*`
- `runtime-reliability-mechanisms.*`

### 4.2 JSON Schema Contracts

- `examples/contracts/runtime-boundary.schema.v1.json`
- `examples/contracts/artifact-lifecycle.schema.v1.json`
- `examples/contracts/second-pass-timeout-profile.schema.v1.json`

## 5. Publication and Review Rhythm

- publish one incremental update every two weeks
- publish one ADR snapshot every month
- run trilingual sync check before every release tag
- require schema version matrix update for every contract change

## 6. Release Gates

A release candidate is blocked if any item fails:

1. section numbering differs across EN/ZH/JA variants
2. contract fields conflict with existing public schemas
3. acceptance scenarios are not machine-testable
4. migration notes are missing for schema changes
5. cross-reference links are broken
6. boundary rules expose private implementation details

## 7. Versioning Matrix Rules

1. additive optional fields are minor-compatible
2. required-field changes require new schema version files
3. field removal is a breaking change and requires migration notes
4. document behavior changes must list synchronized files explicitly

## 8. Cross References

- [Runtime Design Philosophy](./runtime-design-philosophy.md)
- [Agent Pipeline Contract Profile](./agent-pipeline-contract-profile.md)
- [Deep Thinking Model Governance](./deep-thinking-model-governance.md)
- [Memory System Operational Contract](./memory-system-operational-contract.md)
- [Action and Tools System Contract](./action-tools-system-contract.md)
- [Execution Safety Envelope Runtime](./execution-safety-envelope-runtime.md)
- [Runtime Reliability Mechanisms](./runtime-reliability-mechanisms.md)
- [AgenticAI and Open-Source Capability Alignment](./agenticai-opensource-alignment.md)
- [Runtime vNext Iteration Plan and Primary Design Goals](./runtime-vnext-iteration-plan.md)
- [SSE Response Contract](./sse-response-contract.md)
- [Error Taxonomy and Observability](./error-taxonomy-observability.md)
- [Second-Pass Audit Merge Policy](./second-pass-audit-merge-policy.md)
