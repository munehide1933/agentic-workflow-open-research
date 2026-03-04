# Quality Gate フレームワーク

## 1. スコープ

Quality Gate は Anchor Guard の後に実行可能 artifact を評価する。
Anchor Guard と Quality Gate が競合する場合は、より厳しい判定を採用する。

## 2. 処理順序

1. Anchor Guard が実行可能性を判定する。
2. 実行可能が維持された場合のみ Quality Gate が artifact 品質を評価する。
3. 出力クラスは `pass`、`soft_fail`、`hard_fail`。

## 3. チェック次元

- `syntax_check`: パーサ/バリデータ成功
- `risky_pattern_scan`: 静的危険パターンスキャン
- `semantic_safety_check`: ポリシーと意図整合性

## 4. `risky_pattern_scan` 分類枠組み（公開）

公開分類枠組み（詳細ルール本体は非公開可）：

- `RISK_FS_MUTATION`: 破壊的ファイルシステム操作
- `RISK_NETWORK_EGRESS`: 外部エンドポイントへのネットワーク送信
- `RISK_PRIVILEGE_ESCALATION`: 権限昇格またはセキュリティ境界回避
- `RISK_PROCESS_EXEC`: プロセス起動または shell 実行
- `RISK_CREDENTIAL_HANDLING`: 秘密情報/トークン/鍵の露出や不適切処理
- `RISK_DATA_EXFIL`: 広範囲データ持ち出しや意図しない開示パターン

最小 finding スキーマ：

- `pattern_id`
- `category`
- `severity`: `low | medium | high | critical`
- `evidence_span`

## 5. `semantic_safety_check` の操作化

`semantic_safety_check` は「決定論ルール + 任意モデル検証」の合成で評価する。

1. ルールベース policy matcher（必須）
: 禁止操作、前提不足、権限/スコープ違反を検出する。
2. 意図整合チェッカー（必須）
: 生成アクションがユーザ意図を超過していないか検査する。
3. 検証モデル critique（任意）
: 二次モデルで潜在危険を評価。利用不可時はルールのみで有効。

必須出力フィールド：

- `semantic_findings[]`: `{rule_id, severity, rationale}`
- `intent_drift`: boolean

## 6. リスククラス

- `R0`: 検出リスクなし
- `R1`: 低リスク注意
- `R2`: 中リスク。降格配信が必要
- `R3`: 高リスク。実行可能出力を遮断

## 7. 判定ルール

公開デフォルト対応：

1. `syntax_check=fail` => `hard_fail`
2. `risky_pattern_findings` に `severity=critical` があれば `R3`
3. `semantic_findings` に `severity=critical` があれば `R3`
4. `intent_drift=true` かつ critical なし => 少なくとも `R2`
5. 最大リスククラス `R0-R1` => `pass`
6. 最大リスククラス `R2` => `soft_fail`
7. 最大リスククラス `R3` => `hard_fail`

## 8. 出力契約

`quality_gate_result` オブジェクト：

- `decision`: `pass | soft_fail | hard_fail`
- `risk_classes`: 該当リスククラス一覧
- `blocked_rules`: 発火したルール ID 一覧
- `risky_pattern_findings`: 危険パターン検出一覧
- `semantic_findings`: 意味安全性検出一覧
- `remediation`: 安全代替または検証手順

## 9. Anchor Guard との関係

1. Anchor Guard が実行可能出力を遮断した場合、Quality Gate は再許可できない。
2. Anchor Guard が許可しても、Quality Gate は降格/遮断できる。
3. 最終判定は常により厳しい方を採用する。

## 10. 受け入れシナリオ

1. 構文 OK + 危険パターンなし + 意味所見なし => `pass`。
2. 構文 OK + 中リスク危険パターン => `soft_fail`。
3. 意図ドリフトあり（critical なし） => 少なくとも `soft_fail`。
4. critical 危険パターンまたは意味違反 => `hard_fail`。
5. Anchor Guard で遮断 + Quality Gate で pass => 最終的に実行可能配信は遮断。
