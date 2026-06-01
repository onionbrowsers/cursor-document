# 提交代码

分析当前项目未提交的代码变更，由 AI 自动生成符合 Conventional Commits 规范的 commit message，完成 git add + git commit + git push 的完整提交流程。

**用法**：

- `/git-commit`：将所有未提交的变更提交并推送到远端
- `/git-commit 排除 <文件或目录>`：提交时忽略指定的文件或目录，多个用空格或逗号分隔，例如：`/git-commit 排除 src/temp dist`
- `/git-commit 不push`：只提交本地 commit，不执行 push

**执行步骤**：

1. 运行 `git status` 获取所有未暂存/已暂存的变更文件列表
2. 运行 `git diff HEAD`（或 `git diff` + `git diff --cached`）读取完整的代码变更内容
3. 根据用户输入，确定需要排除的文件或目录（若无则不排除）
4. 分析变更内容，判断本次改动的性质，选择合适的 commit type：
   - `feat`：新增功能
   - `fix`：修复 bug
   - `docs`：文档变更
   - `style`：代码格式调整（不影响逻辑）
   - `refactor`：重构
   - `perf`：性能优化
   - `test`：测试相关
   - `chore`：构建/工程化/依赖更新
   - `revert`：回滚
   - `ci`：CI/CD 配置
5. 根据变更内容总结 commit subject（中文，动词开头，不超过 50 字，末尾不加句号），若涉及多个模块可加 scope
6. 将完整执行计划展示给用户预览，包含：
   - 将被提交的文件列表
   - 将被排除的文件（若有）
   - 生成的 commit message，格式为：`<type>(<scope>): <subject>`
   - 是否执行 push 及目标远端分支
7. **等待用户确认**，若用户同意则依次执行：
   - `git add` 所有需要提交的文件（排除用户指定的文件/目录）
   - `git commit -m "<message>"`
   - `git push`（除非用户指定不 push）
8. 每步执行后输出结果，全部完成后汇总展示提交结果

**注意事项**：

- 执行前检查项目根目录是否存在 `commitlint.config.js`：若存在则读取并严格按照其规则生成 commit message；若不存在则遵循 Conventional Commits 默认规范（`<type>(<scope>): <subject>`）
- 若变更涉及多个不相关模块，提示用户是否需要拆分为多次提交
- 若工作区干净（无未提交变更），直接告知用户无需提交
- 排除文件时使用 `git add` 的路径精确匹配，而非 `git add .` 后再 reset 的方式
- push 前先检查当前分支是否有对应远端跟踪分支，若无则使用 `git push -u origin <branch>` 自动建立追踪
- 禁止向 `main` / `master` 分支直接 push，若当前在这两个分支上需提示用户确认
