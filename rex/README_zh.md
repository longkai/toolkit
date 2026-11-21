# Rex 配置

本仓库维护的 [Rex](https://www.superlogical.com/rex/) 配置。`init.lua` 是唯一来源，软链到 Rex 的默认配置路径。

[English](README.md)

## 安装

```sh
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/rex"
mkdir -p "$config_dir"
ln -sfn <repo>/rex/init.lua "$config_dir/init.lua"
```

修改后校验并重载：

```sh
REX_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/rex/init.lua" rex config check
rex config reload
```

如果运行中的 app 还在用旧 keymap，在命令面板里执行 **Reload Config**（`Cmd+Shift+P`），或重启 Rex。

## 配置说明

`init.lua` 只补充 Rex 默认值之外、且实际需要的绑定：

```lua
rex.bind("ctrl+cmd+=", "pane.balance")
```

- `Ctrl+Cmd+=`：均分分屏。Rex 的 `pane.balance` 没有默认键，这个组合与 Ghostty 上游默认一致；
  本仓库的 `ghostty/config` 另外绑了 `Cmd+Shift+E`；Ghostty 的 keybind 是叠加的，两个都能用。
- `Cmd+K` 保持 Rex 默认的 session picker，不改成清屏。
- 命令间跳转用 Rex 默认的 `Cmd+Up` / `Cmd+Down`；`Shift+Cmd+Up/Down` 保留给上/下分屏。

## 快捷键速查

### 分屏 / Pane

| 快捷键 | 作用 |
|---|---|
| `Cmd+D` | 向右分屏 |
| `Shift+Cmd+Up` | 向上分屏 |
| `Shift+Cmd+D`、`Shift+Cmd+Down` | 向下分屏 |
| `Shift+Cmd+Left/Right` | 向左/右分屏 |
| `Cmd+Enter` | 自动选择方向分屏 |
| `Shift+Cmd+Enter` | Zoom 当前 pane |
| `Alt+Cmd+Enter` | 当前 pane 浮动 |
| `Alt+Cmd+M` | 最小化浮动 pane |
| `Alt+Shift+Cmd+Enter` | 最小化所有浮动 pane |
| `Alt+Shift+Cmd+Arrows` | 移动 pane |
| `Cmd+W` | 关闭 pane → tab → 窗口 |
| `Ctrl+Cmd+=` | 均分分屏（本仓库配置） |

### Tab / Session / Window

| 快捷键 | 作用 |
|---|---|
| `Cmd+T` | 新建 tab |
| `Alt+Cmd+W` | 关闭 tab |
| `Cmd+1` … `Cmd+9` | 跳到第 N 个 tab |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | 下一个 / 上一个 tab |
| `Shift+Cmd+]` / `Shift+Cmd+[` | 下一个 / 上一个 tab |
| `Cmd+'` | 在最近两个 tab 之间切换 |
| `Cmd+N` | 新建窗口 |
| `Shift+Cmd+W` | 关闭窗口 |
| `Ctrl+Cmd+F` | 全屏切换 |
| `Shift+Cmd+N` | 新建 session |
| `Cmd+K` | Session picker |
| `Cmd+R` | 刷新 sessions |
| `Alt+Shift+Cmd+N` | 在指定 host 上新建 session |

### 滚动 / 查找 / 复制

| 快捷键 | 作用 |
|---|---|
| `Cmd+Up` / `Cmd+Down` | 上一条 / 下一条 shell 提示符 |
| `Shift+Cmd+C` | 进入 copy mode |
| `/` | 在 copy mode 中搜索 |
| `y` | 复制选区并退出 copy mode |
| `Esc` / `q` | 退出 copy mode |
| `Cmd+F` | 打开查找 |
| `Cmd+G` / `Shift+Cmd+G` | 下一个 / 上一个匹配（仅查找栏内） |
| `Cmd+Y` | Quick Look 预览 |

### App

| 快捷键 | 作用 |
|---|---|
| `Shift+Cmd+P` | 命令面板 |
| `Cmd+P` | Go to Anything |
| `Shift+Cmd+G` | Go to Directory |
| `Cmd+,` | Settings |
| `Cmd+/` | 侧栏开关 |
| `Cmd+.` | Activity 开关 |
| `Cmd+=` / `Cmd+-` / `Cmd+0` | 字号增大 / 减小 / 重置 |

全局 show/hide 用 app 自己的快捷键：`Cmd+Shift+P` → **Change Shortcut…** → **Toggle Visibility**。它不在 `init.lua` 里，因为 `rex.bind` 只在 Rex 前台时生效。

### Hosts

`Switch Host`（`client.host.switch`）**没有默认快捷键**。如果经常在本地/远程 host 之间切换，可以自己绑一个：

```lua
rex.bind("ctrl+cmd+h", "client.host.switch")
```

`Alt+Shift+Cmd+N` 是在指定 host 上新建 session；`Cmd+K` 切换的是 session，不是 host。

### 可选自定义绑定（当前未启用）

```lua
rex.bind("ctrl+cmd+r", "client.config.reload")
rex.bind("cmd+a", "pane.select_all")
```

## 设置备份（macOS）

`init.lua` 跟着 repo 走；GUI 设置不在里面。Rex 把它们存在二进制的
`~/Library/Preferences/com.superlogical.rex.plist`（domain
`com.superlogical.rex`）。

旧机器备份（放在仓库外）：

```sh
defaults export com.superlogical.rex ~/rex-settings.plist
```

新机器先退出 Rex，再恢复：

```sh
defaults import com.superlogical.rex ~/rex-settings.plist
# 重新打开 Rex；如果还是旧值，再跑：
killall cfprefsd
```

以文本方式查看：

```sh
defaults read com.superlogical.rex
plutil -p ~/Library/Preferences/com.superlogical.rex.plist
```

不要把完整的 plist 提交到公开仓库：里面可能有 Tailscale、SSH agent、remote host、账号等信息。放在私有位置，或者只提取外观相关的 key 用 `defaults write`。不想搬 plist 的话，就按下面对照表手动重设。

## Ghostty 外观在 Rex 里的位置

Rex 不读 Ghostty 配置，外观在 Settings 里：

| Ghostty | Rex Settings |
|---|---|
| `theme` | Themes > Light Mode / Dark Mode；Interface > Appearance > Color scheme |
| `font-family`、`font-size` | Terminal > Typography |
| fallback fonts、ligatures、smoothing | Terminal > Advanced Font Settings |
| `adjust-cell-height` | Terminal > Typography > Line height |
| `window-padding-x/y` | Interface > Padding |
| `background-opacity`、`background-blur` | Interface > Appearance > Use glass for panes |
| `window-colorspace = display-p3` | Terminal > Colors > Use Display P3 color space |
| `minimum-contrast` | Terminal > Colors > Improve text contrast |
| `macos-option-as-alt` | Terminal > Keyboard > Option key |
| `cursor-style`、`cursor-style-blink` | Terminal > Cursor |
| `copy-on-select` | Terminal > Selection > Copy on selection |
| `command` | Terminal > Shell > Startup command |
| `notify-on-command-finish` | Notifications > Program Activity（需要 OSC 7501） |
| `unfocused-split-opacity` | Interface > Active Pane > Fade inactive panes |
| `equalize_splits` | `init.lua` 里的 `Ctrl+Cmd+=` |

Rex 没有对应项：

- 数值化的背景透明度、`background-opacity-cells`、`alpha-blending`
- `macos-titlebar-style`、`macos-window-shadow`、`resize-overlay-position`
- `window-padding-balance`、`middle-click-action`、`clipboard-trim-trailing-spaces`
- `mouse-hide-while-typing`、`confirm-close-surface`
- `window-save-state`、`window-inherit-working-directory`、`window-inherit-font-size`

通知使用 OSC 7501 program status 协议；Claude Code 集成在 **Settings > Integrations > Coding Agents** 里开启。
