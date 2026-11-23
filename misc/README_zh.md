# macOS 键盘改键（Dell KB216）

用 Nushell 脚本把 macOS 上 Dell KB216 的**右 Ctrl** 改成其他修饰键。不需要第三方软件，不需要 Python，也不需要 bash。

[English](README.md)

## 为什么是右 Ctrl？

这套方案保留物理键盘本身的键位，以及 macOS **系统修饰键**的映射：

- Caps Lock <-> Control
- Option <-> Command

菜单/Fn 键无法变成 Alt。它在硬件/固件层就发送 **Option+Shift**，去掉 Shift 会同时破坏物理 Shift 键。右 Ctrl 是空闲键；Caps Lock 和右 Shift 仍然可用。

## 命令

| 命令 | 右 Ctrl 变成 | 说明 |
|---|---|---|
| `option` | 左 Option（Alt） | 当作 Alt/Meta 使用 |
| `control` | 右 Control | 恢复硬件本身 |
| `capslock` | Caps Lock | 跟随系统的 Caps Lock <-> Control 设置 |
| `show` | （不修改） | 返回当前映射 |

## 用法

```sh
nu misc/kb-switch.nu show
nu misc/kb-switch.nu option
nu misc/kb-switch.nu control
```

改完后**拔插键盘**生效，不需要重启，也不需要注销。

### 结构化输出

`nu misc/kb-switch.nu show` 是独立进程，stdout 只能是文本。要拿到可管道处理的 Nushell 表格，请把脚本作为模块导入：

```nu
use misc/kb-switch.nu
kb-switch show | where page == "keyboard" | select from to

# 或直接导入命令
use misc/kb-switch.nu *
show | get from
```

列：`page`（`keyboard` 或 `vendor`）、`from`、`to`、`src`、`dst`。

## 修改了什么

脚本编辑每个键盘独立的映射文件：

```
~/Library/Preferences/ByHost/.GlobalPreferences.<IOPlatformUUID>.plist
```

键名：`com.apple.keyboard.modifiermapping.16700-8467-0`（Dell VID `0x413c`，PID `0x2113`）。

写入时：

1. 用 `plutil -convert xml1` 转成 XML。
2. 保留 keyboard page 条目，并更新右 Ctrl 条目。
3. 丢弃 vendor page 条目（之前排查菜单/Fn 键留下的实验）。
4. 用 `plutil -convert binary1` 转回 binary；XML 无效时这一步会失败。
5. 把原文件备份为 `<file>.bak`，并让 `cfprefsd` 重新加载。

plist 里的其他键会原样保留。

## 恢复

```sh
nu misc/kb-switch.nu control
```

把右 Ctrl 映射回它自己。只想撤销最后一次写入时，恢复 `<file>.bak`；想重置整个键盘的映射，打开 **系统设置 > 键盘 > 键盘快捷键... > 修饰键**，选择 Dell KB216，点 **恢复默认**。

## 依赖

- macOS
- Nushell 0.117 或更高版本（`from xml --allow-dtd`）
- 系统自带 `plutil`；仅当 ByHost 下存在多个文件时才用到 `/usr/sbin/ioreg`
