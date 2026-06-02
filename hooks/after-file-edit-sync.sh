#!/usr/bin/env bash
# Cursor afterFileEdit hook：当 .cursor 配置仓库下（非 docs）文件被编辑时，
# 在该 .cursor 配置仓库里汇总执行 git add + commit + push 到 GitHub。
# 兼容项目内 .cursor 软链接到 ~/.cursor/shared-config 的场景。

SYNC_DEBOUNCE_SECONDS="${CURSOR_SYNC_DEBOUNCE_SECONDS:-20}"
PUSH_TIMEOUT_SECONDS="${CURSOR_SYNC_PUSH_TIMEOUT_SECONDS:-120}"
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

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
if [[ "$REAL_FILE_PATH" == "$SHARED_CURSOR_DIR/"* ]]; then
  CURSOR_DIR="$SHARED_CURSOR_DIR"
elif [[ "$FILE_PATH" == *"/.cursor/"* ]]; then
  CURSOR_DIR="${FILE_PATH%/.cursor/*}/.cursor"
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

GIT_DIR="$CURSOR_DIR/.git"
LOCK_DIR="$GIT_DIR/cursor-sync.lock"
LOG_FILE="$GIT_DIR/cursor-sync.log"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

run_with_timeout() {
  local timeout_seconds="$1"
  shift

  if command -v timeout >/dev/null 2>&1; then
    timeout "$timeout_seconds" "$@"
    return $?
  fi

  if command -v perl >/dev/null 2>&1; then
    perl -e 'alarm shift; exec @ARGV' "$timeout_seconds" "$@"
    return $?
  fi

  "$@"
}

# 后台异步执行，避免阻塞 Cursor；同一时间只允许一个同步任务运行。
(
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    log "sync already running; skip trigger: $FILE_PATH"
    exit 0
  fi

  trap 'rm -rf "$LOCK_DIR"' EXIT

  log "change received: $FILE_PATH; sync after ${SYNC_DEBOUNCE_SECONDS}s debounce"
  sleep "$SYNC_DEBOUNCE_SECONDS"

  cd "$CURSOR_DIR" || {
    log "failed to enter cursor config dir: $CURSOR_DIR"
    exit 0
  }

  git add -A
  if git diff --staged --quiet; then
    log "no staged changes; skip commit/push"
    exit 0
  fi

  CHANGED_FILE=$(basename "$FILE_PATH")
  if ! git commit -m "chore: 更新 ${CHANGED_FILE}" >> "$LOG_FILE" 2>&1; then
    log "git commit failed; check repository status"
    exit 0
  fi

  log "start push origin main; timeout=${PUSH_TIMEOUT_SECONDS}s"
  run_with_timeout "$PUSH_TIMEOUT_SECONDS" git push origin main >> "$LOG_FILE" 2>&1
  PUSH_EXIT_CODE=$?

  if [[ "$PUSH_EXIT_CODE" -eq 0 ]]; then
    log "push succeeded"
    exit 0
  fi

  log "push failed or timed out; exit_code=$PUSH_EXIT_CODE; manual command: git -C \"$CURSOR_DIR\" push origin main"
) &

# 写入能力更新标志文件
NEEDS_UPDATE_FILE="$CURSOR_DIR/.needs-capability-update"
echo "changed_at=$(date '+%Y-%m-%d %H:%M:%S')" > "$NEEDS_UPDATE_FILE"
echo "changed_file=${FILE_PATH}" >> "$NEEDS_UPDATE_FILE"

exit 0
