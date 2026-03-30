# SSE レスポンス契約（v1）

## 1. スコープ

本書はエージェント応答の公開ストリーム契約を定義します。
実装方式には依存せず、`basic`、`deep_thinking`、`web_search` の全モードに適用されます。

## 2. イベントエンベロープ

すべての SSE イベントは次の共通フィールドを持ちます。

- `event_type`: `status | content | final | error`
- `trace_id`: 分散トレース用のグローバル ID
- `run_id`: 1 回の `run_agent` 実行 ID
- `session_id`: 会話セッション ID
- `seq`: `1` 始まりの単調増加シーケンス
- `ts`: RFC 3339（UTC）タイムスタンプ
- `payload`: イベント別ペイロード
- `terminal`: 終端フラグ（boolean）

契約ルール：

1. 同一 `run_id` 内で `seq` は厳密に増加すること。
2. `terminal=true` は `final` または `error` のみ許可。
3. 1 run あたり終端イベントは 1 回のみ。
4. 終端イベント後の追加イベント送信は禁止。

### 2.1 トランスポートヘッダーと replay プロファイル

現行 runtime のストリーム伝送は次のレスポンスヘッダーを公開する：

- `x-vercel-ai-ui-message-stream: v1`（UI message stream 投影プロファイル）
- `X-Idempotent-Replay: true`（同一 `Idempotency-Key` のキャッシュ replay 時）

replay ルール：

1. replay は権威終端ペイロード（`final` またはサニタイズ済み `error`）を返し、pipeline ステージを再実行しない。
2. replay ストリームは中間の processing status 分片を送らない。
3. sync エンドポイントの replay 応答には `idempotency_replay=true` を含める。

### 2.2 Frame Builder エンジン互換プロファイル

runtime は UI stream の `status` と `text-delta` を、既定の Python encoder または Rust frame builder のいずれかでエンコードできる。

契約ルール：

1. 同一入力に対し、両エンジンの出力 frame 文字列は byte 等価であること。
2. エンジン切替でストリームプロトコル形状（`start`、`text-start`、`text-delta`、`text-end`、`finish-step`、`finish`、`[DONE]`）を変えてはならない。
3. Rust 経路が失敗した場合、stream 完了セマンティクスを壊さず Python 経路へフォールバックすること。
4. フォールバック理由は閉じたラベル集合で可観測にする：
   - `disabled`
   - `import_error`
   - `runtime_error`
   - `invalid_output`
5. rollout source ラベルは次に正規化する：
   - `staging_replay`
   - `prod_mirror`
   - `unknown`

可観測カウンタ：

- `ui_stream_frame_builder_eligible_events_total{source,event_type}`
- `ui_stream_frame_builder_encoded_events_total{source,event_type,engine}`
- `ui_stream_frame_builder_rust_encoded_events_total{source,event_type}`
- `ui_stream_frame_builder_fallback_events_total{source,event_type,reason}`
- `ui_stream_rust_frame_builder_fallback_total{reason}`

## 3. イベント種別

### 3.1 `status`

`status` はフェーズ遷移と進捗を通知します。

必須ペイロード：

- `phase`: `understand | diagnose | draft | audit | finalize | render`
- `code`: ステータスコード（例: `phase_enter`, `timeout_warning`）
- `message`: 短い説明文

任意ペイロード：

- `progress`: `[0, 1]`
- `retryable`: boolean

`status` は非終端（`terminal=false`）です。

### 3.2 `content`

`content` は増分テキストを運びます。

必須ペイロード：

- `delta`: テキスト差分

任意ペイロード：

- `channel`: `text | artifact`
- `source`: ユーザー本文チャンクの論理ソース（`answer | quote`）
- `phase`: ストリーム段階ラベル（例 `draft_delta`, `answer_delta`, `quote_delta`）
- `artifact_id`: `channel=artifact` 時の識別子（この場合必須）
- `chunk_index`: artifact 分割番号

`content` は非終端（`terminal=false`）です。

### 3.3 `final`

`final` は最終応答を返します。

必須ペイロード：

- `answer`: 最終回答テキスト

任意ペイロード：

- `artifacts`: 生成物メタデータ配列
- `quality_gate_result`: `pass | soft_fail | hard_fail`
- `degraded`: boolean

`final` は終端（`terminal=true`）です。

### 3.4 `error`

`error` は終端エラーを返します。

必須ペイロード：

- `error_code`: 名前空間付きコード（`E_*`）
- `error_message`: 簡潔な説明
- `retryable`: boolean

任意ペイロード：

- `phase`: エラー発生フェーズ
- `details`: サニタイズ済み診断情報

`error` は終端（`terminal=true`）です。

## 4. Artifact チャネル意味論

`content.payload.channel=artifact` の場合：

1. `artifact_id` は必須。
2. 消費側は `artifact_id` 単位でチャンクをバッファする。
3. `chunk_index` がある場合、同一 `artifact_id` 内で単調増加が必要。

`final.payload.artifacts` が存在する場合：

1. 各要素は `artifact_id` を必須とする。
2. ストリームで現れたすべての `artifact_id` は `final.payload.artifacts` に 1 回だけ出現する。
3. 各要素は終端状態 `status`（`complete | partial | blocked`）を持つべき。

消費側の統合ルール：

- `content` は artifact 本体の増分受信。
- `final.payload.artifacts` は確定メタデータと完了シグナル。

## 5. 順序とタイムアウト意味論

許可される順序：

`status* -> content* -> (final | error)`

補足ルール：

1. `status` は `content` の前後に出現可能。
2. 即時失敗では `content` が 0 件でもよい。
3. ステージタイムアウト時は可能なら先に `status(code=timeout_warning)` を送る。
4. 終端タイムアウトは `error(error_code=E_TIMEOUT_STAGE_*)` を必須とする。

### 5.1 ユーザー面順序と整合性制約

最初の user-visible `content` チャンク送出前に、次の `status.payload.code` 順序を満たす必要がある：

`mode_selected -> language_locked -> style_mode_locked`

ユーザー本文ストリーム source allowlist：

- 許可: `answer`, `quote`
- ユーザー本文へ禁止: 上記以外の source 値

ユーザー本文ストリーム phase allowlist：

- 許可: `draft_delta`, `answer_delta`, `quote_delta`
- 禁止: `final_delta` と allowlist 外のすべての phase

ストリーミング注記：

- `initial_analysis` のストリーム内容は内部状態用に収集され得るが、ユーザー本文には転送しない

終端整合性制約：

`final.content`（`final.payload.answer` の同義）`== final_answer_text == persisted_answer`

### 5.2 UI Message 投影ノート

内部 pipeline イベントを UI message stream プロトコルへ投影する場合：

1. allowlist 済み phase のみをユーザー可視 `text-delta` に変換する
2. ストリーム本文が最終本文の厳密な接頭辞である場合、不足サフィックスを追加 `text-delta` として補完する
3. ストリーム本文と権威最終本文が不一致の場合、`data-final-override` に権威最終本文を載せて送出する

## 6. バリデーションと拒否条件

次のいずれかが発生したストリームは拒否または隔離対象です。

1. `seq` の重複または非単調。
2. 非終端イベントで `terminal=true`。
3. 終端イベントの重複。
4. `event_type` と `payload` の不整合。
5. 終端後の追加イベント。
6. `content.channel=artifact` なのに `artifact_id` がない。
7. ストリームに出た `artifact_id` が `final.payload.artifacts` に存在しない。
8. ユーザー可視本文の `content.payload.source` が allowlist 外。
9. `final` の回答と永続化済み終端回答が不一致。
10. エンジン切替により frame 形状や終端クローズ挙動が変化する。

## 7. バージョンと互換性

- バージョン: `v1`
- JSON Schema: [`examples/contracts/sse-event.schema.v1.json`](../../examples/contracts/sse-event.schema.v1.json)
- 後方互換ルール: マイナー更新では任意フィールドの追加のみ許可。

## 8. 受け入れシナリオ

1. 正常: `status -> content -> content -> final`
2. タイムアウト: `status(timeout_warning) -> error(E_TIMEOUT_STAGE_AUDIT)`
3. 早期 schema 失敗: `status -> error(E_SCHEMA_INVALID_PAYLOAD)`
4. artifact ストリーム: `content(channel=artifact,artifact_id=A1)* -> final(artifacts に A1 を含む)`
5. 負例: 終端イベントの二重送信
6. stream idempotent replay（同一 key + 同一 hash）：
   - 期待：終端イベントのみ replay され、`X-Idempotent-Replay: true` が返る。
7. sync idempotent replay（同一 key + 同一 hash）：
   - 期待：レスポンス payload に `idempotency_replay=true` を含む。
8. UI 投影で最終本文が分岐した場合：
   - 期待：`data-final-override` が権威最終本文を返す。
9. Rust frame builder parity：
   - 期待：同一入力では Rust/Python の `status` / `text-delta` frame が byte 等価。
10. Rust frame builder runtime fallback：
   - 期待：エンコード実行時エラー時も stream プロトコルは維持され、fallback カウンタが増加する。
