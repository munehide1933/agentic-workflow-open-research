# Intelligent Agent Runtime（公開研究版）

このリポジトリは、エンタープライズ向けエージェント実装の「設計思想と工学手法」を公開するための文書中心版です。
中核アルゴリズムやローカル実行レイヤーの機密実装は含みません。

## 目的

「よく話せる」だけの対話システムは本番運用で破綻します。
本番で必要なのは、次の4点です。

1. Evidence-First Diagnosis（証拠優先の診断）
2. Second-Pass Audit（独立監査による再評価）
3. Anchor Guard（コード出力の安全境界）
4. 状態機械ベースの制御（明示的遷移と劣化戦略）

## 公開内容

- アーキテクチャ文書
- 診断・監査の契約スキーマ
- フローダイアグラム（Mermaid）
- 技術論文（英語/日本語）
- 実装擬似コード

## 非公開内容

- ローカル実行層（shell/filesystem/system call）
- 本番向けポリシー閾値と秘密プロンプト
- private infra 依存のメモリ実装詳細

詳細は [Open-Source Boundary](./docs/architecture/open-source-boundary.md) を参照してください。

## 実装済み機能（誇張なし）

1. 対話モード: `basic / deep_thinking / web_search`
2. SSE 契約: `status/content/final/error` の明示分離
3. 診断構造化: `facts / hypotheses / excluded_hypotheses / insufficient_evidence`
4. 二段階監査: ドラフト再評価と安全劣化
5. Anchor Guard: アンカー不足時の高リスクコード抑制
6. 品質ゲート: 構文・危険パターン検査と段階的フォールバック
7. セッション/記憶: SQLite + （任意）Qdrant
8. 運用基盤: WAL、リトライ、ログ、レート制限、任意バックアップ

## 顧客課題への対応

- 監査しにくい障害解析回答
- 根拠不足でも断定する応答
- 前提不足のコード提案
- 不安定なストリーム出力による統合難

## 追加ドキュメント

- [Framework Design, Engineering Thinking, and Customer Problem Fit (EN)](./docs/architecture/framework-design-thinking-and-customer-value.en.md)
- [框架设计、思考方式与客户价值映射（中文）](./docs/architecture/framework-design-thinking-and-customer-value.zh.md)
- [Diagnosis Structure（EN）](./docs/papers/diagnosis-structure.evidence-first.en.md)
- [Diagnosis Structure（日本語版）](./docs/papers/diagnosis-structure.evidence-first.ja.md)
- [Anchor Guard（EN）](./docs/papers/anchor-guard.reliable-codegen.en.md)
- [Anchor Guard（日本語版）](./docs/papers/anchor-guard.reliable-codegen.ja.md)
