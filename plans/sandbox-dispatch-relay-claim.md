# 方案：沙箱 dispatch relay 防多端重复执行

> 目标仓库：`/Users/mac/companycode/yonclaw1.0`  
> 背景：Web 多开 + 移动端同开同一远程沙箱时，`GET /pending-dispatch` 为 peek 非 claim，同一 `dispatch-relay` 被多次执行 → 驾驶舱双份创建  
> 状态：Phase 1 已实现（待联调验收）

---

## 1. 问题与边界

**已确认根因（沙箱侧）**

- 文件：`electron/main/browser-agent/dispatch-relay-store.ts`
- `pollWebviewDispatchRelay` 只返回 pending，**不标记领取**
- 出队仅发生在 `POST /dispatch-result` → `resolveWebviewDispatchRelay`
- create 耗时 2–4s 内，多端 poll 都会 `pending.poll.hit` 并执行同一 action

**本方案改沙箱能解决什么**

| 场景 | Phase 1 Claim | Phase 2 定向 |
|------|---------------|--------------|
| Web 多 Tab + 移动端同沙箱，防双 create | ✅ | ✅ |
| 谁发消息谁执行页面 action | ❌（先到先得） | ✅（需 FE 配合） |

**不在本方案 Phase 1 范围**

- 驾驶舱页面 `agent:cockpit-create` 业务幂等（属页面/技能侧兜底，可另开）
- `iuap-yonclaw-cloud-fe` / `claw-mobile` 发消息带 clientInstanceId（Phase 2）

---

## 2. 分阶段

### Phase 1（建议先做）：原子 Claim + Lease

**只改 yonclaw1.0，即可覆盖「多端同沙箱重复 create」。**

#### 2.1 核心状态机

```
enqueue → pending
            │
   claim(consumerId?) ──成功──► claimed(claimedBy, claimedAt, leaseUntil)
            │                         │
            │                    resolve(result/error) → 结束并删队列项
            │                         │
            │                    lease 过期且未 resolve → 回到 pending（可被他人重领）
            │
   已被他人 claim 且 lease 未过期 → poll 返回 pending:false
```

#### 2.2 修改文件（沙箱）

| 文件 | 改动 |
|------|------|
| `electron/main/browser-agent/dispatch-relay-store.ts` | 新增 `claimedBy` / `claimedAt` / `leaseUntil`；`poll` 改为 `claim`（或 poll 内部 claim）；lease 到期可重入 pending；补充事件类型 `claimed` / `claim_rejected` / `lease_expired_requeued` |
| `electron/api/routes/webview-agent.ts` | `handleGetPendingDispatch`：读可选 `clientInstanceId`（或 `consumerId`）query，调用 claim；chain log 增加 `claimedBy`、`claimResult` |
| `electron/utils/webview-agent-chain-log.ts`（如需） | 新 hop：`pending.poll.claimed` / `pending.poll.busy` |
| `tests/unit/` 新增或扩展 | 单测覆盖：单消费者 claim、双消费者只有一个拿到、resolve 后清空、lease 过期可重领、迟到的第二份 dispatch-result → miss |

#### 2.3 API 行为（对外兼容）

`GET /api/webview-agent/pending-dispatch?sessionKey=...&clientInstanceId=...`（`clientInstanceId` Phase 1 可选）

- **成功 claim**：仍返回现有 `{ pending: true, request: {...} }`，多返回 `claimedBy`（便于排查）
- **已被占用**：`{ pending: false, reason: 'claimed' }`（`reason` 可选，旧客户端可忽略）
- **无任务**：`{ pending: false }`（与现网一致）

`POST /dispatch-result`：逻辑基本不变；建议校验 `claimedBy` 与回报方一致（可选严格模式），不一致则 409/忽略并打日志，避免旁路页抢 resolve。

#### 2.4 Lease 取值

- 默认：`min(timeoutMs, max(timeoutMs * 0.9, 3000))` 或直接等于 `timeoutMs`
- create 可能接近 timeout 上限：lease **不要明显短于** `timeoutMs`，否则易「执行中被重领」
- 与现有 enqueue timeout（默认 8s–15s 路由层）对齐；超时仍走现有 `timeout` reject

#### 2.5 验收

1. 单测：双 poll 并发，仅 1 次 claim 成功  
2. 手工：同一沙箱开 2 个 Web 驾驶舱页（或 Web + 移动），说一次「生成经营总览」  
   - chain：同一 `dispatch-relay-*` 只有 **1 次** `pending.poll.claimed`（或 1 次 hit + 多次 busy）  
   - operation-log：`agent:cockpit-create` 成功次数对应该次意图（失败重试除外）  
   - cockpit-runtime：同名不应再出现 650ms 内双文件  

---

### Phase 2（可选）：谁发起谁领取

在 Phase 1 之上增加定向。沙箱改动 + FE 改动缺一不可。

#### 2.6 沙箱侧

| 点 | 说明 |
|----|------|
| `enqueue` 增加 `targetClientInstanceId?` | 来自本轮 Agent run 上下文 |
| `claim` 规则 | 若存在 target，仅 `clientInstanceId === target` 可领；无 target 则退回 Phase 1 先到先得 |
| run 上下文 | Agent 启动 / chat 入口接收 FE 传来的 `clientInstanceId`，挂到 session/run，dispatch 时写入 enqueue |
| binding | 现 `pageInstanceId` 常量为 `cockpit-driving-cabin`，**不能**当唯一执行身份；需支持多 client 在线表，或至少 `activeExecutorId` |

涉及文件（预估）：

- `dispatch-relay-store.ts` / `webview-agent.ts` routes
- Agent/chat 入口（gateway 或 chat 发消息 API，具体点评审时再定）
- virtual binding 存储（若要做 online clients 列表）

#### 2.7 FE 侧（不在本次沙箱-only 提交，但方案需对齐）

- `iuap-yonclaw-cloud-fe`（Web）与移动端：页面加载生成 `clientInstanceId`（`sessionStorage`）
- 发消息 / 开 Agent 带上该 ID  
- poll 带上该 ID  
- 共享 poll hook：`packages/agent-bridge-host`（云前端）与沙箱内嵌页若共用协议，需同步

#### 2.8 降级策略（发起端已关）

1. lease 内：一直等 target  
2. lease/总超时：Agent 收到 timeout  
3. 可选产品策略：超时后允许任意 online client 重领（需产品确认）

---

## 3. 与云前端仓库的关系

| 仓库 | Phase 1 | Phase 2 |
|------|---------|---------|
| `yonclaw1.0`（队列真相源） | **必须改** | **必须改** |
| `iuap-yonclaw-cloud-fe` 的 `agent-bridge-host/dispatch-relay-store.ts` | 若该文件只作文档/镜像、不跑队列，可不同步；若本地 host 也会 enqueue，**建议同步 claim** | poll 传 `clientInstanceId`、发消息带 ID |
| `claw-mobile` | 无 | 同 Web：生成 ID + 发消息 + poll |

说明：远程沙箱场景下，**真正的 pending 队列在 yonclaw1.0**；云前端/移动端只是 poll 客户端。Phase 1 只合并沙箱即可止血。

---

## 4. 建议实施顺序

1. **评审通过本方案 Phase 1**  
2. 在 `yonclaw1.0` 实现 claim + 单测 + chain 日志字段  
3. 用「双 Web / Web+移动」回归经营总览创建  
4. 再开 Phase 2 需求（三端联调），单独排期  

---

## 5. 风险与注意

- **先到先得**：Phase 1 下后台 Tab / 移动端可能领走任务；落盘在沙箱共享存储，一般仍可见，但「执行页」不一定是用户眼前页  
- **lease 过短**：执行中被重领 → 仍可能双 create → Phase 1 lease ≥ 路由 timeout，并建议后续页面 create 对 `dispatch-relay requestId` 做幂等  
- **严格校验 claimedBy**：可减少脏 resolve；若旧客户端不传 ID，Phase 1 应用「匿名 consumer + 仍单次 claim」兼容  
- **不要**用常量 `COCKPIT_PAGE_INSTANCE_ID` 充当 Phase 2 的唯一发起者 ID  

---

## 7. Phase 1 实现记录（2026-07-28）

已改文件（`yonclaw1.0`）：

- `electron/main/browser-agent/dispatch-relay-store.ts` — `claimWebviewDispatchRelay` + lease（0.8 * timeoutMs）+ 同 consumer 幂等重领
- `electron/api/routes/webview-agent.ts` — `pending-dispatch` 走 claim；busy 返回 `reason:claimed`；支持可选 query `clientInstanceId`/`consumerId`
- `electron/utils/webview-agent-chain-bindings.ts` / `webview-agent-chain-log.ts` — 新 hop：`pending.poll.claimed` / `pending.poll.busy` / `relay.claimed` 等
- `tests/unit/dispatch-relay-store-claim.test.ts` — 覆盖双消费者、幂等、lease 重领、迟到 resolve

单测：`vitest run tests/unit/dispatch-relay-store-claim.test.ts` 及 webview-agent 相关回归通过。

`dispatch-result` 采用**宽松**模式：不强制校验 claimedBy（仅透传日志）。

---
