# Rex Config

[Rex](https://www.superlogical.com/rex/) configuration for this repo. `init.lua` is the
single source of truth; link it to Rex's default config path.

[中文文档](README_zh.md)

## Install

```sh
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/rex"
mkdir -p "$config_dir"
ln -sfn <repo>/rex/init.lua "$config_dir/init.lua"
```

Check and reload after editing:

```sh
REX_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/rex/init.lua" rex config check
rex config reload
```

If the running app keeps the old keymap, run **Reload Config** from the command palette
(`Cmd+Shift+P`) or restart Rex.

## Configuration

`init.lua` only adds bindings that are not Rex defaults:

```lua
rex.bind("ctrl+cmd+=", "pane.balance")
```

- `Ctrl+Cmd+=`: equalize split sizes. `pane.balance` has no Rex default; this matches
  Ghostty's upstream default. This repo's `ghostty/config` also binds `equalize_splits` to
  `Cmd+Shift+E`; Ghostty keybindings are additive, so both work.
- `Cmd+K` stays Rex's session picker (not bound to clear).
- Prompt jumping uses Rex defaults: `Cmd+Up` / `Cmd+Down`. `Shift+Cmd+Up/Down` remains
  split up/down.

## Keyboard cheat sheet

### Panes

| Shortcut | Action |
|---|---|
| `Cmd+D` | Split right |
| `Shift+Cmd+Up` | Split up |
| `Shift+Cmd+D`, `Shift+Cmd+Down` | Split down |
| `Shift+Cmd+Left/Right` | Split left/right |
| `Cmd+Enter` | Split best fit |
| `Shift+Cmd+Enter` | Zoom pane |
| `Alt+Cmd+Enter` | Float pane |
| `Alt+Cmd+M` | Minimize floating pane |
| `Alt+Shift+Cmd+Enter` | Minimize all floating panes |
| `Alt+Shift+Cmd+Arrows` | Move pane |
| `Cmd+W` | Close pane, then tab, then window |
| `Ctrl+Cmd+=` | Balance splits (this repo) |

### Tabs, sessions, windows

| Shortcut | Action |
|---|---|
| `Cmd+T` | New tab |
| `Alt+Cmd+W` | Close tab |
| `Cmd+1` … `Cmd+9` | Go to tab N |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Next / previous tab |
| `Shift+Cmd+]` / `Shift+Cmd+[` | Next / previous tab |
| `Cmd+'` | Toggle to the recent tab |
| `Cmd+N` | New window |
| `Shift+Cmd+W` | Close window |
| `Ctrl+Cmd+F` | Toggle full screen |
| `Shift+Cmd+N` | New session |
| `Cmd+K` | Session picker |
| `Cmd+R` | Refresh sessions |
| `Alt+Shift+Cmd+N` | New session on a chosen host |

### Scrollback, find, copy

| Shortcut | Action |
|---|---|
| `Cmd+Up` / `Cmd+Down` | Previous / next shell prompt |
| `Shift+Cmd+C` | Enter copy mode |
| `/` | Search in copy mode |
| `y` | Yank selection and leave copy mode |
| `Esc` / `q` | Leave copy mode |
| `Cmd+F` | Open find |
| `Cmd+G` / `Shift+Cmd+G` | Next / previous match (find bar only) |
| `Cmd+Y` | Quick Look |

### App

| Shortcut | Action |
|---|---|
| `Shift+Cmd+P` | Command palette |
| `Cmd+P` | Go to Anything |
| `Shift+Cmd+G` | Go to Directory |
| `Cmd+,` | Settings |
| `Cmd+/` | Toggle sidebar |
| `Cmd+.` | Toggle activity |
| `Cmd+=` / `Cmd+-` / `Cmd+0` | Font bigger / smaller / reset |

Global show/hide is an app-level shortcut: `Cmd+Shift+P` → **Change Shortcut…** →
**Toggle Visibility**. It is not configured in `init.lua`, because `rex.bind` only runs
while Rex is focused.

### Hosts

`Switch Host` (`client.host.switch`) has **no default shortcut**. Bind one if you switch
between local and remote hosts often:

```lua
rex.bind("ctrl+cmd+h", "client.host.switch")
```

`Alt+Shift+Cmd+N` creates a session on a chosen host. `Cmd+K` switches sessions, not
hosts.

### Optional custom bindings (not enabled)

```lua
rex.bind("ctrl+cmd+r", "client.config.reload")
rex.bind("cmd+a", "pane.select_all")
```

## Settings backup (macOS)

`init.lua` travels with this repo. GUI settings do not: Rex stores them in a binary
plist at `~/Library/Preferences/com.superlogical.rex.plist` (domain
`com.superlogical.rex`).

Back up on the old Mac (outside the repo):

```sh
defaults export com.superlogical.rex ~/rex-settings.plist
```

Restore on a new Mac after quitting Rex:

```sh
defaults import com.superlogical.rex ~/rex-settings.plist
# relaunch Rex; if old values persist, run:
killall cfprefsd
```

Inspect the settings as text:

```sh
defaults read com.superlogical.rex
plutil -p ~/Library/Preferences/com.superlogical.rex.plist
```

Do **not** commit the full plist to a public repository. It can contain Tailscale, SSH
agent, remote-host, or account data. Keep it private, or extract only the appearance
keys with `defaults write`. If you do not want to move the plist, reapply the values
from the table below.

## Ghostty look in Rex Settings

Rex does not read the Ghostty config. Appearance lives in Settings:

| Ghostty | Rex Settings |
|---|---|
| `theme` | Themes > Light Mode / Dark Mode; Interface > Appearance > Color scheme |
| `font-family`, `font-size` | Terminal > Typography |
| fallback fonts, ligatures, smoothing | Terminal > Advanced Font Settings |
| `adjust-cell-height` | Terminal > Typography > Line height |
| `window-padding-x/y` | Interface > Padding |
| `background-opacity`, `background-blur` | Interface > Appearance > Use glass for panes |
| `window-colorspace = display-p3` | Terminal > Colors > Use Display P3 color space |
| `minimum-contrast` | Terminal > Colors > Improve text contrast |
| `macos-option-as-alt` | Terminal > Keyboard > Option key |
| `cursor-style`, `cursor-style-blink` | Terminal > Cursor |
| `copy-on-select` | Terminal > Selection > Copy on selection |
| `command` | Terminal > Shell > Startup command |
| `notify-on-command-finish` | Notifications > Program Activity (needs OSC 7501) |
| `unfocused-split-opacity` | Interface > Active Pane > Fade inactive panes |
| `equalize_splits` | `Ctrl+Cmd+=` in `init.lua` |

Not available in Rex:

- numeric background opacity, `background-opacity-cells`, `alpha-blending`
- `macos-titlebar-style`, `macos-window-shadow`, `resize-overlay-position`
- `window-padding-balance`, `middle-click-action`, `clipboard-trim-trailing-spaces`
- `mouse-hide-while-typing`, `confirm-close-surface`
- `window-save-state`, `window-inherit-working-directory`, `window-inherit-font-size`

Notifications use the OSC 7501 program status protocol. Enable
**Settings > Integrations > Coding Agents** for Claude Code integration.
