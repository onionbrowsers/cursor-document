#!/usr/bin/env bash

set -u

REMOTE_URL="${CURSOR_SHARED_REMOTE:-https://github.com/onionbrowsers/cursor-document.git}"
CENTRAL_DIR="${CURSOR_SHARED_CONFIG_DIR:-$HOME/.cursor/shared-config}"
BRANCH="${CURSOR_SHARED_BRANCH:-main}"
PROJECT_ROOT="${1:-}"

log() {
  printf '[cursor-shared-config] %s\n' "$1"
}

warn() {
  printf '[cursor-shared-config][warn] %s\n' "$1" >&2
}

fail() {
  printf '[cursor-shared-config][error] %s\n' "$1" >&2
  exit 1
}

resolve_project_root() {
  if [[ -n "$PROJECT_ROOT" ]]; then
    cd "$PROJECT_ROOT" 2>/dev/null && pwd
    return
  fi

  git rev-parse --show-toplevel 2>/dev/null || pwd
}

ensure_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    fail "缺少命令: $command_name"
  fi
}

ensure_central_repo() {
  local central_parent
  central_parent="$(dirname "$CENTRAL_DIR")"

  mkdir -p "$central_parent"

  if [[ ! -e "$CENTRAL_DIR" ]]; then
    log "中央配置目录不存在，开始 clone: $CENTRAL_DIR"
    git clone --branch "$BRANCH" "$REMOTE_URL" "$CENTRAL_DIR" || fail "clone 共享 Cursor 配置失败"
    return
  fi

  if [[ ! -d "$CENTRAL_DIR/.git" ]]; then
    fail "中央配置目录已存在但不是 Git 仓库: $CENTRAL_DIR"
  fi

  local current_remote
  current_remote="$(git -C "$CENTRAL_DIR" remote get-url origin 2>/dev/null || true)"
  if [[ "$current_remote" != "$REMOTE_URL" ]]; then
    warn "中央配置 remote 与预期不一致"
    warn "当前: ${current_remote:-无}"
    warn "预期: $REMOTE_URL"
  fi
}

update_central_repo() {
  if ! git -C "$CENTRAL_DIR" diff --quiet || ! git -C "$CENTRAL_DIR" diff --cached --quiet; then
    warn "中央配置目录存在未提交改动，跳过自动 pull: $CENTRAL_DIR"
    return
  fi

  log "拉取中央配置最新内容"
  git -C "$CENTRAL_DIR" fetch origin "$BRANCH" || fail "fetch 中央配置失败"
  git -C "$CENTRAL_DIR" pull --ff-only origin "$BRANCH" || fail "pull 中央配置失败，请手动处理分叉或冲突"
}

validate_central_layout() {
  if [[ ! -f "$CENTRAL_DIR/hooks.json" ]]; then
    warn "中央配置目录缺少 hooks.json，可能不是预期的 .cursor 配置根目录"
  fi

  if [[ ! -d "$CENTRAL_DIR/rules" && ! -d "$CENTRAL_DIR/skills" && ! -d "$CENTRAL_DIR/commands" ]]; then
    fail "中央配置目录不像 Cursor 配置根目录: $CENTRAL_DIR"
  fi
}

backup_existing_cursor() {
  local cursor_path="$1"
  local backup_path="${cursor_path}.backup.$(date '+%Y%m%d%H%M%S')"

  mv "$cursor_path" "$backup_path" || fail "备份已有 .cursor 失败"
  log "已备份原 .cursor 到: $backup_path"
}

link_project_cursor() {
  local project_root="$1"
  local cursor_path="$project_root/.cursor"

  if [[ -L "$cursor_path" ]]; then
    local current_target
    current_target="$(readlink "$cursor_path")"

    if [[ "$current_target" == "$CENTRAL_DIR" ]]; then
      log "当前项目已经链接到共享配置: $cursor_path -> $CENTRAL_DIR"
      return
    fi

    if [[ "${CURSOR_LINK_REPLACE:-0}" != "1" ]]; then
      fail "当前项目 .cursor 已是软链接但目标不是中央配置: $current_target。若要替换，请设置 CURSOR_LINK_REPLACE=1 后重试。"
    fi

    rm "$cursor_path" || fail "删除旧 .cursor 软链接失败"
  elif [[ -e "$cursor_path" ]]; then
    if [[ "${CURSOR_LINK_REPLACE:-0}" != "1" ]]; then
      fail "当前项目已存在 .cursor。为避免覆盖，请确认后设置 CURSOR_LINK_REPLACE=1 重试；脚本会先备份原目录。"
    fi

    backup_existing_cursor "$cursor_path"
  fi

  ln -s "$CENTRAL_DIR" "$cursor_path" || fail "创建 .cursor 软链接失败"
  log "已创建软链接: $cursor_path -> $CENTRAL_DIR"
}

# SubAgent 注册认 ~/.cursor/agents（及项目内真实路径），整棵 .cursor
# 链到 shared-config 时 realpath 出工作区，常进不了 Task 枚举。
# 因此把中央 agents/*.md 再链到用户级目录，正文仍只维护一份。
link_user_agents() {
  local central_agents="$CENTRAL_DIR/agents"
  local user_agents="$HOME/.cursor/agents"
  local linked=0
  local skipped=0

  if [[ ! -d "$central_agents" ]]; then
    log "中央配置暂无 agents/，跳过用户级 SubAgent 链接"
    return
  fi

  mkdir -p "$user_agents" || fail "创建 $user_agents 失败"

  local agent_file
  local agent_name
  local target
  local resolved_target
  local resolved_source

  shopt -s nullglob
  for agent_file in "$central_agents"/*.md; do
    agent_name="$(basename "$agent_file")"
    target="$user_agents/$agent_name"

    if [[ -L "$target" ]]; then
      resolved_target="$(python3 -c "import os; print(os.path.realpath('$target'))" 2>/dev/null || true)"
      resolved_source="$(python3 -c "import os; print(os.path.realpath('$agent_file'))" 2>/dev/null || true)"
      if [[ -n "$resolved_target" && "$resolved_target" == "$resolved_source" ]]; then
        log "用户级 Agent 已链接: $target"
        linked=$((linked + 1))
        continue
      fi
      rm "$target" || fail "删除旧 Agent 软链接失败: $target"
    elif [[ -e "$target" ]]; then
      warn "跳过已存在的非软链接文件（避免覆盖）: $target"
      skipped=$((skipped + 1))
      continue
    fi

    ln -s "$agent_file" "$target" || fail "创建用户级 Agent 软链接失败: $target"
    log "已链接用户级 Agent: $target -> $agent_file"
    linked=$((linked + 1))
  done
  shopt -u nullglob

  log "用户级 SubAgent 链接完成（linked=$linked, skipped=$skipped）"
}

main() {
  ensure_command git
  ensure_command ln
  ensure_command readlink

  local project_root
  project_root="$(resolve_project_root)"

  if [[ -z "$project_root" || ! -d "$project_root" ]]; then
    fail "无法识别项目根目录"
  fi

  log "项目根目录: $project_root"
  log "中央配置目录: $CENTRAL_DIR"
  log "远程仓库: $REMOTE_URL"

  ensure_central_repo
  update_central_repo
  validate_central_layout
  link_project_cursor "$project_root"
  link_user_agents

  log "共享 Cursor 配置初始化完成"
  log "若新增/变更了 SubAgent，请完全退出并重启 Cursor，再开新 Agent 会话验证 Task 枚举"
}

main "$@"
