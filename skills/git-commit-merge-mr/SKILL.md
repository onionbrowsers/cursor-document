---
name: git-commit-merge-mr
description: 一键完成「提交代码 → 合并目标分支 → 创建 GitLab MR」全流程。当用户说「提交代码并生成MR」「提交并合并 <分支> 然后建 MR」「一键发版」「commit merge mr」等，且明确提供了对比分支时触发。必须提供目标分支名，否则提示补充。
---

# 提交代码 + 合并分支 + 创建 GitLab MR 全流程

## 触发场景

- 用户说「提交代码并生成 MR」「提交并合并 `<分支>` 然后建 MR」「一键提交发版」「commit、merge、建 MR」等
- 用户明确提供了一个**目标对比分支**（如 `release-610`）

## 输入

- **目标分支**（必填）：用于合并和创建 MR 的目标分支名，例如 `release-610`
- **排除文件**（可选）：提交时需要排除的文件或目录，多个用空格分隔
- **draft**（可选）：若用户希望创建草稿 MR，传入 `draft`

> ⚠️ **目标分支为必填项**。若用户未提供，立即终止并提示：「请提供目标分支名，例如：提交代码并合并到 release-610 然后建 MR」

---

## 阶段一：提交代码（git-commit）

### 1.1 检查工作区状态

- 运行 `git status` 获取所有变更文件列表
- 运行 `git diff HEAD` 读取完整变更内容
- **若工作区干净**（无任何未提交变更）：跳过阶段一，直接进入阶段二，并告知用户「工作区无变更，跳过提交步骤」

### 1.2 分析变更内容，生成 commit message

- 检查项目根目录是否存在 `commitlint.config.js`，若存在则遵循其规则；否则遵循 Conventional Commits 规范
- 根据变更文件和 diff 内容判断改动性质，选择合适的 `type`：
  - `feat`：新增功能
  - `fix`：修复 bug
  - `docs`：文档变更
  - `style`：代码格式调整
  - `refactor`：重构
  - `perf`：性能优化
  - `test`：测试相关
  - `chore`：构建/工程化/依赖更新
  - `revert`：回滚
  - `ci`：CI/CD 配置
- 生成 commit subject：中文，动词开头，不超过 50 字，末尾不加句号
- 若涉及多个模块，提示用户是否需要拆分（等待确认，若用户选择拆分则终止本 skill，由用户手动操作）

### 1.3 展示提交计划，等待确认

展示以下信息：

```
【阶段一 - 提交代码】
将被提交的文件：
  - <文件列表>
排除的文件（若有）：
  - <排除文件列表>
Commit message：<type>(<scope>): <subject>
推送目标：origin/<当前分支>

【阶段二 - 合并分支】（提交后自动执行）
  拉取 <目标分支> 最新代码 → 合并到当前分支

【阶段三 - 创建 MR】（合并成功后自动执行）
  源分支 → 目标分支：<当前分支> → <目标分支>

确认后将依次执行全部步骤，是否继续？
```

**等待用户确认**，用户同意后方可执行后续步骤。

### 1.4 执行提交

依次执行：
1. `git add` 所有变更文件（排除用户指定的文件/目录）
2. `git commit -m "<message>"`
3. 检查当前分支是否有远端跟踪分支：
   - 若有：`git push`
   - 若无：`git push -u origin <当前分支>`
4. 输出提交结果，记录 commit hash

**注意**：禁止向 `main` / `master` 分支直接 push，若当前在这两个分支需提示用户确认。

---

## 阶段二：合并目标分支（git-merge）

> 阶段一完成（或工作区本就干净）后，自动进入此阶段，**不再等待用户确认**。

### 2.1 验证状态

- 运行 `git branch --show-current` 记录 `CURRENT_BRANCH`
- 若处于 detached HEAD 状态，终止并提示
- 若 `CURRENT_BRANCH` 与目标分支相同，终止并提示「当前已在目标分支，无需合并」
- 运行 `git status --porcelain` 再次确认工作区干净（阶段一执行后应已干净）

### 2.2 fetch 目标分支

- 运行 `git fetch origin <目标分支>`
- 若 fetch 失败（分支不存在或网络问题），输出错误，**终止全流程**（不创建 MR）

### 2.3 切换到目标分支并 pull

- 运行 `git checkout <目标分支>`
  - 若本地不存在该分支，使用 `git checkout -b <目标分支> origin/<目标分支>`
- 运行 `git pull origin <目标分支>`
- 若 pull 失败，切换回 `CURRENT_BRANCH`，**终止全流程**

### 2.4 切换回开发分支并执行合并

- 运行 `git checkout <CURRENT_BRANCH>`
- 运行 `git merge <目标分支> --no-ff -m "Merge branch '<目标分支>' into <CURRENT_BRANCH>"`
- **合并结果判断**：
  - ✅ **无冲突**：继续执行
  - ⚠️ **有冲突**：运行 `git diff --name-only --diff-filter=U` 列出冲突文件，输出提示：
    ```
    合并出现冲突，请按以下步骤手动处理：
    1. 解决以下文件中的冲突标记（<<<<<</>>>>>>）：
       - <冲突文件列表>
    2. 执行 git add <冲突文件> 标记已解决
    3. 执行 /git-commit 完成 merge commit
    4. 完成后再手动执行 /gitlab-mr <目标分支> 创建 MR
    ```
    **终止全流程，不创建 MR**

### 2.5 推送合并结果

- 检查当前分支是否有远端跟踪分支：
  - 若有：`git push`
  - 若无：`git push -u origin <CURRENT_BRANCH>`
- 输出合并推送结果

---

## 阶段三：创建 GitLab MR（gitlab-mr）

> 阶段二合并且推送成功后，自动进入此阶段，**不再等待用户确认**。

### 3.1 获取基础信息

- 运行 `git remote get-url origin` 解析 GitLab project path
  - SSH 格式：`git@host:group/project.git` → `group/project`
  - HTTPS 格式：`https://host/group/project.git` → `group/project`
- 调用 GitLab MCP 工具 `whoami` 获取当前用户 `id`、`name`

### 3.2 收集提交记录

- 运行 `git log --oneline origin/<目标分支>..HEAD` 获取本分支相对目标分支的提交列表（即 MR 包含的所有提交）

### 3.3 生成 MR 标题和描述

- **标题**：分析提交记录，按 Conventional Commits 规范提炼，格式 `<type>(<scope>): <subject>`（中文，不超过 50 字）
- **描述**：生成以下结构的 Markdown：

  ```markdown
  ## 变更说明

  ### <新增功能 / 问题修复 / 工程改进>（按实际变更归类）
  - 逐条列出本次改动要点

  ## 测试
  - [ ] 单元测试通过
  - [ ] 功能手动验证通过
  ```

### 3.4 调用 GitLab MCP 创建 MR

使用 GitLab MCP 工具 `create_merge_request`，传入：
- `project_id`：步骤 3.1 解析的 project path
- `title`：步骤 3.3 生成的标题
- `description`：步骤 3.3 生成的描述
- `source_branch`：`CURRENT_BRANCH`
- `target_branch`：目标分支
- `assignee_ids`：`[当前用户 id]`
- `draft`：用户传入 `draft` 时为 `true`，否则 `false`
- `remove_source_branch`：`false`

> 调用前必须先读取 GitLab MCP 工具的 schema 文件（位于 MCP 目录下）确认参数格式。

### 3.5 输出最终结果

```
========================================
全流程执行完成！

【阶段一 - 提交代码】✅
  Commit: <hash> - <message>
  已推送至 origin/<分支>

【阶段二 - 合并分支】✅
  release-610 → <当前分支>，无冲突
  已推送至 origin/<分支>

【阶段三 - GitLab MR】✅
  MR !<编号>：<标题>
  链接：<web_url>
========================================
```

---

## 全局注意事项

- **目标分支为必填项**，缺少时立即终止，不执行任何 git 操作
- **阶段一**需要用户确认后才执行，**阶段二和三**在上一阶段成功后自动连续执行，无需再次确认
- 若 **阶段二合并出现冲突**，终止全流程，提示用户手动解决后再执行 `/gitlab-mr <目标分支>`
- 若 **GitLab MCP 返回认证错误**，提示用户检查 GitLab MCP 配置，不影响阶段一二的已完成结果
- 所有步骤按阶段逐步输出状态，每个阶段完成后打印进度，全部完成后输出汇总
- 若工作区存在 merge 冲突状态（`Unmerged paths`），不允许执行，提示用户先解决冲突
