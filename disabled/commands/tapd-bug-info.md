# TAPD 查 Bug 详情

根据 Bug ID（及可选的空间 ID）查询 TAPD 缺陷详情，并结构化展示标题、描述、状态、优先级、严重程度、处理人、创建/修改时间及 TAPD 链接。

**用法**：

- `/tapd-bug <bug_id>`：查询指定缺陷。若未提供空间 ID，则先调用 `get_user_participant_projects` 得到参与空间（过滤 organization），再在各空间中调用 TAPD MCP `get_bug(workspace_id, options: { id: bug_id })`，直到某空间返回该 Bug 详情；找到后展示并停止。
- `/tapd-bug <bug_id> <空间ID>`：在指定空间内查询，直接调用 `get_bug(workspace_id, options: { id: bug_id })`，建议带上 `fields` 包含 `description` 以获取详细描述。

**MCP**：user-mcp-server-tapd，工具 `get_bug`。缺陷链接格式：`https://www.tapd.cn/{workspace_id}/bugtrace/bugs/view/{id}`。

请从我的输入中解析 bug_id 与可选的 workspace_id，执行后以清晰格式回复（标题、状态、优先级、描述、链接等）。
