---
name: image-url-to-local
description: 将图片 URL 下载到本地临时目录并返回路径，便于用 Read 工具读取图片内容；用完后清除临时文件。在用户提供图片链接并希望识别、描述或分析图片内容时使用。触发词：图片链接、图片 URL、读取图片、识别图片内容、保存到本地再读、用完后清除。
---

# 图片链接转本地并清理

将图片 URL 下载到 skill 临时目录，供 Read 工具读取；使用完毕后清除临时文件。

## 何时使用

- 用户提供**图片链接**（如 TAPD Bug 描述中的截图 URL、文档中的图片链接），并希望你**识别、描述或分析图片内容**
- 需要「根据图片链接读取内容」且当前环境无法直接对 URL 读图时

## 工作流程

1. **下载**：对每个图片 URL 执行脚本，得到本地绝对路径。
2. **读图**：用 **Read** 工具传入该绝对路径，读取图片并进行分析/描述。
3. **清理**：分析完成后执行清理，删除本次下载的临时文件。

## 脚本用法

脚本路径（相对于项目根）：`.cursor/skills/image-url-to-local/scripts/download-image.js`

**下载图片并得到路径：**

```bash
node .cursor/skills/image-url-to-local/scripts/download-image.js "<图片URL>"
```

输出一行：该图片的**本地绝对路径**。用 Read 工具读该路径即可。

**使用完毕后清理临时文件：**

```bash
node .cursor/skills/image-url-to-local/scripts/download-image.js --clean
```

会删除 `.cursor/skills/image-url-to-local/temp/` 下本次会话下载的所有图片。

## 注意事项

- 脚本使用 Node 内置 `http(s)`，无需额外依赖。
- 支持常见图片格式：png、jpg、jpeg、gif、webp（按 URL 推断扩展名，默认 png）。
- 需要登录或带鉴权的图片 URL 可能下载失败，此时只能提示用户本地保存后再用 Read 读本地路径。
- **务必在完成对图片的分析/描述后执行一次 `--clean`**，避免临时文件长期堆积。
