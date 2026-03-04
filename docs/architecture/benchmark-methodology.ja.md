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

## 3. ベースラインとアブレーション構成

主要制御の寄与を分離できるよう、コンポーネント行列を使用する。

| Profile | Diagnosis | Second Pass | Anchor Guard | Quality Gate | State Machine |
|---|---|---|---|---|---|
| `prompt_only` | off | off | off | off | off |
| `diagnosis_only` | on | off | off | off | on |
| `diagnosis_plus_audit` | on | on | off | off | on |
| `full_no_anchor_guard` | on | on | off | on | on |
| `full_no_quality_gate` | on | on | on | off | on |
| `full_no_second_pass` | on | off | on | on | on |
| `full_pipeline` | on | on | on | on | on |

報告必須項目：

1. 各 profile の絶対指標値
2. `full_pipeline` 比の差分
3. アブレーション差分に基づくコンポーネント寄与説明

## 4. 指標定義

1. Evidence Quality Rate

`anchored_facts / total_facts`

2. Non-Echo Ratio

`non_echo_audits / valid_audits`

Non-echo 計算は second-pass merge policy に従うこと：

- 語彙重複閾値 `< 0.85`
- 意味類似度閾値 `< 0.92`
- デフォルト埋め込み backend `sentence-transformers/all-MiniLM-L6-v2`

別 backend を使う場合は、モデル ID と再較正閾値を報告すること。

3. Unsafe Output Suppression

`blocked_or_degraded_under_missing_anchors / risky_code_requests_with_missing_anchors`

4. Degradation Correctness

`correct_fallback_runs / runs_that_should_degrade`

ここで `runs_that_should_degrade = count(oracle_should_degrade=true の run)`。

5. Final Consistency

`runs_with_contract_consistent_final / total_runs`

## 5. Degrade Oracle（機械実行可能）

### 5.1 述語定義

`oracle_should_degrade = p1 OR p2 OR p3 OR p4 OR p5`

- `p1 = diagnosis.insufficient_evidence`
- `p2 = requires_executable AND anchor_score < 0.80`
- `p3 = audit_status in {invalid, echo, weak}`
- `p4 = quality_gate_result in {soft_fail, hard_fail}`
- `p5 = terminal_state in {S_FAIL_RETRYABLE, S_FAIL_TERMINAL}`

`oracle_reason` は複数ラベル集合：

- `insufficient_evidence` は `p1`
- `missing_anchor` は `p2`
- `invalid_audit` は `p3` かつ `audit_status in {invalid, echo}`
- `weak_audit` は `p3` かつ `audit_status=weak`
- `quality_gate_fail` は `p4`
- `fail_state` は `p5`

### 5.2 `runs_that_should_degrade` の真値ソース

手動ラベルの曖昧さを避けるため、degrade oracle は固定参照実行から生成する。

1. 各タスクを `full_pipeline` 参照 profile で 1 回実行。
2. 永続化成果物から oracle 述語を抽出。
3. `oracle_should_degrade` と `oracle_reason` をデータセット列へ書き戻す。
4. 以後の全 baseline 比較でこの凍結ラベルを使用する。

この凍結ラベル集合が `runs_that_should_degrade` の分母ソースとなる。

## 6. 計測プロトコル

1. データ分割と入力プロンプトを固定。
2. 先に参照 `full_pipeline` 実行で oracle ラベルを生成して凍結。
3. すべての baseline profile を同一要求集合で実行。
4. 生イベント、diagnosis、audit、final 出力を永続化。
5. 永続化成果物と凍結 oracle ラベルのみで指標を算出。
6. サンプル数が十分なら信頼区間を報告。

## 7. データセット仕様

必要列とサンプルは [`examples/contracts/benchmark-dataset-spec.md`](../../examples/contracts/benchmark-dataset-spec.md) を参照。

## 8. レポートテンプレート

最低限含める内容：

- データセット定義とサンプリング方法
- profile 行列とトグル
- 公式付き指標テーブル
- oracle ルールと理由分布
- `full_pipeline` 比のアブレーション差分
- 失敗モード例
- 再現性チェックリスト

## 9. 受け入れ基準

1. 指標式が機械的に検証できる。
2. `runs_that_should_degrade` は決定論的な凍結 oracle ラベル由来である。
3. profile トグルが完全に宣言される。
4. データセットと分割がバージョン管理される。
5. 他チーム再実行で同一ロジックと比較可能な傾向が得られる。
