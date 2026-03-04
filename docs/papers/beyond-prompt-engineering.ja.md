# Beyond Prompt Engineering: Evidence-First Diagnosis と Anchor Guard による高信頼エージェント設計

## 要旨

プロンプト最適化は出力の見た目を改善しますが、本番信頼性を保証しません。
企業向けエージェントの障害は、多くの場合モデル能力不足ではなく制御面の欠落で発生します。

- 証拠契約がない
- 独立監査がない
- コード出力の安全境界がない
- 劣化時の規律がない

本稿は、以下の4要素を組み合わせた高信頼アーキテクチャを提案します。

1. Evidence-First Diagnosis（証拠優先の診断構造）
2. Second-Pass Audit（独立監査による再評価）
3. Anchor Guard（アンカー不足時のコード安全収束）
4. 状態機械ガバナンス（明示遷移と fail-safe）

中核主張は明確です。
企業文脈で「制御不能な対話」は運用価値が低く、状態機械駆動のワークフローが実装上の現実解です。

## 1. 背景: Prompt-Only の限界

Prompt tuning だけでは次を保証できません。

- 事実と証拠の結び付き
- 反証仮説の体系的検討
- 高リスクコード提案の抑制
- 不完全情報下での安全な劣化

この欠落は、障害解析・設計判断・コード生成で再現性の低い挙動を生みます。

## 2. 設計目標

本手法の優先順位は以下です。

1. 制御可能性（Controllability）
2. 監査可能性（Auditability）
3. 安全性（Safety）
4. 劣化時の一貫性（Graceful Degradation）

## 3. ワークフローモデル

自由対話ではなく、契約駆動の段階処理を採用します。

```text
Input -> Understand -> Diagnosis -> Draft -> Second-Pass Audit -> Finalize -> Render
```

各段階は検証可能な入出力契約を持ち、違反時は fail-safe へ遷移します。

## 4. Evidence-First Diagnosis

診断を次の構造に固定します。

- `facts`: 観測可能証拠に紐づく事実
- `hypotheses`: 信頼度付き仮説と実行可能テスト
- `excluded_hypotheses`: 除外仮説
- `insufficient_evidence`: 証拠不足フラグ

### 4.1 効果

事実・推論・不確実性を分離できるため、説得的だが検証不能な回答を抑制できます。

### 4.2 運用規則

`insufficient_evidence=true` の場合、単一の断定原因を提示しない。
代わりに、優先検証ステップを提示します。

## 5. Second-Pass Audit

Second pass は単なる言い換えではありません。
ドラフトを独立視点で再評価する「挑戦フェーズ」です。

監査出力:

- `counter_hypotheses`
- `missing_evidence`
- `unsafe_recommendations`
- `structure_inconsistencies`

### 5.1 マージ規則

監査結果は、形式妥当性・非エコー性・最小品質条件を満たす場合のみ反映します。
不十分な監査を無理に反映せず、安全劣化へ移行します。

## 6. Anchor Guard

コード出力は高リスク成果物です。
そのため、実行可能コードの前にアンカー完全性を確認します。

主要アンカー:

- runtime
- client SDK
- （必要時）HTTP client 前提

アンカー不足時は単一スタック実装を禁止し、スタック非依存戦略または擬似コードへ収束させます。

## 7. 状態機械ガバナンス

信頼性の中核は「遷移規律」です。

例:

- `UNDERSTAND_READY -> DIAGNOSIS_READY`: 診断前提が満たされる場合のみ
- `DRAFT_READY -> AUDIT_READY`: 高リスク/対象ドメイン時のみ
- 任意状態 -> `FAIL_SAFE`: timeout, schema 不整合, policy 違反

これにより、失敗は不可解な暴走ではなく、説明可能な劣化動作になります。

## 8. 診断構造フロー

[Diagnosis Flow Diagram](../diagrams/diagnosis-structure-flow.md) を参照。

## 9. 企業適用の含意

### 9.1 制御不能な対話は負債

自由対話型のまま本番投入すると、次の問題が増幅します。

- 推奨内容の再現不能性
- 危険提案の混入
- インシデント後解析の困難化

### 9.2 状態機械駆動が有効な理由

- 段階ごとの責務が明確
- 証拠不足時の断定禁止を徹底
- 品質ゲートをメトリクス化しやすい
- 監査・コンプライアンス対応を設計に組み込める

## 10. 評価指標（推奨）

文章品質ではなく、制御品質を測定します。

1. 証拠充足率（facts が観測シグナルを持つ割合）
2. 反証新規性率（audit が draft の単純反復でない割合）
3. 危険コード抑止率（アンカー不足時の実行コード遮断）
4. 劣化妥当率（timeout/不正監査時の安全出力維持）
5. 最終整合率（final 出力と永続化結果の一致）

## 11. 限界

- 不確実性をゼロにはできない。可制御化する設計である。
- ドメイン固有の閾値調整は別途必要。
- 遷移網羅の形式検証は今後の課題。

## 関連ディープダイブ

- [Diagnosis Structure（EN）](./diagnosis-structure.evidence-first.en.md)
- [Diagnosis Structure（日本語版）](./diagnosis-structure.evidence-first.ja.md)
- [Anchor Guard（EN）](./anchor-guard.reliable-codegen.en.md)
- [Anchor Guard（日本語版）](./anchor-guard.reliable-codegen.ja.md)

## 結論

Prompt Engineering は必要条件であり、十分条件ではありません。
高信頼エージェントには、証拠契約・独立監査・安全境界・状態機械遷移が必要です。

実務的には次の一文に集約されます。
状態機械で制御されていないエージェントは、企業運用で信頼を獲得しにくい。
