# Runtime 設計哲学

## 1. スコープ

本仕様は runtime 挙動ガバナンスと設計判断公開に使う公開設計哲学を定義する。
本仕様はアーキテクチャ文書、契約 schema、ポリシー更新に対して規範的に適用される。
IAR は既定のデリバリ規律として `Two-Stage Contract-Driven Delivery` を採用する。

対象外：

- private モデル prompt 内部
- private 配備調整定数
- 実装側の秘密情報処理詳細

## 2. 問題定義

Agent が本番で不安定化するのは、制御プレーン規律より生成速度を優先した場合である。
代表的な失敗モード：

- 契約境界なしの機能増殖
- サブシステム間ポリシー衝突の不可視化
- テスト不能な設計主張
- 暗黙フォールバックによる fail-open

## 3. 契約 / データモデル

設計哲学は強制可能な原則集合として表現する。

| フィールド | 型 | 意味 |
| --- | --- | --- |
| `principle_id` | string | 安定原則 ID（例 `P_DETERMINISM_FIRST`） |
| `statement` | string | 規範的原則文 |
| `enforcement_layer` | string | `design | orchestration | runtime | output` |
| `observable_signal` | string | 測定可能な runtime / 文書シグナル |
| `violation_effect` | string | 違反時に必須の挙動 |
| `test_reference` | string | 契約テストまたは受け入れシナリオ ID |

ベースライン原則：

1. `P_CONTRACT_BEFORE_CODE`
2. `P_DETERMINISM_FIRST`
3. `P_EVIDENCE_BEFORE_ASSERTION`
4. `P_SAFETY_BEFORE_EXECUTION`
5. `P_DEGRADE_BEFORE_FAIL_OPEN`
6. `P_SINGLE_WRITER_FINAL_OUTPUT`

## 4. 意思決定ロジック

新しい runtime 挙動は公開前に原則ゲートを通過しなければならない。

```python
def evaluate_design_change(change, principles):
    violations = []
    for principle in principles:
        if not satisfies(change, principle):
            violations.append(principle.principle_id)

    if not violations:
        return {"decision": "accept", "violations": []}

    if "P_SAFETY_BEFORE_EXECUTION" in violations:
        return {
            "decision": "reject",
            "action": "block_release",
            "violations": violations,
        }

    return {
        "decision": "revise",
        "action": "add_mitigation_and_tests",
        "violations": violations,
    }
```

## 5. 失敗と劣化

原則が runtime で衝突した場合：

1. より厳格な安全制約を優先
2. 決定的出力契約を維持
3. 構造化違反メタデータを出力
4. fail-open 実行ではなく有界ガイダンスへ劣化

衝突時優先順位：

1. Safety
2. Determinism
3. Evidence integrity
4. Output quality
5. Cost optimization

## 6. 受け入れシナリオ

1. schema 契約なしの新機能：
   - 期待：`P_CONTRACT_BEFORE_CODE` により拒否。
2. 最適化で同一入力の出力が変化：
   - 期待：`P_DETERMINISM_FIRST` によりブロック。
3. 証拠なしで根因を断定：
   - 期待：`P_EVIDENCE_BEFORE_ASSERTION` により劣化。
4. アンカー不足で実行コード要求：
   - 期待：`P_SAFETY_BEFORE_EXECUTION` により実行出力を遮断。
5. second-pass 失敗で信頼可能パッチなし：
   - 期待：`P_DEGRADE_BEFORE_FAIL_OPEN` により有界 summary へ。
6. 複数モジュールが最終回答を上書き：
   - 期待：`P_SINGLE_WRITER_FINAL_OUTPUT` により first-writer を保持。

## 7. 互換性とバージョニング

- Principle ID は minor 更新で安定維持する。
- minor 更新では任意の新原則追加を許可する。
- 既存原則の削除・再定義は major 変更とする。
- 原則変更時は受け入れシナリオと cross-reference を同期更新する。

## 8. クロスリファレンス

- [Runtime 能力マップ](./runtime-capability-map.ja.md)
- [Agent Pipeline 契約 Profile](./agent-pipeline-contract-profile.ja.md)
- [Execution Safety Envelope Runtime](./execution-safety-envelope-runtime.ja.md)
- [Runtime 信頼性メカニズム](./runtime-reliability-mechanisms.ja.md)
