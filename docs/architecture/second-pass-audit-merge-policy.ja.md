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

互換ルール：

1. v1 で `audit_completeness` がない場合は推定する。
2. 必須キーが妥当で挑戦内容が十分なら `full`。
3. 形式は妥当だが挑戦強度が不足なら `partial`。
4. schema 検証失敗は `invalid`。

## 4. `is_valid_audit()` 判定

`is_valid_audit()` は次の 3 条件をすべて満たす場合のみ true。

1. schema 妥当性
2. non-echo 判定
3. challenge quality 判定

### 4.1 non-echo 判定

公開デフォルト閾値（私有環境で置換可能）：

- 語彙重複率 `< 0.85`
- 意味類似度 `< 0.92`

両方を超える場合は echo とみなし、マージ拒否。

### 4.2 challenge quality 判定

次のいずれかを満たせば有効：

1. `missing_evidence` に行動可能な不足観測がある。
2. `unsafe_recommendations` が具体的な危険提案を示す。
3. `structure_inconsistencies` が diagnosis と draft の不整合を示す。
4. `counter_hypotheses` が重複しない代替仮説を示す。

## 5. マージ動作

### 5.1 `audit_completeness=full`

- 監査指摘を反映して修正する。
- diagnosis の不変条件を維持する。
- 証拠がある場合のみ結論更新を許可する。

### 5.2 `audit_completeness=partial`

partial salvage で利用可能な項目：

- `missing_evidence`
- `unsafe_recommendations`
- `structure_inconsistencies`

partial salvage で禁止する項目：

- 主原因の確実性を引き上げること
- 新規証拠なしに信頼度ランクを上げること

### 5.3 `audit_completeness=invalid`

- マージを拒否する。
- 安全劣化経路（`invalid_or_partial_audit`）へ遷移する。

## 6. 安全劣化

マージ拒否時は次を行う：

1. draft の有用情報を維持する。
2. 不確実性と検証手順を明示する。
3. 新たな高リスク実行コードを追加しない。

## 7. 参照擬似コード

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

## 8. 受け入れシナリオ

1. full + non-echo + 高品質 challenge => マージ
2. full + echo => 拒否
3. partial + non-echo => partial salvage のみ
4. schema 不正 => 安全劣化
