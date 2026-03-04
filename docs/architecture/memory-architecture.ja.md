# Memory レイヤー仕様

## 1. スコープ

本仕様は公開メモリ動作を定義します。

- SQLite 短期メモリ
- Qdrant 長期メモリ（任意）

## 2. 短期メモリ（SQLite）

主な責務：

1. セッション継続性
2. run 単位スナップショット
3. ロールバック支援

公開デフォルト保持期間：

- `session_ttl_days = 30`
- `run_ttl_days = 14`

排出ルール：

1. 日次スイープで期限切れ run を先に削除。
2. アクティブ run がなく TTL 超過のセッションを削除。
3. 可能な場合は `trace_id/run_id/session_id` をログする。

## 3. 長期メモリ（Qdrant、任意）

書き込みタイミング：

1. finalize ステージのみ書き込み。
2. `hard_fail` 出力は書き込みしない。
3. 機密判定された応答は書き込みしない。

## 4. 検索トリガーとパイプライン注入点

検索は `S1_UNDERSTANDING_READY` の後、`S2_DIAGNOSIS_READY` の前で評価する。

パイプライン契約：

1. 検索が有効で、要求が明示的に memory-isolated でない場合に `retrieve_cross_session_memory()` を実行する。
2. ヒットを `min_score` でフィルタし、`state.memory_context[]` に保存する。
3. `build_diagnosis_structure()` は `memory_context` を外部コンテキスト入力として受け取る。

`memory_context` の公開最小項目：

- `memory_id`
- `score`
- `snippet`
- `source_session_id`

## 5. セッション横断検索の意味論

デフォルト検索設定：

- `top_k = 8`
- 関連度閾値 `min_score = 0.72`

挙動ルール：

1. 閾値未満は除外。
2. 検索メモリはコンテキストであり、単独事実ではない。
3. diagnosis は検索メモリを仮説生成や検証手順に利用できる。
4. メモリのみで支えられた主張は、現 run の根拠なしに `facts` へ昇格させない。
5. 低信頼検索は `required_fields` 増加要因とする。

## 6. Verification-First との連携

`diagnosis.insufficient_evidence=true` の場合、ドラフトは verification-first 制約に従う。

1. 明示的な不確実性声明を含める。
2. 主張境界を制限し、根因確実性を引き上げない。
3. 観測可能シグナルに基づく順序付き検証チェックリストを含める。
4. `required_fields` の欠落観測項目を含める。
5. 不可逆な実行アクションを遮断する。

## 7. ロールバック意味論

ロールバック粒度は run 単位。

トリガー：

- 終端 schema 違反
- 終端 policy 違反
- finalize の不可回復失敗

ロールバック動作：

1. 最後に commit 済み run スナップショットへ復元。
2. ロールバック理由の不変トレースを保持。
3. 過去の完了 run ペイロードは書き換えない。

## 8. 受け入れシナリオ

1. TTL 期限で run データが規定通り排出される。
2. finalize 成功で長期メモリへ書き込まれる。
3. hard fail では長期メモリ書き込みがスキップされる。
4. 検索ヒットが diagnosis 前に注入される。
5. メモリ単独主張は裏付けなしで facts に入らない。
6. 証拠不足パスで verification-first 制約付きドラフトが出力される。
7. ロールバック時に直近 commit 状態へ復元される。
