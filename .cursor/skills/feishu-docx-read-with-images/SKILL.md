---
name: feishu-docx-read-with-images
description: 读取飞书新版文档（docx）正文并拉取内嵌图片：用飞书 MCP 换素材临时下载链，再借助 image-url-to-local 下载到本地、Read 读图分析，最后与文字汇总。当用户需要「读飞书 PRD/文档且要看懂文档里的截图、流程图、UI 稿」时使用。触发词：飞书文档读图、飞书 PRD 图片、docx 图片分析、飞书 MCP 临时链读图、飞书文档配图总结。
---

# 飞书文档正文 + 内嵌图片联合阅读

在用户需要**完整理解飞书云文档**（含**正文与图片**）时执行本流程。仅使用 `docs_v1_content_get`（Markdown）**无法**拿到图片素材 token，必须走 **块列表 + 素材临时链**。

## 依赖与配合

- **飞书 MCP**（`user-feishu-mcp`）：`wiki_v2_space_getNode`、`docx_v1_documentBlock_list`、`drive_v1_media_batchGetTmpDownloadUrl`；可选 `docs_v1_content_get` 取 Markdown 正文。
- **image-url-to-local**：对每个临时 URL 执行下载脚本，再用 **Read** 读取本地图片；结束后 **`--clean`**。详见项目内 `.cursor/skills/image-url-to-local/SKILL.md`。

## 何时使用

- 用户给出飞书 **Wiki 链接**或 **docx 链接**，且希望摘要/反讲/验收**包含图中信息**。
- 用户明确说要看 PRD 里的**示意图、原型、流程图截图**等。

## Step 1：解析文档 ID（`document_id`）

| 用户输入 | 操作 |
|----------|------|
| Wiki 链接，`.../wiki/<node_token>` | 调用 **`wiki_v2_space_getNode`**，`query.token` = `node_token`。若 `obj_type === "docx"`，则 **`document_id` = `obj_token`**。若为其他类型，说明该节点不是新版文档，本 Skill 不适用。 |
| docx 链接，`.../docx/<document_id>` | **`document_id`** 即为 URL 中的 token，无需再调 `getNode`。 |

## Step 2：获取正文（可选但推荐）

调用 **`docs_v1_content_get`**：

- `doc_token`: `document_id`
- `doc_type`: `"docx"`
- `content_type`: `"markdown"`
- `lang`: `"zh"`（按需）

将 Markdown 作为**文字层**保留，供最后与读图结果合并汇总。

## Step 3：列出文档块并收集图片 token

分页调用 **`docx_v1_documentBlock_list`**：

- `path.document_id`: Step 1 的 `document_id`
- `query.document_revision_id`: `-1`（最新版本）
- `query.page_size`: `500`（或接口允许的上限）

若 `data.has_more === true`，用 `page_token` 继续请求直到取完。

从 `data.items` 中筛选：**`block_type === 27`** 且存在 **`image.token`**。每个 `image.token` 即素材 **`file_token`**。

**辅助脚本**（可选，避免手写解析）：

```bash
# 将 MCP 返回的完整 JSON 存为 blocks.json 后：
node .cursor/skills/feishu-docx-read-with-images/scripts/extract-image-file-tokens.js blocks.json
```

标准输出为每行一个 token。

## Step 4：批量获取临时下载链接

调用 **`drive_v1_media_batchGetTmpDownloadUrl`**：

- `query.file_tokens`: **字符串数组**，一次最多 **5** 个 token；超过则分批多次调用。

从返回的 `data.tmp_download_urls` 中取每条 **`tmp_download_url`**。链接约 **24 小时**有效。

> **注意**：域名常为 `internal-api-drive-stream.feishu.cn`，在部分网络环境（如沙箱、无外网）下可能无法下载；**优先在用户本机终端**执行 Step 5 的下载脚本。

## Step 5：下载到本地并用 Read 读图（image-url-to-local）

对**每一个** `tmp_download_url` 执行（项目根目录）：

```bash
node .cursor/skills/image-url-to-local/scripts/download-image.js "<tmp_download_url>"
```

脚本**单行输出**本地绝对路径。对该路径调用 **Read** 工具读取图片，完成**内容描述、与 PRD 条款对照、问题点提取**等分析。

**全部图片分析结束后**执行清理：

```bash
node .cursor/skills/image-url-to-local/scripts/download-image.js --clean
```

## Step 6：汇总输出

将以下内容合并为一份结构化回复（可按用户要求改成表格或清单）：

1. **文字层**：Step 2 Markdown 的摘要或全文要点（若未取 Markdown，可用 `docx_v1_document_rawContent` 补纯文本层）。
2. **图片层**：按文档中大致顺序（或文件名顺序）列出每张图的 **Read 结论**（界面结构、文案、状态、与文字需求差异等）。
3. **交叉结论**：图文一致处 / 冲突或待确认处 / 建议产品或设计澄清点。

若某张图下载失败：明确写出失败原因，并建议用户导出截图或在本机网络下重试。

## 错误与边界

- **无图片块**：输出说明「文档无内嵌图片块」，仅交付文字摘要即可。
- **权限**：`getNode` / `documentBlock_list` / `batchGetTmpDownloadUrl` 任一步失败时，提示检查飞书文档阅读权限与 MCP 授权。
- **非 docx**：旧版 doc、表格、多维表格等不走本 Skill；可改用对应 MCP 或让用户导出。

## MCP 工具名速查（server：`user-feishu-mcp`）

| 用途 | 工具名 |
|------|--------|
| Wiki 节点 → docx token | `wiki_v2_space_getNode` |
| 文档 Markdown | `docs_v1_content_get` |
| 文档纯文本 | `docx_v1_document_rawContent` |
| 所有块（含图片） | `docx_v1_documentBlock_list` |
| 素材临时链 | `drive_v1_media_batchGetTmpDownloadUrl` |
