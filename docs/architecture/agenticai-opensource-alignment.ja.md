# AgenticAI と Open-Source の能力整合（2026-03）

## 1. スコープ

本書は、AgenticAI の現行実装ベースラインを本リポジトリの公開 open-research アーキテクチャ文書と整合させるための仕様である。

対象は公開可能な制御プレーン挙動と契約レベルの意味論に限定する。

対象外：

- private prompt の内部仕様
- 配備トポロジーおよび private infra 詳細
- ローカル実行オペレータと非公開ランタイム内部

## 2. ベースラインと証跡ソース

整合ベースライン日付：`2026-03-06`

実装側証跡：

- ランタイムモジュール（`backend/core`, `backend/app`, `backend/database`, `backend/services`）
- API 面（`backend/app/main.py`）
- `backend/tests` の契約テスト

本整合で使用した挙動証跡：

1. `test_runtime_boundary_contract_v1.py`
2. `test_unified_step_runner_contract.py`
3. `test_chat_streaming_contract_v1.py`
4. `test_ui_message_stream_protocol_contract.py`
5. `test_pipeline_metadata_ssot_contract.py`
6. `test_second_pass_timeout_profile_contract.py`
7. `test_second_pass_confirmation_contract.py`
8. `test_anchor_guard_policy.py`
9. `test_guard_skips_codegen_and_gate.py`
10. `test_artifact_version_chain_contract.py`
11. `test_artifact_diff_contract.py`
12. `test_artifact_api_list_detail_download.py`

## 3. 能力整合マトリクス

| 能力ライン | AgenticAI 実装証跡 | 現在の Open-Source カバレッジ | 整合方針 |
| --- | --- | --- | --- |
| ストリーミング出力契約とユーザー面分離 | `chat_stream` + UI message stream adapter + streaming 契約テスト | `sse-response-contract.md` に基礎はあるが、実装 profile 制約は未完全 | SSE 基本仕様は維持し、実装 profile 制約を追補 |
| Runtime boundary と failure-class 遷移 | `runtime_contract.py`, `step_runner.py`, runtime boundary テスト | 状態機械/エラー分類文書に部分反映、runtime_boundary metadata 契約は不足 | runtime-boundary metadata 補足仕様と遷移対応を追加 |
| Second-pass 監査の実行ポリシー | second-pass mode/timeout/trust/no-effect テスト | マージ方針は存在、実行モード挙動の記述は部分的 | 確認モードと timeout profile を second-pass 方針へ追加 |
| コード安全境界（anchor + canonical + quality gate） | anchor guard テスト、canonical output テスト、quality gate hard-fail 降格テンプレートテスト | Anchor/Quality 文書は既存 | 整合済みとして扱い、`canonical output mode` と `skipped_guard` severity を次版で追記 |
| Artifact ライフサイクルとバージョンチェーン | artifact 永続化/版管理/diff/API テスト | 専用の公開アーキテクチャ仕様が未整備 | artifact lifecycle 仕様と公開契約 schema を追加 |
| 最終 metadata SSOT と可観測 payload | pipeline metadata builder + metadata テスト | 可観測性文書はあるが runtime payload フィールド不足 | `runtime_boundary`, `failure_event`, `output_contract`, second-pass timeout profile を追記 |
| メモリ層とセキュリティミドルウェア | summary checkpoint、long-memory 挙動、token/rate-limit middleware | memory 文書は部分対応、運用保護の記述は不足 | summary checkpoint と API 保護意味論を runtime-ops 補足として公開 |
| 決定的 replay と checkpoint 復旧 | 部分的な決定性ガードはあるが、transactional replay checkpoint 契約は未実装 | vNext hardening 計画で未充足として定義済み | checkpoint/replay 契約実装まで roadmap gap として維持 |

## 4. 同期すべき公開契約差分

実装挙動と公開文書を一致させるため、次の差分同期が必要：

1. `SSE response contract`：
   - pre-content 状態順序（`mode_selected -> language_locked -> style_mode_locked`）
   - `content` 発火 source のホワイトリスト（ユーザー本文は `answer|quote` のみ）
   - 一致条件（`final.content == final_answer_text == persisted answer`）
2. `Observability/error taxonomy`：
   - runtime payload 標準フィールド（`runtime_boundary`, `failure_event`, `output_contract`）
   - timeout profile と optional-step timeout の意味論
3. `Second-pass merge policy`：
   - trust-gated merge（`UNTRUSTED` は本文を書き換えない）
   - 自動確認挙動（`second_pass_mode=auto`）
   - adaptive timeout profile 契約
   - second-pass-only 時の no-effect summary 挙動
4. `Artifact contracts`：
   - 版管理チェーン（`version_no`, `parent_artifact_id`, `logical_key`）
   - diff API 契約と session スコープ可視性ルール
5. `Runtime governance`：
   - soft depth limit 時の optional step skip
   - required-step timeout の昇格経路

## 5. 境界と公開ルール

実装挙動を open-research 文書へ同期する際は次を守る：

1. 制御プレーン挙動と公開契約のみを公開する
2. private prompt、秘密情報、private infra 詳細を含めない
3. 実装挙動を決定的かつテスト可能な規則で表現する
4. 契約フィールド拡張時は互換性ルールを明示する

## 6. 受け入れシナリオ

1. Streaming ホワイトリストと順序：
   - 入力：状態イベントと混在 source の content（`answer`, `tool`, `audit`）
   - 期待：許可されたユーザー面 content のみ出力され、pre-content ロック順序が維持される
2. Optional step timeout：
   - 入力：optional step（`reflection`）の timeout
   - 期待：failure class は `retryable_failure`、transition action は `skip_optional_step`
3. Required step timeout：
   - 入力：required step（`synthesis_merge`）の timeout
   - 期待：failure class は `systemic_failure`、当該経路は terminal 扱い
4. Artifact version chain：
   - 入力：同一 logical artifact を 2 回保存し詳細を参照
   - 期待：版番号が増分（`1 -> 2`）、parent 連鎖が存在、logical key が安定
5. Artifact diff：
   - 入力：2 バージョン間の unified diff 要求
   - 期待：unified diff 文字列と統計（`added`, `removed`, `changed`）を返す
6. Second-pass 自動確認：
   - 入力：`second_pass_mode=auto`、通常対話フロー（second-pass-only ではない）
   - 期待：second pass は自動実行されず、`next_action=confirm_second_pass` を返す

## 7. フォローアップ作業項目

`P0`：

1. SSE 実装 profile 補足仕様を追加
2. runtime-boundary payload 補足仕様を追加
3. artifact lifecycle アーキテクチャ仕様を追加

`P1`：

1. second-pass 方針へ実行モード契約を拡張
2. observability 方針へ最終 metadata フィールド集合を拡張

`Roadmap`：

1. transactional checkpointing
2. deterministic replay 契約
3. runtime backpressure と multi-tenant quota 統制

## 8. クロスリファレンス

- [SSE Response Contract](./sse-response-contract.md)
- [Error Taxonomy and Observability](./error-taxonomy-observability.md)
- [Second-Pass Audit Merge Policy](./second-pass-audit-merge-policy.md)
- [Anchor Guard Design](./anchor-guard.md)
- [Quality Gate Framework](./quality-gate-framework.md)
- [Memory Architecture](./memory-architecture.md)
- [State Machine Transition Matrix](./state-machine-transition-matrix.md)
- [Runtime vNext Iteration Plan and Primary Design Goals](./runtime-vnext-iteration-plan.md)
