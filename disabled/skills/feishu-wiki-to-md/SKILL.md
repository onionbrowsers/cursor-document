---
name: feishu-wiki-to-md
description: 将飞书 Wiki 空间或指定节点下的所有文档批量转换为 Markdown 文件，保存到 .cursor/docs/ 目录。当用户提供飞书 Wiki 的 space_id 或节点 token，希望批量导出、转换、保存文档时使用。触发词：飞书转 Markdown、飞书导出、Wiki 转 md、批量转换飞书文档。
---

# 飞书 Wiki 批量转 Markdown

## 用户输入

| 参数 | 是否必填 | 说明 |
|------|----------|------|
| 空间 ID 或节点 token | 必填 | 飞书 Wiki 的 `space_id` 或节点 token |
| 文件夹名称 | 可选 | 输出目录名，默认为 `fe-reverse-teaching` |

目标保存路径：`.cursor/docs/<文件夹名称>/`

---

## 执行步骤

### Step 1：解析空间 ID

调用 `user-feishu-mcp-wiki_v2_space_getNode`，将用户提供的 ID 作为 `token` 参数传入。

- 若成功返回，说明传入的是**节点 token**，从返回结果取 `space_id`，同时记录该 token 作为 `parent_node_token`
- 若失败，说明传入的直接是 **`space_id`**，直接使用，`parent_node_token` 不传

### Step 2：遍历所有节点

循环调用 `user-feishu-mcp-wiki_v2_spaceNode_list`：

```
参数：
- space_id：Step 1 获取的 space_id
- parent_node_token：Step 1 获取的节点 token（若有）
- page_size：50
```

- 若 `has_more` 为 true，使用返回的 `page_token` 继续翻页，直到取完所有节点
- 若节点的 `has_children` 为 true，递归调用本步骤，以该节点的 `node_token` 作为 `parent_node_token`
- 只收集 `obj_type === "docx"` 的节点，记录其 `title` 和 `obj_token`

### Step 3：逐一转换并保存

对每个收集到的 docx 节点：

1. 调用 `user-feishu-mcp-docs_v1_content_get`：
   ```
   doc_token: 节点的 obj_token
   doc_type: "docx"
   content_type: "markdown"
   ```
2. 将返回的 Markdown 内容写入文件：
   - 路径：`.cursor/docs/<文件夹名称>/<节点 title>.md`
   - 文件已存在则覆盖
3. 若获取失败，记录错误信息，继续处理下一个

### Step 4：输出汇总报告

全部完成后，输出：

```
✅ 转换完成，共成功 N 个文档：
- 文件名1.md
- 文件名2.md
...

❌ 失败 M 个（若有）：
- 节点标题：失败原因
```

---

## 示例

**示例 1：指定 space_id + 自定义文件夹**
```
用户：请把飞书空间 7531056966526681116 下的所有文档转成 Markdown，放到 fe-review 文件夹
```
- 目标路径：`.cursor/docs/fe-review/`
- 遍历 space_id 为 `7531056966526681116` 的根节点

**示例 2：指定节点 token + 默认文件夹**
```
用户：把这个节点 XghOwa0aBixkrRkmWLfcvYadnkc 下的文档都转成 md
```
- 调用 `space_getNode` 解析出真实 space_id
- 目标路径：`.cursor/docs/fe-reverse-teaching/`
