# Deep Thinking モデルガバナンス

## 1. スコープ

本仕様は deep-thinking モデル実行における制御プレーンのガバナンス契約を定義する。
profile 選択、fallback 順序、timeout ポリシー連携、replay-safe 実行規則を標準化する。

対象外：

- private モデル提供者との商用交渉条件
- private system prompt と prompt template
- ベンダー固有の安全実装詳細

## 2. 問題定義

モデル選択が暗黙化されると、deep-thinking の本番挙動は不安定になる。
代表的失敗モード：

- リリース間でモデルルーティングが静かに変化する
- fallback 経路がポリシー制約を回避する
- primary と auditor の timeout 挙動が一致しない
- replay で過去のモデル判断を再現できない

## 3. 契約 / データモデル

### 3.1 モデル Profile 契約

| フィールド | 型 | 意味 |
| --- | --- | --- |
| `profile_id` | string | 安定した公開モデル profile ID |
| `role` | string | `primary | auditor | fallback` |
| `mode_allowlist` | array[string] | 許可モード（`basic`、`deep_thinking`、`web_search`） |
| `determinism_mode` | string | `live | replay` |
| `max_input_tokens` | integer | 当該 profile の入力 token 上限 |
| `max_output_tokens` | integer | 当該 profile の出力 token 上限 |
| `temperature` | number | ポリシー指定の生成温度 |
| `timeout_profile_id` | string | timeout profile 契約参照 |
| `cost_tier` | string | `low | medium | high` |
| `safety_class` | string | ポリシー安全クラス |

### 3.2 モデル判断記録

| フィールド | 型 | 意味 |
| --- | --- | --- |
| `run_id` | string | 実行 ID |
| `step_id` | string | pipeline step ID |
| `selected_profile_id` | string | 当該 step で選択された profile |
| `auditor_profile_id` | string | 監査有効時の auditor profile |
| `fallback_chain` | array[string] | 順序付き fallback profile ID |
| `selection_reason` | array[string] | 決定的に再現可能な理由タグ |
| `checkpoint_ref` | string | replay 用 checkpoint 参照 |

## 4. 意思決定ロジック

```python
def build_model_plan(request, policy, boundary, profiles):
    candidates = [
        p for p in profiles
        if request.mode in p.mode_allowlist and p.safety_class == boundary.safety_class
    ]

    ordered = sort_profiles(candidates, request.priority, policy.cost_cap_tier)
    primary = ordered[0]
    auditor = select_auditor_profile(ordered, policy.audit_enabled)
    fallback_chain = ordered[1 : 1 + policy.max_fallback_depth]

    return {
        "primary_profile_id": primary.profile_id,
        "auditor_profile_id": auditor.profile_id if auditor else None,
        "fallback_chain": [p.profile_id for p in fallback_chain],
        "timeout_profile_id": primary.timeout_profile_id,
    }


def execute_model_step(step_input, plan, checkpoint_store, replay_mode=False):
    if replay_mode:
        return checkpoint_store.load_model_output(step_input.run_id, step_input.step_id)

    output = call_model(plan["primary_profile_id"], step_input)
    checkpoint_store.save_model_output(step_input.run_id, step_input.step_id, output)
    return output
```

## 5. 失敗と劣化

1. `retryable_failure`: provider timeout または一時 API 障害 -> retry 予算内で primary を再試行。
2. `model_uncertainty_failure`: 出力信頼度が下限未満 -> auditor profile へ遷移。
3. `audit_rejection_failure`: auditor が draft を否認 -> draft を保持し有界不確実性を返す。
4. `policy_failure`: profile がポリシー制約に違反 -> profile を除外し fallback 継続。
5. `systemic_failure`: fallback を使い切る -> 有界失敗 artifact を返す。

劣化優先順位：

1. replay の再現保証
2. 安全ポリシー完全性
3. ユーザー可視回答の継続性
4. コスト最適化

## 6. 受け入れシナリオ

1. deep-thinking 要求で primary が健全：
   - 期待：primary を選択。auditor はポリシー条件で任意。
2. primary timeout で fallback が利用可能：
   - 期待：`retryable_failure` に分類し fallback 実行。
3. 出力信頼度が閾値未満：
   - 期待：`model_uncertainty_failure` に分類し auditor 経路を起動。
4. replay モード実行：
   - 期待：モデル未呼び出しで checkpoint 出力を使用。
5. レジストリにポリシー非許可 profile が存在：
   - 期待：`policy_failure` に分類し除外。
6. fallback 連鎖が枯渇：
   - 期待：`systemic_failure` に分類し有界劣化 artifact を返す。
7. 負例：出力に private provider 戦略が混入：
   - 期待：output contract で遮断し、サニタイズ済み metadata のみ公開。

## 7. 互換性とバージョニング

- `profile_id` は同一 major ガバナンス系統で安定維持する。
- 任意 profile フィールド追加は minor 互換。
- `primary/auditor/fallback` 役割意味の変更は major 変更。
- timeout profile 参照変更時は timeout schema 互換ノートを更新する。

## 8. クロスリファレンス

- [Runtime 能力マップ](./runtime-capability-map.ja.md)
- [Agent Pipeline 契約 Profile](./agent-pipeline-contract-profile.ja.md)
- [Second-Pass Audit マージポリシー](./second-pass-audit-merge-policy.ja.md)
- [Runtime 信頼性メカニズム](./runtime-reliability-mechanisms.ja.md)
