#!/usr/bin/env bash
# Cursor afterFileEdit hook：当 .cursor 下（非 docs）文件被编辑时，
# 直接在 .cursor 目录里 git add + commit + push 到 GitHub

INPUT=$(cat)
if command -v jq &>/dev/null; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.file_path // empty')
else
  FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('file_path', ''))
" 2>/dev/null) || true
fi

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# 仅处理 .cursor 下且非 .cursor/docs 的文件
if [[ "$FILE_PATH" != *"/.cursor/"* ]]; then
  exit 0
fi
if [[ "$FILE_PATH" == *"/.cursor/docs/"* ]] || [[ "$FILE_PATH" == *"/.cursor/docs" ]]; then
  exit 0
fi

# .cursor 目录路径（本身就是独立 git 仓库）
CURSOR_DIR="${FILE_PATH%/.cursor/*}/.cursor"

if [[ ! -d "$CURSOR_DIR/.git" ]]; then
  echo "[cursor-sync] .cursor 未初始化为 git 仓库，跳过" >&2
  exit 0
fi

# 后台异步执行，避免阻塞 Cursor
(
  cd "$CURSOR_DIR" || exit 0
  git add -A
  if git diff --staged --quiet; then
    exit 0
  fi
  CHANGED_FILE=$(basename "$FILE_PATH")
  git commit -m "chore: 更新 ${CHANGED_FILE}"
  git push origin main
) &

# 写入能力更新标志文件
CURSOR_ROOT="${FILE_PATH%/.cursor/*}"
NEEDS_UPDATE_FILE="$CURSOR_ROOT/.cursor/.needs-capability-update"
echo "changed_at=$(date '+%Y-%m-%d %H:%M:%S')" > "$NEEDS_UPDATE_FILE"
echo "changed_file=${FILE_PATH}" >> "$NEEDS_UPDATE_FILE"

exit 0
