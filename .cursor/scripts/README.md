# .cursor 同步脚本

## sync-cursor-to-document.sh

将当前项目 `.cursor` 目录（**排除 `docs`**）同步到 `/Users/mac/companycode/cursor-document`，并在该仓库内 `git add`、`commit`、`push`。

- 被 **Cursor afterFileEdit hook** 与 **Git post-commit hook** 调用。
- 也可手动执行：`./.cursor/scripts/sync-cursor-to-document.sh`

## 自动同步机制

1. **Cursor Hook**（`afterFileEdit`）：在 Cursor 内用 Agent/Tab 编辑 `.cursor` 下非 `docs` 的文件并保存后，会自动执行同步并 push。
2. **Git post-commit**：在项目内执行 `git commit` 且本次提交包含 `.cursor` 下非 `docs` 的变更时，会自动执行同步并 push。

## 新环境安装 Git hook

在其他机器 clone 本仓库后，若需启用「commit 后自动同步」，请执行一次：

```bash
cp .cursor/scripts/git-post-commit-hook.sh .git/hooks/post-commit && chmod +x .git/hooks/post-commit
```

## 依赖

- `rsync`（macOS 自带）
- `jq` 或 `python3`（Cursor hook 解析 JSON 用；若未安装 jq 可用 `brew install jq`，或使用系统自带的 python3）
- 目标目录 `cursor-document` 需已初始化为 Git 仓库并配置好 remote
