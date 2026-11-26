# Claude Code Footer Mod（context-footer）

> 本文覆盖两个 mod；其他配置见 [settings.json](settings.json) 和 [navigation](navigation_zh.md)。

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
- 终端或 Desktop 端；转发参数的包装器同样可用。

## 安装

如果软链了 `settings.json`（见[另见](#另见)），它已经声明 GitHub marketplace 并启用插件。Claude Code 会按仓库根目录的 `.claude-plugin/marketplace.json` 注册 marketplace，并在首次启动时下载已启用的插件；跳过这里的手动安装。

下面的命令把仓库根目录注册为本地目录 marketplace，用于开发。不要再用同一个 marketplace 名注册第二份。

从仓库根目录执行：

```bash
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
ln -sfn "$PWD" "$CONFIG_DIR/mods"
claude plugin marketplace add "$CONFIG_DIR/mods"
claude plugin install context-footer@kennylong-mods --scope user
claude plugin install model-effort@kennylong-mods --scope user
```

把上面命令里的 `claude` 换成你的包装器即可。

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

`settings.json` 这种写法只用于裸 Claude Code 的开发会话；日常开发优先用 `--plugin-dir`。如果包装器设置了 `CLAUDE_CODE_PLUGIN_DIRS`，优先用 marketplace 安装：`settings.json` 里的值会覆盖包装器自己的值。

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

改完在会话里执行 `/reload-plugins`。从目录 marketplace 安装的插件是就地加载本仓库的，所以改动在下次启动或 `/reload-plugins` 后生效。

# Effort Mod（model-effort）

所有 `deepseek` 模型（包括 subagent 请求）都发 `max`。其他模型用 `/effort` 给它们选的档位，或 Claude Code 的默认值（比如 Opus 5.5 是 `medium`，Opus 5 是 `high`）。

settings 存不了 `max`：`effortLevel` 和 `modelSettings.<model>.effortLevel` 最高只到 `xhigh`，所以由 mod 在请求上设置。

改模型或档位就编辑 `hooks/model-effort.mjs` 里的 `RULES`，第一条匹配的规则生效。测试：`claude plugin test claude/mods/model-effort`。

footer 显示每个模型上一次主线程请求的档位，跨会话保存。某个模型第一次用时，要等第一条请求后才显示。

## 另见

- [settings.json](settings.json)：完整个人配置。model/plugin 等 key 有环境依赖，另外启用了 gopls-lsp、code-simplifier、feature-dev。软链前先备份或合并现有文件，再链到 `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json`。
- [Claude Code 导航](navigation_zh.md)：transcript、rewind、会话恢复快捷键。
