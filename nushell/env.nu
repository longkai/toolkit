# https://www.nushell.sh/book/configuration.html
if ([
    /usr/local/bin/brew
    /opt/homebrew/bin/brew
    /home/linuxbrew/.linuxbrew/bin/brew
] | any {|it| $it | path exists }) {
    # dev daily
    $env.HOMEBREW_PREFIX = match [$nu.os-info.name $nu.os-info.arch] {
        ["macos" "x86_64"] => (/usr/local/bin/brew --prefix),
        ["macos" "aarch64"] => (/opt/homebrew/bin/brew --prefix),
        _ => (/home/linuxbrew/.linuxbrew/bin/brew --prefix),
    }
    $env.HOMEBREW_CELLAR = $'($env.HOMEBREW_PREFIX)/Cellar'
    $env.HOMEBREW_REPOSITORY = $'($env.HOMEBREW_PREFIX)/Homebrew'
    $env.MANPATH = $env.MANPATH? | default '' | split row (char esep) | prepend [$'($env.HOMEBREW_PREFIX)/share/man']
    $env.INFOPATH = $env.INFOPATH? | default '' | split row (char esep) | prepend [$'($env.HOMEBREW_PREFIX)/share/info']

    $env.PATH = [
        $'($env.HOME)/mambaforge/bin'
        $'($env.HOMEBREW_PREFIX)/bin'
        $'($env.HOMEBREW_PREFIX)/sbin'
        $'($env.HOME)/.cargo/bin'
        $'($env.HOME)/go/bin'
    ] ++ $env.PATH
    $env.PATH = $env.PATH | uniq

    $"alias vi = vim
alias docker = nerdctl
alias du = dust
alias find = fd
alias grep = rg
alias cat = bat --theme='Solarized \(dark\)' # better with nushell's theme style?
" | save -f ($nu.temp-path | path join "alias.nu")
} else {
    # casual usage
    $env.PATH ++= [
        ($nu.current-exe | path dirname)
    ]
    $env.PATH = ($env.PATH | uniq)

    'alias grep = grep --color=auto' | save -f ($nu.temp-path | path join "alias.nu")
}

load-env {
    EDITOR: vim
    KUBE_EDITOR: vim # 'code --wait'
    KUBECTL_EXTERNAL_DIFF: 'diff -u -N --color=auto' # work with `kubectl diff`
    NU_LOG_LEVEL: DEBUG
}

# https://carapace-sh.github.io/carapace-bin/setup.html#nushell
$env.CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense' # optional
mkdir ~/.cache/carapace
carapace _carapace nushell | save --force ~/.cache/carapace/init.nu

# https://starship.rs/#nushell
mkdir ~/.cache/starship
starship init nu | save -f ~/.cache/starship/init.nu