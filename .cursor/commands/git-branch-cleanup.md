# 一键清理本地与远程分支

按统一规则批量清理 Git 分支：删除已合并到主干（`origin/master` 或 `origin/main`）的本地分支与远程分支。

**用法**：

- `/git-branch-cleanup 预览`：仅预览将被删除的本地/远程分支，不执行删除
- `/git-branch-cleanup`：直接执行清理（本地 + 远程）

**清理规则**：

1. 自动识别主干分支：
   - 若存在 `origin/master`，则使用 `master`
   - 否则使用 `main`
2. 仅删除“已合并到主干”的分支（通过 `git merge-base --is-ancestor` 判断）
3. 自动保护以下分支，不参与删除：
   - 当前分支（`git branch --show-current`）
   - `main`、`master`、`develop`、`dev`
   - `origin/HEAD`
4. 先执行 `git fetch --all --prune`，确保远程状态最新

**执行步骤**：

1. 识别 `BASE`（`master` 或 `main`）和 `CURRENT`
2. 拉取最新远程分支：`git fetch --all --prune`
3. 清理本地分支：
   - 遍历 `refs/heads`
   - 过滤保护分支
   - 删除已合并分支：`git branch -D <branch>`
4. 清理远程分支：
   - 遍历 `refs/remotes/origin/*`
   - 过滤保护分支
   - 删除已合并分支：`git push origin --delete <branch>`
5. 输出汇总结果：
   - 本地删除成功数 / 失败数
   - 远程删除成功数 / 失败数

**一条命令（执行清理）**：

```bash
BASE=$(git show-ref --verify --quiet refs/remotes/origin/master && echo master || echo main); CURRENT=$(git branch --show-current); PROTECT='main master develop dev'; git fetch --all --prune && LOCAL_OK=0 && LOCAL_FAIL=0 && REMOTE_OK=0 && REMOTE_FAIL=0 && for b in $(git for-each-ref --format='%(refname:short)' refs/heads); do [ -z "$b" ] && continue; [ "$b" = "$CURRENT" ] && continue; case " $PROTECT " in *" $b "*) continue;; esac; if git merge-base --is-ancestor "$b" "origin/$BASE"; then if git branch -D "$b"; then LOCAL_OK=$((LOCAL_OK+1)); else LOCAL_FAIL=$((LOCAL_FAIL+1)); fi; fi; done && for rb in $(git for-each-ref --format='%(refname:short)' 'refs/remotes/origin/*' | sed 's#^origin/##'); do [ -z "$rb" ] && continue; [ "$rb" = "HEAD" ] && continue; [ "$rb" = "origin" ] && continue; [ "$rb" = "$CURRENT" ] && continue; case " $PROTECT " in *" $rb "*) continue;; esac; if git merge-base --is-ancestor "origin/$rb" "origin/$BASE"; then if git push origin --delete "$rb"; then REMOTE_OK=$((REMOTE_OK+1)); else REMOTE_FAIL=$((REMOTE_FAIL+1)); fi; fi; done && echo "cleanup done: base=origin/$BASE current=$CURRENT local_ok=$LOCAL_OK local_fail=$LOCAL_FAIL remote_ok=$REMOTE_OK remote_fail=$REMOTE_FAIL"
```

**预览命令（不删除）**：

```bash
BASE=$(git show-ref --verify --quiet refs/remotes/origin/master && echo master || echo main); CURRENT=$(git branch --show-current); PROTECT='main master develop dev'; git fetch --all --prune && echo "[本地待删除]" && for b in $(git for-each-ref --format='%(refname:short)' refs/heads); do [ -z "$b" ] && continue; [ "$b" = "$CURRENT" ] && continue; case " $PROTECT " in *" $b "*) continue;; esac; git merge-base --is-ancestor "$b" "origin/$BASE" && echo "$b"; done && echo "[远程待删除]" && for rb in $(git for-each-ref --format='%(refname:short)' 'refs/remotes/origin/*' | sed 's#^origin/##'); do [ -z "$rb" ] && continue; [ "$rb" = "HEAD" ] && continue; [ "$rb" = "origin" ] && continue; [ "$rb" = "$CURRENT" ] && continue; case " $PROTECT " in *" $rb "*) continue;; esac; git merge-base --is-ancestor "origin/$rb" "origin/$BASE" && echo "$rb"; done
```

**注意事项**：

- 该命令会删除远程分支，请确保团队已确认清理策略
- 推荐先执行 `/git-branch-cleanup 预览` 再执行正式清理
- 如仓库主干不是 `master/main`，请先手动修改 `BASE` 逻辑后再使用
