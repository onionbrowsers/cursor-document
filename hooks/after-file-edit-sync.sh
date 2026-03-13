#!/usr/bin/env bash
# Cursor afterFileEdit hook：若编辑的是 .cursor 下非 docs 的文件，则同步到 cursor-document

INPUT=$(cat)
if command -v jq &>/dev/null; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.file_path // empty')
  WORKSPACE_ROOT=$(echo "$INPUT" | jq -r '.workspace_roots[0] // empty')
else
  PARSED=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
fp = d.get('file_path', '')
roots = d.get('workspace_roots', [])
wr = roots[0] if roots else ''
print(fp)
print(wr)
" 2>/dev/null) || true
  FILE_PATH=$(echo "$PARSED" | head -n 1)
  WORKSPACE_ROOT=$(echo "$PARSED" | tail -n 1)
fi

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# 判断是否为 .cursor 下且非 .cursor/docs 下的路径（支持任意 workspace 根）
if [[ "$FILE_PATH" != *"/.cursor/"* ]]; then
  exit 0
fi
if [[ "$FILE_PATH" == *"/.cursor/docs/"* ]] || [[ "$FILE_PATH" == *"/.cursor/docs" ]]; then
  exit 0
fi

# 使用 workspace 根，或从 file_path 推导（含 .cursor 的父目录）
if [[ -n "$WORKSPACE_ROOT" ]]; then
  ROOT="$WORKSPACE_ROOT"
else
  # file_path 形如 /path/to/repo/.cursor/xxx，取包含 .cursor 的目录的父目录
  ROOT="${FILE_PATH%/.cursor/*}"
  if [[ "$ROOT" == "$FILE_PATH" ]]; then
    ROOT="$CURSOR_PROJECT_DIR"
  fi
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_SCRIPT="$SCRIPT_DIR/../scripts/sync-cursor-to-document.sh"

if [[ ! -x "$SYNC_SCRIPT" ]]; then
  echo "[after-file-edit-sync] 同步脚本不存在或不可执行: $SYNC_SCRIPT" >&2
  exit 0
fi

export CURSOR_PROJECT_DIR="$ROOT"
"$SYNC_SCRIPT" "$ROOT"
exit 0
