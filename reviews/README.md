# Session Review 目录

本目录由 Cursor Hook 自动维护，用于追踪单次 Agent 开发会话的文件改动。

## 文件说明

| 文件 | 说明 |
| --- | --- |
| `last-session-manifest.md` | 上一轮**有文件编辑**的开发会话改动清单（审查入口，始终只有一份） |
| `.session-files.tmp` | 当前会话进行中的临时累积（`sessionStart` 清空，`stop` 后清空） |
| `.session-meta.json` | 当前会话元数据（开始时间、conversation_id） |
| `archive/` | 历史 manifest 归档（写入新 manifest 前自动移入） |

## 生命周期

1. **sessionStart**：清空临时文件 → 记录会话开始时间（**不归档**既有 manifest）
2. **afterFileEdit**：去重追加本次编辑的文件路径
3. **stop（有编辑）**：归档旧 manifest → 生成/覆盖 `last-session-manifest.md` → 清空临时文件
4. **stop（无编辑）**：仅清空临时文件，**保留**既有 manifest（供 `/review-change` 读取）
5. **/review-change**：新会话读取 manifest 审查 → 标记 `reviewed: true`

## 审查

在新会话中执行：

```text
/review-change
```

详见 `.cursor/skills/review-last-change/SKILL.md`。
