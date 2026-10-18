# workbuddy-supermemory

Persistent, cross-session memory for **WorkBuddy / CodeBuddy** powered by
[Supermemory](https://supermemory.ai). Auto-captures your coding sessions and
recalls relevant context into every new session — no manual "remember this".

This is a port of the hook layer from the official
[`supermemoryai/claude-supermemory`](https://github.com/supermemoryai/claude-supermemory)
plugin, adapted for the WorkBuddy / CodeBuddy harness. Because WorkBuddy's hook
engine is protocol-compatible with Claude Code's, this behaves identically to
the Claude Code plugin: same auto-capture, same recall injection.

## What it does

Three hooks are registered into WorkBuddy's user-level settings:

| Hook | When | Effect |
|---|---|---|
| `session-start.js` | New session | Injects this project's profile + recent memories as context |
| `recall-directive.js` | Every user prompt | Searches memories for the prompt, injects relevant ones |
| `capture.js` | End of each turn (Stop) | Uploads the new transcript turns to be extracted into memories |

All hooks **fail open** — if the memory service is unreachable or a key is
missing, WorkBuddy continues normally without memory, no errors.

## Prerequisites

- **WorkBuddy** installed (creates `~/.workbuddy/settings.json`).
- **Node.js** on your PATH (hooks run `node`).
- A **Supermemory backend**, either:
  - **Local** — a self-hosted `supermemory-server` on `http://127.0.0.1:6767`
    (see the [self-hosting docs](https://supermemory.ai/docs/self-hosting/overview)), or
  - **Cloud** — your Supermemory API key from [console.supermemory.ai](https://console.supermemory.ai).

## Install

```bash
git clone https://github.com/Akiyama-sama/workbuddy-supermemory
cd workbuddy-supermemory

# Local server (default: reads ~/.supermemory/api-key for the key):
./install.sh

# Cloud: pass your base URL and API key explicitly:
./install.sh https://api.supermemory.ai sm_YOUR_API_KEY
```

`install.sh`:
1. Backs up `~/.workbuddy/settings.json` first (timestamped).
2. Writes the API key to `~/.supermemory-codebuddy/credentials.json` (mode 600).
3. Merges the three hooks into the `hooks` section of `~/.workbuddy/settings.json`.

Then **restart WorkBuddy**. A new session should print
`◪ supermemory · N memories loaded for <project>`.

### Re-running / uninstall

Re-running `install.sh` is idempotent (it replaces its own prior entries).

```bash
./uninstall.sh   # removes the hooks; keeps ~/.supermemory-codebuddy and all memories
```

## How memory is scoped per project

Memories are stored under a container tag derived from the repository's git
remote: `repo_<project-name>__<remote-hash>`. This is the **same scheme** the
Claude Code and Codex Supermemory plugins use, so if you already use those on
the same repo, WorkBuddy reads and writes the **exact same memory container** —
your memory is shared across all three harnesses automatically, with no
migration. Repos without a git remote fall back to a local path identity.

To override explicitly, set `SUPERMEMORY_REPO_TAG` in your shell before
launching WorkBuddy.

## Differences from upstream (the port)

The bulk of `hooks/` is unmodified upstream code. Only the harness-specific
bits were renamed:

| Item | claude-supermemory | this port |
|---|---|---|
| Plugin root env var | `${CLAUDE_PLUGIN_ROOT}` | `${CODEBUDDY_PLUGIN_ROOT}` |
| Per-project config dir | `.claude/.supermemory-claude/` | `.codebuddy/.supermemory-codebuddy/` |
| Per-user data dir | `~/.supermemory-claude/` | `~/.supermemory-codebuddy/` |
| Statusline cleanup target | `~/.claude/settings.json` | `~/.workbuddy/settings.json` |
| `PreToolUse` recall-approve | enabled (MCP tool auto-approve) | not installed — see note below |
| `mcp-proxy.js` | included | removed (unused by the hooks) |

**Why no MCP / PreToolUse hook:** the upstream `PreToolUse` hook only
auto-approves Supermemory **MCP** tool calls, and the `recall-directive`
discovery text points the model at an MCP `search_memory` tool. WorkBuddy's MCP
servers are configured through its app UI (not scriptable here), so this port
skips MCP registration entirely and relies on the hooks calling the REST API
directly — recall and capture still work end-to-end. The discovery text was
trimmed to not advertise a tool that isn't present.

## Env vars honored (same as upstream)

- `SUPERMEMORY_API_URL` — backend base URL (default `https://api.supermemory.ai`); `install.sh` bakes it into the hook commands.
- `SUPERMEMORY_REPO_TAG` — force a container tag.
- `SUPERMEMORY_ISOLATE_WORKTREES=true` — scope memory per worktree path instead of per remote.
- `SUPERMEMORY_DEBUG=1` — verbose hook logging.
- `SUPERMEMORY_CC_API_KEY` — inline API key (takes precedence over `~/.supermemory-codebuddy/credentials.json`).

## Project layout

```
hooks/               ported hook scripts + lib/ (the engine)
.codebuddy-plugin/   plugin manifest (name/version/description)
install.sh           merge hooks into ~/.workbuddy/settings.json
uninstall.sh         reverse install.sh, keep data
```

## License

MIT. This is a derivative of `supermemoryai/claude-supermemory` (upstream
declares MIT in its plugin manifest); see [LICENSE](LICENSE).
