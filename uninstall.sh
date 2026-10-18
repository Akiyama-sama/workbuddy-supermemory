#!/bin/bash
# 撤销 install.sh 的全部改动（保留 ~/.supermemory-codebuddy 数据与服务器里的记忆）
set -euo pipefail
SETTINGS="$HOME/.workbuddy/settings.json"

python3 - "$SETTINGS" <<'PYEOF'
import json, sys
sp = sys.argv[1]
hooks = json.load(open(sp))
removed = 0
for event in list(hooks.get("hooks", {})):
    lst = hooks["hooks"][event]
    kept = [g for g in lst if "CODEBUDDY_PLUGIN_ROOT" not in json.dumps(g)]
    removed += len(lst) - len(kept)
    if kept: hooks["hooks"][event] = kept
    else: del hooks["hooks"][event]
json.dump(hooks, open(sp, "w"), ensure_ascii=False, indent=2)
print(f"removed {removed} supermemory hook entries")
PYEOF

echo "已卸载。数据目录 ~/.supermemory-codebuddy 未删除（记忆仍在服务器里）。"
