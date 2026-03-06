# Action/Tools システム契約

## 1. スコープ

本仕様は公開 action/tools runtime 契約を定義する。
ツール呼び出しエンベロープ、実行ゲート、隔離フック、失敗分類を標準化する。

対象外：

- private tool 実装コード
- provider 資格情報と secret 配布詳細
- 非公開インフラ plugin 配線

## 2. 問題定義

tool 実行は runtime で最も高リスクな面である。
代表的失敗モード：

- 無制限 retry によるキュー増幅
- idempotency key なしの副作用呼び出し
- 暗黙ルーティングによる未許可 tool 実行
- tool 出力のユーザー本文ストリーム漏洩

## 3. 契約 / データモデル

### 3.1 ツール呼び出し契約

| フィールド | 型 | 意味 |
| --- | --- | --- |
| `tool_name` | string | allowlist 済み公開 tool ID |
| `call_id` | string | 追跡用一意 call ID |
| `idempotency_key` | string | replay と重複排除の決定キー |
| `input_schema_version` | string | 版管理された入力契約キー |
| `timeout_ms` | integer | 実行 timeout 予算 |
| `max_retries` | integer | retry 上限回数 |
| `sandbox_profile` | string | 実行隔離 profile 参照 |
| `output_channel` | string | `internal | artifact` |

### 3.2 ツール結果契約

| フィールド | 型 | 意味 |
| --- | --- | --- |
| `call_id` | string | 要求 call ID と一致 |
| `status` | string | `ok | timeout | rejected | failed` |
| `error_class` | string | `ok` 以外の失敗分類 |
| `artifact_ref` | string | tool 出力 artifact ID |
| `latency_ms` | integer | 実測 tool 実行遅延 |
| `replay_source` | string | `live | checkpoint` |

## 4. 意思決定ロジック

```python
def execute_tool_call(request, boundary, quotas, checkpoint_store):
    if request.tool_name not in boundary.allowlisted_tools:
        return reject_tool_call(request, "guard_violation_failure")

    if quotas.tool_calls_used >= boundary.budget.tool_call_budget:
        return reject_tool_call(request, "systemic_failure")

    cached = checkpoint_store.lookup_tool_result(request.idempotency_key)
    if cached is not None:
        return cached.with_replay_source("checkpoint")

    result = run_in_sandbox(request)
    checkpoint_store.save_tool_result(request.idempotency_key, result)
    return result.with_replay_source("live")
```

## 5. 失敗と劣化

1. allowlist 違反 -> `guard_violation_failure` で即時拒否。
2. timeout かつ retry 予算あり -> `retryable_failure` で再試行。
3. timeout かつ retry 予算枯渇 -> `tool_skipped` artifact に劣化。
4. idempotency key なし副作用呼び出し -> `policy_failure` で遮断。
5. 不明な tool 例外 -> `tool_failure` としてサニタイズ済み error artifact を返す。

劣化優先順位：

1. replay-safe キャッシュ結果
2. 決定的 fallback tool
3. tool データなしの有界部分出力

## 6. 受け入れシナリオ

1. allowlist 済み tool + 妥当 input schema：
   - 期待：1 回実行して結果 artifact を永続化。
2. 同一 idempotency key の replay 実行：
   - 期待：checkpoint 結果を返し、live tool は呼び出さない。
3. tool timeout で retry 予算あり：
   - 期待：`retryable_failure` 分類で予算内再試行。
4. tool timeout で retry 枯渇：
   - 期待：`tool_skipped` 劣化経路へ遷移。
5. モデルが未許可 tool を要求：
   - 期待：`guard_violation_failure` で遮断。
6. tool 出力が `internal` 指定：
   - 期待：ユーザー本文ストリームに出さない。
7. 負例：`idempotency_key` 欠落：
   - 期待：`policy_failure` として実行拒否。

## 7. 互換性とバージョニング

- tool 名は各 major 系統で安定公開 ID とする。
- 結果の任意フィールド追加は minor 互換。
- idempotency 意味変更は major 契約変更。
- 入力 schema version 更新時は migration notes を必須とする。

## 8. クロスリファレンス

- [Runtime 能力マップ](./runtime-capability-map.ja.md)
- [Execution Safety Envelope Runtime](./execution-safety-envelope-runtime.ja.md)
- [Agent Pipeline 契約 Profile](./agent-pipeline-contract-profile.ja.md)
- [Runtime 信頼性メカニズム](./runtime-reliability-mechanisms.ja.md)
