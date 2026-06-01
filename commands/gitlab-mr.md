# 创建 GitLab Merge Request

通过 GitLab MCP 自动读取当前分支信息与提交记录，生成规范的 MR 标题和描述，并调用 GitLab MCP 创建 Merge Request。

**用法**：

- `/gitlab-mr <目标分支>`：将当前分支合并到指定目标分支，例如：`/gitlab-mr release-610`
- `/gitlab-mr <目标分支> draft`：创建草稿 MR，例如：`/gitlab-mr release-610 draft`

> ⚠️ **必须提供目标分支**，否则直接提示用户补充参数，不执行后续步骤。

**执行步骤**：

1. **参数校验**：解析用户输入，提取 `目标分支`（必填）和可选的 `draft` 标记；若未提供目标分支，立即提示用户补充后重试，终止执行。

2. **读取当前分支信息**：
   - 运行 `git branch --show-current` 获取当前源分支名称
   - 若当前处于 detached HEAD 状态，提示用户切换到具名分支后重试，终止执行

3. **获取项目路径**：
   - 运行 `git remote get-url origin` 获取远端地址
   - 从 URL 中解析 GitLab project path（格式为 `group/project`），支持 SSH（`git@host:group/project.git`）和 HTTPS（`https://host/group/project.git`）两种格式

4. **获取当前用户信息**：
   - 调用 GitLab MCP 工具 `whoami` 获取当前认证用户的 `id`、`name`、`username`

5. **收集提交记录**：
   - 运行 `git log --oneline origin/<目标分支>..HEAD`（若无法 fetch 则用 `git log --oneline -20`）获取当前分支相对目标分支的提交列表

6. **生成 MR 标题与描述**：
   - **标题**：分析提交记录，按 Conventional Commits 规范提炼，格式 `<type>(<scope>): <subject>`（中文 subject，不超过 50 字）；若只有一个提交则直接使用该提交的 message
   - **描述**：生成以下结构的 Markdown 描述：

     ```markdown
     ## 变更说明

     ### 新增功能 / 问题修复 / 工程改进（按实际变更归类）
     - 逐条列出本次改动要点

     ## 测试
     - [ ] 单元测试通过
     - [ ] 功能手动验证通过
     ```

7. **展示预览并等待用户确认**：
   - 展示以下信息供确认：
     - 源分支 → 目标分支
     - project_id
     - MR 标题
     - MR 描述（完整）
     - assignee（当前用户）
     - 是否草稿
   - **等待用户确认**，若用户同意再执行创建

8. **调用 GitLab MCP 创建 MR**：
   - 使用 GitLab MCP 工具 `create_merge_request`，传入以下参数：
     - `project_id`：步骤 3 解析的 project path
     - `title`：步骤 6 生成的标题
     - `description`：步骤 6 生成的描述
     - `source_branch`：当前分支
     - `target_branch`：用户指定的目标分支
     - `assignee_ids`：`[当前用户 id]`
     - `draft`：是否草稿（用户传入 `draft` 参数时为 `true`，否则为 `false`）
     - `remove_source_branch`：`false`

9. **输出结果**：创建成功后展示 MR 编号、标题、状态和 `web_url` 链接。

**注意事项**：

- 必须提供目标分支，缺少时直接报错提示，不进行任何 GitLab 操作
- 若当前分支与目标分支相同，提示用户确认后再继续
- MR 标题和描述均使用**中文**描述
- GitLab MCP 工具调用前必须先读取对应工具的 schema 文件（位于 MCP 目录下）确认参数格式
- 若 GitLab MCP 返回认证错误，提示用户检查 GitLab MCP 配置
