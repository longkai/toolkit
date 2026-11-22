# Git Config

Shared Git configuration for this repo. `git/config` holds behavior and aliases
only; credentials and machine-specific paths stay in `~/.gitconfig`.

## Requirements

- Git 2.37+ (2.40+ for `feature.manyFiles`)
- [delta](https://github.com/dandavison/delta) (`brew install git-delta`)
- `git-lfs` if a repository uses LFS

## Install

```sh
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/git"
mkdir -p "$config_dir"
if [ -e "$config_dir/config" ] && [ ! -L "$config_dir/config" ]; then
  mv "$config_dir/config" "$config_dir/config.bak"
fi
ln -sfn <repo>/git/config "$config_dir/config"
touch ~/.gitconfig && chmod 600 ~/.gitconfig
```

The empty `~/.gitconfig` makes later `git config --global` and
`git maintenance start` writes land in the local file, not the tracked one.

Git reads `~/.config/git/config`, then `~/.gitconfig`; a value in the latter
wins. Inspect the merged view with:

```sh
git config --list --show-origin
```

## Secrets

Never put credentials in `git/config`. Keep machine-local settings in
`~/.gitconfig` (mode 600), and let a credential helper hold the secrets:

```gitconfig
[user]
  name = your-name
  email = you@example.com

[credential]
  helper = store
```

`credential.helper=store` reads `~/.git-credentials` (mode 600). Machine-specific
extras also belong in `~/.gitconfig`: `safe.directory`, credential-free
`url.*.insteadOf` rewrites, and `maintenance.repo` (written by
`git maintenance start`). Prefer a keychain helper (`osxkeychain`,
`libsecret`) when available; with HTTPS-only remotes, `store` is the simple
fallback. Never put a token in the tracked config, and rotate any token that
was stored in plaintext.

## Aliases

Exact definitions are in `git/config`. The non-obvious ones:

| Alias | Purpose |
|---|---|
| `sync` | Fetch/prune and rebase the current branch onto `origin/main` |
| `gone` | List local branches whose upstream was deleted; shows the worktree path when checked out |
| `stale [days]` | List local branches with no commits in N days (default 30) |
| `sw` / `rs` / `unstage` / `last` | switch / restore / unstage / last-commit summary |
| `a` `b` `c` `d` `s` `ch` / `l` | Short forms and compact graph log |

`sync` refreshes remote-tracking refs and rebases the current branch; it never
deletes local branches. `gone` and `stale` are read-only. `stale` excludes
`main`/`master`.

## What is set

`git/config` is the annotated source of truth. The non-obvious delta wiring:
it is the pager for `diff`, `log`, `reflog`, and `show` (not `core.pager`),
with line numbers, and it relies on delta's built-in auto light/dark detection
(GitHub on light, Monokai Extended on dark). Named theme features cannot be
auto-selected, so do not re-add Catppuccin mocha/latte auto-switching.

## Large repo and worktrees

```sh
git fetch origin main
git worktree add ../wt-<task> -b <task> origin/main

# after the PR is squash-merged and the remote branch is deleted
git fetch --prune
git gone
git worktree remove ../wt-<task>
git branch -D <task>
```

`-D` is required after a squash merge: the local commits are not ancestors of
main. Do not rebase a merged branch; start new work from `origin/main`.

Optional per-repo performance settings:

```sh
git config feature.manyFiles true
git config core.fsmonitor true   # Git >= 2.36
git config fetch.writeCommitGraph true
git maintenance start
```

`git maintenance start` persists on the machine and registers the repository
with the user-level scheduler: hourly prefetch and commit-graph, plus daily
repack. Skip it if you do not want background network and I/O.
