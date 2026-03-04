# Anchor Guard 設計仕様

## 目的

環境アンカーが不完全な場合に、不安全または誤誘導な実行可能提案を遮断する。

## 公開アンカー集合

- runtime
- deployment context
- client SDK
- HTTP client（スタック依存 HTTP 詳細が必要な場合）

## スコアリングモデル（加重和 + 条件付き正規化）

### 重み

- `runtime = 0.35`
- `deployment_context = 0.30`
- `client_sdk = 0.25`
- `http_client = 0.10`

### 次元状態値

- `present = 1.0`
- `partial = 0.5`
- `missing = 0.0`
- `not_applicable = exclude`（分母から除外）

### 公式

`anchor_score = sum(weight_i * value_i) / sum(active_weights)`

`active_weights` には `not_applicable` 以外の次元のみを含める。

## HTTP 次元の適用判定（操作化）

`http_client` は `http_dimension_applicable=true` の場合のみ評価対象とする。
このフラグは理解ステージで算出し、ルート状態に保存しなければならない。

デフォルト決定則：

`http_dimension_applicable = requires_executable AND (intent_type in {codegen, ops, diagnosis}) AND has_http_scope_signal`

次のいずれかを満たすと `has_http_scope_signal=true`：

1. 外部 API 呼び出しロジックの生成または修正を要求している。
2. スタック依存 HTTP 挙動（`headers`、`status`、`retry`、`timeout`、`proxy`、`auth signing`、`TLS`）を要求している。
3. デプロイ文脈に API gateway/webhook/service integration 制約がある。

いずれも満たさない場合は `http_client=not_applicable` とし、分母から重みを除外する。

### 判定例

- `intent_type=codegen`、`requires_executable=true`、課題が「webhook retry client を実装」 -> 適用。
- `intent_type=architecture`、`requires_executable=false`、課題が「pub/sub パターン比較」 -> 非適用。

## 次元判定基準（公開デフォルト）

### Runtime

- `present`: ランタイム系統とバージョン範囲が明示されている。
- `partial`: ランタイム系統のみ分かり、バージョン/範囲が不明。
- `missing`: ランタイム系統が不明。

### Deployment Context

- `present`: デプロイ先/ステージ制約が明示されている。
- `partial`: 環境ヒントはあるが制約が不十分。
- `missing`: デプロイ文脈がない。

### Client SDK

- `present`: SDK 系統と利用可能パッケージ識別/バージョン範囲が明示。
- `partial`: SDK 系統のみ分かり、パッケージ/バージョン範囲が不明。
- `missing`: SDK が未特定。

### HTTP Client

- `present`: 必要時に具体的 HTTP client が明示。
- `partial`: HTTP 利用は示唆されるが client が未確定。
- `missing`: 必要だが不明。
- `not_applicable`: スタック依存 HTTP 詳細が不要。

## 閾値ポリシー（据え置き）

- `score < 0.50`: 実行可能コードを遮断
- `0.50 <= score < 0.80`: 擬似コードのみ許可
- `score >= 0.80`: 実行可能出力候補（Quality Gate 通過が必要）

## Guard 適用インターフェース契約

`enforce_anchor_guard_by_score()` の公開契約：

入力：

- `draft_candidate`: 構造化ドラフト（`answer_text`、任意 `artifacts[]`、任意 metadata）
- `anchor_score`: `[0,1]` 浮動小数
- `route_state.http_dimension_applicable`: boolean

出力：

- `guarded_candidate`: 新しい候補オブジェクト（破壊的更新は必須でない）
- `anchor_guard_result`: `{mode, score, missing_anchors[], reasons[]}`

モード対応：

1. `anchor_score < 0.50` -> `mode=blocked`
2. `0.50 <= anchor_score < 0.80` -> `mode=pseudocode_only`
3. `anchor_score >= 0.80` -> `mode=executable_eligible`

モード別必須動作：

1. `blocked`: 実行可能 artifact を除去し、verification-first ガイダンスへ置換。
2. `pseudocode_only`: 実行オペレータを除去し、非実行擬似コードのみ残す。
3. `executable_eligible`: 実行可能 artifact を保持し、後段 Quality Gate に渡す。

## 再計算可能な例

### 例 A: 高信頼、HTTP 非適用

- runtime=`present`、deployment=`present`、sdk=`present`、http=`not_applicable`
- 分子 = `0.35*1.0 + 0.30*1.0 + 0.25*1.0 = 0.90`
- 分母 = `0.35 + 0.30 + 0.25 = 0.90`
- `anchor_score = 1.00` -> 実行可能出力可

### 例 B: 境界値

- runtime=`present`、deployment=`partial`、sdk=`missing`、http=`missing`（必要）
- 分子 = `0.35*1.0 + 0.30*0.5 + 0.25*0.0 + 0.10*0.0 = 0.50`
- 分母 = `1.00`
- `anchor_score = 0.50` -> 擬似コードのみ

### 例 C: 低信頼

- runtime=`missing`、deployment=`partial`、sdk=`missing`、http=`missing`（必要）
- 分子 = `0.35*0.0 + 0.30*0.5 + 0.25*0.0 + 0.10*0.0 = 0.15`
- 分母 = `1.00`
- `anchor_score = 0.15` -> 実行可能コード遮断

## ポリシー動作

診断不確実性下で実行可能コード要求があり、かつアンカー不備の場合：

1. 単一スタック実行コードを遮断
2. スタック非依存ガイダンスまたは擬似コードを返す
3. 欠落アンカーを前提条件として明示

## Quality Gate との優先関係

1. Anchor Guard が先行。
2. 実行可能資格がある場合のみ Quality Gate を実行。
3. 競合時はより厳しい判定を採用。

## 工学的意義

LLM は構文的に正しくても運用上危険なコードを生成し得る。
Anchor Guard はこのリスクを監査可能な明示ポリシーへ変換する。
