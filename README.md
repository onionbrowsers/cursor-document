# Cursor 配置中心

本仓库用于集中维护可跨项目复用的 Cursor 配置，包含 Rules、Commands、Skills、Hooks 和辅助脚本。业务项目可以将本仓库作为 `.cursor` 目录引入，从而复用同一套 AI 行为规范、工程命令和自动化能力。

## 目录结构

| 路径 | 说明 |
| --- | --- |
| `rules/` | Cursor 规则文件，定义 AI 语言、代码风格、Git 规范、React/TypeScript 规范、错误处理和性能规范等。 |
| `commands/` | 可通过 `/命令名` 触发的命令流程，例如 Git 提交、分支合并、GitLab MR 创建等。 |
| `skills/` | 面向复杂任务的 Agent Skill，例如能力检查、反讲文档、飞书文档读取、TAPD 处理、XMind 测试等。 |
| `hooks/` | Cursor Hook 脚本，用于在 Cursor 事件发生后执行自动化动作。 |
| `hooks.json` | Cursor Hook 注册配置。 |
| `scripts/` | 辅助脚本，例如同步配置、安装 Git hook、维护自动化流程等。 |
| `disabled/` | 暂时禁用或归档的 Rules、Commands、Skills、Agents，不作为默认启用能力使用。 |
| `cursor-capabilities.md` | 由 `cursor-capability-check` Skill 生成的能力总览，用于快速了解当前配置能力。 |
| `.cursorlog` | AI 生成、修改和维护配置的操作日志。 |

## 核心能力

### Rules

`rules/` 目录中的 `.mdc` 文件用于约束 AI 在项目中的行为。当前主要覆盖：

- 中文输出规范
- 通用代码风格
- Git 提交与分支规范
- TypeScript 编码规范
- React 组件规范
- 注释规范
- 错误处理规范
- 性能优化规范

其中 `alwaysApply: true` 的规则会全局生效；带 `globs` 的规则只在匹配文件类型时生效。

### Commands

`commands/` 目录用于维护可复用的快捷命令。常见使用方式是在 Cursor 对话中输入：

```text
/git-commit
/git-merge
/gitlab-mr
```

这些命令适合沉淀高频、固定流程的工程操作。

### Skills

`skills/` 目录用于维护更复杂的 Agent 执行指南。Skill 通常由关键词触发，适合处理多步骤任务，例如读取外部文档、生成测试报告、编写反讲文档或维护 Cursor 能力总览。

### Hooks 与 Scripts

`hooks/`、`hooks.json` 和 `scripts/` 用于把 Cursor 事件与 Shell 脚本连接起来。比如在编辑 `.cursor` 能力文件后，触发同步、记录或检查动作。

## 推荐接入方式

### 方式一：Git Submodule（推荐）

如果一个业务项目希望直接复用本仓库作为 `.cursor` 目录，推荐使用 Git Submodule：

```bash
git submodule add https://github.com/onionbrowsers/cursor-document.git .cursor
git commit -m "chore(cursor): 引入共享 Cursor 配置"
```

后续更新共享配置：

```bash
git submodule update --remote .cursor
git add .cursor
git commit -m "chore(cursor): 更新共享 Cursor 配置"
```

适用场景：

- 多个项目共用同一套 Cursor 配置。
- 希望每个项目明确记录当前使用的 `.cursor` 配置版本。
- 希望减少手动复制目录导致的遗漏和版本不一致。

### 方式二：同步脚本

如果不希望业务项目使用 Submodule，也可以通过脚本从本仓库同步配置到多个项目目录。

这种方式适合个人本地快速同步，但缺点是业务项目无法清晰记录 `.cursor` 配置版本，且容易出现手动覆盖或遗漏。

### 方式三：本地软链接

软链接适合同一台机器上的个人开发环境：

```bash
ln -s /path/to/cursor-document /path/to/project/.cursor
```

如果只考虑个人本机多个项目共用同一套配置，可以使用全局 Skill `cursor-shared-config-link` 一键初始化。该 Skill 会调用本机脚本，将当前项目的 `.cursor` 软链接到 `~/.cursor/shared-config`：

```bash
/Users/mac/.cursor/skills/cursor-shared-config-link/scripts/install-shared-cursor.sh "/path/to/project"
```

默认远程仓库为：

```text
https://github.com/onionbrowsers/cursor-document.git
```

初始化后，所有已接入项目都会指向同一份本机 `.cursor` 配置；在任意项目修改 `.cursor`，实际修改的都是同一个中央目录。

该方式适合个人单机开发，不适合团队协作。如果项目已有普通 `.cursor` 目录，脚本默认不会覆盖；确认需要替换时，可设置 `CURSOR_LINK_REPLACE=1` 后重试。

## 日常维护流程

修改 `.cursor` 配置后，在本仓库内提交：

```bash
cd .cursor
git status
git add -A
git commit -m "chore(cursor): 更新 Cursor 配置"
git push
```

其他项目更新配置：

```bash
git submodule update --remote .cursor
```

如果项目需要固定某个配置版本，更新后还需要在业务项目中提交 Submodule 指针：

```bash
git add .cursor
git commit -m "chore(cursor): 更新共享 Cursor 配置版本"
```

## 禁用与归档

不再默认启用、但仍有参考价值的能力文件应移动到 `disabled/` 目录，而不是直接删除。

建议约定：

- `disabled/rules/`：归档暂不启用的规则。
- `disabled/commands/`：归档暂不启用的命令。
- `disabled/skills/`：归档暂不启用的技能。
- `disabled/agents/`：归档暂不启用的 SubAgent。

如果需要重新启用，将对应文件移回原目录，并刷新 `cursor-capabilities.md`。

## 安全与提交规范

- 不提交 Token、密钥、证书、账号密码等敏感信息。
- 不提交 `.env.local`、临时日志、运行产物和项目私有缓存。
- 修改 Rules、Commands、Skills、Hooks 后，建议运行 `cursor-capability-check` Skill 刷新能力总览。
- Commit Message 建议遵循 Conventional Commits，例如：

```text
chore(cursor): 更新共享 Cursor 配置
docs(cursor): 补充配置中心说明
feat(skill): 新增飞书文档读取技能
```

## 常见问题

### 为什么推荐 Submodule？

Submodule 可以让每个业务项目引用同一个 `.cursor` 配置仓库，同时保留明确的版本指针。这样既能共享配置，又能避免复制目录带来的版本漂移。

### `disabled/` 中的内容会生效吗？

不会。`disabled/` 只是归档目录，默认不作为 Cursor 能力启用。

### `cursor-capabilities.md` 是手写的吗？

不是。它应由 `cursor-capability-check` Skill 自动生成或刷新，用来记录当前 `.cursor` 配置的能力总览。

### 其他项目如何拿到最新配置？

如果项目使用 Submodule：

```bash
git submodule update --remote .cursor
```

如果项目使用复制或脚本同步，则需要执行对应同步脚本。
