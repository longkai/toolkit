# macOS Keyboard Remap (Dell KB216)

Remap the Dell KB216 **right Ctrl** key on macOS with a Nushell script. No
third-party software, no Python, no bash.

[中文文档](README_zh.md)

## Why right Ctrl?

This setup keeps the physical keyboard and the macOS **System Modifier Keys**
mapping unchanged:

- Caps Lock <-> Control
- Option <-> Command

The Menu/Fn key cannot become Alt. It sends **Option+Shift** at the
hardware/firmware level, so removing Shift would also break the physical Shift
key. Right Ctrl is the free key; Caps Lock and right Shift stay usable.

## Commands

| Command | Right Ctrl becomes | Notes |
|---|---|---|
| `option` | Left Option (Alt) | Use as an Alt/Meta key |
| `control` | Right Control | Hardware identity; use to restore |
| `capslock` | Caps Lock | Follows the Caps Lock <-> Control System setting |
| `show` | (no change) | Returns the current mapping |

## Usage

```sh
nu misc/kb-switch.nu show
nu misc/kb-switch.nu option
nu misc/kb-switch.nu control
```

Apply the change by **unplugging and replugging the keyboard**. No reboot and
no logout are needed.

### Structured output

`nu misc/kb-switch.nu show` runs in a separate process, so its stdout is text.
To get a Nushell table that you can pipe, import the script:

```nu
use misc/kb-switch.nu
kb-switch show | where page == "keyboard" | select from to

# Or import the commands directly.
use misc/kb-switch.nu *
show | get from
```

Columns: `page` (`keyboard` or `vendor`), `from`, `to`, `src`, `dst`.

## What it changes

The script edits the per-keyboard mapping in:

```
~/Library/Preferences/ByHost/.GlobalPreferences.<IOPlatformUUID>.plist
```

Key: `com.apple.keyboard.modifiermapping.16700-8467-0` (Dell VID `0x413c`,
PID `0x2113`).

On write it:

1. Converts the plist to XML with `plutil -convert xml1`.
2. Keeps the keyboard-page entries and updates the Right Ctrl entry.
3. Drops vendor-page entries (the Menu/Fn experiments).
4. Converts it back to binary with `plutil -convert binary1`; this fails on
   invalid XML.
5. Copies the previous file to `<file>.bak` and reloads `cfprefsd`.

Other keys in the plist are preserved.

## Restore

```sh
nu misc/kb-switch.nu control
```

This maps Right Ctrl back to itself. To undo only the last write, restore
`<file>.bak`. To reset all per-keyboard mappings, open **System Settings >
Keyboard > Keyboard Shortcuts... > Modifier Keys**, select the Dell KB216, and
choose **Restore Defaults**.

## Requirements

- macOS
- Nushell 0.117 or later (`from xml --allow-dtd`)
- System `plutil`; `/usr/sbin/ioreg` only when several ByHost files exist
