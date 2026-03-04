# Second-Pass Audit マージポリシー

## 1. スコープ

本書は draft 出力と second-pass audit 出力の規範的マージ手順を定義します。

## 2. 入力

- `draft`: 一次生成の候補応答
- `diagnosis`: 診断構造（`facts`、`hypotheses`、`excluded_hypotheses`、`insufficient_evidence`、`required_fields`）
- `audit`: 二次監査オブジェクト（v1 または v2）

## 3. 監査契約バージョン

- v1: [`examples/contracts/second-pass-audit.schema.json`](../../examples/contracts/second-pass-audit.schema.json)
- v2: [`examples/contracts/second-pass-audit.schema.v2.json`](../../examples/contracts/second-pass-audit.schema.v2.json)

### 3.1 v1 の履歴的制約

v1 schema の `counter_hypotheses.minItems = 1` は履歴互換のための制約です。
このため v1 では `counter_hypotheses` が空の partial audit を表現できません。

### 3.2 Producer/Consumer 互換ルール（発効日: March 4, 2026）

1. producer は v2 をデフォルト出力とする。
2. v1 は読み取り互換のみ維持する。
3. 空 `counter_hypotheses` を伴う partial audit は v2 を必須とする。
4. v1 で空 `counter_hypotheses` は schema 不正となり `invalid` 扱い。

## 4. 完全度推定

v1 で `audit_completeness` がない場合は内容品質で推定する：

1. `full`: schema 妥当かつ challenge 信号が十分。
2. `partial`: schema 妥当だが challenge 強度が弱い。
3. `invalid`: schema 検証失敗。

## 5. `is_valid_audit()` 判定

`is_valid_audit()` は次の 3 条件をすべて満たす場合のみ true。

1. schema 妥当性
2. non-echo 判定
3. challenge quality 判定

### 5.1 non-echo 判定

公開デフォルト閾値：

- 語彙重複率 `< 0.85`
- 意味類似度 `< 0.92`

#### 5.1.1 語彙重複の計算

- 文字列を小文字化
- 句読点を除去
- 空白区切りでトークン化
- トークン集合で Jaccard 重複率を計算

#### 5.1.2 意味類似度の計算

再現用デフォルト backend：

- 埋め込みモデル: `sentence-transformers/all-MiniLM-L6-v2`
- ベクトル: モデル既定の文埋め込み
- 類似度: L2 正規化後のコサイン類似度
- draft 比較テキスト: 正規化済み `draft` 本文
- audit 比較テキスト: `counter_hypotheses`、`missing_evidence`、`unsafe_recommendations`、`structure_inconsistencies` を正規化して連結した本文

意味入力の正規化は語彙法と同一（小文字化 + 句読点除去 + 空白正規化）。

別モデルを使う場合：

1. benchmark メタデータにモデル ID を記録
2. 固定キャリブレーションセットで閾値を再調整
3. 再調整閾値を結果と一緒に公開

語彙・意味の両閾値を満たさない場合は echo とみなし、マージ拒否。

### 5.2 challenge quality 判定

次のいずれかを満たせば有効：

1. `missing_evidence` に行動可能な不足観測がある。
2. `unsafe_recommendations` が具体的な危険提案を示す。
3. `structure_inconsistencies` が diagnosis と draft の不整合を示す。
4. `counter_hypotheses` が重複しない代替仮説を示す。

## 6. マージ動作

### 6.1 `audit_completeness=full`

- 監査指摘を反映して修正する。
- diagnosis の不変条件を維持する。
- 証拠がある場合のみ結論更新を許可する。

### 6.2 `audit_completeness=partial`

partial salvage で利用可能な項目：

- `missing_evidence`
- `unsafe_recommendations`
- `structure_inconsistencies`

partial salvage で禁止する項目：

- 主原因の確実性を引き上げること
- 新規証拠なしに信頼度ランクを上げること

### 6.3 `audit_completeness=invalid`

- マージを拒否する。
- 安全劣化経路（`invalid_or_partial_audit`）へ遷移する。

## 7. 安全劣化

マージ拒否時は次を行う：

1. draft の有用情報を維持する。
2. 不確実性と検証手順を明示する。
3. 新たな高リスク実行コードを追加しない。

## 8. 参照擬似コード

```python
def resolve_second_pass(draft, diagnosis, audit):
    completeness = get_audit_completeness(audit)

    if not schema_valid(audit):
        return safe_degrade(draft, "invalid_audit_schema")
    if is_echo(audit, draft):
        return safe_degrade(draft, "echo_audit")
    if not has_minimum_challenge_quality(audit):
        return safe_degrade(draft, "weak_audit")

    if completeness == "full":
        return merge_draft_with_audit(draft, audit, diagnosis)
    if completeness == "partial":
        return merge_partial_salvage(draft, audit, diagnosis)
    return safe_degrade(draft, "invalid_or_partial_audit")
```

## 9. 受け入れシナリオ

1. full + non-echo + 高品質 challenge => マージ
2. full + echo => 拒否
3. partial + non-echo => partial salvage のみ
4. schema 不正 => 安全劣化
5. v1 で `counter_hypotheses` が空 => `invalid`
6. counter_hypothesis なし partial audit => v2 必須
