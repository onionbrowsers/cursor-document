---
name: tapd-todo-sync
description: TAPD 待办汇总与当日清单生成 - 通过 TAPD MCP 拉取待办，按类型与时间过滤后生成「yyyy-mm-dd 待办清单」MD。当用户要求查待办、生成待办清单、同步 TAPD 待办时应用。若未提供空间 ID 则使用 SubAgent 扫全部参与空间；若提供 workspace_id 则由主 Agent 直接查询该空间。
---

# TAPD 待办汇总与当日清单

## 触发场景

- 用户说「查一下我的 TAPD 待办」「生成今日待办清单」「同步待办」「拉取 TAPD 待办」等
- 用户执行 `/tapd-todo` 命令（可选带 workspace_id）

## 输入

- **workspace_id**（可选）：若用户提供具体空间 ID，则只查该空间；若不提供，则拉取用户参与的全部项目（排除公司级 organization）后逐空间查询。

## 流程

### 1. 确定待查空间列表

- **有 workspace_id**：待查列表为 `[workspace_id]`，由主 Agent **直接**对该空间调用 get_todo（story、bug、task 各一次），再执行后续「任务时间过滤」与「生成 MD」。
- **无 workspace_id**：
  1. 调用 TAPD MCP `get_user_participant_projects`（不传 nick，使用当前用户）。
  2. 从返回中过滤掉 `category === 'organization'` 的 workspace。
  3. 将剩余 workspace 按每 3～4 个一批拆分，**每批必须交给 SubAgent 执行**（见下方「必须使用 SubAgent」）。
  4. 主 Agent **禁止**对多个 workspace 自行循环调用 `get_todo`；拉取待办的工作**必须**由 SubAgent 完成。
  5. 主 Agent 汇总所有 SubAgent 返回的列表，按 entity_type 合并为 bug / story / task 三组。

### 无 workspace_id 时：必须使用 SubAgent（禁止主 Agent 直接拉取）

当需要「扫全部空间」时，主 Agent **不得**自己对各 workspace 调用 `get_todo`。必须二选一执行：

- **优先**：若当前环境支持按名称调用自定义 SubAgent，则**委托给 `.cursor/agents/tapd-todo-fetch.md` 定义的 tapd-todo-fetch**，在委托时传入本批的 workspace_id 列表；或使用 `/tapd-todo-fetch` 的语义（每批 workspace 触发一次）。
- **否则**：使用 **mcp_task** 工具启动 SubAgent，在 prompt 中复述 tapd-todo-fetch 的职责与本批 workspace_id 列表。

约定如下：

1. **工具**：`mcp_task`
   - **subagent_type**：`generalPurpose`（需要调用 TAPD MCP 并合并结果时使用）。
   - **description**：简短描述，如「拉取指定 TAPD 空间的待办并合并返回」。

2. **任务描述（prompt）**：主 Agent 传给 SubAgent 的 prompt 必须包含：
   - 明确说明：请调用 TAPD MCP（user-mcp-server-tapd）的 `get_todo` 工具。
   - 给出**本批**的 workspace_id 列表（例如 `[22531521, 31170363, 34580325]`）。
   - 要求对每个 workspace_id 分别调用三次 get_todo：`entity_type` 依次为 `story`、`bug`、`task`，`limit` 建议 50。
   - 要求返回一个合并后的列表，每条待办需包含：workspace_id、entity_type（story/bug/task）、以及 TAPD 返回中的 id、title、status、priority、created、due、begin 等字段（用于主 Agent 拼表和做任务 begin 过滤）。
   - 说明项目列表来自 get_user_participant_projects，已排除 organization，无需再查项目列表。

3. **分批与并发**：
   - 将过滤后的 workspace 列表按每 3～4 个为一组拆成多批。
   - 每批启动一个 mcp_task（即一个 SubAgent），可多批并行（注意单轮并发 SubAgent 数不超过 4）。
   - 主 Agent 等待所有 mcp_task 返回后，把各批返回的待办数组合并，再按 entity_type 分为 bug / story / task 三组，进入「任务时间过滤」和「生成 MD」步骤。

4. **示例 prompt 模板（主 Agent 填充后发给 SubAgent）**：

```text
你负责拉取以下 TAPD 空间（workspace_id）的待办并合并返回。空间 ID 列表：[此处由主 Agent 填入本批的 workspace_id，如 22531521, 31170363, 34580325]。

请使用 MCP 工具 user-mcp-server-tapd 的 get_todo：
- 对上面每一个 workspace_id，分别调用三次 get_todo：entity_type 依次为 "story"、"bug"、"task"，limit 设为 50。
- 将全部结果合并为一个列表，每条记录必须包含：workspace_id、entity_type（story/bug/task）、以及 TAPD 返回中的 id、title、status、priority/priority_label、created、modified、due、begin 等字段。
- 最终直接返回这个合并列表的 JSON 或结构化数据，不要做额外分析。主 Agent 会据此生成待办清单并做任务 begin 过滤。
```

### 2. 任务（Task）时间过滤

- 仅对 **task（任务）** 做过滤：若任务的 **开始时间（begin）** 大于**当天 0 点**（即还没到开始日），则**不纳入**当日待办清单。
- 若 `begin` 为空或 null，则保留。
- Bug、Story 不做此过滤。

### 3. 补全所属空间名称（可选）

- 若 TAPD 返回中无 workspace 名称，可对涉及到的 workspace_id 调用 `get_workspace_info(workspace_id)` 取项目名称，用于表格「所属空间」列。

### 4. 生成 Markdown 并写入

- 严格遵守 `.cursor/rules/tapd-todo-list-md.mdc` 中的规范。
- **输出路径**：`.cursor/docs/todoList/yyyy-mm-dd-待办清单.md`，其中 `yyyy-mm-dd` 为**当天**日期。
- 若该文件已存在，**直接覆盖**。
- 表格列：序号、ID、标题、状态、优先级、所属空间、链接、创建时间、截止时间、备注（按 Rule 中的表头顺序）。

### 5. 链接格式

- Bug：`https://www.tapd.cn/{workspace_id}/bugtrace/bugs/view/{id}`
- Story/Task：使用 TAPD 需求/任务详情页路径（一般为 `https://www.tapd.cn/{workspace_id}/prong/stories/view/{id}` 或任务 view 路径，以实际 TAPD 为准）

## 输出

- 将生成的待办清单写入上述路径后，回复用户：已生成当日待办清单，路径为 `.cursor/docs/todoList/yyyy-mm-dd-待办清单.md`，并简要说明各类型数量（Bug x 条、Story x 条、Task x 条）。

## 后续扩展（实现时可不做，仅预留）

- 与反讲文档联动：根据 `.cursor/docs` 下反讲内容，用 TAPD MCP `create_story_or_task` 创建对应 TAPD 任务。
- 用户提供待办清单 MD 后，由 Agent 按清单逐条处理任务与 Bug（定位代码、修复、更新状态等）。
