// Hostile client bodies (security review, 17 Oct 2026). The rules only check the envelope; the
// body is any string up to 200,000 characters. A single crafted submission must never crash the
// owner's reconcile run, pollute Object.prototype, break canonical document paths, or let one uid
// file a second report for a duel under another document id.
//   cd firebase && node --test tools/test/hostile.test.js
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { reconcileAll } = require('../lib/reconcile');
const { computeMetrics } = require('../lib/metrics');
const fx = require('../fixtures/basic');

const G1 = JSON.parse(fx.submissions[0].data.body);

function withHostG1(mutate, id = 'game_G1') {
  const b = JSON.parse(JSON.stringify(G1));
  mutate(b);
  const evil = fx.sub('uA', id, 'game', 'production', 'lan', b);
  return fx.submissions.filter((s) => s.id !== 'game_G1').concat([evil]);
}

function run(subs) {
  const all = reconcileAll(subs);
  const m = computeMetrics(all.byEnv.production, fx.catalog);
  return { all, m };
}

test('a "__proto__" card key in counters is rejected and never reaches Object.prototype', () => {
  const subs = withHostG1((b) => { b.counters[0] = JSON.parse('{"__proto__": {"plays": 5, "activations": 1}}'); });
  const { all } = run(subs);
  assert.equal(all.rejected.schema_game, 1);
  assert.equal(({}).plays, undefined);
  assert.equal(Object.prototype.games_played_in, undefined);
});

test('"__proto__" / "constructor" keys in decks and play kinds are rejected without a crash', () => {
  for (const mutate of [
    (b) => { b.decks[0].main = JSON.parse('{"__proto__": 3}'); },
    (b) => { b.decks[1].extra = { constructor: 1 }; },
    (b) => { b.counters[0]['2'].plays_by_kind = JSON.parse('{"__proto__": 1}'); },
  ]) {
    const { all, m } = run(withHostG1(mutate));
    assert.equal(all.rejected.schema_game, 1);
    assert.ok(m.cards['2']);
  }
});

test('wrong types deep inside a body are rejected instead of throwing', () => {
  const muts = [
    (b) => { b.counters = 'x'; },
    (b) => { b.counters[0]['2'].plays = '9'; },
    (b) => { b.decks = [1, 2]; },
    (b) => { b.decks[0].extra = undefined; },
    (b) => { b.opportunities = [['o1', 7, 2]]; },
    (b) => { b.opportunities = [null]; },
    (b) => { b.participants = [1, 2]; },
  ];
  for (const mutate of muts) {
    const { all } = run(withHostG1(mutate));
    assert.equal(all.rejected.schema_game, 1, String(mutate));
  }
  const draft = JSON.parse(fx.submissions.find((s) => s.id === 'draft_D1').data.body);
  draft.draft.picks[0].offered = 'abc';
  const badDraft = fx.sub('uA', 'draft_D9', 'draft', 'production', 'lan', draft);
  const reward = JSON.parse(fx.submissions.find((s) => s.id === 'reward_R1').data.body);
  reward.reward.actions[0].offered = null;
  const badReward = fx.sub('uA', 'reward_R9', 'reward', 'production', 'lan', reward);
  const { all } = run(fx.submissions.concat([badDraft, badReward]));
  assert.equal(all.rejected.schema_draft, 1);
  assert.equal(all.rejected.schema_reward, 1);
});

test('a game id that is not a plain identifier is rejected (it becomes a canonical document id)', () => {
  for (const gid of ['a/b', '..', '', 'x'.repeat(121), 7]) {
    const subs = withHostG1((b) => { b.game.game_id = gid; }, `game_${gid}`);
    const { all } = run(subs);
    assert.ok(all.rejected.schema_game === 1, `game_id ${gid}`);
  }
});

test('one uid cannot file a second authority report for a duel under another document id', () => {
  const dup = fx.sub('uA', 'game_other', 'game', 'production', 'lan', G1);
  const { all } = run(fx.submissions.concat([dup]));
  assert.equal(all.rejected.doc_id, 1);
  assert.equal(all.byEnv.production.games.G1.status, 'verified');
});

test('an exception while normalising one record rejects only that record', () => {
  const weird = { uid: 'uZ', id: 'game_z', data: { schema_version: 1, kind: 'game', env: 'production', uid: 'uZ', body: '{"game":{"game_id":"z"}}' } };
  Object.defineProperty(weird.data, 'mode', { get() { throw new Error('boom'); }, enumerable: true });
  const { all } = run(fx.submissions.concat([weird]));
  assert.equal(all.rejected.invalid, 1);
  assert.equal(all.byEnv.production.games.G1.status, 'verified');
});
