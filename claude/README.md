# Claude Code Footer Mod (context-footer)

Shows the current model, context usage, and cache hit rate in the Claude Code prompt footer:

```text
auto mode on · 🤖 deepseek · ☂️ 61% · 🎟️ 483.5k/786.4k · 🎯 98%
```

- The weather emoji tracks context usage: <25% ☀️, 25–49% ☁️, 50–74% ☂️, 75–89% ⛈️, ≥90% 🚨.
- `🎟️` shows used and maximum tokens.
- `🎯` shows the main-conversation cache hit rate (`cache_read / all input`).
- Colors use Claude Code theme keys (`success`, `warning`, `error`, `suggestion`) and follow the active theme.

## Requirements

- Claude Code ≥ 2.1.287 (mods).
- The terminal or Desktop surface; the tclaude wrapper works too.

## Install

From the repository root:

```bash
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
ln -sfn "$PWD/claude/mods" "$CONFIG_DIR/mods"
claude plugin marketplace add "$CONFIG_DIR/mods"
claude plugin install context-footer@kennylong-mods --scope user
```

tclaude users can replace `claude` with `tclaude`; arguments are forwarded upstream.

To try it without installing:

```bash
claude --plugin-dir "$PWD/claude/mods/context-footer"
```

Restart Claude Code or run `/reload-plugins` in a session after installing.

## Load directly from the repo (development)

For mod development, load the repository directory directly so saved edits apply without reinstalling:

```bash
export CLAUDE_CODE_PLUGIN_DIRS="$PWD/claude/mods/context-footer"
```

Or set it in `$CONFIG_DIR/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_PLUGIN_DIRS": "/absolute/path/to/toolkit/claude/mods/context-footer"
  }
}
```

This is an absolute path; update it if the repository moves. Separate multiple directories with `:`. The environment change requires restarting Claude Code. Plugins loaded through `--plugin-dir` reload their hooks module when you save; if that does not happen, run `/reload-plugins`.

## Data sources

- `$.session.usage()`: context tokens, window, and percentage.
- The `usage` field of `turn.complete`: cache read, cache creation, and input tokens.
- `$.session.model()`: the current model name.
- Cache totals persist per session in `$.store`; the first load seeds them from the transcript (last 4 MiB).
- No network requests; the transcript is read-only.

## Customize

Edit `hooks/context-footer.mjs`:

- `weatherIcon(percent)`: weather thresholds and emoji.
- `ctxColor` / `cacheColor`: color thresholds.
- `children.push(...)` in `ui.render`: emoji, order, separators, and fields.
- `shortModel` / `short`: model and token formatting.

Run `/reload-plugins` after editing. Note that an installed plugin runs from `$CONFIG_DIR/plugins/cache`; this repository is the source. Re-run `claude plugin install` after changes, or load the source directory with `--plugin-dir`.
