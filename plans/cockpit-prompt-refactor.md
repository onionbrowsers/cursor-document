# 驾驶舱 Prompt 模块重构计划

> 日期：2026-07-20

## 目标

1. 将 `src/lib/cockpit-prompt.ts`（700+ 行）拆为职责清晰的目录模块
2. 创建相关 prompt 去重（`full` / `cockpit-build` 共用 helper）
3. 精简各 mode 文案，降低 token 体积与维护成本
4. 能力注入指纹纳入 `guidanceMode`，避免 mode 切换时跳过约束
5. 保持 `@/lib/cockpit-prompt` 导入路径兼容

## 目录结构

```
src/lib/cockpit-prompt/
  index.ts                 # 对外导出（兼容原路径）
  constants.ts             # 常量 + 意图正则
  types.ts                 # 类型
  page-context.ts          # lite/truncate/resolve 页面上下文
  guidance-mode.ts         # resolveCockpitGuidanceMode
  guidance-state.ts        # 能力指纹注入状态（含 mode）
  sections.ts              # 可复用 prompt 段落（精简版）
  modes.ts                 # 各 guidanceMode 组装
  creation-cache.ts        # 已创建驾驶舱内存缓存
  tool-loop-session.ts     # 工具熔断会话包装
  compaction-session.ts    # Compaction 保留上下文包装
  build.ts                 # buildCockpitPrompt 主入口
```

## 验收点

- `pnpm exec vitest run tests/unit/cockpit-prompt.test.ts tests/unit/regression-risk-tests.test.ts`
- Cockpit 页面 / hook 导入路径无需改动（或仅适配指纹 API）
- `docs/analysis/cockpit-prompt-guide.md` 与新结构对齐
