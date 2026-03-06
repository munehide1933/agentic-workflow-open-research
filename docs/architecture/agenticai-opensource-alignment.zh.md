# AgenticAI 与 Open-Source 能力对齐（2026-03）

## 1. 范围

本文用于将 AgenticAI 当前实现基线，与本仓库公开的 open-research 架构文档做能力对齐。

对齐对象仅包含公开控制平面行为与契约级语义。

不在范围内：

- 私有 prompt 内部细节
- 部署拓扑与私有基础设施细节
- 本地执行算子与非公开运行时内部实现

## 2. 基线与证据来源

对齐基线日期：`2026-03-06`

实现侧证据来源：

- 运行时模块（`backend/core`, `backend/app`, `backend/database`, `backend/services`）
- API 面（`backend/app/main.py`）
- `backend/tests` 下的契约测试

本次对齐使用的行为证据：

1. `test_runtime_boundary_contract_v1.py`
2. `test_unified_step_runner_contract.py`
3. `test_chat_streaming_contract_v1.py`
4. `test_ui_message_stream_protocol_contract.py`
5. `test_pipeline_metadata_ssot_contract.py`
6. `test_second_pass_timeout_profile_contract.py`
7. `test_second_pass_confirmation_contract.py`
8. `test_anchor_guard_policy.py`
9. `test_guard_skips_codegen_and_gate.py`
10. `test_artifact_version_chain_contract.py`
11. `test_artifact_diff_contract.py`
12. `test_artifact_api_list_detail_download.py`

## 3. 能力对齐矩阵

| 能力线 | AgenticAI 实现证据 | 当前 Open-Source 覆盖度 | 对齐决策 |
| --- | --- | --- | --- |
| 流式输出契约与用户面隔离 | `chat_stream` + UI message stream adapter + streaming 契约测试 | `sse-response-contract.md` 已覆盖基础框架，但实现 profile 细节未完全显式 | 保留 SSE 基线规范；后续补实现 profile 约束 |
| Runtime boundary 与失败分类转移 | `runtime_contract.py`, `step_runner.py`, runtime boundary 测试 | 状态机与错误分类文档有覆盖，但缺 runtime_boundary metadata 契约 | 新增 runtime-boundary metadata 补充规范与转移映射 |
| 二阶段审计执行策略 | second-pass mode/timeout/trust/no-effect 测试 | 合并策略已存在，但执行模式行为仅部分文档化 | 扩展 second-pass 策略，补确认模式与超时 profile 行为 |
| 代码安全边界（anchor + canonical + quality gate） | anchor guard 测试、canonical output 测试、quality gate hard-fail 降级模板测试 | Anchor/Quality 文档已存在 | 标记为已对齐；下一版补 canonical output mode 与 `skipped_guard` 严重级别 |
| Artifact 生命周期与版本链 | artifact 持久化/版本/diff/API 测试 | 尚无独立公开架构规范 | 新增 artifact lifecycle 规范与公开契约 schema |
| 最终 metadata SSOT 与可观测 payload | pipeline metadata builder + metadata 测试 | 可观测性文档存在，但 runtime payload 字段不完整 | 扩展 observability 规范，补 `runtime_boundary`, `failure_event`, `output_contract`, second-pass timeout profile 字段 |
| 记忆体系与安全中间件 | summary checkpoint、long-memory 行为、token/rate-limit middleware | memory 架构已覆盖部分语义；运行保护细节未完整公开 | 新增 runtime-ops 补充文档，公开 summary checkpoint 与 API 保护语义 |
| 确定性回放与 checkpoint 恢复 | 当前仅有部分确定性防护；实现中尚无事务化 replay checkpoint 契约 | vNext hardening 计划已标注为缺口 | 继续作为 roadmap 缺口，待实现 checkpoint/replay 契约后同步 |

## 4. 需要同步的公开契约增量

为保持开源文档与实现行为一致，需要同步以下增量：

1. `SSE response contract`：
   - pre-content 状态顺序（`mode_selected -> language_locked -> style_mode_locked`）
   - `content` 发射源白名单（用户正文仅 `answer|quote`）
   - 一致性约束（`final.content == final_answer_text == persisted answer`）
2. `Observability/error taxonomy`：
   - runtime payload 标准字段（`runtime_boundary`, `failure_event`, `output_contract`）
   - timeout profile 与 optional-step timeout 语义
3. `Second-pass merge policy`：
   - trust-gated merge（`UNTRUSTED` 永不改写正文）
   - 自动确认行为（`second_pass_mode=auto`）
   - adaptive timeout profile 契约
   - second-pass-only 场景的 no-effect summary 行为
4. `Artifact contracts`：
   - 版本链（`version_no`, `parent_artifact_id`, `logical_key`）
   - diff 接口契约与 session 级可见性规则
5. `Runtime governance`：
   - soft depth limit 下 optional step 跳过
   - required-step timeout 升级路径

## 5. 边界与发布规则

将实现行为同步到 open-research 文档时，遵循：

1. 仅发布控制平面行为与公开契约
2. 不包含私有 prompt、密钥材料、私有基础设施细节
3. 将实现行为表达为可确定、可测试规则
4. 契约字段扩展时保留兼容性说明

## 6. 验收场景

1. Streaming 白名单与顺序：
   - 输入：状态事件 + 混合 source 的内容分片（`answer`, `tool`, `audit`）
   - 预期：仅允许用户面内容发射，且 pre-content 锁定顺序保持
2. Optional step timeout：
   - 输入：可选步骤（`reflection`）超时
   - 预期：failure class 为 `retryable_failure`，transition action 为 `skip_optional_step`
3. Required step timeout：
   - 输入：必选步骤（`synthesis_merge`）超时
   - 预期：failure class 为 `systemic_failure`，该步骤路径终止
4. Artifact 版本链：
   - 输入：同一 logical artifact 连续保存两次并查询详情
   - 预期：版本号递增（`1 -> 2`），存在 parent 关联，logical key 稳定
5. Artifact diff：
   - 输入：请求两个版本的 unified diff
   - 预期：返回 unified 文本与统计字段（`added`, `removed`, `changed`）
6. Second-pass 自动确认：
   - 输入：`second_pass_mode=auto`，普通对话流（非 second-pass-only）
   - 预期：二阶段不自动执行，响应含 `next_action=confirm_second_pass`

## 7. 后续工作项

`P0`：

1. 新增 SSE 实现 profile 补充规范
2. 新增 runtime-boundary payload 补充规范
3. 新增 artifact lifecycle 架构规范

`P1`：

1. 扩展 second-pass 策略，补执行模式契约
2. 扩展 observability 规范，补最终 metadata 字段集

`Roadmap`：

1. 事务化 checkpointing
2. 确定性 replay 契约
3. runtime 背压与多租户配额治理

## 8. 交叉引用

- [SSE Response Contract](./sse-response-contract.md)
- [Error Taxonomy and Observability](./error-taxonomy-observability.md)
- [Second-Pass Audit Merge Policy](./second-pass-audit-merge-policy.md)
- [Anchor Guard Design](./anchor-guard.md)
- [Quality Gate Framework](./quality-gate-framework.md)
- [Memory Architecture](./memory-architecture.md)
- [State Machine Transition Matrix](./state-machine-transition-matrix.md)
- [Runtime vNext Iteration Plan and Primary Design Goals](./runtime-vnext-iteration-plan.md)
