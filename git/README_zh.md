# Git 配置

本仓库维护的共享 Git 配置。`git/config` 只放行为设置和 alias；密码、token、
机器相关路径全部留在 `~/.gitconfig`。

## 依赖

- Git 2.37+（`feature.manyFiles` 需要 2.40+）
- [delta](https://github.com/dandavison/delta)（`brew install git-delta`）
- `git-lfs`（仓库使用 LFS 时需要）

## 安装

```sh
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/git"
mkdir -p "$config_dir"
if [ -e "$config_dir/config" ] && [ ! -L "$config_dir/config" ]; then
  mv "$config_dir/config" "$config_dir/config.bak"
fi
ln -sfn <repo>/git/config "$config_dir/config"
touch ~/.gitconfig && chmod 600 ~/.gitconfig
```

空的 `~/.gitconfig` 会让后续 `git config --global` 和 `git maintenance start`
写到本机文件，而不是被软链的仓库文件。

Git 先读 `~/.config/git/config`，再读 `~/.gitconfig`；后者优先。查看合并后的配置：

```sh
git config --list --show-origin
```

## 密码与机器相关配置

绝不要把凭据写进 `git/config`。本机设置放在 `~/.gitconfig`（权限 600），凭据
交给 credential helper：

```gitconfig
[user]
  name = your-name
  email = you@example.com

[credential]
  helper = store
```

`credential.helper=store` 读取 `~/.git-credentials`（权限 600）。机器相关的
`safe.directory`、无凭据的 `url.*.insteadOf` 转换、以及 `maintenance.repo`
（由 `git maintenance start` 写入）也都放在 `~/.gitconfig`。有桌面钥匙串时优先用
`osxkeychain` / `libsecret`；只能 HTTPS 时 `store` 是最简单的兜底。不要把 token
写进入库的配置；曾经明文保存过的 token 建议轮换。

## Alias

完整定义见 `git/config`。非显而易见的几个：

| Alias | 作用 |
|---|---|
| `sync` | fetch/prune 并 rebase 当前分支到 `origin/main` |
| `gone` | 列出上游已删的本地分支；被 worktree 签出时显示路径 |
| `stale [days]` | 列出 N 天没有提交的本地分支（默认 30） |
| `sw` / `rs` / `unstage` / `last` | switch / restore / 取消暂存 / 最后一次提交摘要 |
| `a` `b` `c` `d` `s` `ch` / `l` | 简写与紧凑图形 log |

`sync` 只刷新 remote-tracking ref 并 rebase 当前分支，不删本地分支；
`gone`、`stale` 都是只读命令。`stale` 排除 `main`/`master`。

## 包含哪些设置

`git/config` 是带注释的唯一来源。delta 的非默认接线是：它作为 `diff`、`log`、
`reflog`、`show` 的分页器（不是 `core.pager`），带行号，并依赖 delta 内置的
明暗自动探测（亮色 GitHub、深色 Monokai Extended）。delta 不支持自动挑选命名
主题，所以不要再加 Catppuccin mocha/latte 自动切换。

## 大仓与 worktree

```sh
git fetch origin main
git worktree add ../wt-<task> -b <task> origin/main

# PR squash 合并、远程分支被删之后
git fetch --prune
git gone
git worktree remove ../wt-<task>
git branch -D <task>
```

squash 合并后必须用 `-D`：本地提交不是 main 的祖先。不要对已合并分支继续
rebase，直接从 `origin/main` 开新分支。

可选的仓库级性能设置：

```sh
git config feature.manyFiles true
git config core.fsmonitor true   # Git >= 2.36
git config fetch.writeCommitGraph true
git maintenance start
```

`git maintenance start` 会持久化到本机并注册用户级定时器：每小时 prefetch 和
commit-graph，每天增量 repack。不想要后台网络和 I/O 就跳过。
