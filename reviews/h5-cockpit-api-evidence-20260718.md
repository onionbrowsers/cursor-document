# 驾驶舱 create 循环卡死证据（2026-07-18）

> **重要更正（2026-07-18 16:40）**：此前将「`payload.ok=false` 却写 Creation succeeded」归因于 H5 接口矛盾，**该归因错误**。该文案来自 YonClaw 侧 `packages/openclaw-webview-agent/index.ts` 的 `summarizePageActionPayload`，对所有 `cockpit-create*` 回包无条件硬编码 `nextAction: "Creation succeeded..."`，并丢弃 H5 原始 `error` / `needAgentDataFill` / `taskId`。H5 团队无需按原问题 A 排查。

---

## 会话与现象

| 项 | 值 |
|---|---|
| 最新会话 | `7f7991ec-c685-4d3c-946d-f561969dd622.jsonl` |
| 时间窗口 | UTC 08:17–08:32（北京时间约 16:17–16:32） |
| 症状 | UI 内容闪现又清空；create 长时间无结果；工具调用死循环 |

同会话统计（截止约 08:32）：

| 动作 | 次数 |
|---|---|
| `agent:cockpit-create` | 25+ |
| `agent:cockpit-create-prepare` | 10 |
| `agent:cockpit-create-complete` | 15 |
| `agent:cockpit-list` | 33 |
| create 真正成功（`ok=true` + 有 cockpitId） | **仅 1 次**（金蝶 `2586968470075736064`） |
| create 返回 `ok=false` + 假「Creation succeeded」 | **24+ 次** |

UI 闪烁原因：`create-prepare` 反复进入「正在生成」过渡态（清空内容），`create-complete` 又关闭过渡态（内容回来），页面被反复拉进拉出。

---

## 根因（YonClaw，已定位）

文件：`packages/openclaw-webview-agent/index.ts` → `summarizePageActionPayload`

历史行为（已修）：

1. `normalizedAction.includes('cockpit-create')` 匹配过宽，把 `create-prepare` / `create-complete` 也套上 create 摘要；
2. **无条件**写入 `nextAction: "Creation succeeded..."`，不看 `ok`；
3. 白名单 `pickDefined` **丢弃** H5 回包里的 `error` / `reason` / `needAgentDataFill` / `taskId`。

模型看到的结果变成：

```json
{
  "ok": false,
  "action": "agent:cockpit-create",
  "widgetCount": 0,
  "widgets": [],
  "nextAction": "Creation succeeded. Reuse cockpitId for follow-up widget updates; do not recreate unless the user explicitly asks for a new cockpit."
}
```

无 `error`、无 `cockpitId`、却声称成功 → 模型只能 `cockpit-list` → 找不到 → 改名再 create → 被 H5 `taskId-match` 幂等短路（ok=false）→ 再次被摘要成同样矛盾结果 → 死循环。

代表性 requestId（会话 `7f7991ec`）：`fc3ec0bf8acd173c`（UTC 08:18:03）。

---

## YonClaw 已做修复

1. 仅对真正的 `agent:cockpit-create`（`endsWith('cockpit-create')`）做 create 摘要；prepare/complete 透传。
2. `ok=false` 时 nextAction 明确写失败 / 幂等短路，并要求禁止再 create。
3. 保留 `error` / `reason` / `needAgentDataFill` / `taskId`。
4. 单测覆盖失败态不得出现 “Creation succeeded”。

---

## 仍需 H5 确认的事项（缩小范围）

以下**不是**「Creation succeeded 矛盾文案」问题，而是创建链路本身：

1. **首次 create 为何返回 `ok=false`**：原始 H5 错误原因曾被摘要层丢弃，日志里无法还原。修复后请再抓一次原始 `agent:cockpit-create-result`，确认失败 `error`/`code` 是否清晰。
2. **`taskId-match` 幂等短路**：能力文档写明重复 create 会短路且不创建新舱；建议短路时稳定返回：`ok=false`、`error`、已有 `cockpitId`（若有）、`needAgentDataFill`。
3. **`cockpit_delete` / `cockpit_query` 对已删除 ID 的 404**：更建议返回幂等成功或 `alreadyDeleted`，避免诱导重试（见历史会话 `45a505ee` 金蝶 ID 删除后多次 404）。

### 历史会话 `45a505ee` 中 delete/get 404（仍有效）

| 行号 | 时间 (UTC) | action | cockpitId | 说明 |
|---|---|---|---|---|
| L138–139 | 07:05:50 | cockpit-delete | `2586780436407517184` | **首次删除成功** |
| L147/151/220/290 | 后续 | cockpit-delete | 同上 | 对已删除 ID → 404 |
| L312 | 07:12:13 | cockpit-get | 同上 | 已删除 → `/cockpit_query` 404 |
| L316 | 07:12:22 | cockpit-get | `2586780440686452736` | 臆造 ID → 404 |

本会话**未证实**「刚 create 成功的 ID 立刻 get 就 404」。

---

## 给协作方的一句话

- **YonClaw**：假 “Creation succeeded” 是摘要层 bug，已修；请重启 Gateway / 重载 webview-agent 插件后再测创建。
- **H5**：请重点保证失败/幂等短路回包带清晰 `error` +（如有）已有 `cockpitId`；delete/query 对已删除 ID 语义收敛。
