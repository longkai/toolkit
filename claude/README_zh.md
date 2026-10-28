# Claude Code Footer Mod（context-footer）

在 Claude Code 的 prompt footer 里显示当前模型、context 用量和 cache 命中率：

```text
auto mode on · 🤖 deepseek · ☂️ 61% · 🎟️ 483.5k/786.4k · 🎯 98%
```

- 天气 emoji 按 context 占用切换：<25% ☀️、25–49% ☁️、50–74% ☂️、75–89% ⛈️、≥90% 🚨。
- `🎟️` 显示已用 / 上限 token。
- `🎯` 显示主对话 cache 命中率（`cache_read / 全部输入`）。
- 颜色使用 Claude Code 主题键（`success`、`warning`、`error`、`suggestion`），跟随当前主题。

## 依赖

- Claude Code ≥ 2.1.287（mods）。
- 终端或 Desktop 端；tclaude 包装器同样可用。

## 安装

从仓库根目录执行：

```bash
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
ln -sfn "$PWD/claude/mods" "$CONFIG_DIR/mods"
claude plugin marketplace add "$CONFIG_DIR/mods"
claude plugin install context-footer@kennylong-mods --scope user
```

tclaude 用户把 `claude` 换成 `tclaude` 即可，参数会转发给上游。

只想临时试用、不安装：

```bash
claude --plugin-dir "$PWD/claude/mods/context-footer"
```

安装后重启 Claude Code，或在会话里执行 `/reload-plugins`。

## 从仓库直接加载（开发）

开发 mod 时建议直接加载仓库目录，改完保存即可同步，不用重装 marketplace：

```bash
export CLAUDE_CODE_PLUGIN_DIRS="$PWD/claude/mods/context-footer"
```

或写进 `$CONFIG_DIR/settings.json`：

```json
{
  "env": {
    "CLAUDE_CODE_PLUGIN_DIRS": "/absolute/path/to/toolkit/claude/mods/context-footer"
  }
}
```

这是绝对路径，仓库移动后要更新；多个目录用 `:` 分隔。env 需要重启 Claude Code 生效。`--plugin-dir` 加载的插件在保存 hooks 文件时会自动重载；若没有生效，执行 `/reload-plugins`。

## 数据来源

- `$.session.usage()`：context tokens、window、percent。
- `turn.complete` 的 `usage`：cache read、cache creation、input tokens。
- `$.session.model()`：当前模型名。
- cache 统计按 session 持久化在 `$.store`；首次加载会从 transcript（最后 4 MiB）回填。
- 无网络请求；transcript 只读。

## 自定义

编辑 `hooks/context-footer.mjs`：

- `weatherIcon(percent)`：天气档位和 emoji。
- `ctxColor` / `cacheColor`：颜色阈值。
- `ui.render` 里的 `children.push(...)`：emoji、顺序、分隔符和显示字段。
- `shortModel` / `short`：模型名和 token 格式。

改完在会话里执行 `/reload-plugins`。注意安装后的副本在 `$CONFIG_DIR/plugins/cache`，本仓库是源；修改后重新执行 `claude plugin install`，或用 `--plugin-dir` 直接加载源目录。
