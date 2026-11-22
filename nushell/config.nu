$env.config.cursor_shape.emacs = 'block'

# PATH 外部命令高亮；每次按键有少量解析开销，觉得卡就删。
$env.config.highlight_resolved_externals = true
# 不启用 auto_cd_implicit：同名目录会遮蔽命令（文档明确 directory wins；实测 `git` 目录
# 会让 `git` 变成 cd，得用 `^git` 才执行外部命令）。要省 `cd` 可自行打开并承担这个代价。

# 模拟 bash 的 yank-last-arg：Alt+. 把上一条命令的最后一个词插入到当前行光标处。
# 注意：reedline 没有 bash 的 Esc 前缀超时，Esc 和 . 分开按不会触发，必须发 ESC+. 本身
# （即 Alt/Option+.）。
# 简化版：不解析引号（`echo "fix bug"` 会插入 `bug"`），也不支持连续按往前翻历史。
# （不能用 `$ans.command`：快捷键触发的 executehostcommand 本身也会刷新 $ans，
#   连按第二次就会取到这条 commandline edit 命令自己。）
# 先按 name 去掉旧绑定再追加：0.117 起 `=` 会整表替换，`++=` 重载时又会留下旧键位。
let insert_last_token = {
    name: "insert_last_token"
    modifier: "alt"
    keycode: "char_."
    event: {
        send: executehostcommand
        cmd: "commandline edit --insert (history | last | get command? | default '' | str trim | split row ' ' | last)"
    }
    mode: [ emacs, vi_normal, vi_insert, vi_visual, helix_normal, helix_select, helix_insert ]
}
$env.config.keybindings = (
    $env.config.keybindings
    | where {|kb| ($kb.name? | default '') != "insert_last_token" }
    | append $insert_last_token
)

# Ctrl+O 用 vim 编辑当前命令行，并把光标定位到原来的位置（0.117 支持 {line}/{col}/{file} 占位符，
# 位置从 1 开始）。不设时回退到 $env.VISUAL / $env.EDITOR，但总是停在第一行开头。
# 注意：{col} 是 grapheme 计数，vim 的 cursor() 按字节，两者对 CJK 等宽字符不一致，
# 列会偏左；纯 ASCII 不受影响。Vim 8.2.5000+ 可改用
# `+call setcursorcharpos({line}, {col})` 按字符定位。
$env.config.buffer_editor = [vim "+call cursor({line}, {col})" "{file}"]

alias k = kubectl
alias g = git
alias c = curl
alias l = ls
alias ll = ls -l
alias la = ls -a

source ($nu.data-dir | path join "alias.nu")

# 外部命令补全交给 carapace：nu 自己只会补文件路径/内置命令/变量，不认识 git、kubectl
# 等外部命令的子命令和参数（不设这个，`git chec<Tab>` 什么都没有）。
# `$place.command` 已自动展开 alias（g chec → git chec），在管道后、`;` 后、闭包和子表达式里
# 也能正确定位当前命令。
#
# 必须用 @interactive 让补全在输入线程内联执行：0.116 起外部补全默认扔到后台线程，结果回来前
# 菜单处于 provisional 状态，此时按 Enter 不会应用补全，而是直接执行原始半截命令行
# （`k exec -it -n ns po/foo-<Tab><Enter>` 会把没补完的 pod 名交给 kubectl）。nu 判断「内联」
# 的方式是看闭包最后一个管道元素是否为 @interactive 命令，所以闭包只能调用下面这个包装命令。
# 代价：补全期间阻塞输入，耗时等于一次 carapace 调用（kubectl 约几十到几百毫秒），
# 与 0.116 的同步补全一致。
# 另一个代价：非交互 nu（如 `nu -c '... | commandline complete'`）会报
# interactive_completer_needs_a_terminal；这是 @interactive 的限制。
# 包装里最后一行不能省：carapace 对某些位置返回空列表（实测 `git add /etc/ho<Tab>`）。
# @interactive 的补全返回 null 会被当成「空结果」，不会回退；必须返回
# {completions: [], fallback: true} 才能让 nu 回退到自带的文件路径补全。
@interactive
def carapace-complete [place: record] {
    try {
        carapace $place.command.0 nushell ...$place.command
        | from json
        | if ($in | is-empty) { {completions: [], fallback: true} } else { $in }
    } catch {
        {completions: [], fallback: true}
    }
}

$env.config.completions.external.completer = {|place| carapace-complete $place }

# 补全缓存保持默认（100 条）：kubectl 等外部补全走 @interactive，nu 对 interactive 结果
# 显式不写缓存，实时数据不会陈旧；普通文件补全若遇到陈旧（子目录增减文件），再设 0。

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
