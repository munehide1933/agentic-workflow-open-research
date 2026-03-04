# Quality Gate ルールフレームワーク

## 1. スコープ

Quality Gate は Anchor Guard の後段で実行可能成果物を評価します。
両者が衝突する場合は、より厳しい判定を採用します。

## 2. 処理順序

1. Anchor Guard が実行可能出力の可否を判定。
2. 可の場合のみ Quality Gate を適用。
3. 結果は `pass`、`soft_fail`、`hard_fail`。

## 3. チェック軸

- `syntax_check`: 構文/パーサ検証
- `risky_pattern_scan`: 危険パターンスキャン
- `semantic_safety_check`: 意図とポリシー整合性

## 4. リスク分類

- `R0`: リスクなし
- `R1`: 低リスク注意
- `R2`: 中リスク（劣化出力が必要）
- `R3`: 高リスク（実行可能出力を遮断）

## 5. 判定ルール

公開デフォルト：

1. `syntax_check=fail` => `hard_fail`
2. 最大リスク `R0-R1` => `pass`
3. 最大リスク `R2` => `soft_fail`
4. 最大リスク `R3` => `hard_fail`

## 6. 出力契約

`quality_gate_result` のフィールド：

- `decision`: `pass | soft_fail | hard_fail`
- `risk_classes`: 該当リスク分類一覧
- `blocked_rules`: 発火したルール ID
- `remediation`: 安全代替または検証手順

## 7. Anchor Guard との優先関係

1. Anchor Guard が遮断した場合、Quality Gate は再許可できない。
2. Anchor Guard が許可しても、Quality Gate は劣化/遮断できる。
3. 最終判定は常により厳しい方を採用する。

## 8. 受け入れシナリオ

1. 構文 OK + 危険パターンなし => `pass`
2. 構文 OK + 中リスクパターン => `soft_fail`
3. 構文 NG => `hard_fail`
4. Anchor Guard 遮断 + Quality Gate pass => 最終的に遮断扱い
