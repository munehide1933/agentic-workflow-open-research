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
