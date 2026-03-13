#!/usr/bin/env bash
# Git post-commit：若本次 commit 涉及 .cursor（排除 docs），则同步到 cursor-document 并 push
# 安装到当前仓库：cp .cursor/scripts/git-post-commit-hook.sh .git/hooks/post-commit && chmod +x .git/hooks/post-commit

ROOT="$(git rev-parse --show-toplevel)"
CHANGED=$(git diff-tree --no-commit-id --name-only -r HEAD)

NEED_SYNC=false
while IFS= read -r path; do
  if [[ "$path" == .cursor/* ]] && [[ "$path" != .cursor/docs/* ]] && [[ "$path" != .cursor/docs ]]; then
    NEED_SYNC=true
    break
  fi
done <<< "$CHANGED"

if [[ "$NEED_SYNC" != "true" ]]; then
  exit 0
fi

SYNC_SCRIPT="$ROOT/.cursor/scripts/sync-cursor-to-document.sh"
if [[ ! -x "$SYNC_SCRIPT" ]]; then
  echo "[post-commit] 同步脚本不存在或不可执行: $SYNC_SCRIPT" >&2
  exit 0
fi

"$SYNC_SCRIPT" "$ROOT"
exit 0
