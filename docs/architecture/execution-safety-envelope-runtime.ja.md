# Execution Safety Envelope Runtime

## 1. スコープ

本仕様は実行可能挙動に対する強制可能な runtime 安全境界を定義する。
allowlist 行動、sandbox 隔離、予算制御、決定的 guard 結果を標準化する。

対象外：

- private guard ルール本文と機密 abuse シグネチャ
- 公開 runtime boundary 外のホストレベル操作
- 内部インフラ hardening runbook

## 2. 問題定義

実行ポリシーが助言に留まると runtime 安全は破綻する。
代表的失敗モード：

- blacklist 方式では新しい攻撃面を取りこぼす
- step 失敗がグローバルプロセス状態を汚染する
- token/tool/latency の増加が無制限になる
- ループや逸脱がポリシー超過後も継続する

## 3. 契約 / データモデル

### 3.1 Runtime Boundary 契約

| フィールド | 型 | 意味 |
| --- | --- | --- |
| `boundary_id` | string | 不変な境界ポリシー ID |
| `boundary_version` | string | 版管理された runtime boundary 契約 |
| `sandbox_mode` | string | `process | container | microvm | isolate` |
| `isolation_scope` | string | `per_step | per_run` |
| `allowlisted_tools` | array[string] | 当該 run の許可 tool 一覧 |
| `denied_action_classes` | array[string] | 明示 deny action クラス |
| `budget` | object | token/tool/latency/memory/output 制限 |
| `guard_policy_id` | string | 決定的 guard ポリシー参照 |
| `termination_policy` | object | ループ上限と timeout 終端規則 |

### 3.2 Budget オブジェクト

| フィールド | 型 | 意味 |
| --- | --- | --- |
| `token_budget` | integer | run 全体の最大 token |
| `tool_call_budget` | integer | run 全体の最大 tool 呼び出し |
| `latency_budget_ms` | integer | 最大 wall-clock 実行時間 |
| `memory_quota_mb` | integer | メモリ使用上限 |
| `output_size_limit_bytes` | integer | 出力 payload サイズ上限 |

## 4. 意思決定ロジック

```python
def enforce_execution_boundary(step_request, boundary, usage):
    if step_request.tool_name and step_request.tool_name not in boundary.allowlisted_tools:
        return fail("guard_violation_failure", "tool_not_allowlisted")

    if usage.tokens_used > boundary.budget.token_budget:
        return fail("systemic_failure", "token_budget_exhausted")

    if usage.tool_calls_used > boundary.budget.tool_call_budget:
        return fail("systemic_failure", "tool_call_budget_exhausted")

    if usage.latency_ms > boundary.budget.latency_budget_ms:
        return fail("retryable_failure", "latency_budget_exhausted")

    if usage.loop_count > boundary.termination_policy.max_loop_iterations:
        return fail("guard_violation_failure", "loop_limit_exceeded")

    return pass_boundary()


def execute_step_with_isolation(step_request, boundary):
    with start_sandbox(boundary.sandbox_mode, boundary.isolation_scope) as sandbox:
        return sandbox.run(step_request)
```

## 5. 失敗と劣化

1. guard 違反 -> `safe_recovery` へ遷移し実行可能出力を禁止。
2. 予算枯渇 -> 分岐を終端し有界診断 artifact を返す。
3. sandbox 起動失敗 -> 実行不可ガイダンス出力へ劣化。
4. 出力サイズ超過 -> ポリシー境界で切り詰め `degraded=true`。
5. timeout 連続発生 -> 当該 run を circuit-open して後続実行拒否。

## 6. 受け入れシナリオ

1. allowlist 済み tool + 予算内実行：
   - 期待：sandbox 内で step 実行し継続。
2. 非許可 tool 呼び出し：
   - 期待：`guard_violation_failure`、実行しない。
3. finalize 前に token 予算枯渇：
   - 期待：`systemic_failure`、有界応答のみ返す。
4. step が上限ループを超過：
   - 期待：guard が終端し回復遷移へ。
5. tool 実行中に sandbox クラッシュ：
   - 期待：故障は隔離され、全体 runtime 状態は不変。
6. 出力 payload が上限超過：
   - 期待：決定的切り詰めと劣化マーカー。
7. 負例：blacklist のみ設定：
   - 期待：境界検証で拒否（allowlist 必須）。

## 7. 互換性とバージョニング

- 新 deny クラスと任意 budget フィールド追加は minor 互換。
- 既定 guard 意味変更は major 変更。
- budget 単位変更（例 ms -> s）は新 major schema 必須。
- boundary version 更新は runtime metadata 契約へ同期する。

## 8. クロスリファレンス

- [Runtime 能力マップ](./runtime-capability-map.ja.md)
- [Action/Tools システム契約](./action-tools-system-contract.ja.md)
- [エラー分類と可観測性仕様](./error-taxonomy-observability.ja.md)
- [Runtime 信頼性メカニズム](./runtime-reliability-mechanisms.ja.md)
