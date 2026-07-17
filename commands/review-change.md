# 审查上次改动

在新会话中审查**上一轮开发 Agent 会话**的代码改动与影响面。

**用法**：

```text
/review-change
/review-change 重点看 gateway 相关
/review-change 跑 typecheck
```

**执行步骤**：

1. 加载并遵循 `.cursor/skills/review-last-change/SKILL.md`
2. 读取 `.cursor/reviews/last-session-manifest.md` 作为改动入口（不依赖 git diff 全文）
3. 按 Skill 流程完成影响面分析、按需读文件、可选自动化检查
4. 输出精简审查结论表 + 验收步骤 + 出问题时应提供的信息
5. 将 manifest 标记为 `reviewed: true`

**说明**：

- manifest 由 Hook 在**有文件编辑**的开发会话 `stop` 时写入；写入新清单前才会将旧 manifest 归档到 `archive/`
- 纯审查会话不会清空 manifest，可在新会话直接 `/review-change`
- 若提示「暂无可审查改动」，说明上一轮会话未产生文件编辑，或 Hook 尚未生效（可重启 Cursor 后重试）
- 本命令用于**独立审查会话**，不要在同一轮开发会话末尾混用

**若审查发现问题，用户应提供**：

- manifest 中列出的相关文件路径
- 终端或浏览器 Console 报错全文
- 复现步骤与预期/实际结果
