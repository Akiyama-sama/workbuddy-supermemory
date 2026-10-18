#!/bin/bash
# workbuddy-supermemory installer
# 接入方式：WorkBuddy 用户级 hooks（~/.workbuddy/settings.json 的 hooks 段，
# 与 wb-switch 同款机制，已验证生效）。不依赖 WB 插件注册表。
# 用法: ./install.sh [http://127.0.0.1:6767]
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"
API_URL="${1:-http://127.0.0.1:6767}"
SETTINGS="$HOME/.workbuddy/settings.json"
CRED_DIR="$HOME/.supermemory-codebuddy"

[ -f "$SETTINGS" ] || { echo "找不到 $SETTINGS（WorkBuddy 未安装？）"; exit 1; }
cp "$SETTINGS" "$SETTINGS.bak.supermemory-$(date +%s)"

# apiKey：本地服务读 ~/.supermemory/api-key，云端传第二个参数
API_KEY="${2:-$(cat "$HOME/.supermemory/api-key" 2>/dev/null || true)}"

mkdir -p "$CRED_DIR"
if [ -n "$API_KEY" ]; then
  python3 -c "
import json,sys,time,pathlib
p=pathlib.Path(sys.argv[1]); p.write_text(json.dumps({'apiKey':sys.argv[2],'savedAt':time.strftime('%Y-%m-%dT%H:%M:%S.000Z')},indent=2)+'\n'); p.chmod(0o600)
print('credentials ok')" "$CRED_DIR/credentials.json" "$API_KEY"
else
  echo "警告: 无 API key（云端用户先跑一次 WorkBuddy 会话触发浏览器登录，或手动写 $CRED_DIR/credentials.json）"
fi

python3 - "$PLUGIN_DIR" "$API_URL" "$SETTINGS" <<'PYEOF'
import json, sys
plugin_dir, api_url, settings_path = sys.argv[1], sys.argv[2], sys.argv[3]
hooks = json.load(open(settings_path))

MARKER = "CODEBUDDY_PLUGIN_ROOT"  # present in our commands, absent from other hooks (e.g. wb-switch)

def entry(script, timeout=30):
    return {"type": "command",
            "command": f'SUPERMEMORY_API_URL="{api_url}" CODEBUDDY_PLUGIN_ROOT="{plugin_dir}" node "{plugin_dir}/hooks/{script}"',
            "timeout": timeout}

def merge(event, arr):
    lst = hooks.setdefault("hooks", {}).setdefault(event, [])
    lst[:] = [g for g in lst if MARKER not in json.dumps(g)]
    lst.append({"hooks": [entry(s) for s in arr]})

# 三件套（PreToolUse recall-approve 只在注册了 supermemory MCP 时才有意义，跳过；
# SessionStart 注入 + UserPromptSubmit 按 prompt 召回 + Stop 捕获 = 完整闭环）
merge("SessionStart", ["session-start.js"])
merge("UserPromptSubmit", ["recall-directive.js"])
merge("Stop", ["capture.js"])

json.dump(hooks, open(settings_path, "w"), ensure_ascii=False, indent=2)
print("hooks merged ->", settings_path)
PYEOF

echo "完成。重启 WorkBuddy 后，新会话应出现 '◪ supermemory · N memories loaded'。"
echo "卸载: ./uninstall.sh（保留数据与记忆）"
