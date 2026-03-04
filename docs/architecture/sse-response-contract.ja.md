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
- `artifact_id`: `channel=artifact` 時の識別子

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

## 4. 順序とタイムアウト意味論

許可される順序：

`status* -> content* -> (final | error)`

補足ルール：

1. `status` は `content` の前後に出現可能。
2. 即時失敗では `content` が 0 件でもよい。
3. ステージタイムアウト時は可能なら先に `status(code=timeout_warning)` を送る。
4. 終端タイムアウトは `error(error_code=E_TIMEOUT_STAGE_*)` を必須とする。

## 5. バリデーションと拒否条件

次のいずれかが発生したストリームは拒否または隔離対象です。

1. `seq` の重複または非単調。
2. 非終端イベントで `terminal=true`。
3. 終端イベントの重複。
4. `event_type` と `payload` の不整合。
5. 終端後の追加イベント。

## 6. バージョンと互換性

- バージョン: `v1`
- JSON Schema: [`examples/contracts/sse-event.schema.v1.json`](../../examples/contracts/sse-event.schema.v1.json)
- 後方互換ルール: マイナー更新では任意フィールドの追加のみ許可。

## 7. 受け入れシナリオ

1. 正常: `status -> content -> content -> final`
2. タイムアウト: `status(timeout_warning) -> error(E_TIMEOUT_STAGE_AUDIT)`
3. 早期 schema 失敗: `status -> error(E_SCHEMA_INVALID_PAYLOAD)`
4. 負例: 終端イベントの二重送信
