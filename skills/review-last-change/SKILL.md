---
name: review-last-change
description: 审查上一次 Cursor 开发会话的改动。当用户执行 /review-change、说「审查上次改动」「check 上一轮 AI 改动」时触发。读取 last-session-manifest.md，分析影响面并按需审查核心文件。
---

# 审查上一次会话改动

在新会话中审查**上一轮开发 Agent 会话**的代码改动。不依赖 git diff 全文，以 Hook 生成的 manifest 为入口。

## 前置条件

1. 读取 `.cursor/reviews/last-session-manifest.md`
2. 若不存在：读取 `.cursor/reviews/archive/` 下**最新** `*-manifest.md` 作为兜底（Hook 修复前可能被过早归档）
3. 若仍不存在或 `file_count` 为 0：告知用户「暂无可审查的上一轮会话改动」，并说明需先完成一次含文件编辑的开发会话
3. 若 `reviewed: true`：提示用户该轮已审查；若仍要复查，继续执行但注明为重复审查

## 审查流程（按序执行）

### Step 1 — 读 manifest，确定范围

- 只读 manifest，**不要**一次性 Read 全部改动文件
- 从 manifest 提取文件列表与操作类型（added / modified / deleted / edited）
- 若文件数 > 8，优先选核心文件（入口、路由、store、共享 lib、接口边界）进行首轮审查

### Step 2 — 影响面分析

- 阅读 `docs/architecture/module-impact-map.md`
- 根据改动路径判断可能波及的模块文档，按需阅读 `docs/architecture/module-impact/` 下相关文档
- 输出简短「影响面摘要」（哪些模块/边界可能受影响）

### Step 3 — 按需读文件审查

- 按优先级逐个 Read 核心改动文件（首轮建议 ≤ 8 个）
- 关注：逻辑正确性、边界处理、类型安全、i18n/暗色模式（若涉及 UI）、host-api 边界、跨模块耦合
- **禁止**将 `git diff` 全文贴入上下文；**禁止**无差别读取所有文件

### Step 4 — 可选自动化检查

按改动范围选择性执行（不要无脑全跑）：

| 改动类型 | 建议命令 |
| --- | --- |
| TS/TSX 逻辑 | `pnpm run typecheck` |
| 单元测试相关 | `pnpm exec vitest run <相关测试文件>` |
| 通信路径变更 | `pnpm run comms:replay` + `pnpm run comms:compare` |
| OpenClaw 插件变更 | 参考 `AGENTS.md` 中 bundled plugin 检查清单 |

命令失败时记录关键报错行，纳入审查结论。

### Step 5 — 可选 Bugbot 深审

仅当用户明确要求，或 manifest 涉及高风险区域（auth、gateway、支付、数据持久化）时：

- 启动一个 `bugbot` 子 Agent（`readonly: true`）
- 使用 `Diff: natural language`，`Change Description` 由 manifest 文件列表 + 你的影响面摘要组成
- 参考项目内 `review-bugbot` Skill 的 prompt 格式

### Step 6 — 输出审查结论

用精简格式输出，**不要长篇复述代码**：

```markdown
## 审查结论

| 严重度 | 位置 | 发现 |
| --- | --- | --- |
| high/medium/low/info | path:line | 简述 |

### 影响面
- ...

### 建议验收
1. ...
2. ...

### 若有问题，请提供
- 相关文件路径
- 终端 / Console 报错全文
- 复现步骤
```

- 无问题时：一句话说明「未发现明显问题」+ 建议验收步骤
- **不要**自动修复问题，除非用户明确要求

### Step 7 — 标记已审查

审查完成后，更新 manifest 中的 `- **reviewed**: false` 为 `- **reviewed**: true`，并追加一行 `- **reviewed_at**: <当前时间>`。

## 上下文控制

- manifest 设计为 ≤100 行，始终只保留上一轮**有编辑**的开发会话
- 历史 manifest 在**下一次有编辑的会话 `stop` 写入新清单前**归档到 `.cursor/reviews/archive/`
- 纯审查会话（无文件编辑）不会覆盖或归档既有 manifest
- 仅在 `last-session-manifest.md` 缺失时，才用 `archive/` 最新一份作兜底

## 与 git 的关系

- manifest 按**会话边界**记录，适用于脏工作区
- git diff 仅作辅助参考，不作为主要输入
- 若 manifest 缺失但用户坚持审查，可退化为 `git diff` + 用户口述改动范围
