---
name: tapd-bug-verify-and-resolve
description: 根据 TAPD Bug ID 查询缺陷详情，在浏览器中验证修复后，经用户确认再将 Bug 状态更新为已解决并填写问题原因与解决方案。适用于任意项目与 TAPD 空间。触发词：验证 bug 修复、bug 改已解决、根据 bug id 验证并关闭、bug 验证后更新状态。
---

# TAPD Bug 验证并关闭

从读取 Bug ID 到在浏览器中验证修复，经**用户确认**后更新 Bug 状态为「已解决」并填写问题原因、解决方案。通用流程，不依赖具体项目或迭代。

## 何时使用

- 用户希望**验证某个 TAPD Bug 是否已修复**，并在验证通过后**把 Bug 状态改为已解决**
- 用户提供了 **Bug ID** 和用于验证的**页面链接**（或愿意在对话中补全）

## 前置条件与必填项

执行前必须确认以下输入：

| 输入 | 必填 | 说明 |
|------|------|------|
| **bug_id** | 是 | TAPD 缺陷 ID（如 `1154368771001464082`） |
| **page_url** | 是 | 用于在浏览器中验证的完整页面地址（如 `http://host:port/path?query`），需能打开到与 Bug 相关的功能页面 |
| **workspace_id** | 否 | TAPD 空间 ID。若不提供，则先拉取用户参与空间再逐空间查找该 Bug |

**若用户未提供 bug_id 或 page_url**：先向用户索要，再开始后续步骤。

---

## 工作流程

### 步骤 1：获取 Bug 详情

- 若用户**未提供 workspace_id**：
  - 调用 TAPD MCP `get_user_participant_projects`，过滤掉 `category === 'organization'` 的空间。
  - 对剩余每个空间依次调用 `get_bug(workspace_id, { id: bug_id, fields: 'id,title,description,status,current_owner,created,modified' })`，直到某空间返回该 Bug。
- 若用户**提供了 workspace_id**：直接调用 `get_bug(workspace_id, { id: bug_id, fields: '...' })`。
- 记录：Bug 所属 **workspace_id**、**标题**、**描述**、当前状态。缺陷链接格式：`https://www.tapd.cn/{workspace_id}/bugtrace/bugs/view/{id}`。
- 若 Bug 描述中含**图片**（如 `/tfl/captures/...`），必须按以下流程处理：
  1. 调用 TAPD MCP `get_image(workspace_id, { image_path })` 获取图片下载链接（`download_url`）。
  2. 使用 **image-url-to-local** skill 下载图片到本地：`node .cursor/skills/image-url-to-local/scripts/download-image.js "<download_url>"`，得到本地绝对路径。
  3. 用 **Read** 工具读取该路径分析图片内容。
  4. 分析完成后立即执行清理：`node .cursor/skills/image-url-to-local/scripts/download-image.js --clean`，避免临时文件残留。
  - **禁止**直接用 `curl` 或 Shell 将图片下载到 `/tmp` 等任意目录，必须通过 image-url-to-local skill 统一管理。

### 步骤 2：根据 Bug 描述定位相关代码

- 使用**当前工作分支**的代码。
- 根据 Bug **标题与描述**中的功能关键词（如模块名、页面名、组件名、接口路径等）在项目内搜索对应**页面、组件或接口**，便于理解修改点与验证重点。
- 不假定任何项目特有的路径或命名，仅按关键词与项目结构做合理推断。

### 步骤 3：浏览器验证

- 使用 Cursor 自带的 **@Browser**（或 MCP **cursor-ide-browser**）打开用户提供的 **page_url**。
- 根据 Bug 描述在页面上检查问题是否已修复（样式、交互、数据展示等）。
- 若验证过程需要**用户配合**（如登录、切换环境、点击某入口、使用特定数据），在对话中**明确提示用户**在浏览器中操作，待用户反馈后再继续。
- 验证完成后**不要立即更新 TAPD**，进入步骤 4。

### 步骤 4：打断式确认（必须执行）

- **在更新 Bug 状态之前**，必须向用户确认：
  - 明确询问：「请在浏览器中确认该 Bug 是否已修复。若已修复，请回复确认，我将把该 Bug 状态改为已解决并填写问题原因与解决方案。」
- **仅在用户明确表示「已确认」「通过」「可以关闭」等肯定答复后**，才执行步骤 5。
- 若用户表示未通过或需要继续修改，则**不调用 update_bug**，并给出后续建议。

### 步骤 5：git commit 并推送远程分支（需用户确认）

在更新 TAPD 状态之前，先询问用户是否需要将本次修复提交并推送到远程分支：

> 「本次修复是否需要提交代码并推送到远程分支？若需要请确认，若不需要请回复跳过。」

- **用户回复「需要」「确认」「是」等肯定答复**：执行以下子步骤，完成后进入步骤 6。
- **用户回复「不需要」「跳过」「否」等否定答复**：跳过本步骤，直接进入步骤 6。

#### 子步骤（用户确认后执行）

1. **确认当前分支**  
   执行 `git branch --show-current` 获取当前分支名。

2. **暂存改动文件**  
   执行 `git add <修改的文件路径>`，只暂存与本次 Bug 修复相关的文件，不暂存无关改动。

3. **提交代码**  
   按照项目 git-conventions 规范，commit message 格式为：

   ```text
   fix(<scope>): <简明描述本次 bug 修复内容>

   - 问题原因：<导致 bug 的根因>
   - 解决方案：<实际修复方式>

   Closes #<bug_id>
   ```

   - `scope` 取改动文件所属模块/页面名（如 `middle-recommend`）
   - subject 使用**中文**，以动词开头（如"修复"、"修正"），不超过 50 字
   - 使用 HEREDOC 方式提交：`git commit -m "$(cat <<'EOF'` ... `EOF``)"`

4. **推送远程分支**  
   执行 `git push origin <当前分支名>`，将修复推送到对应远程分支。  
   - 若远程分支不存在，使用 `git push -u origin <当前分支名>` 创建并关联。
   - 推送成功后在回复中告知用户分支名及提交信息摘要。

### 步骤 6：更新 Bug 状态与必填字段

1. **获取该空间缺陷的自定义字段配置**  
   调用 `get_entity_custom_fields(workspace_id, { entity_type: 'bugs' })`，在返回中查找用于「问题原因」「解决方案」的字段（通常为 textarea 类型，名称可能为「问题原因」「解决方案」等），记下对应的 `custom_field_*` 键名。

2. **归纳问题原因与解决方案**  
   根据 Bug 标题、描述以及本次代码修改，用简短文字归纳：
   - **问题原因**：导致该 Bug 的根因（如缺少空值校验、未做超长兜底等）。
   - **解决方案**：实际采取的修复方式（如过滤无标题数据、增加截断样式等）。

3. **调用 update_bug**  
   使用 TAPD MCP `update_bug(workspace_id, options)`，其中 `options` 至少包含：
   - `id`: 缺陷 ID
   - `v_status`: `"已解决"`（或该空间「已解决」对应的状态名）
   - 上一步查到的「问题原因」对应的 `custom_field_*`: 填写的问题原因文案
   - 上一步查到的「解决方案」对应的 `custom_field_*`: 填写的解决方案文案

   若该空间没有这些自定义字段，则只更新 `id` 与 `v_status`，并在回复中说明原因。

4. **处理人**  
   若用户希望将处理人改为自己，请用户提供其 **TAPD 昵称**（如 `zhangsan` 或 `张三zhangsan`），在 `update_bug` 的 `options` 中增加 `current_owner: 用户提供的昵称`。若用户未提供，可在回复中说明可自行在 TAPD 页面修改处理人。

---

## 依赖与约定

- **MCP**：user-mcp-server-tapd（`get_bug`、`get_user_participant_projects`、`get_entity_custom_fields`、`update_bug`，必要时 `get_image`）。
- **浏览器**：Cursor 自带 @Browser 或 cursor-ide-browser，用于打开 `page_url` 做验证。
- **分支**：始终基于**当前工作分支**的代码做代码定位与理解，不写死分支名。
- **跨项目**：本流程不依赖具体项目、路由或 TAPD 空间配置，仅依赖用户提供 bug_id、page_url 及（可选）workspace_id；自定义字段名通过 `get_entity_custom_fields` 动态获取。

---

## 注意事项

- 步骤 4 的**用户确认**不可跳过，避免在未验证通过时误关 Bug。
- `page_url` 需由用户提供可访问的地址（本地、预发或已部署环境），Agent 不猜测或构造链接。
- 若 Bug 描述中的图片需要识别内容，**必须**使用 **image-url-to-local** skill（先调 `get_image` 拿到 `download_url`，再通过 skill 脚本下载），分析完成后立即执行 `--clean` 清理，禁止直接 curl 到 `/tmp` 等任意目录。
- 步骤 5（git commit & push）在步骤 4 用户确认 Bug 已修复后执行，需再次询问用户是否推送远程分支；用户选择跳过时直接进入步骤 6。
- 步骤 6（更新 TAPD）始终在步骤 5 之后执行，无论步骤 5 是否被跳过。
