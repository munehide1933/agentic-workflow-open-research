# ルーティングとモード選択仕様

## 1. スコープ

本仕様は、要求を `basic`、`deep_thinking`、`web_search` のいずれにルーティングするかを定義する。

## 2. 入力特徴

ルーティングは次の特徴ベクトルを使用する。

- `intent_type`: `qa | diagnosis | codegen | architecture | ops`
- `complexity_score`: float `[0, 1]`
- `freshness_need`: float `[0, 1]`
- `external_lookup_required`: boolean
- `risk_level`: `low | medium | high`
- `requires_executable`: boolean

## 3. 特徴量計算（公開デフォルト）

`complexity_score` と `freshness_need` はルート判定前に算出しなければならない。

### 3.1 `complexity_score`

`complexity_score = 0.35*s1 + 0.25*s2 + 0.20*s3 + 0.20*s4`

- `s1` 多段要求: `min(1.0, estimated_steps / 4)`
- `s2` 制約密度: `min(1.0, explicit_constraints_count / 6)`
- `s3` 成果物要求: コード/設定/手順出力が必要なら `1.0`、それ以外 `0.0`
- `s4` 曖昧性ペナルティ: 主要エンティティ欠落 `1.0`、部分指定 `0.5`、それ以外 `0.0`

### 3.2 `freshness_need`

`freshness_need = 0.50*f1 + 0.30*f2 + 0.20*f3`

- `f1` 明示的鮮度意図: `latest`、`today`、`this week` や日付/バージョン依存要求を含む場合 `1.0`
- `f2` 可変ドメイン信号: 価格、リリース、障害ステータス、ポリシー更新など可変領域なら `1.0`
- `f3` 検証意図: check/search/verify を明示要求する場合 `1.0`

実装がこの抽出器を置換する場合は、次を公開すること。

1. 抽出器 ID/バージョン
2. キャリブレーションデータセット要約
3. 比較可能性のための等価閾値

## 4. 判定ルール

公開デフォルトルール：

1. `external_lookup_required=true` または `freshness_need >= 0.70` なら `web_search`。
2. それ以外で `complexity_score >= 0.65` または `risk_level=high` なら `deep_thinking`。
3. それ以外は `basic`。

## 5. フォールバックルール

1. `web_search` timeout/failure -> `deep_thinking` にフォールバックし `insufficient_evidence=true` を設定。
2. `deep_thinking` timeout -> `basic` の verification-first 出力へフォールバック。
3. `basic` から `deep_thinking` への昇格はループガード許可時のみ。

## 6. ループガード（必須）

`basic -> deep_thinking -> basic` 循環を防ぐため：

1. `max_deep_escalations_per_run = 1`
2. 同一 run 内で `deep_thinking` timeout 済みなら `basic -> deep_thinking` を禁止。
3. フォールバック回数が `2` に達したら run 残りを `basic` にロック。
4. ロック時は verification-first 出力を必須とする。

必須 route-state フラグ：

- `deep_timeout_seen`: boolean
- `deep_escalation_count`: integer
- `mode_lock`: `none | basic`

## 7. `web_search` 証拠フィードバック

信頼度ラベルは検索提供元の生フィールドではなく、システム側 `web_search_evidence_ranker` が付与する。

証拠単位の信頼度スコア：

`evidence_confidence_score = 0.50*r1 + 0.30*r2 + 0.20*r3`

- `r1` ソース信頼性（`official_docs=1.0`、`major_publisher=0.8`、`community_source=0.6`、`unknown=0.4`）
- `r2` 複数ソース一致度（独立ソース間での主張重複）
- `r3` 鮮度適合度（公開日と要求鮮度ウィンドウの一致）

ラベル対応：

- `high`: `score >= 0.80`（重み `1.0`）
- `medium`: `0.55 <= score < 0.80`（重み `0.6`）
- `low`: `score < 0.55`（重み `0.3`）

フィードバック効果：

1. 集約信頼度が低い場合 `insufficient_evidence=true` を設定可能。
2. 仮説順位付けは証拠重みを反映しなければならない。
3. 鮮度証拠不足は `required_fields` に追加する。

## 8. 決定性とログ

各 run で次を永続化すること：

- 選択モード
- 特徴量値
- マッチしたルール ID
- フォールバック経路（存在する場合）
- ループガード状態（`deep_timeout_seen`, `deep_escalation_count`, `mode_lock`）
- `web_search` 利用時の信頼度ラベルと分解スコア（`r1`, `r2`, `r3`）

## 9. 受け入れシナリオ

1. 高鮮度要求 -> `web_search`。
2. 鮮度要求なし高複雑度 -> `deep_thinking`。
3. 低複雑度かつ低リスク -> `basic`。
4. `web_search` 失敗 -> フォールバックかつ不確実性フラグ設定。
5. `deep_thinking` timeout 後に `basic` 不確実性上昇 -> 再昇格ループなし。
6. 同一 query は同一抽出器下で安定したモード選択になる。
