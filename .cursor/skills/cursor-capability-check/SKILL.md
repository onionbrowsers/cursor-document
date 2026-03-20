# Skill: cursor-capability-check

## 概述

扫描 `.cursor` 目录下的所有能力文件（commands、rules、hooks、skills、scripts、agents），重新生成并更新 `.cursor/cursor-capabilities.md` 汇总文档，同时深度分析各文件之间的依赖关系与功能重叠，输出检查报告。

## 触发词

- cursor 能力检查
- 更新能力总览
- 刷新能力文档
- cursor-capability-check
- 更新 cursor-capabilities
- .cursor 文件检查

## 适用场景

- `.cursor` 目录下新增/删除/修改了任意能力文件（commands、rules、hooks、skills）后
- 想了解当前 `.cursor` 中有哪些能力及其关系时
- 检查是否有功能重叠或可优化的配置时
- `.cursor/.needs-capability-update` 文件存在时（由 afterFileEdit Hook 自动创建）

---

## 执行步骤

### Step 0：检查是否需要更新

```
读取 .cursor/.needs-capability-update 文件（如果存在）
→ 记录其中的变更时间和变更文件信息
→ 用于在报告中展示"本次触发原因"
```

### Step 1：扫描 .cursor 目录结构

依次列出以下目录中的所有文件（排除 `.cursor/docs/` 和 `.cursor/skills/*/temp/`）：

```
.cursor/
├── commands/        → 所有 .md 文件
├── rules/           → 所有 .mdc 文件
├── hooks/           → 所有 .sh 文件
├── hooks.json       → Hook 注册配置
├── skills/          → 每个子目录的 SKILL.md
├── agents/          → 所有 .md 文件
├── scripts/         → 所有 .sh/.js 文件
└── .cursorlog       → 日志文件（仅读取最近 20 行）
```

### Step 2：读取文件内容，生成摘要

对 Step 1 中发现的每个文件：

1. 使用 Read 工具读取文件内容（SKILL.md 类文件只需读取前 60 行获取概述和触发词）
2. 生成 1-2 句话的功能摘要
3. 记录：
   - 文件路径
   - 文件类型（command/rule/hook/skill/agent/script）
   - 功能摘要
   - 关键依赖（其他 skill、MCP、外部工具等）
   - 触发方式（触发词、事件、命令名）

### Step 3：分析文件关系

基于 Step 2 收集的信息，分析以下维度：

**依赖关系：**
- Skill A 在执行中调用了 Skill B → A 依赖 B
- Skill 引用了某条 Rule → 记录规范依赖
- Command 与 Skill 实现相同功能 → 记录重叠关系
- Hook 触发了某个 Script → 记录触发链

**功能重叠检测规则（逐一对比）：**
- 两个文件的功能摘要中，核心业务词相同（如"TAPD 待办"、"飞书文档"、"Bug 状态"）
- 一个文件是另一个文件功能的完整子集
- 两个文件操作相同的目标资源（如同一个 TAPD 接口、同一类 Markdown 文件）

**可互相使用检测：**
- Skill A 的某步骤与 Skill B 的功能完全一致 → 建议 A 调用 B
- Command 的功能可以通过调用现有 Skill 实现 → 建议 Command 简化为入口

### Step 4：重写汇总文档

覆盖写入 `.cursor/docs/cursor-capabilities.md`，结构如下：

```markdown
# .cursor 能力总览

> 最后更新：[当前日期]
> 本次扫描发现 X 个 commands、Y 条 rules、Z 个 skills...

## Commands（命令）
[表格：文件 | 命令 | 功能描述]

## Rules（规则）
### 始终应用
[表格：文件 | 功能描述]
### 按需应用
[表格：文件 | 适用范围 | 功能描述]

## Hooks（钩子）
[表格：事件 | 脚本 | 功能描述]

## Skills（技能）
[表格：技能目录 | 触发词 | 功能描述 | 依赖]

## Agents（SubAgent）
[表格：文件 | 触发方式 | 功能描述]

## Scripts（脚本）
[表格：文件 | 触发方式 | 功能描述]

## 文件关系与依赖
[ASCII 关系图 + 文字说明]

## 功能重叠检查
[⚠️ 重叠项表格 | ✅ 合理分层表格]
```

> **重要**：更新文件中的"最后更新"日期为当前执行日期。

### Step 5：清理标志文件

```
如果 .cursor/.needs-capability-update 文件存在，则删除它
→ 表示本次更新已处理完毕
```

### Step 6：输出执行摘要

向用户输出以下信息：

```
✅ 能力总览已更新 → .cursor/docs/cursor-capabilities.md

📊 本次扫描结果：
  - Commands：X 个
  - Rules：Y 条（Z 条 alwaysApply）
  - Skills：W 个
  - Agents：A 个
  - Scripts：B 个

⚠️ 发现功能重叠 N 处：
  1. [简短描述]
  2. ...

🔗 发现可优化的依赖关系 M 处：
  1. [简短描述]
  2. ...
```

---

## 注意事项

- 文档重写时**不要**修改 `.cursor/docs/` 下的其他文档（fe-reverse-teaching、product-requirement-document 等）
- 如果某个文件无法读取，在文档中标注 `[无法读取]`，不要跳过
- 功能重叠的判断要**保守**：仅在有明确证据时才标记为重叠，避免误报
- 对于规范类文件（如 `fe-reverse-teaching` Skill）和执行类文件（如 `write-fe-reverse-teaching-doc` Skill）的分层，视为**合理设计**，不标记为重叠
- 汇总文档末尾添加：`*本文档由 cursor-capability-check Skill 维护，请勿手动编辑。*`
