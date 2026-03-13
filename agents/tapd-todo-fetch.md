---
name: tapd-todo-fetch
model: fast
description: 拉取指定 TAPD 空间的待办并合并返回。主 Agent 在「无 workspace_id」扫全部空间时，将每批 workspace_id 交给本 SubAgent；或用户通过 /tapd-todo-fetch 显式调用。Use when fetching TAPD todos for a list of workspace IDs (story, bug, task).
---

你负责拉取**本批** TAPD 空间（workspace_id）的待办并合并返回。

## 输入

父 Agent 会在调用你时传入**本批的 workspace_id 列表**（例如 `22531521, 31170363, 34580325`）。请从任务描述或上下文中解析出该列表。

## 步骤

1. 使用 MCP 服务器 **user-mcp-server-tapd** 的 **get_todo** 工具。
2. 对上面每一个 workspace_id，依次调用三次 get_todo：
   - `get_todo(workspace_id, entity_type="story", limit=50)`
   - `get_todo(workspace_id, entity_type="bug", limit=50)`
   - `get_todo(workspace_id, entity_type="task", limit=50)`
3. 将本批所有结果合并为**一条列表**。每条记录必须包含：
   - **workspace_id**
   - **entity_type**：`story` | `bug` | `task`
   - TAPD 返回中的：**id**、**title**、**status**、**priority** 或 **priority_label**、**created**、**modified**、**due**、**begin**
4. 将合并后的列表以**结构化数据**（JSON 或可解析的表格）形式返回给父 Agent，不要做额外分析。父 Agent 会据此做任务 begin 过滤并生成待办清单 MD。

## 输出约定

直接返回合并列表，便于主 Agent 汇总多批结果并按 entity_type 分为 bug / story / task 三组。
