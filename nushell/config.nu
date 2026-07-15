$env.config.cursor_shape.emacs = 'block'
# 模拟 bash 的 yank-last-arg：Ctrl+. 把上一条命令的最后一个 token 插入到当前行光标处。
# 简化版：只取「上一条历史命令」的最后一段，不支持连续按往前翻历史 / 选第 N 个参数。
# 依赖 Kitty 键盘协议才能识别 Ctrl+符号（Ghostty/Kitty 支持）。
$env.config.keybindings ++= [
    {
        name: "insert_last_token"
        modifier: "control"
        keycode: "char_."
        event: {
            send: executehostcommand
            cmd: "commandline edit --insert (history | last | get command | str trim | split row ' ' | last)"
        }
        mode: [ emacs, vi_normal, vi_insert ]
    }
]

alias k = kubectl
alias g = git
alias c = curl
alias l = ls
alias ll = ls -l
alias la = ls -a
alias less = less -IR

source ($nu.temp-dir | path join "alias.nu")

# https://carapace-sh.github.io/carapace-bin/setup.html#nushell
source ~/.cache/carapace/init.nu

# https://starship.rs/#nushell
use ~/.cache/starship/init.nu

use std/clip

# in ./scripts dir
use mod.nu *