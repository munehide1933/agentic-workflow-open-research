# 状態機械の完全遷移行列

## 1. 状態集合

- `S0_INPUT_NORMALIZED`
- `S1_UNDERSTANDING_READY`
- `S2_DIAGNOSIS_READY`
- `S3_DRAFT_READY`
- `S4_AUDIT_READY`
- `S5_FINAL_READY`
- `S6_RENDERED`
- `S_FAIL_RETRYABLE`
- `S_FAIL_TERMINAL`

## 2. 並行性ルール

同一セッションは single-flight を必須とする。
同セッションで実行中 run がある場合は `E_CONCURRENCY_CONFLICT` を返す。

## 3. 遷移行列

| From | To | Guard | Notes |
|---|---|---|---|
| `S0_INPUT_NORMALIZED` | `S1_UNDERSTANDING_READY` | 入力正規化成功 | 制御フロー開始 |
| `S1_UNDERSTANDING_READY` | `S2_DIAGNOSIS_READY` | 診断が必要かつ最小観測性を満たす | 不要時は直接 draft |
| `S1_UNDERSTANDING_READY` | `S3_DRAFT_READY` | 直接回答経路を選択 | 診断分岐をスキップ |
| `S2_DIAGNOSIS_READY` | `S3_DRAFT_READY` | diagnosis schema 妥当 | draft 合成へ |
| `S3_DRAFT_READY` | `S4_AUDIT_READY` | second pass 対象 | 高リスクまたは対象ドメイン |
| `S3_DRAFT_READY` | `S5_FINAL_READY` | second pass 不要 | 直接 finalize |
| `S4_AUDIT_READY` | `S5_FINAL_READY` | 監査有効（または partial salvage 可） | マージポリシー適用 |
| `S5_FINAL_READY` | `S6_RENDERED` | 出力契約妥当 | レンダリング完了 |
| `S6_RENDERED` | `S0_INPUT_NORMALIZED` | 同セッションで新規入力 | セッション再入 |
| `ANY_NON_TERMINAL` | `S_FAIL_RETRYABLE` | timeout または一時障害 | 安全劣化 + 再試行可 |
| `ANY_NON_TERMINAL` | `S_FAIL_TERMINAL` | schema 違反、policy hard block、不可回復エラー | run 終了 |

## 4. 禁止遷移（例）

1. 理解段階なしの `S0 -> S3`
2. draft 省略の `S2 -> S5`
3. render 後の `S6 -> S4`
4. 同一 run で `S_FAIL_TERMINAL` からの再遷移

## 5. Fail 分類

- `S_FAIL_RETRYABLE`: ポリシー上再試行可能。出力は不確実性境界を明示する。
- `S_FAIL_TERMINAL`: 現 run では回復不能。新規 run が必要。

## 6. 受け入れシナリオ

1. すべての合法辺に正例テストがある。
2. すべての禁止辺に負例テストがある。
3. 同一セッション競合は `E_CONCURRENCY_CONFLICT` を返す。
4. `S6 -> S0` の再入が動作する。
