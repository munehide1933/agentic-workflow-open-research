# Agent Pipeline 契約 Profile

## 1. スコープ

本仕様は runtime pipeline の公開ステージ契約を定義する。
ステージ順序、I/O、遷移規則、ユーザー面出力ゲートを標準化する。
この pipeline は IAR における `Two-Stage Contract-Driven Delivery` の実行形態である。

対象外：

- private prompt 合成内部
- プロバイダ固有 API ペイロード内部
- 非公開配備フック

## 2. 問題定義

正式なステージ profile がないと、sync/stream 経路で挙動が乖離する。
代表的失敗：

- ステージ並び替えによる診断妥当性崩壊
- optional/required timeout 振る舞いの不一致
- 内部ステージ出力のユーザー本文漏洩
- auto モード second-pass の曖昧運用

## 3. 契約 / データモデル

### 3.1 ステージ契約

| フィールド | 型 | 意味 |
| --- | --- | --- |
| `stage_id` | string | 安定ステージキー |
| `required` | boolean | 必須/任意ステージ |
| `timeout_ms` | integer | ステージ timeout 予算 |
| `input_keys` | array[string] | 必須入力 state キー |
| `output_keys` | array[string] | 出力 state キー |
| `on_timeout_event` | string | timeout 時の遷移イベント |
| `failure_class` | string | 終端 timeout の失敗分類 |

### 3.2 ベースライン順序

1. `understand`（required）
2. `initial_analysis`（required）
3. `diagnosis_structure`（ルーティング条件で optional）
4. `reflection`（optional）
5. `synthesis_draft`（required）
6. `second_pass`（ポリシー条件で optional）
7. `synthesis_finalize`（required）
8. `render`（required）

現行 runtime に合わせたルーティング注記：

- `interaction_mode=KNOWLEDGE` かつ `domain=general` で `initial_analysis` が非空の場合、synthesis の前に `reflection` を実行する

### 3.3 ユーザー面出力ゲート

最初の user-visible content より前に必須順序：

`mode_selected -> language_locked -> style_mode_locked`

ユーザー本文ストリーム source ホワイトリスト：

- 許可：`answer`, `quote`
- ブロック：`tool`, `audit`, `plan`, `debug`, `status`, `artifact`

Output Contract Gate v3.0 不変条件：

- single writer: 最終回答テキストを commit できるのは `synthesis_finalize` のみ
- second-pass は `signals-only`: 生の audit テキストは本文ストリームへ出さない
- 終端整合性: `final.content == final_answer_text == persisted_answer`

ストリーミング可視性ゲート：

- `initial_analysis` の streaming delta は内部用であり、ユーザー本文へ転送しない
- ユーザー本文へ転送する phase は `draft_delta | answer_delta | quote_delta` のみ
- `final_delta` と allowlist 外 phase は破棄する

## 4. 意思決定ロジック

```python
def run_pipeline(state, stage_specs):
    emit_status("mode_selected")
    emit_status("language_locked")
    emit_status("style_mode_locked")

    for spec in stage_specs:
        if spec.optional and should_skip_optional(spec.stage_id, state):
            apply_transition("on_optional_step_timeout")
            continue

        result = run_stage_with_timeout(spec, state)

        if result.timeout and spec.required:
            set_failure("systemic_failure", spec.stage_id, "required_step_timeout")
            return finalize_failure(state)

        if result.timeout and not spec.required:
            set_failure("retryable_failure", spec.stage_id, "optional_step_timeout")
            apply_transition(spec.on_timeout_event)
            continue

        state = merge_stage_output(state, result.output)

    return finalize_success(state)
```

## 5. 失敗と劣化

1. required ステージ timeout -> 当該 run 分岐を終端
2. optional ステージ timeout -> retryable として skip
3. second-pass `auto` -> 自動実行せず `confirm_second_pass` を返す
4. second-pass が非信頼 -> draft 維持、audit テキストを本文へ出力しない
5. 非許可 phase のストリーム分片 -> 分片を破棄して run 継続
6. synthesis merge で意味の縮退が発生 -> invariant gate が draft にフォールバック
7. synthesis テキストにテンプレート残骸が混入 -> 生断片を隔離し本文はサニタイズ済みのみ保持
8. 末尾が中断記号（`->`、`→`、未完了句読点）で終わる -> tail-completion guard が終端文を補完

## 6. 受け入れシナリオ

1. second-pass 無効の標準経路：
   - 期待：順序通り実行し直接 finalize。
2. optional reflection timeout：
   - 期待：`skip_optional_step` 遷移で継続。
3. required synthesis finalize timeout：
   - 期待：`systemic_failure` 分類で分岐終端。
4. 通常チャット + auto second-pass：
   - 期待：`next_action=confirm_second_pass`、second-pass 未実行。
5. second-pass-only + auto：
   - 期待：確認待ちなしで second-pass 実行。
6. 内部 source 漏洩試行（`audit_delta`）：
   - 期待：ユーザー本文ストリームへ出ない。
7. `initial_analysis` ストリーミングが内部 delta を生成：
   - 期待：内部状態にのみ反映し、ユーザー本文へは出さない。
8. `interaction_mode=KNOWLEDGE` かつ `domain=general`：
   - 期待：synthesis 前に `reflection` へ遷移する。
9. merge 出力が重要な engineering anchor を欠落：
   - 期待：invariant gate が draft へフォールバック（`fallback=draft`）。
10. 詳細説明にテンプレート残留がある：
   - 期待：ノイズ断片は本文から除去され quarantine 折りたたみへ移動。
11. 最終文が中断マーカーで終わる：
   - 期待：tail-completion guard が完結した終端文を出力。

## 7. 互換性とバージョニング

- ステージ ID とベースライン順序は minor で安定維持。
- minor では optional ステージ追加を許可（既定値を明示）。
- required ステージの順序変更は major 変更。
- 出力ゲート変更時は SSE/UI stream 契約文書を同時更新する。

## 8. クロスリファレンス

- [Runtime 設計哲学](./runtime-design-philosophy.ja.md)
- [SSE レスポンス契約](./sse-response-contract.ja.md)
- [Second-Pass Audit マージポリシー](./second-pass-audit-merge-policy.ja.md)
- [Runtime 信頼性メカニズム](./runtime-reliability-mechanisms.ja.md)
