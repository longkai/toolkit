# Vim Config

A minimal, plugin-free Vim configuration for occasional config-file editing and
command-line work. Based on Vim 9.0+; used on macOS (system Vim 9.1) and Linux
(Vim 9.0).

[中文文档](README_zh.md)

## Install

Link the config to `~/.vimrc`:

```sh
ln -sfn <repo>/vim/vimrc ~/.vimrc
```

To avoid a hidden file in `$HOME`, use Vim's `~/.vim/vimrc` lookup instead.
`~/.vimrc` takes precedence, so move it away first:

```sh
mkdir -p ~/.vim
[ -e ~/.vimrc ] && mv ~/.vimrc ~/.vimrc.bak
ln -sfn <repo>/vim/vimrc ~/.vim/vimrc
```

Verify in Vim: `:set mouse?` should show `mouse=`, and `:echo &history` should
show `200`.

## Design

- Sources `$VIMRUNTIME/defaults.vim` for Vim's official defaults (backspace,
  ruler, showcmd, wildmenu, incsearch, syntax, filetype, history, cursor
  restore, ...), then overrides only deliberate differences.
- `unlet! skip_defaults_vim` is required on macOS: the system vimrc sets this
  variable, which otherwise makes `defaults.vim` exit immediately.
- `set mouse=` disables the mouse because Vim 9.1's `defaults.vim` enables it
  for xterm-like terminals; this keeps macOS and Linux behavior consistent.
- Two-space soft tabs, absolute and relative line numbers, `scrolloff=3`,
  `ignorecase` + `smartcase`, `hlsearch`, and `<Esc><Esc>` to clear search
  highlighting.
- No plugins or third-party dependencies. Clipboard, mouse, and cursorline are
  available as commented options at the end.

## Notes

- `set encoding=utf-8` is kept as a guard for non-UTF-8 locales such as
  `LANG=C`.
- `defaults.vim` maps `Q` to `gq` (format instead of Ex mode). Add
  `nnoremap Q <nop>` if that is not wanted.
