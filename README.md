# workbuddy-supermemory

给 **WorkBuddy / CodeBuddy** 加上跨会话的持久记忆，后端用 [Supermemory](https://supermemory.ai)：自动捕获你的编码会话、在每个新会话里召回相关上下文——不用手动"记住这个"。

本仓库是官方 [`supermemoryai/claude-supermemory`](https://github.com/supermemoryai/claude-supermemory) 插件 hook 层的移植，适配 WorkBuddy / CodeBuddy。WorkBuddy 的 hook 引擎与 Claude Code 协议同构，所以行为和 Claude Code 插件完全一致：同样的自动捕获、同样的召回注入。

## 它做什么

安装时往 WorkBuddy 的用户级配置里注册三个 hook：

| Hook | 触发时机 | 效果 |
|---|---|---|
| `session-start.js` | 新会话开始 | 把本项目的 profile + 近期记忆注入为会话上下文 |
| `recall-directive.js` | 每次提交 prompt | 按 prompt 语义搜索记忆，注入相关条目 |
| `capture.js` | 每轮结束（Stop） | 把新增的对话内容上传，抽取为记忆 |

所有 hook 都是 **fail-open**：记忆服务连不上、key 缺失时，WorkBuddy 照常运行、只是没有记忆，不会报错。

## 前置条件

- 已安装 **WorkBuddy**（存在 `~/.workbuddy/settings.json`）
- **Node.js** 在 PATH 上（hook 用 `node` 执行）
- 一个 **Supermemory 后端**，二选一：
  - **本地自托管** —— 跑着的 `supermemory-server`（`http://127.0.0.1:6767`），见[自托管文档](https://supermemory.ai/docs/self-hosting/overview)；或
  - **云端** —— 在 [console.supermemory.ai](https://console.supermemory.ai) 拿 API key。

## 让 Agent 帮你装（复制下面这段，粘贴给 Claude Code / Codex / WorkBuddy 均可）

```text
帮我安装 workbuddy-supermemory，让 WorkBuddy 拥有跨会话持久记忆，步骤如下：

1. 先探测本地后端：curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:6767/
   - 返回 200：用本地服务，跳到第 2 步（key 会自动从 ~/.supermemory/api-key 读取）。
   - 连不上：问我有没有云端 API key（sm_ 开头）；如果都没有，先执行
     curl -fsSL https://supermemory.ai/install | bash
     装好本地 supermemory-server 并启动（首次启动会自动生成 key 到 ~/.supermemory/api-key）。

2. 克隆并进入仓库：
   git clone https://github.com/Akiyama-sama/workbuddy-supermemory && cd workbuddy-supermemory

3. 通读 README.md 和 install.sh 源码，确认它只做一件事：把三个 hook 合并进
   ~/.workbuddy/settings.json（脚本会先自动备份该文件），然后执行：
   - 本地后端：./install.sh
   - 云端后端：./install.sh https://api.supermemory.ai sm_你的key

4. 安装后离线验证 hook 链路（不需要重启 WorkBuddy）：
   echo '{"hook_event_name":"SessionStart","session_id":"verify-1","cwd":"你的项目绝对路径"}' \
     | SUPERMEMORY_API_URL=<第3步用的地址> CODEBUDDY_PLUGIN_ROOT=<仓库绝对路径> \
       node hooks/session-start.js
   输出里有 "supermemory" 和 memories loaded / No previous memories 字样即为成功。

5. 告诉我：重启 WorkBuddy，开新会话应看到 "◪ supermemory · N memories loaded"。
   卸载运行 ./uninstall.sh（只移除 hook，保留数据和记忆）。
```

## 手动安装

```bash
git clone https://github.com/Akiyama-sama/workbuddy-supermemory
cd workbuddy-supermemory

# 本地服务（默认，自动读 ~/.supermemory/api-key）：
./install.sh

# 云端：显式传地址和 key
./install.sh https://api.supermemory.ai sm_YOUR_API_KEY
```

`install.sh` 做三件事：① 带时间戳备份 `~/.workbuddy/settings.json`；② 把 API key 写入 `~/.supermemory-codebuddy/credentials.json`（权限 600）；③ 把三个 hook 合并进 settings.json 的 `hooks` 段。

装完**重启 WorkBuddy**，新会话应出现 `◪ supermemory · N memories loaded for <项目名>`。

重复运行 `install.sh` 是幂等的（只会替换自己名下的条目，不动其他 hook，比如账户切换类的）。卸载：

```bash
./uninstall.sh   # 移除 hook；保留 ~/.supermemory-codebuddy 和服务器里的全部记忆
```

## 记忆如何按项目隔离（跨 harness 共享的原理）

记忆存放在以仓库 git remote 哈希命名的容器里：`repo_<项目名>__<remote-hash>`。这与 Claude Code、Codex 的官方 Supermemory 插件用的是**同一套命名规则**——所以如果你在同一个仓库已经用了那两家，WorkBuddy 会直接读写**同一个记忆容器**，三家 harness 的记忆天然共享，无需任何迁移。没有 git remote 的目录回退到本地路径身份。

想显式指定容器，启动 WorkBuddy 前设 `SUPERMEMORY_REPO_TAG`。

## 与上游的差异（移植点）

`hooks/` 主体是未改动的上游代码，只改了 harness 相关的部分：

| 项目 | claude-supermemory | 本移植 |
|---|---|---|
| 插件根变量 | `${CLAUDE_PLUGIN_ROOT}` | `${CODEBUDDY_PLUGIN_ROOT}` |
| 项目级配置目录 | `.claude/.supermemory-claude/` | `.codebuddy/.supermemory-codebuddy/` |
| 用户数据目录 | `~/.supermemory-claude/` | `~/.supermemory-codebuddy/` |
| statusline 清理目标 | `~/.claude/settings.json` | `~/.workbuddy/settings.json` |
| `PreToolUse` recall-approve | 启用（自动放行 MCP 只读工具） | 未安装，原因见下 |
| `mcp-proxy.js` | 有 | 移除（hooks 未引用） |

**为什么不装 MCP / PreToolUse**：上游的 `PreToolUse` hook 只服务于 Supermemory **MCP** 工具的自动放行，`recall-directive` 的发现文案也会引导模型去调 MCP `search_memory` 工具。而 WorkBuddy 的 MCP server 只能通过 App 界面配置、没法脚本注入，所以本移植完全不走 MCP——召回和捕获全靠 hook 直连 REST API，功能完整。发现文案已裁剪，不再提示一个不存在的工具。

## 支持的环境变量（与上游一致）

- `SUPERMEMORY_API_URL` —— 后端地址（默认 `https://api.supermemory.ai`）；`install.sh` 会把它写进 hook 命令里。
- `SUPERMEMORY_REPO_TAG` —— 强制指定容器标签。
- `SUPERMEMORY_ISOLATE_WORKTREES=true` —— 按 worktree 路径隔离记忆（默认按 remote）。
- `SUPERMEMORY_DEBUG=1` —— hook 输出调试日志。
- `SUPERMEMORY_CC_API_KEY` —— 内联 API key（优先于 `~/.supermemory-codebuddy/credentials.json`）。

## 目录结构

```
hooks/               移植过来的 hook 脚本 + lib/（核心逻辑）
.codebuddy-plugin/   插件清单（name/version/description）
install.sh           把 hook 合并进 ~/.workbuddy/settings.json（自动备份）
uninstall.sh         反向操作，保留数据
```

## 许可

MIT。本项目衍生自 `supermemoryai/claude-supermemory`（上游 manifest 声明 MIT），见 [LICENSE](LICENSE)。
