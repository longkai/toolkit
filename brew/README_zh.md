# Homebrew 跨平台同步

用「拆分式 `Brewfile` + Git」在 **macOS** 与 **Linux** 之间同步 Homebrew 软件，并可选每日定时器，只做安全的「拉取 + 安装」。

[English](README.md)

## 为什么要拆分文件？

Linux 上的 Homebrew（Linuxbrew）**不支持 `cask` 和 `mas`**——它们是 macOS 独有的（图形 App / Mac App Store）。命令行 `formula` 则大多两平台通用。因此按职责拆分：

| 文件 | 内容 | 生效平台 |
|------|------|----------|
| `Brewfile` | 共用 formula/tap + 按平台条件加载子文件 | macOS 和 Linux（入口） |
| `Brewfile.macos` | `cask`、`mas`、macOS 专属 formula | macOS |
| `Brewfile.linux` | Linux 专属 formula | Linux |

入口 `Brewfile` 本质是 Ruby，用 `OS.mac?` / `OS.linux?` 判断后 `instance_eval` 只加载匹配的子文件，因此**两平台用同一条安装命令**，Linux 会自动忽略 cask。

## 安装 / 应用

```sh
brew bundle install --file=brew/Brewfile
```

或用辅助脚本（会先 `git pull --ff-only`）：

```sh
nu brew/sync.nu apply
# 或作为模块导入：use brew/sync.nu ; sync apply
```

若还想**升级**已安装的软件（apply + `brew update` + `brew upgrade` + `brew cleanup`）：

```sh
nu brew/sync.nu upgrade
```

这里的 `brew cleanup` 只清理**旧版本残留和下载缓存**——它不是 `brew bundle --cleanup`，绝不会卸载你正在用的软件。

`brew bundle install` 是**幂等**的：只装缺的、已装的跳过，可反复安全执行。

> **危险 — `--cleanup`：** `brew bundle install --cleanup` 会**卸载**清单里没列出的软件。这里刻意**不使用**它。只有当你确实想让 Brewfile 成为唯一事实来源时，才手动加上。

## 日常同步循环（新增一个软件）

在某台机器装了新东西时：

```sh
brew install ripgrep                 # 1. 正常安装

# 2. 记录到对应文件：
#    - 跨平台命令行工具  -> brew/Brewfile
#    - macOS 专属 cask/mas -> brew/Brewfile.macos
#    - Linux 专属 formula  -> brew/Brewfile.linux
echo 'brew "ripgrep"' >> brew/Brewfile        # 最简单的手动方式
# ...或运行 `nu brew/sync.nu dump` 后整理草稿（见下）

git add brew/ && git commit -m "add ripgrep" && git push   # 3. 提交
```

在另一台机器：

```sh
git pull
brew bundle install --file=brew/Brewfile      # 装上新软件
```

### `sync.nu dump` —— 导出当前软件供整理

```sh
nu brew/sync.nu dump
```

- macOS 上会用当前的 **cask + mas** 覆盖写入 `Brewfile.macos`（安全，因为它们本就 macOS 专属）。
- **formula + tap** 会写入 `Brewfile.<os>.draft` 草稿。Homebrew 无法判断某个 formula 是否跨平台，所以由**你**决定：把通用的移进 `Brewfile`，平台专属的留在 `Brewfile.<os>`，然后删掉草稿并提交。

## 自动同步（半自动，可选）

定时器跑 `sync.nu upgrade`——`git pull --ff-only` + `brew bundle install` + `brew update` + `brew upgrade` + `brew cleanup`，因此定时运行会安装新声明的软件、把已装软件升级到最新版，并清理旧版本/缓存。它仍然**绝不卸载**正在使用的软件（`brew cleanup` ≠ `brew bundle --cleanup`）。导出/提交刻意保持手动（自动 dump 会破坏拆分结构，并在两台机器间制造 git 冲突）。

> 如果你希望定时器只安装、不自动升级，把定时器的参数从 `upgrade` 改回 `apply` 即可（launchd 的 `ProgramArguments` / systemd 的 `ExecStart`）。

> **绝不用 root：** Homebrew 拒绝以 root 运行。请使用下面的**用户级** launchd agent / systemd *user* timer，不要用系统级/root 调度器，也不要 `sudo`。

### macOS —— launchd（不要用 cron）

现代 macOS 上 `cron` 已弃用，且常因 Full Disk Access（TCC）限制静默失败。请改用用户域的 **LaunchAgent**。

```sh
# 1. 编辑 plist：把 __REPO__ 换成本仓库绝对路径，
#    把 __HOME__ 换成你的 home 目录（如 /Users/kennylong）。
cp brew/launchd/io.kennylong.brew-sync.plist ~/Library/LaunchAgents/

# 2. 加载
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/io.kennylong.brew-sync.plist
# 旧版 macOS：launchctl load ~/Library/LaunchAgents/io.kennylong.brew-sync.plist

# 查看 / 日志
launchctl print gui/$(id -u)/io.kennylong.brew-sync | grep -i state
tail -f ~/Library/Logs/brew-sync.log
```

卸载：

```sh
launchctl bootout gui/$(id -u)/io.kennylong.brew-sync
rm ~/Library/LaunchAgents/io.kennylong.brew-sync.plist
```

### Linux —— systemd user timer

```sh
# 1. 编辑 brew-sync.service：把 __REPO__ 换成本仓库绝对路径。
mkdir -p ~/.config/systemd/user
cp brew/systemd/brew-sync.service brew/systemd/brew-sync.timer ~/.config/systemd/user/

# 2. 启用
systemctl --user daemon-reload
systemctl --user enable --now brew-sync.timer

# 3. 无头 / 无活动登录会话？让 user 服务无需登录也能运行：
loginctl enable-linger "$USER"

# 查看 / 日志
systemctl --user list-timers brew-sync.timer
tail -f ~/.local/state/brew-sync.log
```

卸载：

```sh
systemctl --user disable --now brew-sync.timer
rm ~/.config/systemd/user/brew-sync.{service,timer}
systemctl --user daemon-reload
```

service 在运行前会执行 `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"`，因为 systemd 单元启动时环境很干净，否则找不到 `brew`。

## 文件说明

```
brew/
├── Brewfile          # 入口：共用 formula/tap + 按 OS 条件加载
├── Brewfile.macos    # cask / mas / macOS 专属 formula
├── Brewfile.linux    # Linux 专属 formula
├── sync.nu           # apply（拉取+安装）/ upgrade（+升级+清理）/ dump —— nushell

├── launchd/          # macOS LaunchAgent（用户域）
└── systemd/          # Linux user timer + service
```
