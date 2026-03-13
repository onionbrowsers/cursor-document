# TAPD 更新 Bug 状态

更新指定 TAPD 缺陷的状态（及可选备注）。

**用法**：

- `/tapd-bug-status <bug_id> <状态>`：更新该 Bug 的状态。若未提供空间 ID，则先通过 `get_bug` 在各参与空间中查找该 bug_id 所属的 workspace_id，再调用 `update_bug`。
- `/tapd-bug-status <bug_id> <状态> <空间ID>`：在指定空间内更新，直接调用 `update_bug(workspace_id, options: { id: bug_id, v_status: 状态 })`。
- 状态可用**中文**（推荐）：如「已解决」「已关闭」「接受/处理」等，使用 TAPD MCP `update_bug` 的 **v_status** 字段。若不支持中文则用英文 status（如 resolved、closed、in_progress），可先调用 `get_workflows_status_map(workspace_id, { system: "bug" })` 查看该空间缺陷状态枚举。
- 可选：在命令后追加备注内容，通过 TAPD 评论或描述更新（若 MCP 支持）一并提交。

**MCP**：user-mcp-server-tapd，工具 `update_bug`（必填 workspace_id、options.id；状态用 v_status 或 status）。

请从我的输入中解析 bug_id、状态、可选的 workspace_id 与备注，执行后确认是否更新成功并回复结果。
