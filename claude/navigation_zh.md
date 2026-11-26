# Claude Code 导航

## 当前会话

fullscreen 渲染器下：

- `PgUp` / `PgDn`：上/下滚半屏。
- `Ctrl+Home` / `Ctrl+End`：跳到会话开头 / 回到最新并恢复 auto-follow。
- 鼠标滚轮 / 触控板：逐行滚动。
- 顶部会提示最近一条滚出视野的 prompt，点它直接跳过去。

`Ctrl+O` 打开 transcript viewer：

| 按键 | 作用 |
|---|---|
| `/` | 搜索；`n` / `N` 下一个 / 上一个匹配 |
| `{` / `}` | 上一条 / 下一条用户 prompt |
| `g` / `G` | 顶部 / 底部 |
| `Ctrl+u` / `Ctrl+d` | 半页 |
| `q` / `Esc` / `Ctrl+O` | 退出 viewer |
| `?` | 当前界面的快捷键 |

空输入框按 `?` 打开快捷键面板。`Ctrl+R` 搜的是你输入过的 prompt 历史，不是 Claude 的回复；
`Up` / `Down` 也能召回之前的 prompt。

## 回退或恢复

- 空输入框按 `Esc` `Esc`，或 `/rewind`（别名 `/undo`）：选择 checkpoint。
  `Restore conversation` 会把原来的 prompt 回填到输入框，不会自动重跑。
- `claude --resume`（选择器）、`claude -c`（当前目录最近的会话），或会话内 `/resume`：
  回到旧会话。

## Fullscreen 渲染器与终端 scrollback

fullscreen 渲染器使用 alternate screen，所以终端模拟器的 scrollback 里没有对话内容。
在 transcript viewer 里：

- `[`：把整段对话写进终端原生 scrollback，之后终端的查找和 copy mode 就能用。
- `v`：写到临时文件并用 `$EDITOR` 打开。

`/tui default` 切回 classic 渲染器，对话会直接进入终端 scrollback；
启动时设置 `CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1` 也一样。

transcript viewer 的 `{` / `}` / `g` / `G` 是它自己的 vi 风格键位，不需要开 Claude Code 的
vim mode；vim mode 只影响输入框编辑。

fullscreen 渲染器仍在 research preview，键位可能变化。官方文档：
[interactive mode](https://code.claude.com/docs/en/interactive-mode)、
[fullscreen](https://code.claude.com/docs/en/fullscreen)。
