# Runtime 能力マップ（7 トラック拡張）

## システム識別

- システム名: `Intelligent Agent Runtime (IAR)`
- 設計パターン: `Two-Stage Contract-Driven Delivery`（中文表記: `双阶段契约驱动交付模式`）

## 1. スコープ

本書は 7 トラック runtime 拡張の統合エントリーマップである。
トピック境界、依存順序、公開 cadence、契約成果物を定義する。

対象外：

- private prompt 内部仕様
- private infra アドレスと配備トポロジー
- ローカル実行オペレータ

## 2. 能力トラック

公開 runtime 能力は次の 7 トラックで拡張する。

1. `Design Philosophy`
2. `Agent Pipeline`
3. `Deep Thinking Model Governance`
4. `Memory System`
5. `Action/Tools System`
6. `Execution Safety Envelope`
7. `Reliability Mechanisms`

各トラックは EN/ZH/JA の独立仕様として公開する。

## 3. 依存グラフ

| トラック | 依存 | 主な出力 |
| --- | --- | --- |
| Design Philosophy | - | 意思決定原則と境界ルール |
| Agent Pipeline | Design Philosophy | ステージ契約と遷移 profile |
| Deep Thinking Model Governance | Design Philosophy, Agent Pipeline | モデルルーティングとフォールバック方針 |
| Memory System | Agent Pipeline | memory 注入と checkpoint 意味論 |
| Action/Tools System | Agent Pipeline, Safety Envelope | ツール呼び出し契約と tool failure 方針 |
| Execution Safety Envelope | Design Philosophy | allowlist、guard、budget、出力制御 |
| Reliability Mechanisms | Pipeline, Safety, Deep Thinking | runtime boundary、timeout 遷移、failover profile |

## 3.1 システム層マッピング（IAR 設計図）

このマッピングは現在の IAR システム設計図と整合し、各コンポーネントを公開能力トラックに対応付ける。

![IAR Full System View](./assets/runtime-diagrams/runtime-full-system-view.png)

このシステム図を公開構成の主要ビジュアルとし、下表はレビュー向けの契約テキスト表現として保持する。

| レイヤー | 代表コンポーネント | 主な対応トラック |
| --- | --- | --- |
| Frontend | Next.js `Composer`、`Conversation View`、`useAgentChat/useArtifactLibrary` hooks、Web UI トグル | Agent Pipeline、Reliability |
| API Gateway | FastAPI ルート、セキュリティ middleware、SSE ストリーム endpoint | Safety Envelope、Observability |
| Agent Orchestration | `AgentPipeline`、ステージ遷移、`Output Contract Gate v3.0`、final 単一 writer 経路 | Agent Pipeline、Reliability |
| Platform Services | `Vision Extract`、`Language Rewriter`、`Long-term Memory`、stream adapter | Deep Thinking、Memory、Action/Tools |
| Data Layer | SQLite artifact/summary、Qdrant collection、backup scheduler | Memory、Reliability |
| Observability | runtime event stream、構造化ログ、遅延/token budget/trace メトリクス | 可観測性契約、Reliability |
| External Dependencies | モデル API、optional web search provider | Deep Thinking governance、Action/Tools policy |

## 4. 文書セットと契約成果物

### 4.1 アーキテクチャ文書

- `runtime-design-philosophy.*`
- `agent-pipeline-contract-profile.*`
- `deep-thinking-model-governance.*`
- `memory-system-operational-contract.*`
- `action-tools-system-contract.*`
- `execution-safety-envelope-runtime.*`
- `runtime-reliability-mechanisms.*`

### 4.2 JSON Schema 契約

- `examples/contracts/runtime-boundary.schema.v1.json`
- `examples/contracts/artifact-lifecycle.schema.v1.json`
- `examples/contracts/second-pass-timeout-profile.schema.v1.json`

## 5. 公開とレビュー cadence

- 2 週間ごとに増分更新を 1 回公開
- 月次で ADR snapshot を 1 回公開
- リリースタグ前に三言語同期チェックを実施
- 契約変更時は schema version matrix を必ず更新

## 6. リリースゲート

次のいずれかが失敗した場合、リリース候補はブロックする。

1. EN/ZH/JA の章番号が不一致
2. 契約フィールドが既存公開 schema と競合
3. 受け入れシナリオが機械検証不能
4. schema 変更に migration notes がない
5. cross-reference リンクが壊れている
6. 境界ルールが private 実装情報を露出する

## 7. バージョンマトリクス規則

1. 任意フィールドの追加は minor 互換
2. 必須フィールド変更は新 schema version ファイルを要求
3. フィールド削除は breaking change で migration notes 必須
4. 文書挙動変更時は同期更新対象ファイルを明示する

## 8. クロスリファレンス

- [Runtime 設計哲学](./runtime-design-philosophy.ja.md)
- [Agent Pipeline 契約 Profile](./agent-pipeline-contract-profile.ja.md)
- [Deep Thinking モデルガバナンス](./deep-thinking-model-governance.ja.md)
- [Memory システム運用契約](./memory-system-operational-contract.ja.md)
- [Action/Tools システム契約](./action-tools-system-contract.ja.md)
- [Execution Safety Envelope Runtime](./execution-safety-envelope-runtime.ja.md)
- [Runtime 信頼性メカニズム](./runtime-reliability-mechanisms.ja.md)
- [AgenticAI と Open-Source の能力整合](./agenticai-opensource-alignment.ja.md)
- [Runtime vNext イテレーション計画と主要設計目標](./runtime-vnext-iteration-plan.ja.md)
- [Runtime レイヤードアーキテクチャ図（EN）](./runtime-layered-architecture.md)
- [SSE レスポンス契約](./sse-response-contract.ja.md)
- [エラー分類と可観測性仕様](./error-taxonomy-observability.ja.md)
- [Second-Pass Audit マージポリシー](./second-pass-audit-merge-policy.ja.md)
