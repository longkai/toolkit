$env.config.cursor_shape.emacs = 'block'
# Kitty 键盘协议：只在「本地终端」开启，ssh 进来的会话一律关闭。
#
# 与 Ghostty 结合（Ghostty 1.0 起就支持该协议，1.4 修复了 macOS 上 Option+Backspace
# 在协议下只发裸 DEL、丢掉修饰键的问题）。开启后 reedline 能区分这些原本「撞码」的键：
#   Shift+Enter       → 插入换行写多行命令（默认键位，不开协议时它和 Enter 发同一个 \r）
#   Ctrl+Backspace    → 删除前一个词（默认键位，不开协议时等同普通 Backspace）
#   Ctrl+.            → 下面自定义的「插入上条命令最后一个参数」
#   Ctrl+I / Tab 等   → 可分别绑定
#
# 实测（nu 0.116）：nu 只在「显示提示符、等待输入」时 push（ESC[>1u），执行任何命令前先 pop
# （ESC[<1u），命令结束回到提示符再 push。所以 ssh、vim、claude 等外部程序看到的都是普通
# 键盘模式，不受影响。
#
# 为什么还要按 SSH 判断：该模式是**终端级状态**。只有当 nu 正停在提示符时被 SIGKILL、
# ssh 掉线，来不及 pop，终端才会被留在 disambiguate 模式；此时 Ctrl+U 不再发 0x15，
# 而发 ESC[117;5u。bash 的 readline 不认识这个序列，会响铃并把残余的 `7;5u` 当字面
# 文本插入 —— 即「Ctrl+U 不清行、反而吐出 7;5u」。远端 nu 最容易遇到这种情况
# （远端 shell 是 bash，~/.bashrc 里 exec nu 是注释掉的），所以远端一律不开。
#
# 卡住时的救急命令（无需重启终端）：printf '\e[<u'
$env.config.use_kitty_protocol = ($env.SSH_TTY? | is-empty)
# 模拟 bash 的 yank-last-arg：Ctrl+. 把上一条命令的最后一个 token 插入到当前行光标处。
# 简化版：只取「上一条历史命令」的最后一段，不支持连续按往前翻历史 / 选第 N 个参数。
# （不能用 `$ans.command`：快捷键触发的 executehostcommand 本身也会刷新 $ans，
#   连按第二次就会取到这条 commandline edit 命令自己。）
# 依赖 Kitty 键盘协议才能识别 Ctrl+符号（Ghostty/Kitty 支持）；
# ssh 会话中协议关闭，此键位静默失效，不影响其他键位。
# 0.115 起直接赋值即「合并进默认键位」（按 name 去重，重载配置不会重复），无需 ++=。
$env.config.keybindings = [
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
alias claude = tclaude

source ($nu.temp-dir | path join "alias.nu")

# 外部命令补全交给 carapace：nu 自己只会补文件路径/内置命令/变量，不认识 git、kubectl
# 等外部命令的子命令和参数（不设这个，`git chec<Tab>` 什么都没有）。
# `$place.command` 已自动展开 alias（g chec → git chec），在管道后、`;` 后、闭包和子表达式里
# 也能正确定位当前命令；补全在后台线程执行，不阻塞输入。
# 最后一行不能省：carapace 对某些位置返回空列表（实测 `git add /etc/ho<Tab>`），空列表会被当成
# 「没有候选」；返回 null 表示「不接管」，nu 才会回退到自带的文件路径补全。
$env.config.completions.external.completer = {|place|
    carapace $place.command.0 nushell ...$place.command
    | from json
    | if ($in | is-empty) { null } else { $in }
}

# 补全/历史菜单打开后继续输入或退格时，菜单保持打开并实时重新过滤，而不是直接关掉（0.116）。
$env.config.completions.persistent_menus = true

# `$ans`（0.115）：上一条命令的结果，免去重跑或复制粘贴。
#   $ans.last       上一条管道的输出（需下面的上限 > 0 才会保存，超出上限会截断并告警）
#   $ans.exit_code  退出码；$ans.duration 耗时；$ans.command 原始命令文本
# 例：`kubectl get po -o json | from json` 后，直接 `$ans.last | get items.metadata.name`
$env.config.max_last_result_size = 10mb

# starship 提示符由 env.nu 写入 vendor autoload 目录，启动时自动加载，这里无需 use。

use std/clip

# in ./scripts dir
use mod.nu *
