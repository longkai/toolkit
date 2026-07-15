#!/usr/bin/env nu
#
# brew/sync.nu — cross-platform Homebrew sync helper (Brewfile + Git).
#
# Run it directly:
#   nu brew/sync.nu apply
#   nu brew/sync.nu upgrade
#   nu brew/sync.nu dump
#
# Or import as a module and call the `sync` command:
#   use brew/sync.nu
#   sync apply
#   sync upgrade
#   sync dump
#
# Subcommands:
#   apply   Pull the repo (fast-forward only) and install everything the
#           current platform's Brewfile declares. Idempotent and safe to run
#           on a schedule (launchd / systemd timer). Never removes anything.
#
#   upgrade Everything `apply` does, then `brew update` + `brew upgrade` to
#           bump already-installed formulae/casks to their latest versions,
#           finishing with `brew cleanup` to prune old versions + caches.
#           Never uninstalls in-use packages (this is NOT `bundle --cleanup`).
#
#   dump    Export currently-installed packages into files next to the
#           Brewfile so you can curate them:
#             - casks + mas       -> Brewfile.macos       (macOS only)
#             - formulae + taps   -> Brewfile.<os>.draft  (for manual review)
#           Nothing is committed automatically.
#
# Notes:
#   * Homebrew refuses to run as root; do NOT run this with sudo.
#   * External commands (git/brew) get real argument lists, never string-eval.

use std/log

# Directory this script lives in (resolved at parse time, symlink-safe).
const SCRIPT_DIR = (path self | path dirname)

# Fail fast unless brew is available and we are not root.
def check-brew [] {
    if (which brew | is-empty) {
        error make {msg: 'brew not found in PATH. On Linux add: eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'}
    }
    if (is-admin) {
        error make {msg: 'refusing to run as root; Homebrew must run as a normal user.'}
    }
}

# Default entry: print usage.
export def main [] {
    print 'Usage: nu brew/sync.nu <command>   (or: use brew/sync.nu ; sync <command>)

Commands:
  apply    git pull --ff-only + brew bundle install (safe, idempotent)
  upgrade  apply + brew update + upgrade + cleanup (bump + prune; used by timers)
  dump     export installed packages into curated / draft Brewfiles for review'
}

# Shared: git pull --ff-only + brew bundle install for the current platform.
def pull-and-install [] {
    let brewfile = [$SCRIPT_DIR Brewfile] | path join
    if not ($brewfile | path exists) {
        error make {msg: $'missing Brewfile at ($brewfile)'}
    }
    let repo = $SCRIPT_DIR | path dirname

    log info $'git pull --ff-only in ($repo)'
    git -C $repo pull --ff-only

    log info $'brew bundle install --file=($brewfile)'
    # No --cleanup: never uninstall packages automatically.
    brew bundle install --file $brewfile
}

# git pull --ff-only + brew bundle install for the current platform.
export def "main apply" [] {
    check-brew
    pull-and-install
    log info 'done.'
}

# apply, then refresh Homebrew and upgrade already-installed packages.
export def "main upgrade" [] {
    check-brew
    pull-and-install

    log info 'brew update'
    brew update

    log info 'brew upgrade'
    # Upgrades outdated formulae + casks.
    brew upgrade

    log info 'brew cleanup'
    # Prunes OLD versions + stale download cache to reclaim disk.
    # This is `brew cleanup`, NOT `brew bundle --cleanup`: it never
    # uninstalls a package you currently have installed.
    brew cleanup
    log info 'done.'
}

# Export installed packages into curated / draft Brewfiles for review.
export def "main dump" [] {
    check-brew
    let os = $nu.os-info.name

    if $os == 'macos' {
        let macfile = [$SCRIPT_DIR Brewfile.macos] | path join
        log info $'dumping casks + mas into ($macfile | path basename), overwrite'
        # Casks/mas are macOS-only, so they belong in Brewfile.macos directly.
        brew bundle dump --file $macfile --casks --mas --force
    }

    let draft = [$SCRIPT_DIR $'Brewfile.($os).draft'] | path join
    log info $'dumping formulae + taps draft into ($draft | path basename) for manual review'
    # Formulae/taps can't be auto-classified as shared vs platform-specific,
    # so they go to a DRAFT file for you to sort out.
    brew bundle dump --file $draft --formulae --taps --force

    let shared = [$SCRIPT_DIR Brewfile] | path join
    let platform = [$SCRIPT_DIR $'Brewfile.($os)'] | path join
    print $"
==> Draft written. Next steps \(manual, on purpose\):
    1. Review ($draft)
    2. Move CROSS-PLATFORM formulae/taps into: ($shared)
    3. Move platform-only ones into:           ($platform)
    4. Delete the draft, then: git add brew/ && git commit"
}
