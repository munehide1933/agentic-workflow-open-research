# Diagnosis Structure: Evidence-First 推論による高信頼エージェント診断

## 要旨

複雑なエンジニアリング診断では、流暢な文章生成だけでは不十分です。
本番運用で有用なエージェントには、説得的な物語ではなく検証可能な推論成果物が必要です。
本稿は `facts`、`hypotheses`、`excluded_hypotheses`、`insufficient_evidence` から成る診断構造を提案します。
さらに second-pass audit と状態機械制御を組み合わせることで、過剰断定を抑えつつ可監査性を高める実践方法を示します。

## 1. 序論: なぜ CoT だけでは診断品質が安定しないのか

CoT 型出力は次の理由で運用時に破綻しやすくなります。

- 証拠と推論が同一文章に混在する
- 証拠不足が自信ある文体に隠れる
- 代替仮説が明示されない
- 失敗時の挙動が再現不能

これは文体の問題ではなく、運用リスクの問題です。

## 2. パラダイム転換: 会話生成から状態機械診断へ

重要なのはプロンプトではなく制御構造です。

```text
Input -> Signal Detection -> Diagnosis Structure -> Draft -> Second-Pass Audit -> Finalize
```

各段階に契約と劣化規則を置き、契約違反時には安全側へ遷移します。

## 3. コアアーキテクチャ

### 3.1 Evidence-First 原則

`hypotheses` より先に `facts` を確立します。
観測根拠がない仮説は主原因として昇格させません。

### 3.2 四元構造（Quad-Structure）

#### `facts`

- 観測可能な事実
- evidence span / key と紐付け
- source 属性で出所を明示

#### `hypotheses`

- 原因候補
- 信頼度ラベル
- 実行可能な検証手順
- 優先順位

#### `excluded_hypotheses`

- 除外した候補を明示
- 代替案の消失を防ぐ

#### `insufficient_evidence`

- 不確実性を明示するハードフラグ
- 断定出力を抑制
- 検証優先モードへ遷移

## 4. Second-Pass Audit（独立批評）

ドラフト後に独立監査を実施し、以下を出力します。

- `counter_hypotheses`
- `missing_evidence`
- `unsafe_recommendations`
- `structure_inconsistencies`

反映は条件付きです。

- 形式妥当性
- 非エコー性
- 安全ポリシー適合

条件を満たさない場合は safe degrade または partial salvage を選択します。

## 5. 核心実装を公開しない公開方法

商用価値を維持しつつ工学的価値を公開するには、以下が有効です。

1. 診断/監査の JSON 契約を公開
2. 状態遷移とガード条件を公開
3. マージ方針を擬似コードで公開
4. プロンプト微調整と閾値は非公開

## 6. コア図表

`facts -> hypotheses -> second_pass_audit` の流れは
[Diagnosis Structure Flow](../diagrams/diagnosis-structure-flow.md) を参照。

## 7. 企業文脈での論点

制御不能な対話は、企業運用では次の問題を生みます。

- 推奨内容の再現性不足
- 事後監査の困難化
- 文脈不足時の危険提案混入

実務上これは低シグナル出力です。
状態機械駆動は、遷移規律・失敗境界・測定可能性を提供するため、運用適合性が高くなります。

## 8. 評価指標

可読性ではなく制御品質を測定します。

1. `facts` の証拠カバレッジ
2. 反証仮説の新規性
3. 証拠不足時の劣化妥当性
4. 最終出力契約の整合性

定量改善率を主張する場合は、再現可能な評価プロトコルを併記すべきです。

## 9. 結論

高信頼エージェントの鍵は、プロンプト巧拙よりも推論構造・監査規律・遷移ガバナンスにあります。
Evidence-First Diagnosis は、対話出力を工学的意思決定に耐える成果物へ変換する実践的手法です。

