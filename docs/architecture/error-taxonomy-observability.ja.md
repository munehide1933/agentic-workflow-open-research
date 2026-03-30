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
- `request_id`
- `trace_id`
- `run_id`
- `session_id`

## 4. 構造化ログ契約

必須フィールド：

- `ts`
- `level`
- `request_id`
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
2. HTTP 境界では `request_id` を必須とし、レスポンスヘッダー `X-Request-ID` で返す。
3. `trace_id` は複数サービスを跨いで共有可能。
4. 同一 run のステージログと SSE イベントは `trace_id` と `run_id` を共有する。
5. リトライ時は新しい `run_id` を払い出し、`trace_id` は維持する。

## 6. SSE エラー写像

SSE `error` ペイロードには公開可能フィールドのみを含め、秘密情報を含めない。

## 7. Runtime 最終 Metadata 契約

runtime の終端 metadata は次の公開フィールドを必須とする：

- `runtime_boundary`
- `failure_event`
- `output_contract`
- `second_pass.timeout_profile`

これらは追加互換で運用し、minor 更新で既存公開フィールドを削除してはならない。

## 8. メトリクスとトレース基線

必須メトリクス次元：

- `step_latency_ms`（`p50`、`p95`、`p99`）
- `token_input`、`token_output`
- `model_cost`
- `audit_time`
- `guard_rejection_count`
- `retry_count`
- `failure_type_distribution`

rollout / parity ガバナンス用メトリクス：

- `quality_kernel_rollout_calls_total{source,surface}`
- `quality_kernel_rollout_fallback_total{source,surface,reason}`
- `quality_kernel_compare_requests_total{source,surface}`
- `quality_kernel_compare_request_mismatch_total{source,surface}`
- `quality_kernel_parity_mismatch_total{field}`
- `quality_kernel_parity_mismatch_by_source_total{source,surface,field}`
- `ui_stream_frame_builder_eligible_events_total{source,event_type}`
- `ui_stream_frame_builder_encoded_events_total{source,event_type,engine}`
- `ui_stream_frame_builder_rust_encoded_events_total{source,event_type}`
- `ui_stream_frame_builder_fallback_events_total{source,event_type,reason}`
- `ui_stream_rust_frame_builder_fallback_total{reason}`
- `first_meaningful_content_ms`（histogram）
- `idempotency_cleanup_run_total`
- `idempotency_cleanup_expired_total`
- `idempotency_cleanup_deleted_total`
- `idempotency_cleanup_lock_skip_total`
- `idempotency_cleanup_error_total`

トレース階層基線：

- `agent_run_id`
- `step_id`
- `model_call_span`
- `tool_call_span`
- `audit_span`
- `merge_span`

runtime quality ペイロード基線：

- `runtime_quality.stage_snapshots[*]` は `stage`、`model_deployment`、`estimated_tokens_in`、`estimated_tokens_out`、`duration_ms`、`flags` を含む
- `runtime_quality.invariant_gate` は `passed`、`reason_codes`、`metrics`、`fallback` を含む
- `runtime_quality.degradation_flags` は run レベルの劣化マーカーを保持する
- `runtime_quality.performance.runtime_timeline[*]` は `event`、`stage`、`phase`、`status`、`reason_code`、`ts_ms`、`details` を含む
- `runtime_quality.performance.transition_records[*]` は `from_state`、`to_state`、`event`、`action`、`reason_code`、`ts_ms`、`details` を含む
- `runtime_quality.arbitration_ledger` は決定的仲裁決定投影とシグナルスナップショットを含む
- `runtime_quality.arbitration_summary` はユーザー可視の仲裁サマリー項目を含む
- `runtime_quality.performance.general_latency_flags_effective.ttft_v2_enabled` は TTFT v2 の有効プロファイル状態を示す
- `runtime_quality.performance.first_meaningful_content_ms` は preview 以外の最初の有意味コンテンツ遅延を記録する

### 8.1 Runtime Guardrail Severity 契約

runtime guardrail 判定出力は次の 4 つの severity クラスを使う：

- `blocker`
- `high`
- `warning`
- `spike_alerts`

guardrail 出力形状：

- `blocker[]`：即時リリース停止条件
- `high[]`：リリース停止対象の品質/信頼性回帰
- `warning[]`：停止はしないが追跡必須の回帰
- `spike_alerts[]`：ベースライン差分の急騰シグナル
- `signals{...}`：ゲート判定に使う比率信号
- `rollout_primary_sources[]`：強制判定対象の rollout source（既定で `prod_mirror` を含む）

coverage-aware ルール：

- SSE fallback の `high` 判定は coverage が最小閾値（`sse_fallback_eval_min_coverage`）を満たす場合のみ有効。
- coverage 不足時は `high` ではなく warning（`sse_fallback_rate_not_enforced_low_coverage`）を出す。

### 8.2 Regex Cache 診断面（任意）

Rust quality kernel 拡張が利用可能な場合、regex cache 診断として以下を公開できる：

- `hit_total`
- `miss_total`
- `eviction_total`
- `failure_cache_hit_total`
- `entry_count`
- `schema_version`
- `max_entries`

この診断面は観測用途のみで、runtime 挙動分岐の入力にしてはならない。

## 9. 受け入れシナリオ

1. モデル timeout で `E_TIMEOUT_STAGE_*` と完全なトレース項目を出力。
2. schema 解析失敗で `E_SCHEMA_INVALID_PAYLOAD` を出力。
3. 同一セッション競合で `E_CONCURRENCY_CONFLICT` を出力。
4. 全エラーイベントを `trace_id` + `run_id` で結合できる。
5. 終端 metadata が `runtime_boundary`、`failure_event`、`output_contract`、`second_pass.timeout_profile` を含む。
6. メトリクス基盤がステージ単位の遅延分位（`p50/p95/p99`）を出力する。
7. HTTP エラー応答は常に `request_id` と `X-Request-ID` を含む。
8. runtime quality の performance ペイロードに `runtime_timeline` と `transition_records` が含まれる。
9. 仲裁発火 run は `arbitration_ledger` と `arbitration_summary` の両方を含む。
10. compare-mode の request mismatch rate は field mismatch 件数ではなく compare request 総数を分母に使う。
11. coverage が最小閾値未満の場合、guardrail は SSE fallback の `high` 判定を抑制する。
12. idempotency cleanup 実行では run/expired/deleted カウンタが単調更新で報告される。
