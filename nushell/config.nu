$env.config.cursor_shape.emacs = 'block'
$env.config.keybindings ++= [
    {
        name: "insert_last_token"
        modifier: "alt"
        keycode: "char_."
        event: [
            {
                edit: "InsertString"
                value: "!$"
            },
            {
                "send": "Enter"
            }
        ]
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

# in ./scripts dir
use mod.nu *