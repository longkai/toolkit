import { expect, test } from 'claude-code/testing'

// Stands for the engine beneath the plugin: it records the effort it receives.
function engine(sent: unknown[]) {
  return async function* (_: unknown, e: any) {
    sent.push(e.effort)
    return { turnId: e.turnId, index: e.index, answer: '', toolUses: [], stopReason: null, usage: null }
  }
}

test('rules set the request effort', async ($, on) => {
  const sent: unknown[] = []
  on('turn.step', engine(sent))

  const cases = [
    { model: 'claude-deepseek-v4.1-flash[1m]', effort: 'xhigh' },
    { model: 'claude-deepseek-v4-pro[1m]', effort: 'low', agentId: 'a1' },
    { model: 'claude-opus-5-5[1m]', effort: 'xhigh' },
    { model: 'claude-deepseek-v4.1-flash[1m]' },
  ]
  for (const c of cases) {
    const stream = $.turn.step({ turnId: 't1', index: 0, messageCount: 1, ...c } as any)
    for await (const _ of stream) {
      // Drain the stream so the result settles.
    }
    await stream.result
  }

  expect(sent).toEqual(['max', 'max', 'xhigh', undefined])
})
