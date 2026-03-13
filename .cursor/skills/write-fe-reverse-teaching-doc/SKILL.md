---
name: write-fe-reverse-teaching-doc
description: 根据 PRD 飞书文档链接/ID 和目标飞书 doc ID，在本地指定文件夹创建前端反讲 Markdown 文档，编写后通过 feishu-mcp 写入飞书文档，并将 Mermaid 流程图转换为 mermaid.ink 图片链接。触发词：前端反讲文档、反讲、写反讲、fe-reverse-teaching、前端反讲。
---

# 写前端反讲文档并同步到飞书

## 触发条件

用户提供以下信息时自动执行本 Skill：
- PRD 飞书文档链接或 node token（用于阅读需求）
- 目标飞书 doc ID（用于写入，格式如 `JPqfdx8oxoc542xaKdzc4zsCnad`，取自 `https://xxx.feishu.cn/docx/<ID>`）
- 本地存放路径（如 `.cursor/docs/fe-reverse-teaching/中价课/`）

---

## 工作流步骤

### Step 1：读取 PRD

用 `wiki_v2_space_getNode` 或 `docx_v1_document_rawContent_get` 读取 PRD 内容，提取：
- 需求背景、功能目标
- 涉及页面、接口、埋点
- 技术难点

### Step 2：在本地创建 MD 文件

在用户指定目录下创建 `【前端反讲】<项目名>.md`，按[文档模板](#文档模板)编写完整内容。

流程图使用 `mermaid` 代码块书写，后续 Step 4 统一转换。

### Step 3：Mermaid 转图片链接

对所有 ` ```mermaid ` 代码块，执行以下转换：

```bash
node -e "
const code = \`<mermaid 内容>\`;
const encoded = Buffer.from(code)
  .toString('base64')
  .replace(/\+/g, '-')
  .replace(/\//g, '_')
  .replace(/=/g, '');
console.log('https://mermaid.ink/img/' + encoded);
"
```

> **注意**：必须使用 URL-safe base64（`+`→`-`，`/`→`_`，去掉 `=`），否则返回 404。
> 不要对 JSON 包装再编码，直接对 mermaid 代码字符串编码。

将代码块替换为：
```markdown
![流程图描述](https://mermaid.ink/img/<encoded>)
```

### Step 4：Markdown 转飞书文档块

调用 `docx_v1_document_convert`：

```json
{
  "path": { "document_id": "<DOC_ID>" },
  "body": {
    "content_type": "markdown",
    "content": "<完整 MD 内容>"
  }
}
```

返回的 `blocks` 数组即为所有文档块。

### Step 5：清理 merge_info（含表格时必须）

MD 中含 HTML 表格时，转换结果的 Table 块会包含只读字段 `merge_info`，插入时会报错。

用 Node.js 清理：

```javascript
const data = JSON.parse(fs.readFileSync('/tmp/convert_data.json', 'utf8'));
data.data.blocks.forEach(block => {
  if (block.block_type === 31 && block.table?.property?.merge_info) {
    delete block.table.property.merge_info;
  }
});
fs.writeFileSync('/tmp/convert_clean.json', JSON.stringify(data));
```

### Step 6：分批插入飞书文档

调用 `docx_v1_documentBlockDescendant_create`。

**关键参数结构**（容易出错）：

```json
{
  "path": {
    "document_id": "<DOC_ID>",
    "block_id": "<DOC_ID>"
  },
  "body": {
    "children_id": ["<block_id_1>", "<block_id_2>"],
    "descendants": [<所有 block 对象>]
  }
}
```

- `path.document_id` 和 `path.block_id` 均填目标文档 ID
- `body.children_id` 只放顶层块的 block_id
- `body.descendants` 放本批次所有块（含子块）

**分批策略**：每批最多 12 个顶层块，JSON 不超过 25KB。用 Node.js 脚本分批，写入 `/tmp/ins_chunk{N}.json`，逐批调用。

---

## 文档模板

```markdown
# 【前端反讲】<项目名>

# 修改记录

| 版本号 | 修改日期 | 作者 | 修改说明 |
|--------|----------|------|----------|
| v1.0 | <日期> | 前端开发 | 初版创建 |

# 1 项目背景
## 1.1 背景介绍
## 1.2 文档资料
- PRD：[链接]
- UI 设计稿：
- Git 仓库：
## 1.3 项目关联方

| 角色 | 姓名/团队 | 职责 |
|------|-----------|------|
| 产品经理 | | 需求定义与验收 |
| 前端开发 | | 页面开发与联调 |
| 后端开发 | | 接口开发与联调 |
| 测试 | | 功能测试与验收 |

# 2 名词解释

| 名词 | 说明 |
|------|------|

# 3 设计目标
## 3.1 功能目标
## 3.2 技术目标
## 3.3 性能指标
## 3.4 其他指标

# 4 系统环境
## 4.1 本功能所处的环境
## 4.2 相关软件及硬件

# 5 设计思路和方案
## 5.1 整体流程图
## 5.2 页面整体结构
## 5.3 整体项目难点梳理与解决方案

| 难点描述 | 解决方案 |
|----------|----------|

# 6 详细设计
## 6.1 页面结构说明
## 6.2 通用代码设计
## 6.3 接口描述
## 6.4 测试考虑

# 7 埋点信息

| 事件名称 | 事件ID | 事件描述 | 触发时机 | 触发页面 | 参数列表 |
|----------|--------|----------|----------|----------|----------|
```

---

## 常见错误

| 错误 | 原因 | 修复 |
|------|------|------|
| `field validation failed: merge_info` | Table 块含只读字段 | Step 5 清理 merge_info |
| mermaid.ink 返回 404 | 未用 URL-safe base64 | 替换 `+`→`-`、`/`→`_` |
| `CallMcpTool` JSON parse error | 参数未嵌套在 `path`/`body` | 检查参数结构 |
| 内容重复插入 | 未跳过已插入的块 | 分批时从第 2 个顶层块开始 |
