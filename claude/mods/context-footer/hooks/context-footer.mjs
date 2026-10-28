// Adds the context-window percentage to the footer's SessionMode line.

let reading = null;
let totals = { input: 0, create: 0, read: 0 };
let sessionKey = null;

export function register(on) {
  on("session.start", async ($, e, next) => {
    const result = await next(e);
    reading = null;
    await loadTotals($);
    await takeReading($);
    return result;
  });

  on("session.end", async ($, e, next) => {
    const result = await next(e);
    if (e.reason === "clear") {
      totals = { input: 0, create: 0, read: 0 };
      reading = null;
      await clearTotals($);
    }
    return result;
  });

  on("turn.start", async ($, e, next) => {
    const result = await next(e);
    if (!e.agentId) {
      await takeReading($);
    }
    return result;
  });

  on("classic.PostModelSwitch", async ($, e, next) => {
    const result = await next(e);
    await takeReading($);
    return result;
  }).catch(($, e, next) => next(e));

  on("turn.complete", async ($, e, next) => {
    const result = await next(e);
    if (!e.agentId) {
      const usage = result.usage ?? e.usage;
      if (usage) {
        totals.input += usage.input_tokens ?? 0;
        totals.create += usage.cache_creation_input_tokens ?? 0;
        totals.read += usage.cache_read_input_tokens ?? 0;
      }
      await saveTotals($);
      await takeReading($);
    }
    return result;
  });

  on("ui.render", { component: "SessionMode" }, ($, e, next) => {
    if (!reading) {
      return next(e);
    }
    const { Box, Text } = $.ui.resolve(e);
    const modes = Array.isArray(e.props.modes) ? e.props.modes : [];
    const children = [];

    if (modes.length > 0) {
      modes.forEach((mode, index) => {
        if (index > 0) children.push(Text({ color: "subtle", children: " & " }));
        const color = modeColor(mode);
        children.push(color
          ? Text({ color, children: String(mode) })
          : Text({ color: "subtle", children: String(mode) }));
      });
      children.push(Text({ color: "subtle", children: "  ·  " }));
    }

    if (reading.model) {
      children.push(Text({ color: "autoAccept", bold: true, children: `🤖 ${reading.model}` }));
      children.push(Text({ color: "subtle", children: "  ·  " }));
    }

    const ctxColor = reading.percent >= 75 ? "error" : reading.percent >= 50 ? "warning" : reading.percent >= 25 ? "suggestion" : "success";
    children.push(Text({ children: `${weatherIcon(reading.percent)} ` }));
    children.push(Text({ color: ctxColor, children: `${reading.percent}%` }));

    if (reading.tokens !== undefined) {
      children.push(Text({ color: "subtle", children: `  🎟️ ${short(reading.tokens)}/${short(reading.window)}` }));
    }
    if (reading.cache !== undefined) {
      const cacheColor = reading.cache >= 80 ? "suggestion" : reading.cache >= 50 ? "warning" : "error";
      children.push(Text({ color: "subtle", children: "  ·  " }));
      children.push(Text({ color: cacheColor, children: `🎯 ${reading.cache}%` }));
    }

    return Box({ flexDirection: "row", children });
  });
}

async function takeReading($) {
  try {
    const { context } = await $.session.usage();
    if (!context || !context.window) {
      return;
    }
    let model = reading?.model ?? "";
    try {
      const m = await $.session.model();
      model = typeof m === "string" ? m : (m?.id ?? m?.display_name ?? model);
    } catch {
      // Keep the previous model name when the session cannot report it.
    }
    reading = {
      model: shortModel(model),
      tokens: typeof context.tokens === "number" ? context.tokens : undefined,
      window: context.window,
      percent: Math.round(context.percent ?? ((context.tokens ?? 0) / context.window) * 100),
      cache: cachePercent(),
    };
    $.ui.invalidate("ui.render");
  } catch {
    // Keep the last reading when usage is unavailable.
  }
}

async function loadTotals($) {
  try {
    sessionKey = `cache:${await $.session.id()}`;
    const saved = await $.store.get(sessionKey);
    if (saved && typeof saved === "object") {
      totals = {
        input: Number(saved.input) || 0,
        create: Number(saved.create) || 0,
        read: Number(saved.read) || 0,
      };
      return;
    }
    totals = { input: 0, create: 0, read: 0 };
    if (await seedTotals($)) {
      await saveTotals($);
    }
  } catch {
    totals = { input: 0, create: 0, read: 0 };
  }
}

async function seedTotals($) {
  try {
    const home = await $.env.get("HOME");
    const configDir = (await $.env.get("CLAUDE_CONFIG_DIR")) ?? (home ? `${home}/.claude` : "");
    const id = await $.session.id();
    const root = await $.session.root();
    if (!configDir || !id || !root) {
      return false;
    }
    const dir = root.replace(/[^a-zA-Z0-9]/g, "-");
    const file = String(id).endsWith(".jsonl") ? String(id) : `${id}.jsonl`;
    const path = `${configDir}/projects/${dir}/${file}`;
    const { stdout, exitCode } = await $.process.run(
      ["tail", "-c", "4194304", path],
      { timeoutMs: 30000 },
    );
    if (exitCode !== 0 || !stdout) {
      return false;
    }
    const lines = stdout.split("\n");
    lines.shift();
    let input = 0;
    let create = 0;
    let read = 0;
    for (const line of lines) {
      if (!line) continue;
      let entry;
      try {
        entry = JSON.parse(line);
      } catch {
        continue;
      }
      if (entry.type !== "assistant" || entry.isSidechain) continue;
      const usage = entry.message?.usage;
      if (!usage) continue;
      input += usage.input_tokens ?? 0;
      create += usage.cache_creation_input_tokens ?? 0;
      read += usage.cache_read_input_tokens ?? 0;
    }
    if (input + create + read === 0) {
      return false;
    }
    totals = { input, create, read };
    return true;
  } catch {
    return false;
  }
}

async function saveTotals($) {
  try {
    sessionKey = `cache:${await $.session.id()}`;
    await $.store.set(sessionKey, totals);
  } catch {
    // Cache stats are best-effort.
  }
}

async function clearTotals($) {
  totals = { input: 0, create: 0, read: 0 };
  try {
    if (sessionKey) await $.store.set(sessionKey, totals);
  } catch {
    // Best-effort.
  }
}

function weatherIcon(percent) {
  if (percent < 25) return "☀️";
  if (percent < 50) return "☁️";
  if (percent < 75) return "☂️";
  if (percent < 90) return "⛈️";
  return "🚨";
}

function modeColor(mode) {
  const text = String(mode);
  if (/auto/i.test(text)) return "warning";
  if (/accept/i.test(text)) return "autoAccept";
  if (/plan/i.test(text)) return "planMode";
  return undefined;
}

function cachePercent() {
  const total = totals.input + totals.create + totals.read;
  return total > 0 ? Math.round((totals.read / total) * 100) : undefined;
}

function shortModel(model) {
  return String(model ?? "").replace(/^claude-/, "").replace(/\[1m\]$/, "");
}

function short(n) {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(n % 1_000_000 === 0 ? 0 : 1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(n % 1_000 === 0 ? 0 : 1)}k`;
  return String(n);
}
