# Memory システム運用契約

## 1. スコープ

本仕様は runtime memory 挙動を運用契約として定義する。
memory 注入、検索上限、summary checkpoint、可視性制約を標準化する。

対象外：

- private index トポロジーと shard 配置
- private embedding 調整とランキング内部
- インフラ固有の複製実装詳細

## 2. 問題定義

契約なしの memory 運用は暗黙の非決定性を生む。
代表的失敗モード：

- 注入件数の無制限化でコストと遅延が膨張
- stale memory が現在の推論を汚染
- 検索失敗が無言で空文脈になる
- セッション可視性規則がテナント間で破られる

## 3. 契約 / データモデル

### 3.1 Memory ポリシー契約

| フィールド | 型 | 意味 |
| --- | --- | --- |
| `memory_scope` | string | `session | tenant | global` |
| `max_injected_items` | integer | step ごとの注入上限件数 |
| `retrieval_timeout_ms` | integer | memory 検索 timeout 予算 |
| `summary_checkpoint_interval` | integer | summary checkpoint 作成間隔 |
| `min_relevance_score` | number | 注入採用の最小関連スコア |
| `fallback_mode` | string | `sqlite_only | summary_only | no_memory` |
| `visibility_rule` | string | session/tenant 可視性契約キー |

### 3.2 Memory イベント記録

| フィールド | 型 | 意味 |
| --- | --- | --- |
| `run_id` | string | 実行 ID |
| `step_id` | string | pipeline step ID |
| `retrieval_query` | string | 正規化検索クエリ |
| `retrieved_count` | integer | 取得件数 |
| `injected_keys` | array[string] | prompt 注入した memory キー |
| `checkpoint_id` | string | summary checkpoint artifact ID |
| `degradation_path` | string | 適用した劣化経路 |

## 4. 意思決定ロジック

```python
def resolve_memory_context(state, policy, stores):
    records = stores.primary.search(
        query=state.memory_query,
        timeout_ms=policy.retrieval_timeout_ms,
        min_score=policy.min_relevance_score,
        limit=policy.max_injected_items,
    )

    if not records:
        return {"items": [], "degradation": "summary_only"}

    visible = [r for r in records if check_visibility(r, state.session_id, state.tenant_id)]
    return {"items": visible[: policy.max_injected_items], "degradation": None}


def maybe_write_summary_checkpoint(state, policy, stores):
    if state.step_index % policy.summary_checkpoint_interval != 0:
        return None

    summary = build_summary_snapshot(state)
    checkpoint = stores.primary.write_summary(state.session_id, summary)
    return checkpoint.checkpoint_id
```

## 5. 失敗と劣化

1. 主検索 backend timeout -> `summary_only` へ劣化。
2. summary backend 不可用 -> 明示 metadata 付きで `no_memory` へ劣化。
3. 可視性不整合を検出 -> `policy_failure` として該当レコード破棄。
4. `max_injected_items` 超過 -> ランク順で決定的に切り詰め。
5. checkpoint 書き込み失敗 -> run 継続、warning 記録、予算内再試行。

## 6. 受け入れシナリオ

1. session 実行で検索 backend が健全：
   - 期待：高スコアかつ可視なレコードを注入。
2. vector backend 検索 timeout：
   - 期待：summary context のみに劣化。
3. 関連スコア閾値を満たすレコードなし：
   - 期待：空注入 + `summary_only` マーカー。
4. 検索結果にテナント外レコード混入：
   - 期待：可視性規則で遮断し注入しない。
5. checkpoint 間隔に到達：
   - 期待：summary checkpoint artifact を生成。
6. checkpoint 一時書き込み失敗：
   - 期待：非終端 warning、予算内リトライ。
7. 負例：注入件数が上限を超過：
   - 期待：決定的切り詰めとメトリクス加算。

## 7. 互換性とバージョニング

- Memory ポリシーキーの任意追加は minor 互換。
- `visibility_rule` の意味変更は major 変更。
- 新 fallback mode 追加時は受け入れシナリオ更新必須。
- Memory イベントの任意フィールド追加は後方互換。

## 8. クロスリファレンス

- [Runtime 能力マップ](./runtime-capability-map.ja.md)
- [Agent Pipeline 契約 Profile](./agent-pipeline-contract-profile.ja.md)
- [Memory レイヤー仕様](./memory-architecture.ja.md)
- [Runtime 信頼性メカニズム](./runtime-reliability-mechanisms.ja.md)
