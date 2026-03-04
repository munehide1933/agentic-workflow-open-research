# 信頼性 Benchmark 方法論

## 1. 目的

本書は、アーキテクチャ信頼性の主張を再現可能に評価する方法を定義します。

## 2. ベンチマーク課題セット

推奨バケット：

1. インシデント診断
2. アーキテクチャトレードオフ分析
3. 安全制約付きコード生成
4. コンテキスト不足トラブルシュート
5. 鮮度依存 Q&A

推奨最小規模：合計 500 問、バケット別層化サンプリング。

## 3. ベースライン群

- `prompt_only`: diagnosis 構造なし、second pass なし、guard なし
- `diagnosis_only`: diagnosis 構造あり、second pass なし、anchor/quality 連携なし
- `full_pipeline`: diagnosis + second pass + anchor guard + quality gate + 状態機械統制

## 4. 指標定義

1. Evidence Quality Rate

`anchored_facts / total_facts`

2. Non-Echo Ratio

`non_echo_audits / valid_audits`

3. Unsafe Output Suppression

`blocked_or_degraded_under_missing_anchors / risky_code_requests_with_missing_anchors`

4. Degradation Correctness

`correct_fallback_runs / runs_that_should_degrade`

5. Final Consistency

`runs_with_contract_consistent_final / total_runs`

## 5. 計測プロトコル

1. データ分割と入力プロンプトを固定。
2. すべてのベースラインを同一要求集合で実行。
3. 生イベント、diagnosis、audit、final 出力を永続化。
4. 永続化成果物のみから指標算出。
5. サンプル数が十分なら信頼区間を報告。

## 6. レポートテンプレート

最低限含める内容：

- データセット定義とサンプリング方法
- ベースライン設定
- 公式付き指標テーブル
- 失敗モード例
- 再現性チェックリスト

## 7. 受け入れ基準

1. 指標式が機械的に検証できる。
2. データセットと分割がバージョン管理されている。
3. 他チーム再実行で同一ロジックと比較可能な傾向が得られる。
