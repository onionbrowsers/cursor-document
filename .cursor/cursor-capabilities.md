# .cursor 能力总览

> **最后更新：** 2026-03-26  
> **本次扫描：** 6 个 commands、10 条 rules（4 条 alwaysApply）、1 个 hook、10 个 skills、1 个 agent、3 个 scripts（含 README）  
> **本次触发原因：** `afterFileEdit` 写入 `.cursor/.needs-capability-update`（`changed_file=.cursor/.cursorlog`，`changed_at=2026-03-26 15:29:13`），已执行本 Skill 并清理标志文件。

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
| `commands/feishu-doc-summary.md` | `/feishu-doc-summary` | 给定飞书文档 ID 或 URL，读取正文及图片，生成包含一句话概述、核心要点、详细摘要的结构化中文摘要 |
| `commands/git-branch-cleanup.md` | `/git-branch-cleanup` | 批量删除已合并到主干的本地和远程 Git 分支，支持预览模式，自动保护 main/master/develop 等分支 |
| `commands/git-commit.md` | `/git-commit` | 分析未提交变更，AI 自动生成符合 Conventional Commits 规范的中文 commit message，经用户确认后执行完整提交流程 |
| `commands/tapd-bug-info.md` | `/tapd-bug` | 根据 Bug ID 查询 TAPD 缺陷详情，结构化展示标题、状态、优先级、严重程度及链接 |
| `commands/tapd-bug-status.md` | `/tapd-bug-status` | 更新指定 TAPD 缺陷状态，改为「已解决」时强制总结原因与方案并写入评论 |
| `commands/tapd-todo.md` | `/tapd-todo` | 拉取当前用户所有 TAPD 项目待办（Bug/需求/任务），生成当日待办清单 MD 写入 `docs/todoList/` |

---

## Rules（规则）

`.mdc` 规则文件在 AI 每次响应时生效，分为**始终应用**和**按需应用**两类。

### 始终应用（alwaysApply）

| 文件 | 功能描述 |
|------|----------|
| `rules/ai-behavior.mdc` | 定义 AI 身份（高级前端开发者）、工作流程（先思考伪代码再编码）、代码质量要求，规定每次生成代码后更新 `.cursorlog` |
| `rules/chinese-language.mdc` | 强制所有思考过程与回答内容使用中文，包括注释、计划、分析等，英文提问也用中文回答 |
| `rules/code-style.mdc` | 通用编码规范：早返回、DRY、`handle` 前缀事件处理、CSS cursor 规范、类型定义、绝对路径导入、常量 UPPER_SNAKE_CASE、async/await |
| `rules/git-conventions.mdc` | Git 规范：Conventional Commits 格式（中文描述）、分支命名前缀、原子提交、禁止直接推 main/master |

### 按需应用（特定文件类型触发）

| 文件 | 适用范围 | 功能描述 |
|------|----------|----------|
| `rules/comment-conventions.mdc` | `.ts/.tsx` | JSDoc `/** */` 格式、`@description/@param/@returns/@example`，Interface/Enum 字段行内注释，禁止叙述性注释 |
| `rules/error-handling.mdc` | `.ts/.tsx` | async/await 必须 try-catch、组件三态（loading/error/data）、统一 ApiError 类、ErrorBoundary |
| `rules/performance.mdc` | `.tsx` | useMemo/useCallback/React.memo 正确使用、列表 key 不用 index、虚拟滚动（>100条）、路由懒加载、Promise.all 并行 |
| `rules/react-conventions.mdc` | `.tsx` | 目录结构、PascalCase 命名、Props 接口 `I` 前缀、自定义 Hook `use` 前缀、Next.js Server/Client 规范 |
| `rules/tapd-todo-list-md.mdc` | 按需 | TAPD 待办清单 MD 格式：文件命名、三类固定标题、Markdown 表格规范 |
| `rules/typescript-conventions.mdc` | `.ts/.tsx` | Interface `I` 前缀、Enum `E` 前缀、Type `T` 前缀、数组 `T[]` 格式、避免 `any` 用 `unknown`、tsconfig 严格模式 |

---

## Hooks（钩子）

通过 `hooks.json` 注册，在特定 Cursor 事件后自动触发 Shell 脚本。

| 事件 | 脚本 | 功能描述 |
|------|------|----------|
| `afterFileEdit` | `hooks/after-file-edit-sync.sh` | 当编辑的是 `.cursor` 目录下（排除 `.cursor/docs`）的文件时，自动调用同步脚本将 `.cursor` 目录同步到外部 `cursor-document` Git 仓库 |

---

## Skills（技能）

技能是给 AI Agent 的结构化执行指南，通过关键词触发，AI 读取 `SKILL.md` 后按步骤自主执行。

| 技能目录 | 触发词 | 功能描述 | 依赖 |
|----------|--------|----------|------|
| `skills/fe-reverse-teaching/` | 前端反讲文档、反讲规范 | 定义反讲文档结构（7章节）、代码注释格式、接口表格、埋点表格写法，禁止 HTML 表格，Mermaid 须转 mermaid.ink | — |
| `skills/feishu-docx-read-with-images/` | 飞书文档读图、飞书 PRD 图片 | 读取飞书 docx 正文 + 内嵌图片联合分析：收集图片 token → 换临时链 → 下载 → 读图 → 汇总 | `image-url-to-local` |
| `skills/feishu-wiki-to-md/` | 飞书转 Markdown、批量转换飞书文档 | 遍历飞书 Wiki 空间/节点下所有 docx，批量转 MD 保存到 `.cursor/docs/` | feishu-mcp |
| `skills/find-skill/` | 有没有技能能做 X、找一个技能 | 在开放技能生态中搜索匹配的技能，找到后提供安装命令 | `npx skills` CLI |
| `skills/image-url-to-local/` | 图片链接、图片 URL、读取图片 | 将图片 URL 下载到本地临时目录，返回路径供 Read 工具分析，用后清理 | Node.js |
| `skills/tapd-bug-verify-and-resolve/` | 验证 bug 修复、bug 改已解决 | 查询 Bug 详情 → 代码定位 → 浏览器验证 → 用户确认 → 可选提交 → 更新状态并填写原因方案 | tapd-mcp、browser |
| `skills/tapd-todo-sync/` | 查待办、生成待办清单、同步 TAPD | 拉取全部空间待办，按时间过滤，生成当日待办清单 MD 写入 `todoList/` | `tapd-todo-fetch` SubAgent、`tapd-todo-list-md` 规则 |
| `skills/write-fe-reverse-teaching-doc/` | 写反讲、前端反讲文档、fe-reverse-teaching | 读 PRD → 本地创建 MD → Mermaid 转图片链接 → 插入飞书文档 | `fe-reverse-teaching` 规范、feishu-mcp |
| `skills/xmind-browser-code-test/` | 基于 XMind 测试、自动测试报告 | 下载 XMind → 解析用例 → 浏览器截图 → 结合代码审查 → 生成 Markdown 测试报告 | feishu-mcp（下载）、browser |
| `skills/cursor-capability-check/` | cursor 能力检查、更新能力总览 | 扫描 `.cursor` 全目录，重新生成本文档，并分析文件关系与功能重叠 | — |

---

## Agents（SubAgent）

通过 `Task` 工具启动的专用子 Agent，处理批量或并行任务。

| 文件 | 触发方式 | 功能描述 |
|------|----------|----------|
| `agents/tapd-todo-fetch.md` | `tapd-todo-sync` Skill 内部调用 | 接收一批 workspace_id，对每个空间分别拉取 story/bug/task 三类待办（各 limit=50），合并为结构化 JSON 返回 |

---

## Scripts（脚本）

手动或由 Hook/Git Post-commit 自动触发的 Shell 脚本。

| 文件 | 触发方式 | 功能描述 |
|------|----------|----------|
| `scripts/sync-cursor-to-document.sh` | Hook 触发 / 手动 | 用 rsync 将 `.cursor`（排除 `docs/`）同步到 `/Users/mac/companycode/cursor-document`，并在目标仓库执行 add + commit + push |
| `scripts/git-post-commit-hook.sh` | Git post-commit | 项目 git commit 后，若本次提交含 `.cursor` 非 docs 变更，自动触发同步脚本 |
| `scripts/README.md` | — | 说明同步脚本用途、两种触发机制（Cursor Hook + Git post-commit）及新环境安装方式 |

---

## 文件关系与依赖

```
┌─────────────────────────────────────────────────────────────────┐
│                        Skills 依赖关系                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  feishu-docx-read-with-images  ──依赖──▶  image-url-to-local   │
│                                                                 │
│  write-fe-reverse-teaching-doc ──遵循──▶  fe-reverse-teaching   │
│                             └──调用──▶  feishu-mcp              │
│                                                                 │
│  tapd-todo-sync  ──启动──▶  tapd-todo-fetch (SubAgent)          │
│                  ──遵循──▶  tapd-todo-list-md (Rule)            │
│                                                                 │
│  tapd-bug-verify-and-resolve  ──调用──▶  tapd-mcp               │
│                               └──调用──▶  browser MCP           │
│                                                                 │
│  xmind-browser-code-test  ──调用──▶  feishu-mcp（下载）         │
│                           └──调用──▶  browser MCP               │
│                                                                 │
│  feishu-wiki-to-md  ──调用──▶  feishu-mcp                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                       Commands 与 Skills 关系                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  /tapd-todo  ──功能重叠──▶  tapd-todo-sync (Skill)              │
│   （轻量命令触发）              （完整 Skill 实现）               │
│                                                                 │
│  /tapd-bug-status  ──功能部分重叠──▶  tapd-bug-verify-and-resolve│
│   （仅更新状态）                 （含验证+代码+浏览器完整流程）   │
│                                                                 │
│  /feishu-doc-summary  ──功能子集──▶  feishu-docx-read-with-images│
│   （纯文字摘要）                    （含图片读取）               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                       Hooks 与 Scripts 关系                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  hooks.json  ──注册──▶  after-file-edit-sync.sh                 │
│                                   └──调用──▶  sync-cursor-to-document.sh │
│                                                                 │
│  scripts/git-post-commit-hook.sh  ──调用──▶  sync-cursor-to-document.sh  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 功能重叠检查

> 以下是当前发现的功能重叠或可优化点，供参考：

### ⚠️ 重叠项

| 项目 A | 项目 B | 重叠说明 | 建议 |
|--------|--------|----------|------|
| `/tapd-todo` Command | `tapd-todo-sync` Skill | 两者均生成 TAPD 待办清单 MD，逻辑高度相似 | Command 可简化为调用 Skill 的入口，避免维护两套 |
| `/tapd-bug-status` Command | `tapd-bug-verify-and-resolve` Skill | `/tapd-bug-status` 是 Skill 功能的子集（仅状态更新） | 建议 Skill 内部复用 Command 的状态更新逻辑 |
| `/feishu-doc-summary` Command | `feishu-docx-read-with-images` Skill | `/feishu-doc-summary` 不含图片处理，Skill 是超集 | 可在 Command 中提示"需要读图时使用 feishu-docx-read-with-images Skill" |

### ✅ 合理分层

| 组合 | 说明 |
|------|------|
| `fe-reverse-teaching` (规范) + `write-fe-reverse-teaching-doc` (执行) | 规范与执行分离，合理 |
| `tapd-todo-list-md` (格式规则) + `tapd-todo-sync` (执行 Skill) | 格式规则独立，可被多个 Skill 引用 |
| `image-url-to-local` (工具 Skill) + `feishu-docx-read-with-images` (业务 Skill) | 工具层与业务层解耦，合理 |

---

*本文档由 `cursor-capability-check` Skill 维护，请勿手动编辑。*
