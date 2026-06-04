# 侧栏智能体会话区 802:84337 — 分步操作记录

设计源：`mastergo://getd2c/189284485329449-802-84337` / DSL `802:84337`

## Step 1 — DSL 拆解与差距

| 设计节点 | 含义 |
|----------|------|
| `713:012180` | 智能体 24×24 图标 |
| `713:012210` / `713:012214` | 名称 13/600、描述 11/#888 |
| `713:012197` | 会话左侧绿色勾 #00B578 |
| `713:012259` | 右侧时间 12/#666（如「1周」） |
| `713:012163` | 行 hover/active 底 #E2E2E2 32px |
| `713:012246` / `713:012228` / `713:012230` | 置顶 / 重命名 / 更多 |

**原实现问题**：时间在标题下方；hover 仅「更多」菜单含重命名；无置顶；分组头带设置按钮。

**状态**：`done`

## Step 2 — 可复用组件拆分

| 组件 | 职责 |
|------|------|
| `SidebarAgentPanel` | 可配置头（icon/name/description/headerActions）+ children slot |
| `SidebarSessionItem` | 单条会话（左图标/中标题/右时间；hover/active 显操作） |
| `SidebarSessionMoreMenu` | 三点下拉仅删除（复用 Popup+YcButton） |

**状态**：`done`

## Step 3 — 置顶持久化

- `useSidebarUiStore.pinnedSessionKeys` + `togglePinnedSessionKey`
- 组内排序：置顶优先，再按活动时间

**状态**：`done`

## Step 4 — 接入 Sidebar 虚拟列表

- 替换 `agent-header` / `session` / `show-more` 渲染
- 移除分组头 Settings
- 会话行 32px；智能体头 52px；可变高度虚拟滚动

**状态**：`done`

## Step 5 — 交互与布局修复（用户反馈）

- 智能体头 `items-center` 纵向居中
- 会话行：整行 `group-hover` 灰底；flex 右槽 `76px` 切换时间/操作，避免重叠
- 移除操作 icon 单独 hover 背景
- 三点菜单：去掉 `visible` 门控；`destroyOnClose` + 关闭态 positioner `pointer-events: none`
- 行高 40px（`py-[4px]`）；展开更多去掉 hover 灰底

**状态**：`done`

## Step 6 — 置顶逻辑与图标（713:012341）

- 点亮图标 `SIDEBAR_SESSION_PIN_ACTIVE_ICON`（#F59E0C）
- `sortSidebarSessionsWithPins` + `normalizePinnedSessionKeys`（`src/lib/sidebar-session-pin-order.ts`）
- 最近置顶排最前；取消置顶落在非置顶区第一项（`lastUnpinnedSessionKey`）
- 已置顶行：常驻点亮图钉，无 hover 操作条；点击图钉取消置顶
- 持久化 `pinnedSessionKeys`（`yonclaw-sidebar-ui`）

**状态**：`done`

## Step 7 — 侧栏底部头像 / 设置图标（713:011911 / 713:012347）

- `SidebarFooterAvatar`：24×24、`rounded-[4px]`、`border-white/80`；内容仍走 `Avatar` + `UserInfoPopover`
- `SidebarFooterSettingsIcon`：替换原 `settingsGlyphIcon` 三横线图标

**状态**：`done`

## 排查表

| 现象 | 查哪步 |
|------|--------|
| 时间仍在标题下 | Step 4 / SidebarSessionItem |
| hover 无置顶/铅笔 | Step 2 |
| 仍有设置齿轮 | Step 4 |
| 置顶刷新后丢失 | Step 3 |
| 滚动错位 | Step 4 可变行高 offsets |
