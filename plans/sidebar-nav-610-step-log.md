# 侧栏导航区 610 对齐 — 分步操作记录

设计源：`mastergo://getd2c/189284485329449-796-82851`（节点 `796:82851`）  
范围：**仅红框 4 项导航**（搜索区不在本日志内）  
用户确认（2026-06-03）：
1. 新建任务：去掉 ⌘K 展示、去掉磨砂胶囊，透明行 + 气泡加号图标（610）
2. 灰底：`hover` + 当前路由 `active` 均为 `#E2E2E2`

---

## Step A — 扁平行布局，去掉 GlassNavItem 对导航的干扰

| 项 | 内容 |
|----|------|
| **设计依据** | 行高 32px；文案 13/18；无 `rounded-2xl` / `bg-white/95` |
| **改动** | `NavItem` 改为 `div` + `data-testid="sidebar-nav-item"`；`h-8 min-h-[32px]`；13/18 |
| **涉及文件** | `Sidebar.tsx` |
| **验收** | 四项高度一致，无大圆角玻璃底 |
| **状态** | `done` |

---

## Step B — 新建任务（610）

| 项 | 内容 |
|----|------|
| **设计依据** | `732:81593` 无填充；`732:81728` 气泡+加号；`732:81596` #111 regular；无 ⌘K |
| **改动** | 删除磨砂 pill / badge；`NEW_TASK_NAV_ICON` + `newTaskNavIcon.tsx` |
| **涉及文件** | `mastergo-nav-icons-data.ts`, `newTaskNavIcon.tsx`, `Sidebar.tsx` |
| **验收** | 无灰胶囊、无右侧 ⌘K；描边气泡图标 |
| **状态** | `done`（全局 ⌘K 快捷键逻辑保留，仅 UI 不展示） |

---

## Step C — 定时任务 / 技能中心

| 项 | 内容 |
|----|------|
| **设计依据** | `732:81572` / `732:81589`：#333333，13/18 regular |
| **改动** | 图标 `14×14`；`tone=muted` |
| **涉及文件** | `Sidebar.tsx` |
| **验收** | 文案 #333 |
| **状态** | `done` |

---

## Step D — 智能体市场

| 项 | 内容 |
|----|------|
| **设计依据** | `732:81564` #111 font-weight 500；`CHANNEL_NAV_ICON` |
| **改动** | `agentMarketNavIcon.tsx`；`tone=emphasis` |
| **涉及文件** | `agentMarketNavIcon.tsx`, `Sidebar.tsx` |
| **验收** | 三节点图标 + medium 文案 |
| **状态** | `done` |

---

## Step E — hover + active 灰底

| 项 | 内容 |
|----|------|
| **设计依据** | `732:81570` `#E2E2E2` |
| **改动** | `SIDEBAR_NAV_ROW_HIGHLIGHT`；`hover:bg-[#E2E2E2]` |
| **涉及文件** | `Sidebar.tsx` |
| **验收** | 悬停与路由选中均为灰条 |
| **状态** | `done`（`/` 新建任务仍 `suppressActive`，不在聊天页显示选中灰底） |

---

## Step F — 行间距

| 项 | 内容 |
|----|------|
| **设计依据** | 文案 y 约 30px 节奏 |
| **改动** | `<nav>` `gap-[4px]` → `gap-[6px]` |
| **涉及文件** | `Sidebar.tsx` |
| **验收** | 垂直间距略增 |
| **状态** | `done` |

---

## 若最终仍对不上 — 按步排查

| 现象 | 优先怀疑步骤 |
|------|----------------|
| 仍有磨砂胶囊 / ⌘K | **Step B** |
| 图标仍是黑方块 / Store | **Step B / D** |
| 选中变白底、圆角过大 | **Step A**（误用 GlassNavItem） |
| 文案 12px / semibold | **Step A** |
| 灰底仅 active 无 hover | **Step E** |
| 新建任务在 `/` 也有灰底 | `suppressActive` 产品逻辑，非 Step E |
| 行距过密 | **Step F** |
