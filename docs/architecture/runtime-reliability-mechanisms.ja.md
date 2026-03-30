# Runtime 信頼性メカニズム

## 1. スコープ

本仕様は runtime 制御プレーンの本番信頼性メカニズムを定義する。
決定的オーケストレーション、checkpoint、replay 一貫性、ワークロード統制、SLA 指向失敗処理を対象とする。

対象外：

- private 当番アラート経路とエスカレーション詳細
- private インフラ自動スケーリング内部
- ベンダー固有デプロイトポロジー

## 2. 問題定義

「一度だけ動く」runtime は production-grade ではない。
代表的失敗モード：

- クラッシュ復旧時にモデル再呼び出しが発生し結果が変わる
- retry 経路が決定的契約を破壊する
- キュー圧でタイムアウトが連鎖する
- マルチテナント負荷で資源が不公平に枯渇する

## 3. 契約 / データモデル

### 3.1 決定的オーケストレーション記録

| フィールド | 型 | 意味 |
| --- | --- | --- |
| `state_version` | string | 状態 schema バージョン |
| `state_hash` | string | 直列化状態のハッシュ |
| `step_id` | string | 決定的 pipeline step 識別子 |
| `transition_event` | string | 状態機械遷移イベント |
| `checkpoint_id` | string | 不変 checkpoint artifact ID |
| `replay_safe` | boolean | replay 一貫性保証フラグ |

### 3.2 Runtime 最終 Metadata フィールド集合

| フィールド | 型 | 意味 |
| --- | --- | --- |
| `runtime_boundary` | object | 当該 run の境界契約スナップショット |
| `failure_event` | object | 正規化失敗分類ペイロード |
| `output_contract` | object | 最終出力整合性 metadata |
| `second_pass.timeout_profile` | object | second-pass の解決済み timeout プロファイル |
| `runtime_quality.stage_snapshots` | array | ステージ別 model/token/遅延スナップショット |
| `runtime_quality.invariant_gate` | object | merge ガード結果（`passed`、`reason_codes`、`metrics`、`fallback`） |
| `runtime_quality.degradation_flags` | array | run レベル劣化フラグ |
| `runtime_quality.performance.general_latency_flags_effective.ttft_v2_enabled` | boolean | TTFT v2 有効プロファイルフラグ |
| `runtime_quality.performance.first_meaningful_content_ms` | integer | preview 以外の最初の有意味コンテンツ遅延 |

### 3.3 Failure Event 契約

| フィールド | 型 | 意味 |
| --- | --- | --- |
| `failure_type` | string | retryable/model/audit/guard/tool/policy/systemic |
| `stage_id` | string | 失敗発生ステージ |
| `transition_to` | string | 決定的な遷移先状態 |
| `retryable` | boolean | 再試行可否 |
| `degradation_path` | string | 選択した劣化経路キー |

### 3.4 Artifact/Evidence チェーン契約

artifact/evidence のバージョン連鎖は次の不変フィールドで追跡する：

| フィールド | 型 | 意味 |
| --- | --- | --- |
| `logical_key` | string | バージョン横断の論理識別子 |
| `version_no` | integer | 単調増加するバージョン番号 |
| `parent_artifact_id` | string or null | 親バージョン参照 |
| `sha1` | string | 不変コンテンツダイジェスト |
| `trace_id` | string | 監査 replay のトレース紐付け |
| `message_id` | string | ユーザー可視 artifact の場合に必須 |

### 3.5 Request-Scoped Partial Replay 契約

現行 runtime の replay は request スコープで、対象ステップを限定する：

- 既定対象ステップ：`synthesis_draft`、`synthesis_merge`
- 各対象ステップに replay 試行上限を持つ
- replay journal は可観測性専用で、挙動分岐の入力に使わない

閉じた replay reason-code 列挙：

- `timeout`
- `token_overflow`
- `context_length`
- `transient_failure`
- `not_in_target_scope`
- `max_attempts_exceeded`
- `unsupported_executor`

snapshot 適用ルール：

- authoritative キーのみ状態上書きを許可
- advisory キーは warning/error/degrade 診断に限定
- 非 owned キー（例 `query`）は replay snapshot で上書き不可

### 3.6 API idempotency とセッションライフサイクル契約

API 境界での公開信頼性契約：

| フィールド | 型 | 意味 |
| --- | --- | --- |
| `Idempotency-Key` | string | `/api/chat` と `/api/chat/stream` のクライアント重複排除キー |
| `request_hash` | string | endpoint + 正規化リクエストペイロードの決定的ハッシュ |
| `idempotency_replay` | boolean | sync replay 時のレスポンス payload フラグ |
| `X-Idempotent-Replay` | string | stream replay レスポンスヘッダー（replay 時 `true`） |
| `idempotency_status` | enum | `in_progress | completed | failed | expired` |
| `response_payload` | object | replay に使うキャッシュ済み権威終端ペイロード |

決定的競合ルール：

1. 同一 key + 同一 hash + completed -> キャッシュ payload を replay
2. 同一 key + 同一 hash + in-progress -> `409`
3. 同一 key + 異なる hash -> `409`

セッションライフサイクル可視化ルール：

1. セッション未存在 -> `404`（`SESSION_NOT_FOUND`）
2. セッション削除/失効 -> `410`（`SESSION_GONE`）

### 3.7 Idempotency Cleanup Scheduler 契約

idempotency cleanup はアプリケーション lifecycle 内の定期 scheduler として動作し、stale レコードを整理する。

契約挙動：

1. `IDEMPOTENCY_CLEANUP_ENABLED=true` の場合のみ scheduler を実行する。
2. 各 cleanup サイクルは単一ホストロックを使う。
3. stale `in_progress` は endpoint 別 TTL で `expired` に遷移する：
   - sync endpoint は `IDEMPOTENCY_SYNC_IN_PROGRESS_TTL_SECONDS`
   - stream endpoint は `IDEMPOTENCY_STREAM_IN_PROGRESS_TTL_SECONDS`
4. `IDEMPOTENCY_RETENTION_DAYS` を超えた終端レコードは削除する。
5. cleanup カウンタは単調増加で記録する：
   - `idempotency_cleanup_run_total`
   - `idempotency_cleanup_expired_total`
   - `idempotency_cleanup_deleted_total`
   - `idempotency_cleanup_lock_skip_total`
   - `idempotency_cleanup_error_total`

### 3.8 Runtime Guardrail Release-Gate 契約

release gate は runtime snapshot と任意 baseline snapshot を入力に、次の severity を返す：

- `blocker`：即時停止
- `high`：リリース停止対象の回帰
- `warning`：停止はしないが要追跡
- `spike_alerts`：ベースライン差分の急騰アラート

主要な強制点：

1. quality fallback rate と compare mismatch rate は rollout source 単位で評価する（既定に `prod_mirror` を含む）。
2. SSE fallback の `high` 判定は coverage が最小閾値を超える場合のみ有効。
3. idempotency payload 破損と raw error 漏えいは `blocker` 条件。
4. sync executor full-timeout 三要素（`utilization`、`timeout_count`、`still_running_ratio`）は `blocker` 条件。
5. 監査可能性のため、出力には計算済み `signals` を必須で含める。

## 4. 意思決定ロジック

```python
def worker_loop(queue, scheduler, checkpoint_store):
    while True:
        if scheduler.backpressure_active():
            queue.defer_low_priority()

        task = queue.pop_next()
        if not task:
            continue

        quota = scheduler.reserve(task.tenant_id, task.workflow_id)
        if not quota.granted:
            queue.requeue(task, reason="quota_exceeded")
            continue

        state = checkpoint_store.load_or_init(task.run_id)
        result = run_state_machine_step(task, state)
        checkpoint_store.commit(task.run_id, result.checkpoint)

        if result.failure_event:
            apply_failure_transition(task.run_id, result.failure_event)


def replay_run(run_id, checkpoint_store):
    checkpoints = checkpoint_store.load_all(run_id)
    return deterministic_replay(checkpoints)
```

## 5. 失敗と劣化

1. `retryable_failure` -> 同一 trace で指数バックオフ付き有界再試行。
2. `model_uncertainty_failure` -> fallback model または有界テンプレート出力。
3. `audit_rejection_failure` -> draft を保持し不確実性を追記。
4. `guard_violation_failure` -> 安全回復分岐へ遷移し実行出力を遮断。
5. `tool_failure` -> 決定的劣化経路（`mock` または `skip`）を適用。
6. `policy_failure` -> 公開ポリシーエラーでハードブロック。
7. `systemic_failure` -> 負荷遮断を行い SLA 安全な劣化応答を返す。

runtime ワークロード統制：

- テナント quota を用いたキュー優先制御
- tenant/workflow 単位の同時実行上限
- 遅延とキュー深度に基づく backpressure
- token・memory・実行スロット予算による資源スケジューリング
- sync executor snapshot は backpressure/timeout カウンタを公開し、runtime guardrail リリース判定に利用する
- 昇格前に guardrail severity 出力（`blocker/high/warning/spike_alerts`）を必ず評価する

## 6. 受け入れシナリオ

1. checkpoint commit 後に worker がクラッシュ：
   - 期待：最後の commit から再開し、モデル再呼び出しなし。
2. 復旧後に同一入力を replay：
   - 期待：最終出力と state hash chain が一致。
3. キュー深度が backpressure 閾値を超過：
   - 期待：低優先タスクを延期し高優先 SLA を維持。
4. テナント token quota 超過：
   - 期待：quota ポリシーで再キューまたは拒否。
5. second-pass timeout profile が上限に到達：
   - 期待：metadata の `resolved_seconds == max_seconds`。
6. required ステージで tool_failure 発生：
   - 期待：決定的失敗遷移と構成済み劣化を適用。
7. second-pass で audit rejection 発生：
   - 期待：draft 保持、challenge は本文ストリーム非表示。
8. 負例：replay 用 checkpoint が欠落：
   - 期待：replay を拒否し明示的整合性エラーを返す。
9. replay 入力が可観測ノイズのみ異なる：
   - 期待：fingerprint は不変。
10. replay が unsupported と判定：
   - 期待：replay metadata はゼロカウンタと空 journal を返す。
11. replay snapshot に非 owned キーが含まれる：
   - 期待：適用時に非 owned キーは無視される。
12. sync idempotent replay（同一 key/hash）：
   - 期待：キャッシュ payload を返し、`idempotency_replay=true` を付与。
13. stream idempotent replay（同一 key/hash）：
   - 期待：終端 replay を返し、`X-Idempotent-Replay: true` を付与。
14. idempotency key が異なる payload hash と衝突：
   - 期待：`409` を返し、pipeline の重複実行は発生しない。
15. 削除済みセッション API アクセス：
   - 期待：`410` と `SESSION_GONE` を返す。
16. 定期 idempotency cleanup：
   - 期待：stale `in_progress` は `expired` へ遷移し、retention 超過の終端レコードは削除される。
17. TTFT v2 flag-gated プロファイル：
   - 期待：ストリーム遅延系の有効フラグが強制オンになり、`first_meaningful_content_ms` が記録される。
18. runtime guardrail coverage-aware SSE ゲート：
   - 期待：coverage 不足時は SSE fallback の `high` を抑制し warning を出す。

## 7. 互換性とバージョニング

- checkpoint 記録の任意項目追加は minor 互換。
- 状態直列化形式変更は明示的な version 増分が必要。
- 失敗タイプ名称変更は major 互換破壊。
- metadata フィールド追加は後方互換、削除は major 改定が必要。

## 8. クロスリファレンス

- [Runtime 能力マップ](./runtime-capability-map.ja.md)
- [Execution Safety Envelope Runtime](./execution-safety-envelope-runtime.ja.md)
- [エラー分類と可観測性仕様](./error-taxonomy-observability.ja.md)
- [Second-Pass Audit マージポリシー](./second-pass-audit-merge-policy.ja.md)
- [Runtime Boundary Schema v1](../../examples/contracts/runtime-boundary.schema.v1.json)
- [Artifact Lifecycle Schema v1](../../examples/contracts/artifact-lifecycle.schema.v1.json)
- [Second-Pass Timeout Profile Schema v1](../../examples/contracts/second-pass-timeout-profile.schema.v1.json)
