# Homebrew Cross-Platform Sync

Keep the same set of Homebrew packages in sync between **macOS** and **Linux** using a split `Brewfile` + Git, with an optional daily timer that only *pulls and installs*.

[中文文档](README_zh.md)

## Why split files?

Homebrew on Linux (Linuxbrew) **does not support `cask` or `mas`** — those are macOS-only (GUI apps / Mac App Store). Command-line `formula`e are largely shared across both platforms. So the files are split by responsibility:

| File | Contents | Loaded on |
|------|----------|-----------|
| `Brewfile` | Shared formulae/taps + conditional include of the platform file | macOS & Linux (entry point) |
| `Brewfile.macos` | `cask`, `mas`, macOS-only formulae | macOS |
| `Brewfile.linux` | Linux-only formulae | Linux |

The entry `Brewfile` is evaluated as Ruby and uses `OS.mac?` / `OS.linux?` to `instance_eval` only the matching sub-file, so **the same install command works on both platforms** and Linux silently ignores casks.

## Install / apply

```sh
brew bundle install --file=brew/Brewfile
```

Or via the helper (also does a `git pull --ff-only` first):

```sh
nu brew/sync.nu apply
# or, as a module: use brew/sync.nu ; sync apply
```

To also **upgrade** already-installed packages (apply + `brew update` + `brew upgrade` + `brew cleanup`):

```sh
nu brew/sync.nu upgrade
```

`brew cleanup` here only prunes **old versions and stale download caches** — it is *not* `brew bundle --cleanup` and never uninstalls a package you currently use.

`brew bundle install` is **idempotent**: it installs only what's missing and skips what's already there, so it's safe to run repeatedly.

> **Danger — `--cleanup`:** `brew bundle install --cleanup` will **uninstall** anything not listed in the Brewfile. It is intentionally **not** used here. Only add it manually if you truly want the Brewfile to be the single source of truth.

## Daily sync loop (adding a new package)

When you install something new on one machine:

```sh
brew install ripgrep                 # 1. install as usual

# 2. record it in the right file:
#    - cross-platform CLI tool  -> brew/Brewfile
#    - macOS-only cask/mas       -> brew/Brewfile.macos
#    - Linux-only formula        -> brew/Brewfile.linux
echo 'brew "ripgrep"' >> brew/Brewfile        # quick manual way
# ...or run `nu brew/sync.nu dump` and curate the draft (see below)

git add brew/ && git commit -m "add ripgrep" && git push   # 3. publish
```

On the other machine:

```sh
git pull
brew bundle install --file=brew/Brewfile      # installs the new package
```

### `sync.nu dump` — export current packages for curation

```sh
nu brew/sync.nu dump
```

- On macOS it overwrites `Brewfile.macos` with your current **casks + mas** apps (safe — those are macOS-only).
- It writes **formulae + taps** to a `Brewfile.<os>.draft` file. Homebrew can't tell whether a formula is cross-platform, so **you** decide: move shared ones into `Brewfile`, keep platform-only ones in `Brewfile.<os>`, then delete the draft and commit.

## Automatic sync (semi-automatic, optional)

The timers run `sync.nu upgrade` — `git pull --ff-only` + `brew bundle install` + `brew update` + `brew upgrade` + `brew cleanup` — so scheduled runs install newly-declared packages, bump installed ones to their latest versions, and prune old versions/caches. It still **never uninstalls** an in-use package (`brew cleanup` ≠ `brew bundle --cleanup`). Export/commit stays manual on purpose (auto-dumping would break the split structure and cause git conflicts between machines).

> If you'd rather the timer only install (no auto-upgrade), change the timer's argument from `upgrade` back to `apply` (launchd `ProgramArguments` / systemd `ExecStart`).

> **Never as root:** Homebrew refuses to run as root. Use the **user-level** launchd agent / systemd *user* timer below — never a system-wide/root scheduler, and never `sudo`.

### macOS — launchd (not cron)

On modern macOS `cron` is deprecated and often fails silently due to Full Disk Access (TCC) restrictions. Use a **LaunchAgent** in your user domain instead.

```sh
# 1. Edit the plist: replace __REPO__ with this repo's absolute path,
#    and __HOME__ with your home dir (e.g. /Users/kennylong).
cp brew/launchd/io.kennylong.brew-sync.plist ~/Library/LaunchAgents/

# 2. Load it
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/io.kennylong.brew-sync.plist
# older macOS: launchctl load ~/Library/LaunchAgents/io.kennylong.brew-sync.plist

# Check / logs
launchctl print gui/$(id -u)/io.kennylong.brew-sync | grep -i state
tail -f ~/Library/Logs/brew-sync.log
```

Uninstall:

```sh
launchctl bootout gui/$(id -u)/io.kennylong.brew-sync
rm ~/Library/LaunchAgents/io.kennylong.brew-sync.plist
```

### Linux — systemd user timer

```sh
# 1. Edit brew-sync.service: replace __REPO__ with this repo's absolute path.
mkdir -p ~/.config/systemd/user
cp brew/systemd/brew-sync.service brew/systemd/brew-sync.timer ~/.config/systemd/user/

# 2. Enable
systemctl --user daemon-reload
systemctl --user enable --now brew-sync.timer

# 3. Headless / no active login session? Let user services run without login:
loginctl enable-linger "$USER"

# Check / logs
systemctl --user list-timers brew-sync.timer
tail -f ~/.local/state/brew-sync.log
```

Uninstall:

```sh
systemctl --user disable --now brew-sync.timer
rm ~/.config/systemd/user/brew-sync.{service,timer}
systemctl --user daemon-reload
```

The service does `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"` before running, because a systemd unit starts with a minimal environment and wouldn't otherwise find `brew`.

## Files

```
brew/
├── Brewfile          # entry: shared formulae/taps + OS-conditional include
├── Brewfile.macos    # casks / mas / macOS-only formulae
├── Brewfile.linux    # Linux-only formulae
├── sync.nu           # apply (pull+install) / upgrade (+ upgrade+cleanup) / dump — nushell

├── launchd/          # macOS LaunchAgent (user domain)
└── systemd/          # Linux user timer + service
```
