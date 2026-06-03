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
| **计划改动** | `NavItem` 改为原生 `div` 行；`min-h-[32px]`；`rounded-[8px]` |
| **涉及文件** | `Sidebar.tsx` |
| **验收** | 四项高度一致，无大圆角玻璃底 |
| **状态** | `pending` |

---

## Step B — 新建任务（610）

| 项 | 内容 |
|----|------|
| **设计依据** | `732:81593` 无填充；`732:81728` 气泡+加号 14px；`732:81596` #111 regular；无 ⌘K |
| **计划改动** | 删除 `SIDEBAR_NEW_TASK_GLASS_PILL` / `badge`；新增 `NEW_TASK_NAV_ICON` + `newTaskNavIcon.tsx` |
| **涉及文件** | `mastergo-nav-icons-data.ts`, `newTaskNavIcon.tsx`, `Sidebar.tsx` |
| **验收** | 无灰胶囊、无右侧快捷键；图标为描边气泡 |
| **状态** | `pending` |

---

## Step C — 定时任务 / 技能中心

| 项 | 内容 |
|----|------|
| **设计依据** | `732:81572` / `732:81589`：#333333，13/18 regular；图标 14px @ x=16 |
| **计划改动** | `CronTaskNavIcon` / `InspirationNavIcon` 统一 `h-[14px] w-[14px]`；`tone=muted` |
| **涉及文件** | `Sidebar.tsx` |
| **验收** | 文案 #333，图标 14px |
| **状态** | `pending` |

---

## Step D — 智能体市场

| 项 | 内容 |
|----|------|
| **设计依据** | `732:81564` #111 font-weight 500；图标 `732:81568`；非 lucide Store |
| **计划改动** | `agentMarketNavIcon.tsx` 使用 `CHANNEL_NAV_ICON`；`tone=emphasis` |
| **涉及文件** | `agentMarketNavIcon.tsx`, `Sidebar.tsx` |
| **验收** | 三节点网络图标；文案略粗于另两项 |
| **状态** | `pending` |

---

## Step E — hover + active 灰底

| 项 | 内容 |
|----|------|
| **设计依据** | `732:81570` fill `#E2E2E2`，229×32，圆角约 8px |
| **计划改动** | `hover:bg-[#E2E2E2]` + `isActive` 同色；去掉 `SIDEBAR_MENU_GLASS_HOVER` 白底 hover |
| **涉及文件** | `Sidebar.tsx` |
| **验收** | 悬停与选中均为灰条，非白底 |
| **状态** | `pending` |

---

## Step F — 行间距

| 项 | 内容 |
|----|------|
| **设计依据** | 文案 y：125→155→185，约 30px 节奏 |
| **计划改动** | `<nav>` 使用 `gap-[6px]` 或等效（相对原 gap-[4px]） |
| **涉及文件** | `Sidebar.tsx` |
| **验收** | 四项垂直间距接近设计稿 |
| **状态** | `pending` |

---

## 若最终仍对不上 — 按步排查

| 现象 | 优先怀疑步骤 |
|------|----------------|
| 仍有磨砂胶囊 / ⌘K | **Step B** 未生效或分支未走到 |
| 图标仍是黑方块 / Store | **Step B / D** 图标组件未替换 |
| 选中变白底、圆角过大 | **Step A / E** GlassNavItem 或 hover 类残留 |
| 文案 12px / semibold | **Step A** NavItem 样式未更新 |
| 灰底仅 active 无 hover | **Step E** |
| 行距过密 | **Step F** |
