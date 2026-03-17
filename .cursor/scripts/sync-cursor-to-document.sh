#!/usr/bin/env bash
# 将 .cursor（排除 docs）同步到 cursor-document 并 push
# 可被 Cursor afterFileEdit hook 与 Git post-commit hook 调用
# 注意：不使用 set -e，避免某一步失败时静默中断；关键步骤单独判断并输出错误信息

CURSOR_DOCUMENT_DIR="/Users/mac/companycode/cursor-document"

# 项目根目录：优先参数，其次 CURSOR_PROJECT_DIR，最后 git 根
if [[ -n "$1" ]]; then
  PROJECT_ROOT="$1"
elif [[ -n "$CURSOR_PROJECT_DIR" ]]; then
  PROJECT_ROOT="$CURSOR_PROJECT_DIR"
else
  PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || true
fi

if [[ -z "$PROJECT_ROOT" || ! -d "$PROJECT_ROOT/.cursor" ]]; then
  echo "[sync-cursor] 未找到项目根或 .cursor 目录，跳过同步"
  exit 0
fi

SOURCE_DIR="$PROJECT_ROOT/.cursor"
DEST_DIR="$CURSOR_DOCUMENT_DIR/.cursor"
mkdir -p "$DEST_DIR"

# 同步 .cursor 到目标的 .cursor 子目录，排除 docs，保留目标根目录其他内容（如 .git）
if ! rsync -a --delete \
  --exclude='docs' \
  "$SOURCE_DIR/" \
  "$DEST_DIR/"; then
  echo "[sync-cursor] rsync 失败，请检查路径与权限" >&2
  exit 1
fi

# 在 cursor-document 仓库内提交并推送
if [[ ! -d "$CURSOR_DOCUMENT_DIR/.git" ]]; then
  echo "[sync-cursor] $CURSOR_DOCUMENT_DIR 不是 Git 仓库，已同步文件，跳过 push"
  exit 0
fi

cd "$CURSOR_DOCUMENT_DIR" || { echo "[sync-cursor] 无法 cd 到 $CURSOR_DOCUMENT_DIR" >&2; exit 1; }
git add -A
if git diff --staged --quiet; then
  echo "[sync-cursor] 无变更，跳过 commit/push"
  exit 0
fi

if ! git commit -m "chore: 从 precision-study-mvp 同步 .cursor（排除 docs）"; then
  echo "[sync-cursor] git commit 失败，请检查 cursor-document 仓库状态" >&2
  exit 1
fi

if ! git push; then
  echo "[sync-cursor] git push 失败（常见原因：未配置认证、网络、保护分支），请手动在 cursor-document 目录执行 git push" >&2
  exit 1
fi

echo "[sync-cursor] 已同步并 push 到 cursor-document"
