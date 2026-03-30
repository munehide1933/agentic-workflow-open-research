# AgenticAI と Open-Source の能力整合（2026-03）

## 1. スコープ

本書は、AgenticAI の現行実装ベースラインを本リポジトリの公開 open-research アーキテクチャ文書と整合させるための仕様である。

対象は公開可能な制御プレーン挙動と契約レベルの意味論に限定する。

対象外：

- private prompt の内部仕様
- 配備トポロジーおよび private infra 詳細
- ローカル実行オペレータと非公開ランタイム内部

## 2. ベースラインと証跡ソース

整合ベースライン日付：`2026-03-23`

実装側証跡：

- ランタイムモジュール（`backend/core`, `backend/app`, `backend/database`, `backend/services`）
- API 面（`backend/app/main.py`）
- `backend/tests` の契約テスト

本整合で使用した挙動証跡：

1. `test_runtime_boundary_contract_v1.py`
2. `test_unified_step_runner_contract.py`
3. `test_chat_streaming_contract_v1.py`
4. `test_ui_message_stream_parts_mapping.py`
5. `test_pipeline_metadata_ssot_contract.py`
6. `test_second_pass_timeout_profile_contract.py`
7. `test_second_pass_confirmation_contract.py`
8. `test_chat_idempotency_contract.py`
9. `test_deleted_session_access_contract.py`
10. `test_request_context_contract.py`
11. `test_health_contract.py`
12. `test_runtime_timeline_metadata_contract.py`
13. `test_arbitration_ledger_decision_projection.py`
14. `test_sync_executor_backpressure_contract.py`
15. `test_sync_executor_timeout_observability_contract.py`
16. `test_ops_runtime_metrics_contract.py`
17. `test_artifact_diff_contract.py`
18. `test_artifact_api_list_detail_download.py`
19. `test_quality_kernel_adapter_contract.py`
20. `test_quality_kernel_review_batch_adapter_contract.py`
21. `test_quality_kernel_regex_cache_contract.py`
22. `test_quality_kernel_rust_helpers_contract.py`
23. `test_ui_message_stream_rust_frame_builder_contract.py`
24. `test_ttft_v2_flag_gated_contract.py`
25. `test_idempotency_cleanup_contract.py`
26. `test_runtime_guardrails_script_contract.py`
27. `test_runtime_guardrail_release_flow_contract.py`

## 3. 能力整合マトリクス

| 能力ライン | AgenticAI 実装証跡 | 現在の Open-Source カバレッジ | 整合方針 |
| --- | --- | --- | --- |
| ストリーミング出力契約とユーザー面分離 | pipeline ストリームイベント + UI message stream adapter + streaming テスト | SSE 契約は存在するが adapter レベル replay/final-override の明示が不足 | SSE profile に replay ヘッダー、終端 replay ルール、final-override 挙動を同期 |
| Runtime boundary と failure-class 遷移 | `runtime_contract.py`、`step_runner.py`、runtime boundary テスト | reliability/error taxonomy に runtime boundary metadata は反映済み | 決定的遷移マッピングを維持して整合継続 |
| second-pass 実行とサニタイズ | second-pass mode/timeout/trust/no-effect/error sanitize テスト | merge policy と timeout profile schema は既存 | signals-only 本文ルールを明示して整合維持 |
| API idempotency replay（sync + stream） | chat ルートの idempotency 予約/回放/409 競合テスト | tool レベル idempotency はあるが API replay 契約は未明示 | runtime reliability に `Idempotency-Key` 契約を追加 |
| request 相関と公開エラー封筒 | request context middleware + exception handler 契約 | error/observability 文書に `request_id` 必須条件が不足 | `request_id` を公開相関の必須項目として追加 |
| runtime timeline と遷移診断 | runtime timeline metadata テスト + transition projection テスト | runtime quality 基線はあるが timeline/transition が不足 | `runtime_quality.performance.runtime_timeline` と `transition_records` を追加 |
| 仲裁決定の可視化 | arbitration ledger projection テスト + UI `data-arbitration` part | pipeline 文書にルーティング記述はあるが仲裁 payload 構造が不足 | observability 基線に `arbitration_ledger` と `arbitration_summary` を追加 |
| backpressure と timeout 可観測性 | sync executor backpressure/timeout テスト + ops metrics ペイロード | reliability 文書は概念記述中心 | runtime ops 可視性として sync executor snapshot 意味論を追加 |
| Rust quality kernel rollout と整合性ガバナンス | Rust adapter fallback/compare-mode テスト + rollout source ラベル + mismatch カウンタ | 公開文書に rollout ラベル、compare 分母、fallback 理由集合の契約が不足 | observability/reliability に rollout source、fallback taxonomy、request 単位 mismatch rate を追加 |
| Rust SSE frame builder rollout | `status`/`text-delta` の Rust エンコード parity/fallback テスト | SSE 文書は投影ルールのみで、エンジン切替時の parity/fallback が未定義 | SSE 契約に byte 等価、フォールバック、メトリクス面を追加 |
| TTFT v2 flag-gated レイテンシプロファイル | `TTFT_V2_ENABLED` と `first_meaningful_content_ms` の契約テスト | TTFT v2 で強制有効化される実行フラグが文書化不足 | reliability/observability に v2 有効フラグとレイテンシ指標契約を追加 |
| idempotency cleanup ライフサイクル | cleanup scheduler + cleanup 契約テスト（`in_progress` 失効、終端保持の掃除） | API replay 契約はあるが定期 cleanup セマンティクスが不足 | reliability に stale reclaim、状態遷移、cleanup メトリクスを追加 |
| runtime guardrail リリースゲート | ルール判定テスト（`blocker/high/warning/spike`）+ preprod リリースフロー試験 | 既存文書に severity モデルと spike capture 意味論が不足 | observability 基線に severity クラスと信号マッピングを追加 |
| health と起動契約 | `/api/health` ペイロード契約 + lifespan 起動テスト | 公開文書で health フィールド集合が固定されていない | health 契約説明と受け入れシナリオを追加 |
| 決定的 replay と transactional checkpoint 復旧 | replay guardrails はあるが transactional replay log は未完 | vNext hardening でギャップ管理済み | 実装完了まで roadmap gap として維持 |

## 4. 本改定で同期した公開契約差分

1. `SSE response contract`：
   - transport profile ヘッダー（`x-vercel-ai-ui-message-stream: v1`、`X-Idempotent-Replay`）
   - 同一 `Idempotency-Key` の replay ルール：pipeline 再実行なしで権威終端ペイロードを返す
   - ストリーミング本文と権威終端本文が不一致の場合の `data-final-override` 投影
2. `Observability/error taxonomy`：
   - `request_id` を公開エラーペイロード/構造化ログの必須相関項目として追加
   - runtime quality 追加：`performance.runtime_timeline`、`performance.transition_records`
   - 仲裁可視化基線：`runtime_quality.arbitration_ledger`、`runtime_quality.arbitration_summary`
3. `Runtime reliability`：
   - sync/stream エンドポイントの API レベル idempotency 契約
   - 競合意味論：同 key + 異なる hash -> `409`、in-progress key -> `409`
   - セッション削除意味論：未存在 `404`、削除済みライフサイクル `410`
4. `Runtime ops 可視性`：
   - sync executor snapshot フィールド（`inflight`、`max_inflight`、timeout/backpressure counters）
   - `/api/ops/runtime-metrics` 基線（`settings_fingerprint`、`settings_reload_count`）
5. `Rust rollout ガバナンス`：
   - quality kernel rollout source 契約（`staging_replay`、`prod_mirror`、`unknown`）
   - compare-mode の request 分母契約（`quality_kernel_compare_requests_total` と mismatch 指標）
   - quality kernel / UI stream frame builder の fallback 理由集合（`disabled`、`import_error`、`runtime_error` など）
6. `idempotency cleanup ライフサイクル`：
   - 単一ホストロック付きの定期 cleanup scheduler
   - stale `in_progress` レコードを `expired` へ遷移
   - 終端レコードを retention で削除
7. `TTFT v2 runtime profile`：
   - `TTFT_V2_ENABLED=true` では stream-first/chunked/early-flush と early-preview が強制有効
   - runtime quality performance に `first_meaningful_content_ms` を明示
8. `runtime guardrail リリースゲート`：
   - severity クラス `blocker | high | warning | spike`
   - rollout 品質/SSE fallback rate は coverage 閾値を満たす場合のみ強制判定

## 5. 境界と公開ルール

実装挙動を open-research 文書へ同期する際は次を守る：

1. 制御プレーン挙動と公開契約のみを公開する
2. private prompt、秘密情報、private infra 詳細を含めない
3. 実装挙動を決定的かつテスト可能な規則で表現する
4. 契約フィールド拡張時は互換性ルールを明示する

## 6. 受け入れシナリオ

1. Streaming ホワイトリストと順序：
   - 入力：混在 source/phase チャンク（`answer`、`quote`、`audit_delta`、`final_delta`）
   - 期待：allowlist 済みユーザー面コンテンツのみ送出
2. stream idempotent replay：
   - 入力：`/api/chat/stream` へ同一 `Idempotency-Key` + 同一 request hash
   - 期待：終端イベントのみ replay され、`X-Idempotent-Replay: true` が付与される
3. sync idempotent replay：
   - 入力：`/api/chat` へ同一 `Idempotency-Key` + 同一 request hash
   - 期待：キャッシュ済み結果を返し、`idempotency_replay=true`
4. idempotency 競合：
   - 入力：同一 `Idempotency-Key` だが request hash が異なる
   - 期待：`409` 競合、pipeline は重複実行されない
5. request 相関：
   - 入力：`X-Request-ID` が有効/無効/過長のリクエスト
   - 期待：レスポンスは常に `X-Request-ID` を返し、無効値は再生成される
6. 削除済みセッションアクセス：
   - 入力：削除済み session で chat/messages/rollback API を実行
   - 期待：`410` と `SESSION_GONE` を返す
7. runtime quality timeline：
   - 入力：timeline/transition 記録有効の run
   - 期待：終端 metadata に `runtime_quality.performance.runtime_timeline` と `transition_records` が存在
8. 仲裁投影：
   - 入力：モード衝突で仲裁が発火するケース
   - 期待：終端 metadata と UI stream の双方に仲裁決定 payload が存在
9. health エンドポイント契約：
   - 入力：`GET /api/health`
   - 期待：安定フィールド（`service_id`、`service_name`、`api_version`、`time`）を返す
10. Rust quality kernel compare mode：
   - 入力：rollout 有効 + compare サンプリングに命中
   - 期待：主応答契約は不変、mismatch は観測系カウンタのみ更新
11. Rust SSE frame builder の実行時フォールバック：
   - 入力：Rust frame encoder が runtime 例外を送出
   - 期待：stream プロトコルは維持され、fallback カウンタが増加
12. idempotency cleanup スイープ：
   - 入力：stale `in_progress` と retention 超過 `completed` が存在
   - 期待：`in_progress` -> `expired`、古い終端レコード削除
13. TTFT v2 flag-gated 実行：
   - 入力：`TTFT_V2_ENABLED=true`
   - 期待：有効フラグが v2 経路に切替わり、`first_meaningful_content_ms` が記録される
14. runtime guardrail high 判定：
   - 入力：coverage 条件を満たしつつ `quality_fallback_rate[prod_mirror]` が閾値超過
   - 期待：guardrail レポートに `high` が出力され、リリースフローを停止

## 7. フォローアップ作業項目

`P0`：

1. request-context と公開エラー封筒の補足仕様を追加
2. runtime-ops metrics と guardrail release flow の補足仕様を追加
3. `examples/contracts` に idempotency replay payload schema 例を追加
4. quality kernel と SSE frame builder の rollout ゲート指標補足仕様を追加

`P1`：

1. UI message stream mapping 補足仕様（part type マトリクス）を独立公開
2. artifact lifecycle 仕様に replay payload 可視性制約を追加

`Roadmap`：

1. transactional checkpointing
2. deterministic replay log 契約
3. 負荷時のマルチテナント公平性の検証

## 8. クロスリファレンス

- [SSE Response Contract](./sse-response-contract.md)
- [Error Taxonomy and Observability](./error-taxonomy-observability.md)
- [Runtime Reliability Mechanisms](./runtime-reliability-mechanisms.md)
- [Second-Pass Audit Merge Policy](./second-pass-audit-merge-policy.md)
- [Memory Architecture](./memory-architecture.md)
- [State Machine Transition Matrix](./state-machine-transition-matrix.md)
- [Runtime vNext Iteration Plan and Primary Design Goals](./runtime-vnext-iteration-plan.md)
