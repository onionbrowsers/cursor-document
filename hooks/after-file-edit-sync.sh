#!/usr/bin/env bash
# Cursor afterFileEdit hook：当 .cursor 配置仓库下（非 docs）文件被编辑时，
# 直接在该 .cursor 配置仓库里 git add + commit + push 到 GitHub。
# 兼容项目内 .cursor 软链接到 ~/.cursor/shared-config 的场景。

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

SHARED_CURSOR_DIR="${CURSOR_SHARED_CONFIG_DIR:-$HOME/.cursor/shared-config}"

if command -v realpath >/dev/null 2>&1; then
  REAL_FILE_PATH=$(realpath "$FILE_PATH" 2>/dev/null || printf '%s' "$FILE_PATH")
else
  REAL_FILE_PATH="$FILE_PATH"
fi

CURSOR_DIR=""
if [[ "$FILE_PATH" == *"/.cursor/"* ]]; then
  CURSOR_DIR="${FILE_PATH%/.cursor/*}/.cursor"
elif [[ "$REAL_FILE_PATH" == "$SHARED_CURSOR_DIR/"* ]]; then
  CURSOR_DIR="$SHARED_CURSOR_DIR"
else
  exit 0
fi

# 仅处理 .cursor 下且非 docs 的文件
if [[ "$FILE_PATH" == *"/.cursor/docs/"* ]] || [[ "$FILE_PATH" == *"/.cursor/docs" ]] || [[ "$REAL_FILE_PATH" == "$CURSOR_DIR/docs/"* ]] || [[ "$REAL_FILE_PATH" == "$CURSOR_DIR/docs" ]]; then
  exit 0
fi

if [[ ! -d "$CURSOR_DIR/.git" ]]; then
  echo "[cursor-sync] .cursor 配置目录未初始化为 git 仓库，跳过: $CURSOR_DIR" >&2
  exit 0
fi

if [[ ! -f "$CURSOR_DIR/hooks.json" && ! -d "$CURSOR_DIR/rules" && ! -d "$CURSOR_DIR/skills" && ! -d "$CURSOR_DIR/commands" ]]; then
  echo "[cursor-sync] 目标目录不是 Cursor 配置仓库，跳过: $CURSOR_DIR" >&2
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
NEEDS_UPDATE_FILE="$CURSOR_DIR/.needs-capability-update"
echo "changed_at=$(date '+%Y-%m-%d %H:%M:%S')" > "$NEEDS_UPDATE_FILE"
echo "changed_file=${FILE_PATH}" >> "$NEEDS_UPDATE_FILE"

exit 0
