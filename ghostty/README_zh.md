# Ghostty 配置（极客风 · macOS）

一份面向命令行重度用户（尤其是 Claude Code CLI）的 [Ghostty](https://ghostty.org/) 配置，追求**极致美观**与**高效**：随系统自动切换深浅主题、毛玻璃通透质感、全局热键呼出、连字与 Emacs Meta 键支持。

[English](README.md)

## 特性一览

| 需求 | 实现 |
|------|------|
| 随系统自动切换外观 | `theme = light:Catppuccin Latte,dark:Catppuccin Mocha`，跟随 macOS 明暗模式自动切换 |
| 默认 Shell | `command = /opt/homebrew/bin/nu`，新窗口/标签默认启动 nushell |
| 全局呼出/隐藏（类 iTerm2） | `Option + Space` 呼出 Quake 式 quick terminal，顶部下拉、失焦自动隐藏 |
| Emacs 风格命令行编辑 | `macos-option-as-alt = true`，左右 Option 均作 Meta 键（`M-b`/`M-f`/`M-d` 等），nushell 的 reedline 默认 emacs 键位 |
| 毛玻璃美观 | 半透明背景 + 背景模糊 + 透明标题栏 + 窗口阴影 |
| 字体连字 | Cascadia Code Nerd Font，开启 `calt`/`liga` 连字与 Nerd Font 图标 |
| 专注当前窗口 | 透明 + 毛玻璃间接区分前后台；分屏时用 `unfocused-split-opacity` 突出当前分屏 |
| 命令面板 & 效率键 | `Cmd+Shift+P` 命令面板；`Cmd+Shift+J` 把当前屏+历史导出到编辑器；`Cmd+Shift+Enter` 缩放分屏；`Cmd+Shift+E` 均分分屏；`Cmd+Shift+↑/↓` 命令间跳转 |
| Nushell 深度集成 | `nushell/config.nu` 开启内置 `shell_integration`（OSC 2/7/8/133），解锁标题、目录继承、超链接与命令跳转 |
| 渲染优化 | `alpha-blending = linear-corrected` 让透明背景下文字更清晰；`minimum-contrast` 可读性护栏 |

## 依赖

- **Ghostty ≥ 1.3.1**（配置基于 1.3.1 stable 编写并校验）
- **Nushell**（默认 shell，配置里写死绝对路径 `/opt/homebrew/bin/nu`）
  ```sh
  brew install nushell
  which nu   # 若不是 /opt/homebrew/bin/nu，请据此修改 config 中的 command
  ```
- **Cascadia Code Nerd Font**（提供连字与图标）
  ```sh
  brew install --cask font-cascadia-code-nf
  ```
  如未安装该字体，Ghostty 会回退到默认等宽字体，连字/图标可能缺失。

## 安装（软链到默认配置路径）

Ghostty 在 macOS 读取 `~/.config/ghostty/config`。将本仓库的配置软链过去即可，后续 `git pull` 更新自动生效：

```sh
mkdir -p ~/.config/ghostty
ln -sf ~/src/toolkit/ghostty/config ~/.config/ghostty/config
```

> 请把 `~/src/toolkit` 替换为你本机实际的仓库路径。

## 首次使用需授权

全局热键（`Option + Space`）依赖 `keybind = global:...`，需要授予辅助功能权限，否则热键在其他 App 中无效：

**系统设置 → 隐私与安全性 → 辅助功能 → 打开 Ghostty 开关**

## 常用操作

- **热重载配置**：修改配置后，在 Ghostty 中按 `Cmd + Shift + ,` 即可重新加载，无需重启。
- **打开配置**：`Cmd + ,`
- **校验配置合法性**：
  ```sh
  /Applications/Ghostty.app/Contents/MacOS/ghostty +show-config
  ```
- **查看可用主题 / 字体**：
  ```sh
  /Applications/Ghostty.app/Contents/MacOS/ghostty +list-themes
  /Applications/Ghostty.app/Contents/MacOS/ghostty +list-fonts
  ```

## 说明与限制

- **「失去焦点时调暗整个窗口」**：Ghostty 1.3.1 **没有**整窗失焦调暗的原生能力（`unfocused-split-opacity` 仅作用于分屏）。本配置改用**半透明 + 毛玻璃**让前后台窗口自然区分，达到「专注当前窗口」的近似效果。如需真正的整窗失焦变暗，可借助系统级工具（如 Hammerspoon、HazeOver）实现。
- **连字开关**：如不喜欢连字，将 `config` 中的 `font-feature = calt` / `font-feature = liga` 改为 `-calt` / `-liga` 即可。
- **Meta 键不生效排障**：本配置已设 `macos-option-as-alt = true`，左右 Option 均作 Meta。若仍不生效，逐项排查：
  1. 确认配置**已热重载**（`Cmd + Shift + ,`）或重启 Ghostty；
  2. 确认没有其它配置源覆盖（macOS 上除 `~/.config/ghostty/config` 外，`~/Library/Application Support/com.mitchellh.ghostty/` 里若存在配置也会被加载合并，建议以软链为唯一来源）；
  3. 在 nushell 里测试 `M-b`/`M-f`（词间跳转）、`M-d`（删词）——这些是 reedline 默认 emacs 键位；
  4. 若你更想保留「右 Option 输入 `é`/`—` 等特殊字符」，把 `true` 改回 `left`，并改用**左** Option 触发 Meta。
- **Nushell shell 集成（已接入）**：Ghostty 官方「注入式」集成不含 nu，但本仓库已在 `nushell/config.nu` 里开启 nushell 内置的 `shell_integration`，发送标准 OSC 序列：
  - `osc2` 用当前目录/命令更新窗口与标签标题；
  - `osc7` 上报 cwd，新标签/分屏/quick terminal 自动继承当前目录；
  - `osc8` 输出可点击超链接；
  - `osc133` 标记提示符边界，解锁 Ghostty 的「命令间跳转」——按 `Cmd+Shift+↑/↓` 在每次命令的提示符间跳转（回看长输出定位每次执行超方便）。
  <br>（`osc633` 为 VSCode 专用、`osc9_9` 为 ConEmu/Windows 专用，Ghostty 不解析会静默忽略，无影响。）
- **应用图标**：`macos-icon = xray` 为极客风格，可换成 `official`、`holographic`、`microchip`、`blueprint` 等。
- **主题联动（Catppuccin，与 git delta 一致）**：本仓库的 `git/config` 里，[delta](https://github.com/dandavison/delta) 分页器也配了随终端明暗自动切换的 Catppuccin 主题（`detect-dark-light = auto` + `catppuccin-mocha` / `catppuccin-latte` 两个带 `dark=true`/`light=true` 的「主题」feature），与这里的 `theme = light:Catppuccin Latte, dark:Catppuccin Mocha` 一一对应：系统切浅色 → 二者都用 Latte，切深色 → 都用 Mocha，`git diff` / `git log` / `git blame` 的配色和终端始终统一。<br>**换主题时记得两边一起改**：若把本文件的 `theme` 换成别的配色，也要同步更新 `git/config` 文末的 `[delta "..."]` 两个区块（语法主题名 + 各项 hex），否则 diff 配色会与终端脱节。
