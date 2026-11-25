# Vim 配置

极简、无插件的 Vim 配置，面向偶尔在终端修改配置文件 / 做命令行编辑。
基于 Vim 9.0+；在 macOS（系统 Vim 9.1）和 Linux（Vim 9.0）上使用。

[English](README.md)

## 安装

软链到 `~/.vimrc`：

```sh
ln -sfn <repo>/vim/vimrc ~/.vimrc
```

如果不想在 `$HOME` 留隐藏文件，可以用 Vim 9.0+ 支持的 `~/.vim/vimrc`。
`~/.vimrc` 优先，需要先把旧的移走：

```sh
mkdir -p ~/.vim
[ -e ~/.vimrc ] && mv ~/.vimrc ~/.vimrc.bak
ln -sfn <repo>/vim/vimrc ~/.vim/vimrc
```

在 Vim 里验证：`:set mouse?` 应显示 `mouse=`，`:echo &history` 应显示
`200`。

## 设计

- `source $VIMRUNTIME/defaults.vim`：继承 Vim 官方默认项（backspace、ruler、
  showcmd、wildmenu、incsearch、syntax、filetype、history、光标恢复等），
  只覆盖有意不同的部分。
- `unlet! skip_defaults_vim`：macOS 的系统 vimrc 会设置该变量，不清掉的话
  `defaults.vim` 会直接退出。
- `set mouse=`：Vim 9.1 的 `defaults.vim` 会在 xterm 类终端默认开启鼠标；
  显式关闭，保持 macOS 与 Linux 行为一致。
- 2 空格软 Tab、绝对/相对行号、`scrolloff=3`、`ignorecase` + `smartcase`、
  `hlsearch`，以及 `<Esc><Esc>` 清除搜索高亮。
- 无插件、无第三方依赖。剪贴板、鼠标、cursorline 作为注释选项放在文件末尾，
  按需取消注释。

## 备注

- `set encoding=utf-8` 保留作为 `LANG=C` 等非 UTF-8 环境的兜底。
- `defaults.vim` 会把 `Q` 映射为 `gq`（格式化，不再进入 Ex 模式）；不习惯
  可以加 `nnoremap Q <nop>`。
