# Runtime vNext イテレーション計画と主要設計目標（Production Hardening）

## 1. 文書の位置づけ

本書は、Runtime の次イテレーションを外部読者向けに説明する文書である。
機能一覧を示すことが目的ではない。production-grade に必要な信頼性、安全性、監査可能性、運用統制をどう満たすかを示す。

## 2. 想定読者

- プラットフォーム/インフラエンジニア
- アーキテクチャレビュー担当者と技術責任者
- SRE と運用統制チーム
- 本番適用性を評価する協業先

## 3. このフェーズ終了時の到達状態

本フェーズ終了時、Runtime は次を検証可能な形で満たす。

- 実行行動が厳密に制約・隔離されている
- ワークフローが replay/recovery/audit 可能である
- 主要経路の可観測性が欠落なく整備されている
- 障害が分類・自動遷移・自動劣化できる
- マルチテナント運用で backpressure、quota、資源統制が機能する

## 4. 現在の基盤と主要ギャップ

現時点で実装済み：

- Anchor Guard + Quality Gate（安全収束の基礎）
- Evidence/Audit schema（証拠・監査の構造化）
- 状態機械オーケストレーション（決定性の土台）

未充足ギャップ：

- execution isolation
- deterministic replay
- production observability
- runtime-level backpressure
- multi-tenant safety
- resource quota & scheduling
- end-to-end SLA and failure handling

## 5. スコープと非目標

In Scope：

- SO2AFR の能力補完（Safety / Orchestration / Observability / Auditability / Failure / Runtime Ops）
- 契約先行の schema 設計とバージョン統制
- 自動化されたリリースゲートと回帰検証

Out of Scope：

- 新規ビジネス機能の拡張
- private infra 内部情報の公開
- 本番強化と無関係な実験作業

## 6. SO2AFR 設計目標（Goal -> Mechanism -> Acceptance Signal）

| Layer | Goal | Key Mechanisms | Acceptance Signals |
| --- | --- | --- | --- |
| S | 強制可能な実行安全境界 | 閉じた allowlist、step sandbox、5 つの予算（token/tool/latency/memory/output） | すべての要求が allow/deny 判定される。予算超過は必ず停止し監査証跡が残る |
| O | 決定的オーケストレーションと復旧 | FSM を SSOT 化、transactional checkpoint、副作用の idempotency key | 同一入力で replay 一致。障害後は checkpoint から再開しモデル再呼び出しをしない |
| O2 | 可観測性の契約化 | 必須 metrics/log/trace フィールド、run-step-span 系譜 | 主要経路の trace が完全。終端エラーを trace_id + run_id で結合可能 |
| A | 独立検証可能な監査チェーン | evidence version/diff/hash、独立監査パス、deterministic merge | hash を再計算可能。監査 replay が可能。同一証拠で merge 結果が安定 |
| F | 運用可能な失敗システム | failure taxonomy、状態機械イベント化、degradation graph | すべての失敗が分類され、自動遷移/自動劣化し、場当たり運用に依存しない |
| R | スケール可能な runtime 運用 | queue + worker + priority、backpressure、マルチテナント quota | ピーク時の連鎖障害を防止。テナント隔離と SLA アラートを観測可能 |

## 7. イテレーションロードマップ（8-10 週間）

### Sprint 1（Week 1-2）: Contract First + Safety Baseline

重点：契約と安全下限を先に固定する。

Deliverables：

- v1 schema bundle：execution/state/checkpoint/failure/observability/audit
- allowlist policy と budget enforcement
- baseline sandbox 実行パス

Exit Criteria：

- schema conformance tests が合格
- 非 allowlist 行動が完全な監査記録付きで拒否される

### Sprint 2（Week 3-5）: Deterministic Core

重点：動作可能状態から replay/recovery 可能状態へ移行する。

Deliverables：

- transactional checkpoint pipeline
- replay engine（復旧時のモデル再呼び出し禁止）
- crash recovery + side-effect idempotency contract

Exit Criteria：

- replay consistency テストが合格
- fault injection で checkpoint 継続実行を確認

### Sprint 3（Week 6-7）: Observability + Failure System

重点：ランタイム挙動を計測可能・診断可能・自動処理可能にする。

Deliverables：

- metrics/tracing/JSON logs の全経路実装
- failure taxonomy + transition matrix 固定
- degradation policy engine

Exit Criteria：

- 主要 workflow の trace topology が完全
- すべての failure class が自動遷移と劣化経路を実行できる

### Sprint 4（Week 8-10）: Runtime Ops + Audit Strengthening

重点：本番運用統制と監査閉ループを完成させる。

Deliverables：

- backpressure、queue priority 制御、quota ガバナンス
- マルチテナント並行性と資源スケジューリング方針
- evidence version/hash/diff + independent auditor path
- SLA/SLO 演習と負荷試験レポート

Exit Criteria：

- 高負荷・キュー圧下で安定挙動を維持し連鎖障害がない
- 監査チェーンが独立 replay 検証に対応

## 8. 対外公開計画（高級設計パターン）

設計進化を外部に継続的に示すため、本フェーズで以下を公開する。

1. Execution Safety Envelope Pattern
2. Deterministic Log Replay Pattern
3. Observability-as-Contract Pattern
4. Independent Auditor Chain Pattern
5. Failure-Class + Degradation Graph Pattern
6. Quota-Driven Multi-Tenant Scheduler Pattern

各パターン文書の固定構成：

- 問題設定と制約
- 契約定義と状態遷移
- 障害処理と劣化ロジック
- 受け入れケースと反例

公開 cadence：

- 2 週間ごとに 1 本のパターン文書公開または改訂
- 月次で ADR snapshot を 1 回公開
- 各 sprint 完了時にマイルストーン検証結果を公開

## 9. 契約とバージョン統制

- API contract versioning（明示バージョンと互換ウィンドウ）
- backward compatibility rules（追加は互換、削除は major）
- error schema contract（安定した最小フィールドと意味）
- checkpoint schema evolution（旧版の読み込み/移行サポート）

## 10. リリースゲート

以下のいずれか 1 つでも未達なら production rollout を停止する。

1. replay-safe が保証されない、または replay が乖離する
2. failure class が未整備、または自動遷移が欠落する
3. 主要経路に trace/log/metrics の盲点がある
4. evidence hash が再現不能、または監査 replay の独立検証ができない
5. 負荷時に backpressure/ quota 制御が破綻する
6. SLA 基準が安定していない、またはアラートが機能しない

## 11. 成果物

- `runtime-vnext architecture spec`（全体仕様 + サブ仕様）
- `schema bundle v1`（6 契約 + バージョンノート）
- `transition & degradation matrix`
- `checkpoint/replay conformance tests`
- `observability dashboard & alert rules`
- `SLA/SLO baseline & stress report`
- `audit replay evidence report`
- `ADR snapshot series`

## 12. 完了定義（Definition of Done）

vNext は次をすべて満たしたときに完了とする。

1. SO2AFR 各層に実装・テスト・運用証跡がある
2. 同一入力で replay が安定一致し、復旧でモデル再呼び出しをしない
3. failure handling が自動劣化し、場当たり運用に依存しない
4. マルチテナント資源境界が観測可能・強制可能・監査可能である
5. 公開したパターン文書と検証レポートが外部レビュー可能である
