// Forces a per-model effort level on each model request.
//
// Settings cannot persist "max": effortLevel stops at "xhigh". The override is
// applied to the request in turn.step.

// The first rule whose pattern matches the request model wins.
const RULES = [
  { model: /deepseek/i, effort: "max" },
];

export function register(on) {
  // Subagent steps are included: a rule applies to every request of its model.
  on("turn.step", async function* ($, e, next) {
    const effort = effortFor(e);
    return yield* next(effort === e.effort ? e : { ...e, effort });
  });
}

function effortFor(e) {
  // A model without effort support carries no effort; leave it without one.
  if (e.effort === undefined) return undefined;
  return RULES.find((rule) => rule.model.test(e.model))?.effort ?? e.effort;
}
