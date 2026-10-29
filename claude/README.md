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
claude plugin install model-effort@kennylong-mods --scope user
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

Run `/reload-plugins` after editing. A plugin installed from a directory marketplace loads in place from this repository, so edits apply at the next session start or `/reload-plugins`.

Under tclaude, prefer the marketplace install: tclaude sets `CLAUDE_CODE_PLUGIN_DIRS` for its own built-in mod, and a value in `settings.json` replaces it.

# Effort Mod (model-effort)

Sends `max` for every `deepseek` model, subagent requests included. Other models use the level `/effort` picked for them, or Claude Code's own default (for example `medium` for Opus 5.5, `high` for Opus 5).

Settings cannot hold `max`: `effortLevel` and `modelSettings.<model>.effortLevel` accept `xhigh` at most, so the mod sets it on the request instead.

Edit `RULES` in `hooks/model-effort.mjs` to change the models or the level. The first matching rule wins. Run the tests with `claude plugin test claude/mods/model-effort`.

The footer shows the level of each model's last main request, kept across sessions. A model's first session shows it after its first request.
