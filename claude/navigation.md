# Claude Code Navigation

## Current conversation

In the fullscreen renderer:

- `PgUp` / `PgDn`: scroll half a screen.
- `Ctrl+Home` / `Ctrl+End`: jump to the start / return to the latest and resume following.
- Mouse wheel / trackpad: scroll line by line.
- The top hint shows the last prompt that scrolled out of view; click it to jump back.

`Ctrl+O` opens the transcript viewer:

| Key | Action |
|---|---|
| `/` | Search; `n` / `N` next / previous match |
| `{` / `}` | Previous / next user prompt |
| `g` / `G` | Top / bottom |
| `Ctrl+u` / `Ctrl+d` | Half page |
| `q` / `Esc` / `Ctrl+O` | Close the viewer |
| `?` | Keys for the current view |

With an empty input, `?` opens the shortcut panel. `Ctrl+R` searches your prompt history,
not Claude's replies; `Up` / `Down` also recall previous prompts.

## Rewind or resume

- `Esc` `Esc` with an empty input, or `/rewind` (alias `/undo`): choose a checkpoint.
  `Restore conversation` puts the original prompt back in the input; it does not rerun it.
- `claude --resume` (picker), `claude -c` (most recent session in this directory), or
  `/resume` in a session: return to an earlier session.

## Fullscreen renderer and terminal scrollback

The fullscreen renderer uses the alternate screen, so the terminal emulator's scrollback
does not contain the conversation. In the transcript viewer:

- `[` writes the transcript into the terminal's native scrollback, after which the
  terminal's find and copy mode work on it.
- `v` writes it to a temporary file and opens it in `$EDITOR`.

`/tui default` switches to the classic renderer, whose conversation goes directly into
the terminal scrollback. `CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1` selects it at startup.

The transcript viewer's `{` / `}` / `g` / `G` keys are its own vi-style bindings. They do
not require Claude Code's vim mode; vim mode only affects editing the prompt.

Fullscreen rendering is still a research preview, so keys may change. See the official
[interactive mode](https://code.claude.com/docs/en/interactive-mode) and
[fullscreen](https://code.claude.com/docs/en/fullscreen) docs.
