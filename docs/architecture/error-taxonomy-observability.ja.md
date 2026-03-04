# エラー分類と可観測性仕様

## 1. スコープ

本仕様は公開エラー名前空間、必須ログ項目、トレース連携ルールを定義します。

## 2. エラーコード名前空間

公開プレフィックス：

- `E_MODEL_*`: モデル提供者/実行時エラー
- `E_SCHEMA_*`: schema 検証・解析エラー
- `E_TIMEOUT_*`: ステージタイムアウト
- `E_POLICY_*`: ポリシー/ガード違反
- `E_ROUTER_*`: ルーティング判定失敗
- `E_MEMORY_*`: メモリ read/write/search 失敗
- `E_CONCURRENCY_*`: セッション同時実行衝突

必須公開コード：

- `E_CONCURRENCY_CONFLICT`（同一セッション同時実行の拒否）

## 3. 終端エラーフィールド

終端エラーには必ず以下を含める：

- `error_code`
- `error_message`
- `retryable`
- `phase`
- `trace_id`
- `run_id`
- `session_id`

## 4. 構造化ログ契約

必須フィールド：

- `ts`
- `level`
- `trace_id`
- `run_id`
- `session_id`
- `phase`
- `state`
- `event`
- `error_code`（存在時）
- `latency_ms`

任意フィールド：

- `mode`
- `rule_id`
- `fallback_path`
- `quality_gate_decision`
- `anchor_score`

## 5. トレース連携ルール

1. 1 ユーザー要求は 1 `run_id`。
2. `trace_id` は複数サービスを跨いで共有可能。
3. 同一 run のステージログと SSE イベントは `trace_id` と `run_id` を共有する。
4. リトライ時は新しい `run_id` を払い出し、`trace_id` は維持する。

## 6. SSE エラー写像

SSE `error` ペイロードには公開可能フィールドのみを含め、秘密情報を含めない。

## 7. 受け入れシナリオ

1. モデル timeout で `E_TIMEOUT_STAGE_*` と完全なトレース項目を出力。
2. schema 解析失敗で `E_SCHEMA_INVALID_PAYLOAD` を出力。
3. 同一セッション競合で `E_CONCURRENCY_CONFLICT` を出力。
4. 全エラーイベントを `trace_id` + `run_id` で結合できる。
