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

