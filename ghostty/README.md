# Ghostty Config (Geek Style · macOS)

A [Ghostty](https://ghostty.org/) configuration tuned for heavy command-line users (especially the Claude Code CLI), aiming for **maximum aesthetics** and **efficiency**: auto light/dark theme switching, frosted-glass translucency, a global hotkey terminal, font ligatures, and Emacs Meta-key support.

[中文文档](README_zh.md)

## Features

| Goal | How |
|------|-----|
| Auto light/dark appearance | `theme = light:Catppuccin Latte,dark:Catppuccin Mocha`, follows the macOS system appearance |
| Default shell | `command = /opt/homebrew/bin/nu`, new windows/tabs launch nushell |
| Global toggle (iTerm2-like) | `Option + Space` toggles a Quake-style quick terminal that drops from the top and auto-hides on blur |
| Emacs-style line editing | `macos-option-as-alt = true`, both Options act as Meta (`M-b`/`M-f`/`M-d`, etc.); nushell's reedline uses emacs keybindings by default |
| Frosted-glass look | `background-opacity = 0.75` + `background-blur = macos-glass-regular` (native macOS Liquid Glass) + `background-opacity-cells` (full-screen TUIs stay translucent too) + transparent titlebar + window shadow |
| Font ligatures | Cascadia Code Nerd Font with `calt`/`liga` ligatures and Nerd Font glyphs |
| Focus the active window | Translucency + blur separate foreground/background naturally; `unfocused-split-opacity` highlights the active split |
| Command palette & power keys | `Cmd+Shift+P` command palette; `Cmd+Shift+J` dump screen+scrollback to your editor; `Cmd+Shift+Enter` zoom split; `Cmd+Shift+E` equalize splits; `Cmd+Shift+↑/↓` (or `Cmd+↑/↓`) jump between prompts; `Cmd+Shift+O` toggle frosted/opaque background |
| SSH that just works | `ssh-terminfo` + `ssh-env`: on ssh, installs the `xterm-ghostty` terminfo on the remote and forwards truecolor-related env vars; falls back to `xterm-256color` when the remote has no `tic` |
| Deep nushell integration | `nushell/config.nu` enables built-in `shell_integration` (OSC 2/7/8/133): titles, cwd inheritance, hyperlinks, prompt jumping |
| Rendering polish | `alpha-blending = linear-corrected` for crisper text over translucency; `minimum-contrast` readability guard; `window-padding-balance = equal` for equal padding on all sides |

## Requirements

- **Ghostty ≥ 1.4.0** (written against 1.4.0; `copy-on-select = none`, `window-padding-balance = equal` and the unified ssh integration are 1.4+ behaviors)
- **Nushell** (default shell; the config hardcodes the absolute path `/opt/homebrew/bin/nu`)
  ```sh
  brew install nushell
  which nu   # if not /opt/homebrew/bin/nu, update `command` in config accordingly
  ```
- **Cascadia Code Nerd Font** (ligatures + icons)
  ```sh
  brew install --cask font-cascadia-code-nf
  ```
  Without this font, Ghostty falls back to a default monospace font and ligatures/icons may be missing.

## Install (symlink to the default config path)

On macOS, Ghostty reads `~/.config/ghostty/config`. Symlink this repo's config there so future `git pull`s take effect automatically:

```sh
mkdir -p ~/.config/ghostty
ln -sf ~/src/toolkit/ghostty/config ~/.config/ghostty/config
```

> Replace `~/src/toolkit` with the actual path to this repo on your machine.

## First-run permission

The global hotkey (`Option + Space`) relies on `keybind = global:...`, which requires Accessibility permission; otherwise the hotkey won't work in other apps:

**System Settings → Privacy & Security → Accessibility → enable Ghostty**

## Common operations

- **Reload config**: after editing, press `Cmd + Shift + ,` inside Ghostty — no restart needed. **Exception**: on macOS, `background-opacity` only takes effect after fully quitting (`Cmd + Q`) and relaunching.
- **Open config**: `Cmd + ,`
- **Validate config**:
  ```sh
  /Applications/Ghostty.app/Contents/MacOS/ghostty +show-config
  ```
- **List themes / fonts**:
  ```sh
  /Applications/Ghostty.app/Contents/MacOS/ghostty +list-themes
  /Applications/Ghostty.app/Contents/MacOS/ghostty +list-fonts
  ```

## Notes & limitations

- **"Dim the whole window on focus loss"**: Ghostty 1.4 still has **no** native full-window dim-on-blur (`unfocused-split-opacity` only affects splits). This config instead uses **translucency + blur** so foreground/background windows separate naturally, approximating "focus the active window". For true full-window dimming, use a system-level tool such as Hammerspoon or HazeOver.
- **Toggle ligatures**: dislike ligatures? Change `font-feature = calt` / `font-feature = liga` in `config` to `-calt` / `-liga`.
- **Meta key not working?**: this config sets `macos-option-as-alt = true` so both Options act as Meta. If it still doesn't work, check in order:
  1. Confirm the config was **reloaded** (`Cmd + Shift + ,`) or restart Ghostty;
  2. Make sure no other config source overrides it (on macOS, besides `~/.config/ghostty/config`, a config under `~/Library/Application Support/com.mitchellh.ghostty/` is also loaded/merged — keep the symlink as the single source);
  3. Test `M-b`/`M-f` (word motion) and `M-d` (delete word) in nushell — these are reedline's default emacs bindings;
  4. If you prefer keeping the right Option for special characters (`é`/`—`), change `true` back to `left` and use the **left** Option for Meta.
- **Nushell shell integration (wired up)**: since 1.4, Ghostty's ssh/sudo wrappers behave identically across bash/zsh/fish/elvish/Nushell; prompt-related features come from nushell's built-in `shell_integration`, enabled in this repo's `nushell/config.nu`, emitting standard OSC sequences:
  - `osc2` updates window/tab title with the current dir/command;
  - `osc7` reports cwd so new tabs/splits/quick terminal inherit the current directory;
  - `osc8` emits clickable hyperlinks;
  - `osc133` marks prompt boundaries, unlocking Ghostty's prompt jumping — press `Cmd+Shift+↑/↓` or `Cmd+↑/↓` to jump between prompts (great for locating each run in long output).
  <br>(`osc633` is VSCode-only and `osc9_9` is ConEmu/Windows-only; Ghostty silently ignores them.)
- **SSH (`ssh-terminfo` / `ssh-env`)**: since 1.4 both go through `ghostty +ssh`. On ssh, Ghostty installs its **bundled** terminfo on the remote (reinstalled automatically after upgrades, cached per host+port, no local `infocmp` needed) and forwards `COLORTERM` / `TERM_PROGRAM` / `TERM_PROGRAM_VERSION`, without overriding `SetEnv` in `~/.ssh/config`. If the remote has no `tic`, it falls back to `TERM=xterm-256color`.
  - Verify: ssh into a fresh host and run `echo $TERM`; expect `xterm-ghostty` (or `xterm-256color` without `tic`).
  - Cache: `ghostty +ssh-cache` (list), `ghostty +ssh-cache user@host:22` (one host), `ghostty +ssh-cache --prune=30d` (prune stale entries).
  - If an ssh call isn't wrapped (e.g. from a script), run `ghostty +ssh -- user@host` to get the same behavior.
- **App icon**: `macos-icon = xray` is the geeky choice; swap it for `official`, `holographic`, `microchip`, `blueprint`, etc.
- **Theme linkage (Catppuccin, matches git delta)**: this repo's `git/config` configures the [delta](https://github.com/dandavison/delta) pager to auto-switch its Catppuccin theme with the terminal's light/dark mode (`detect-dark-light = auto` + two theme features `catppuccin-mocha` / `catppuccin-latte` marked with `dark=true`/`light=true`), mirroring the `theme = light:Catppuccin Latte, dark:Catppuccin Mocha` here: system goes light → both use Latte, dark → both use Mocha, so `git diff` / `git log` / `git blame` colors always stay in sync with the terminal.<br>**Change both together when you swap themes**: if you change `theme` here to a different palette, also update the two `[delta "..."]` blocks at the bottom of `git/config` (syntax-theme name + the hex values), otherwise diff colors will drift out of sync with the terminal.
