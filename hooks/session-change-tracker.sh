#!/usr/bin/env bash
# Cursor Hook：追踪单次 Agent 会话中的文件改动，会话结束时写入 last-session-manifest.md
# 用法：由 hooks.json 传入事件名 — sessionStart | afterFileEdit | stop

set -euo pipefail

HOOK_EVENT="${1:-}"
PROJECT_ROOT="${CURSOR_PROJECT_DIR:-$(pwd)}"
REVIEWS_DIR="$PROJECT_ROOT/.cursor/reviews"
TEMP_FILE="$REVIEWS_DIR/.session-files.tmp"
META_FILE="$REVIEWS_DIR/.session-meta.json"
MANIFEST_FILE="$REVIEWS_DIR/last-session-manifest.md"
ARCHIVE_DIR="$REVIEWS_DIR/archive"
MAX_MANIFEST_FILES=50

INPUT=$(cat)

mkdir -p "$REVIEWS_DIR" "$ARCHIVE_DIR"

run_python() {
  python3 - "$@" <<'PY'
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import List, Optional

action = sys.argv[1]
project_root = Path(sys.argv[2]).resolve()
reviews_dir = project_root / ".cursor" / "reviews"
temp_file = reviews_dir / ".session-files.tmp"
meta_file = reviews_dir / ".session-meta.json"
manifest_file = reviews_dir / "last-session-manifest.md"
archive_dir = reviews_dir / "archive"
max_files = int(sys.argv[3])
raw_input = sys.argv[4] if len(sys.argv) > 4 else ""

IGNORE_PATTERNS = (
    r"(^|/)\.git(/|$)",
    r"(^|/)node_modules(/|$)",
    r"(^|/)dist(/|$)",
    r"(^|/)build(/|$)",
    r"(^|/)coverage(/|$)",
    r"(^|/)\.cursor/reviews(/|$)",
    r"(^|/)temp_uv_extract(/|$)",
)

def now_str() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")

def load_json(text: str) -> dict:
    if not text.strip():
        return {}
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return {}

def to_relative_path(file_path: str) -> Optional[str]:
    if not file_path:
        return None
    path = Path(file_path)
    if not path.is_absolute():
        return str(path).replace("\\", "/")
    try:
        return str(path.resolve().relative_to(project_root)).replace("\\", "/")
    except ValueError:
        return None

def should_ignore(relative_path: str) -> bool:
    normalized = relative_path.replace("\\", "/")
    return any(re.search(pattern, normalized) for pattern in IGNORE_PATTERNS)

def read_lines(path: Path) -> List[str]:
    if not path.exists():
        return []
    return [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]

def write_lines(path: Path, lines: List[str]) -> None:
    path.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")

def archive_manifest() -> None:
    if not manifest_file.exists():
        return
    content = manifest_file.read_text(encoding="utf-8").strip()
    if not content:
        manifest_file.unlink(missing_ok=True)
        return
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    target = archive_dir / f"{stamp}-manifest.md"
    target.write_text(content + "\n", encoding="utf-8")
    manifest_file.unlink(missing_ok=True)

def detect_operation(relative_path: str) -> str:
    full_path = project_root / relative_path
    if not full_path.exists():
        return "deleted"
    git_dir = project_root / ".git"
    if not git_dir.exists():
        return "edited"
    import subprocess
    try:
        subprocess.run(
            ["git", "-C", str(project_root), "ls-files", "--error-unmatch", relative_path],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return "modified"
    except subprocess.CalledProcessError:
        return "added"

def handle_session_start(payload: dict) -> None:
    # 仅清空本会话累积；不归档 last-session-manifest，避免 /review-change 新会话读不到上一份清单
    write_lines(temp_file, [])
    meta = {
        "started_at": now_str(),
        "conversation_id": payload.get("conversation_id") or payload.get("conversationId") or "",
        "workspace_roots": payload.get("workspace_roots") or payload.get("workspaceRoots") or [],
    }
    meta_file.write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

def handle_after_file_edit(payload: dict) -> None:
    relative_path = to_relative_path(payload.get("file_path") or payload.get("filePath") or "")
    if not relative_path or should_ignore(relative_path):
        return
    lines = read_lines(temp_file)
    if relative_path not in lines:
        lines.append(relative_path)
        write_lines(temp_file, lines)

def handle_stop(payload: dict) -> None:
    meta = load_json(meta_file.read_text(encoding="utf-8")) if meta_file.exists() else {}
    started_at = meta.get("started_at") or "unknown"
    ended_at = now_str()
    conversation_id = meta.get("conversation_id") or payload.get("conversation_id") or payload.get("conversationId") or ""
    files = read_lines(temp_file)

    if not files:
        # 无文件编辑（如纯审查会话）：保留既有 manifest，仅清空临时累积
        write_lines(temp_file, [])
        return

    # 仅在有新改动写入前归档旧 manifest
    archive_manifest()

    operations = [(path, detect_operation(path)) for path in files]
    truncated = len(operations) > max_files
    listed = operations[:max_files]

    lines = [
        "# Last Session Manifest",
        "",
        "> 由 Cursor Hook 自动生成。在新会话执行 `/review-change` 可审查上一次开发会话的改动。",
        "",
        f"- **session_started_at**: {started_at}",
        f"- **session_ended_at**: {ended_at}",
    ]
    if conversation_id:
        lines.append(f"- **conversation_id**: {conversation_id}")
    lines.extend([
        "- **reviewed**: false",
        f"- **file_count**: {len(operations)}",
        "",
        "## Files",
        "",
        "| 路径 | 操作 |",
        "| --- | --- |",
    ])
    for path, op in listed:
        lines.append(f"| `{path}` | {op} |")

    if truncated:
        lines.extend([
            "",
            f"> 共 {len(operations)} 个文件，manifest 仅列出前 {max_files} 个。",
        ])

    lines.extend([
        "",
        "## 审查提示",
        "",
        "- 审查时先读本 manifest，再按需 Read 核心改动文件，禁止全量贴 diff",
        "- 对照 `docs/architecture/module-impact-map.md` 检查影响面",
        "- 审查完成后由 `/review-change` 将 `reviewed` 标记为 true",
        "",
    ])

    manifest_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
    write_lines(temp_file, [])

if action == "sessionStart":
    handle_session_start(load_json(raw_input))
elif action == "afterFileEdit":
    handle_after_file_edit(load_json(raw_input))
elif action == "stop":
    handle_stop(load_json(raw_input))
PY
}

if [[ -z "$HOOK_EVENT" ]]; then
  exit 0
fi

run_python "$HOOK_EVENT" "$PROJECT_ROOT" "$MAX_MANIFEST_FILES" "$INPUT"
exit 0
