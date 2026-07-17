# .cursor 能力总览

> **最后更新：** 2026-07-15  
> **本次扫描：** 5 个 commands、10 条 rules（5 条 alwaysApply）、2 个 hook 脚本（3 类事件）、7 个 skills、0 个 agents、4 个 scripts（含 README 与 git-hooks）  
> **本次触发原因：** `afterFileEdit` 写入 `.cursor/.needs-capability-update`（`changed_file=/Users/mac/companycode/yonclaw1.0/.cursor/.cursorlog`，`changed_at=2026-07-15 17:42:15`），用户确认「运行」后执行本 Skill 并清理标志文件。

本文档由 `cursor-capability-check` Skill 自动生成并维护；当 `.cursor` 下（非 `docs/`）能力文件变更后，可再次运行该 Skill 刷新。

---

## 目录

- [Commands（命令）](#commands命令)
- [Rules（规则）](#rules规则)
- [Hooks（钩子）](#hooks钩子)
- [Skills（技能）](#skills技能)
- [Agents（SubAgent）](#agentssubagent)
- [Scripts（脚本）](#scripts脚本)
- [文件关系与依赖](#文件关系与依赖)
- [功能重叠检查](#功能重叠检查)

---

## Commands（命令）

通过 `/命令名` 在 Cursor 对话框中触发，由 AI 执行预定义流程。

| 文件 | 命令 | 功能描述 |
|------|------|----------|
| `commands/git-branch-cleanup.md` | `/git-branch-cleanup` | 批量删除已合并到主干的本地/远程 Git 分支，支持预览模式，自动保护 main/master/develop 等分支 |
| `commands/git-commit.md` | `/git-commit` | 分析未提交变更，按 Conventional Commits（或 commitlint）生成 message，预览确认后执行 add、commit、push（可排除路径或 `不push`） |
| `commands/git-merge.md` | `/git-merge` | 拉取指定远程分支最新代码并合并到当前分支（`--no-ff`），支持 `--no-push`；工作区脏时拒绝；冲突时禁止 AI 自动解冲突并终止 |
| `commands/gitlab-mr.md` | `/gitlab-mr` | 通过 GitLab MCP 生成 MR 标题与描述并创建 Merge Request，支持 `draft`，创建前展示预览等待确认 |
| `commands/review-change.md` | `/review-change` | 在新会话审查上一轮开发会话改动；加载 `review-last-change` Skill，以 `last-session-manifest.md` 为入口 |

---

## Rules（规则）

`.mdc` 规则文件在 AI 响应时生效，分为**始终应用**和**按需应用**两类。

### 始终应用（alwaysApply）

| 文件 | 功能描述 |
|------|----------|
| `rules/ai-behavior.mdc` | 定义 AI 身份、工作流程（先思考再编码）、代码质量要求；要求生成代码后更新 `.cursorlog`；有 `.needs-capability-update` 时提示刷新能力总览 |
| `rules/chinese-language.mdc` | 强制所有思考过程与回答使用中文，英文提问也用中文回答 |
| `rules/code-style.mdc` | 通用编码规范：早返回、DRY、`handle` 前缀事件处理、CSS cursor、类型、绝对路径导入、常量、async/await |
| `rules/development-workflow.mdc` | 多需求先澄清；大型改动分步执行；完成后给验收指引；会话改动由 Hook 写入 manifest，独立审查用 `/review-change` |
| `rules/git-conventions.mdc` | Conventional Commits（中文 subject）、分支命名、原子提交、禁止直接推 main/master、PR 规范 |

### 按需应用（特定文件类型触发）

| 文件 | 适用范围 | 功能描述 |
|------|----------|----------|
| `rules/comment-conventions.mdc` | `.ts/.tsx` | JSDoc 格式、`@description/@param/@returns/@example`，Interface/Enum 字段注释规范 |
| `rules/error-handling.mdc` | `.ts/.tsx` | async/await 须 try-catch、组件 loading/error/data 三态、统一错误类型与 ErrorBoundary |
| `rules/performance.mdc` | `.tsx` | 渲染与资源加载优化：memo、列表 key、虚拟滚动、懒加载、并行请求等 |
| `rules/react-conventions.mdc` | `.tsx` | 组件结构、命名、Props/Hooks、Next.js Server/Client 相关约定 |
| `rules/typescript-conventions.mdc` | `.ts/.tsx` | Interface/Enum/Type 命名前缀、避免 `any`、严格类型习惯 |

---

## Hooks（钩子）

通过 `hooks.json` 注册，在特定 Cursor 事件后自动触发 Shell 脚本。

| 事件 | 脚本 | 功能描述 |
|------|------|----------|
| `sessionStart` | `hooks/session-change-tracker.sh sessionStart` | 初始化本会话改动追踪（清空/准备 `.cursor/reviews` 临时状态） |
| `afterFileEdit` | `hooks/after-file-edit-sync.sh` | 编辑 `.cursor` 下非 `docs` 文件时：若配置目录本身是 Git 仓库则 debounce 后 add/commit/push；并写入 `.needs-capability-update` |
| `afterFileEdit` | `hooks/session-change-tracker.sh afterFileEdit` | 将本次编辑的文件路径追加到会话改动清单临时文件 |
| `stop` | `hooks/session-change-tracker.sh stop` | 会话结束时根据临时清单生成 `reviews/last-session-manifest.md`（有编辑才写；旧清单可归档） |

---

## Skills（技能）

技能是给 AI Agent 的结构化执行指南，通过关键词触发，AI 读取 `SKILL.md` 后按步骤自主执行。

| 技能目录 | 触发词 | 功能描述 | 依赖 |
|----------|--------|----------|------|
| `skills/cursor-capability-check/` | cursor 能力检查、更新能力总览、刷新能力文档 | 扫描 `.cursor` 能力文件，重写本汇总文档，分析依赖与重叠，清理 `.needs-capability-update` | — |
| `skills/fe-reverse-teaching/` | 前端反讲文档、反讲规范、fe-reverse-teaching | 定义反讲文档结构、章节、表格与埋点等写作标准（规范类） | 可选 feishu-mcp（PRD 链接） |
| `skills/find-skill/` | find a skill、有没有技能能做 X、安装技能 | 用 `npx skills` 在开放技能生态中搜索并指引安装 | `npx skills` CLI |
| `skills/git-commit-merge-mr/` | 提交代码并生成 MR、一键发版、commit merge mr | 三阶段：提交 → 合并目标分支 → 创建 GitLab MR；冲突立即终止且禁止 AI 自动解冲突 | GitLab MCP；复用 `/git-commit` `/git-merge` `/gitlab-mr` 逻辑 |
| `skills/image-url-to-local/` | 图片链接、图片 URL、读取图片、识别图片内容 | 下载图片 URL 到临时目录供 Read 读图，完成后 `--clean` 清理 | Node 脚本 `scripts/download-image.js` |
| `skills/review-last-change/` | `/review-change`、审查上次改动、check 上一轮 AI 改动 | 读 `last-session-manifest.md`，做影响面与按需代码审查，可选 typecheck/bugbot | Hook manifest；可选 Bugbot |
| `skills/xmind-browser-code-test/` | XMind 测试、根据 XMind 生成测试报告 | 搬山下载 XMind → 解析用例 → 浏览器对比 → 结合代码审查 → Markdown 报告 | feishu-booking MCP、browser MCP |

---

## Agents（SubAgent）

| 文件 | 触发方式 | 功能描述 |
|------|----------|----------|
| — | — | 当前 `.cursor/agents/` 目录不存在，无项目内自定义 SubAgent |

---

## Scripts（脚本）

手动或由 Hook / Git post-commit 触发的脚本。

| 文件 | 触发方式 | 功能描述 |
|------|----------|----------|
| `scripts/sync-cursor-to-document.sh` | 手动 / `git-post-commit-hook.sh` | rsync `.cursor`（排除 `docs/`）到 `cursor-document` 仓库并 commit/push |
| `scripts/git-post-commit-hook.sh` | 安装到 `.git/hooks/post-commit` | 项目 commit 含 `.cursor` 非 docs 变更时调用 `sync-cursor-to-document.sh` |
| `scripts/git-hooks/post-commit` | `core.hooksPath=.cursor/scripts/git-hooks` | 若项目 `.cursor` 自身为 Git 仓库，则 debounce 后对其 add/commit/push（与 afterFileEdit 同步逻辑同族） |
| `scripts/README.md` | — | 说明同步脚本用途与安装方式（部分描述与当前 Hook 实现存在漂移，见重叠检查） |
| `skills/image-url-to-local/scripts/download-image.js` | Skill 调用 | 下载图片到 skill `temp/` 或 `--clean` 清理 |

---

## 文件关系与依赖

```
┌─────────────────────────────────────────────────────────────────┐
│                     Commands ↔ Skills                            │
├─────────────────────────────────────────────────────────────────┤
│  /git-commit  ──┐                                                │
│  /git-merge   ──┼──编排进──▶  git-commit-merge-mr (Skill)       │
│  /gitlab-mr   ──┘              （一键三阶段，非重复实现入口）      │
│                                                                 │
│  /review-change  ──加载──▶  review-last-change (Skill)           │
│                     ▲                                           │
│                     │ 读取                                       │
│  session-change-tracker (stop) ──写──▶ last-session-manifest.md │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     Rules 交叉引用                                │
├─────────────────────────────────────────────────────────────────┤
│  development-workflow  ──指引──▶  /review-change + Hook manifest │
│  ai-behavior  ──提示──▶  .needs-capability-update               │
│                    └──更新──▶  .cursorlog                       │
│  git-conventions  ──约束──▶  /git-commit / git-commit-merge-mr  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     Hooks / Scripts 同步链                         │
├─────────────────────────────────────────────────────────────────┤
│  hooks.json                                                         │
│    ├─ afterFileEdit → after-file-edit-sync.sh                     │
│    │                    ├─ (.cursor 自为 git) commit/push 配置仓   │
│    │                    └─ 写入 .needs-capability-update          │
│    ├─ afterFileEdit → session-change-tracker.sh (记文件)           │
│    ├─ sessionStart  → session-change-tracker.sh (初始化)           │
│    └─ stop          → session-change-tracker.sh (写 manifest)     │
│                                                                 │
│  git-post-commit-hook.sh ──调用──▶ sync-cursor-to-document.sh     │
│  git-hooks/post-commit   ──同步──▶ .cursor 配置仓本身（若独立 git）│
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     其他 Skill 依赖                               │
├─────────────────────────────────────────────────────────────────┤
│  image-url-to-local  ──调用──▶  download-image.js                 │
│  xmind-browser-code-test ──调用──▶ feishu-booking MCP + browser   │
│  find-skill  ──调用──▶  npx skills CLI                            │
│  cursor-capability-check ──读写──▶ cursor-capabilities.md         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 功能重叠检查

### ⚠️ 重叠 / 漂移项

| 项目 A | 项目 B | 说明 | 建议 |
|--------|--------|------|------|
| `after-file-edit-sync.sh` | `scripts/git-hooks/post-commit` | 两者都会在「`.cursor` 自身为 Git 仓库」时 debounce 后 commit/push，触发源不同（编辑 vs 项目 commit） | 保留双触发可接受；建议统一日志与 debounce 配置说明，避免文档写乱 |
| `scripts/README.md` | 实际 `after-file-edit-sync.sh` | README 仍写 Hook 会调用 `sync-cursor-to-document.sh`，但当前 Hook **不**调用该脚本，而是直接提交 `.cursor` 配置仓并写 `.needs-capability-update` | 更新 README，与实现对齐 |
| `sync-cursor-to-document.sh` | `after-file-edit-sync.sh` / `git-hooks/post-commit` | 同步目标不同：前者 → `cursor-document`；后者 → `.cursor` 自身 remote | 属双通道备份，需在文档中明确「谁同步到哪」以免运维困惑 |

### ✅ 合理分层

| 组合 | 说明 |
|------|------|
| `/git-commit` + `/git-merge` + `/gitlab-mr` ↔ `git-commit-merge-mr` | 单步命令 vs 一键编排；Skill 显式复用三阶段逻辑，非并行维护两套无关实现 |
| `/review-change` ↔ `review-last-change` | Command 为入口，Skill 为实现，合理 |
| `session-change-tracker` ↔ `review-last-change` | Hook 生产 manifest，Skill 消费审查，流水线清晰 |
| `fe-reverse-teaching`（规范） | 无配套执行 Skill 时单独作为写作规范使用，与执行类技能分层一致 |
| `image-url-to-local`（工具） | 供读图场景复用，与业务 Skill 解耦 |

---

*本文档由 cursor-capability-check Skill 维护，请勿手动编辑。*
