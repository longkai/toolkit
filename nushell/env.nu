# https://www.nushell.sh/book/configuration.html
# path add：前置（或 --append 追加）并自动去重，取代手写的 `++ $env.PATH | uniq`
use std/util "path add"

# Homebrew: Apple Silicon uses /opt/homebrew, Linux uses /home/linuxbrew.
let brew = [/opt/homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew] | where {|it| $it | path exists } | first

if ($brew | is-not-empty) {
    # dev daily
    $env.HOMEBREW_PREFIX = (^$brew --prefix)
    $env.HOMEBREW_CELLAR = $'($env.HOMEBREW_PREFIX)/Cellar'
    $env.HOMEBREW_REPOSITORY = $'($env.HOMEBREW_PREFIX)/Homebrew'

    path add [
        $'($env.HOME)/mambaforge/bin'
        $'($env.HOMEBREW_PREFIX)/bin'
        $'($env.HOMEBREW_PREFIX)/sbin'
        $'($env.HOME)/.cargo/bin'
        $'($env.HOME)/go/bin'
    ]

    # Only alias tools that exist; `du`/`docker` must keep working otherwise.
    let aliases = [
        (if (which vim | is-not-empty) { 'alias vi = vim' })
        (if (which nerdctl | is-not-empty) { 'alias docker = nerdctl' })
        (if (which dust | is-not-empty) { 'alias du = dust' })
        (if (which rg | is-not-empty) { 'alias grep = rg' })
        (if (which bat | is-not-empty) { "alias cat = bat --theme='Solarized (dark)'" })
        (if (which tclaude | is-not-empty) { 'alias claude = tclaude' })
    ] | compact
    $aliases | str join (char nl) | save -f ($nu.data-dir | path join "alias.nu")
} else {
    # casual usage
    path add --append ($nu.current-exe | path dirname)

    'alias grep = grep --color=auto' | save -f ($nu.data-dir | path join "alias.nu")
}

load-env {
    EDITOR: vim
    KUBE_EDITOR: vim # 'code --wait'
    KUBECTL_EXTERNAL_DIFF: 'diff -u -N --color=auto' # work with `kubectl diff`
    NU_LOG_LEVEL: DEBUG # verbose; s3 presign also logs its signing key
}

# carapace：补全器直接写在 config.nu（0.116 的 `{|place|}` 新 API），不再生成并 source
# `carapace _carapace nushell` 的旧版 init（它只会注册已弃用的 `{|spans|}` 补全器）。
# 这里只保留 carapace 自身读取的桥接配置。
$env.CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense'

# starship：写入 vendor autoload 目录，nu 在 config.nu 之后自动加载，无需在 config.nu 里 use。
# （save --force 会自动创建缺失的父目录）
starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")
