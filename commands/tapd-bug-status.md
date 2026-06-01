# TAPD 更新 Bug 状态

更新指定 TAPD 缺陷的状态（及可选备注）。

**用法**：

- `/tapd-bug-status <bug_id> <状态>`：更新该 Bug 的状态。若未提供空间 ID，则先通过 `get_bug` 在各参与空间中查找该 bug_id 所属的 workspace_id，再调用 `update_bug`。
- `/tapd-bug-status <bug_id> <状态> <空间ID>`：在指定空间内更新，直接调用 `update_bug(workspace_id, options: { id: bug_id, v_status: 状态 })`。
- 状态可用**中文**（推荐）：如「已解决」「已关闭」「接受/处理」等，使用 TAPD MCP `update_bug` 的 **v_status** 字段。若不支持中文则用英文 status（如 resolved、closed、in_progress），可先调用 `get_workflows_status_map(workspace_id, { system: "bug" })` 查看该空间缺陷状态枚举。
- 可选：在命令后追加备注内容，通过 TAPD 评论或描述更新（若 MCP 支持）一并提交。

## 强制规则（状态=已解决）

当用户要求将 Bug 状态改为「已解决」或 `resolved` 时，必须自动执行以下动作，不可省略：

1. **自动总结**并生成两部分内容：
   - 问题原因
   - 解决方案
2. 先调用 `update_bug` 将状态更新为已解决。
3. 再调用 TAPD 评论接口补充流转说明（优先使用 `create_comments`，`entry_type` 使用 `bug_remark`），将上述两部分内容写入评论。
4. 若用户未提供原因/方案，Agent 必须基于已知上下文（bug 标题、描述、近期改动）先给出合理总结并提交；提交后在回复中明确告知“原因和解决方案已填写”。
5. 若 `create_comments` 因权限或接口限制失败，必须在回复中明确失败原因，并提示用户补充人工填写路径。

推荐评论模板：

【问题原因】
<自动总结的问题原因>

【解决方案】
<自动总结的解决方案>

**MCP**：user-mcp-server-tapd，工具 `update_bug`（必填 workspace_id、options.id；状态用 v_status 或 status）、`create_comments`（用于补充原因与解决方案）。

请从我的输入中解析 bug_id、状态、可选的 workspace_id 与备注，执行后确认是否更新成功并回复结果。
