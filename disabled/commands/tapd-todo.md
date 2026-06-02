# TAPD 待办清单

拉取当前用户在 TAPD 的待办（缺陷、需求、任务），生成当日待办清单 Markdown 并写入 `.cursor/docs/todoList/yyyy-mm-dd-待办清单.md`（同一天多次执行会覆盖该文件）。

**用法**：

- `/tapd-todo`：拉取你参与的所有项目下的待办，汇总后生成当日清单。**必须**通过 SubAgent（`.cursor/agents/tapd-todo-fetch.md` 或 mcp_task）按批拉取，**禁止**主 Agent 直接对多个空间循环调用 get_todo。
- `/tapd-todo <空间ID>`：仅拉取指定空间（workspace_id）的待办并生成当日清单，例如 `/tapd-todo 60401003`。单空间时可由主 Agent 直接调 get_todo。

**规则**：任务类待办仅包含「开始时间不晚于当天」的项；清单格式遵循 `.cursor/rules/tapd-todo-list-md.mdc`。无 workspace_id 时的完整流程遵循 `.cursor/skills/tapd-todo-sync/SKILL.md`。

请严格按上述方式执行：无空间 ID 时务必用 SubAgent（tapd-todo-fetch 或 mcp_task）拉取，不得由主 Agent 对多空间直接调 get_todo。若有空间 ID 请从我的输入中解析。
