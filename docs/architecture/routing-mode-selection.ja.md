# ルーティングとモード選択仕様

## 1. スコープ

本仕様は、要求を `basic`、`deep_thinking`、`web_search` に振り分ける規則を定義します。

## 2. 入力特徴量

以下の特徴ベクトルを使用します。

- `intent_type`: `qa | diagnosis | codegen | architecture | ops`
- `complexity_score`: `[0, 1]` の実数
- `freshness_need`: `[0, 1]` の実数
- `external_lookup_required`: boolean
- `risk_level`: `low | medium | high`
- `requires_executable`: boolean

## 3. 決定ルール

公開デフォルトルール：

1. `external_lookup_required=true` または `freshness_need >= 0.70` の場合は `web_search`。
2. それ以外で `complexity_score >= 0.65` または `risk_level=high` の場合は `deep_thinking`。
3. 上記以外は `basic`。

## 4. フォールバック

1. `web_search` が timeout/failure の場合は `deep_thinking` へフォールバックし、`insufficient_evidence=true` を設定。
2. `deep_thinking` timeout の場合は `basic` の verification-first 出力へフォールバック。
3. `basic` から `deep_thinking` への昇格はループガード許可時のみ。

## 5. ループガード（必須）

`basic -> deep_thinking -> basic` ループ防止のため、以下を適用する。

1. `max_deep_escalations_per_run = 1`
2. 同一 run で `deep_thinking` timeout が発生済みなら再昇格禁止
3. フォールバック回数が `2` に達したら run 終了まで `basic` にロック
4. ロック時は verification-first 出力を必須とする

必須ルート状態フラグ：

- `deep_timeout_seen`: boolean
- `deep_escalation_count`: integer
- `mode_lock`: `none | basic`

## 6. `web_search` 証拠の診断への還流

外部証拠の信頼度ラベル：

- `high` -> 重み `1.0`
- `medium` -> 重み `0.6`
- `low` -> 重み `0.3`

還流効果：

1. 集約信頼度が低い場合は `insufficient_evidence=true` を設定可能。
2. 仮説ランキングは重みを反映する。
3. 鮮度証拠が不足する場合は `required_fields` に追加する。

## 7. 決定性とログ

各 run で次を記録すること：

- 選択モード
- 特徴量値
- マッチしたルール ID
- フォールバック経路（発生時）
- ループガード状態（`deep_timeout_seen`, `deep_escalation_count`, `mode_lock`）

## 8. 受け入れシナリオ

1. 高鮮度要件 => `web_search`
2. 高複雑度かつ低鮮度要件 => `deep_thinking`
3. 低複雑度・低リスク => `basic`
4. `web_search` 失敗 => フォールバック + 不確実性フラグ
5. `deep_thinking` timeout 後に `basic` 不確実性上昇 => 再昇格ループなし
