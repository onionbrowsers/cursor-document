# 总结飞书文档（含图片）

给定一个飞书文档 ID（或文档 URL），通过 feishu-mcp 读取文档内容（包括图片），并由 AI 生成结构化摘要。

**用法**：

- `/feishu-doc-summary <document_id>`：总结指定 document_id 的飞书文档
- `/feishu-doc-summary <飞书文档 URL>`：从 URL 中自动提取 document_id 并总结

**执行步骤**：

1. 解析用户输入，提取 `document_id`：
   - 若输入为纯 ID（如 `doxbcmEtbFrbbq10nPNu8gabcef`），直接使用
   - 若输入为飞书 docx URL（如 `https://xxx.feishu.cn/docx/XxxYyyZzz`），从路径最后一段提取 document_id
   - 若输入为 wiki URL（如 `https://xxx.feishu.cn/wiki/XxxYyyZzz`），调用 feishu-mcp 工具 `wiki_v2_space_getNode`（传入 `token = URL 最后一段`）获取 `obj_token`，将其作为 document_id 使用

2. 调用 feishu-mcp 工具 `docx_v1_document_get`（传入 `document_id`）获取文档标题和基本信息

3. 调用 feishu-mcp 工具 `docs_v1_content_get`（传入 `doc_token = document_id`、`doc_type = docx`、`content_type = markdown`）获取文档 Markdown 格式正文内容
   - 若 `docs_v1_content_get` 调用失败，回退使用 `docx_v1_document_rawContent` 获取纯文本内容

4. **读取文档中的图片**：

   > 飞书 docx 的图片不在 Markdown 正文中，而是以 block 形式独立存储。需通过 block API 获取 image token，再调用 MCP 工具获取临时下载链接。

   1. 调用 feishu-mcp 工具 `docx_v1_documentBlock_list`（传入 `document_id`，`page_size=500`），筛选 `block_type == 27` 的图片块，提取每个块的 `image.token`
   2. 若无图片块，跳过本步骤
   3. 调用 feishu-mcp 工具 `drive_v1_media_batchGetTmpDownloadUrl`（传入 `query.file_tokens = [image_token_1, image_token_2, ...]`，每次最多 5 个），从响应中提取每个 token 对应的临时下载 URL（有效期 24 小时）
   4. 对每个临时下载 URL，执行下载：

      ```bash
      node .cursor/skills/image-url-to-local/scripts/download-image.js "<tmp_download_url>"
      ```

      脚本输出的路径即为本地临时文件路径
   5. 用 **Read 工具**读取每个本地路径，识别并描述图片内容，记录图片序号与所在章节
   6. 全部图片处理完毕后，执行清理：

      ```bash
      node .cursor/skills/image-url-to-local/scripts/download-image.js --clean
      ```

   7. **降级处理**：
      - 若 `drive_v1_media_batchGetTmpDownloadUrl` 调用失败（如 403）→ app 缺少素材下载权限，跳过图片并在摘要末尾注明：「文档含 N 张图片，因 app 权限不足未能读取」

5. 基于文档文字内容 + 图片分析结果，生成以下结构化摘要并输出：
   - **文档标题**：来自步骤 2
   - **一句话概述**：用一句话概括文档核心内容（不超过 50 字）
   - **核心要点**：提取 3～7 条关键信息，以无序列表呈现
   - **详细摘要**：按文档原有章节结构，逐段总结主要内容；若章节包含图片则附上对应图片描述
   - **行动项 / 结论**（如有）：提取文档中明确的待办事项、决策或结论

**注意事项**：

- 所有摘要内容使用**中文**输出
- 摘要应忠实于原文，不添加原文中没有的信息
- 若文档内容过长，优先保证核心要点和详细摘要的完整性
- 若文档获取失败（如无权限、ID 不存在），直接告知用户错误原因，不继续执行
- 图片下载通过 feishu-mcp 工具 `drive_v1_media_batchGetTmpDownloadUrl` 获取临时链接，无需手动配置 token；app 需在飞书开放平台具备素材下载权限
