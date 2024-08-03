$env.config = {
    cursor_shape: {
        emacs: block
    }
    keybindings: [
        {
            name: insert_last_token
            modifier: alt
            keycode: char_.
            mode: [emacs, vi_normal, vi_insert]
            event: [
                { edit: InsertString, value: ' !$'}
                { send: Enter }
            ]
        }
    ]
}

def command-exists [cmd: string] {
    which $cmd | is-not-empty
}

alias k = kubectl
alias g = git
alias c = curl
alias l = ls
alias ll = ls -l
alias la = ls -a

source /tmp/alias.nu

# https://carapace-sh.github.io/carapace-bin/setup.html#nushell
source ~/.cache/carapace/init.nu

# https://starship.rs/#nushell
use ~/.cache/starship/init.nu

use mod.nu *
