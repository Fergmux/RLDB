// Reconciliation and metric regressions on the deterministic fixture (no emulator needed):
//   cd firebase && node --test tools/test/*.test.js
// Expected numerators/denominators are derived by hand in the comments.
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { reconcileAll } = require('../lib/reconcile');
const { computeMetrics } = require('../lib/metrics');
const fx = require('../fixtures/basic');

const r = (num, den) => ({ num, den, rate: den > 0 ? num / den : null });

function prod(subs = fx.submissions) { return reconcileAll(subs).byEnv.production; }

test('classification: verified, conflicted, provisional, abandoned, local', () => {
  const env = prod();
  assert.equal(env.games.G1.status, 'verified');
  assert.equal(env.games.G2.status, 'conflicted');
  assert.match(env.games.G2.notes[0], /winner/);
  assert.equal(env.games.G3.status, 'provisional');
  assert.equal(env.games.G4.status, 'abandoned');
  assert.equal(env.games.G5.status, 'local');
  assert.deepEqual(env.games.G1.players, ['u:uA', 'u:uB']);
  assert.deepEqual(env.games.G3.players, ['u:uC', null]);
});

test('environments are separated and invalid submissions rejected', () => {
  const all = reconcileAll(fx.submissions);
  assert.ok(all.byEnv.test.games.G6);
  assert.equal(all.byEnv.production.games.G6, undefined);
  assert.equal(all.rejected.uid_mismatch, 1);
  assert.equal(all.rejected.body_json, 1);
  assert.equal(all.rejected.probe, 1);
});

test('rebuild is idempotent (same hashes)', () => {
  const a = prod();
  const b = prod([...fx.submissions].reverse());
  for (const gid of Object.keys(a.games)) assert.equal(a.games[gid].hash, b.games[gid].hash);
});

test('player W/L: eligible decisive network duels only (G1, G3)', () => {
  const m = computeMetrics(prod(), fx.catalog);
  assert.equal(m.eligible_games, 2);
  assert.deepEqual(m.players['u:uA'].win_rate, r(1, 1));   // G1 win; G2 conflicted, G4 abandoned, G5 bot excluded
  assert.deepEqual(m.players['u:uB'].win_rate, r(0, 1));   // G1 loss
  assert.deepEqual(m.players['u:uC'].win_rate, r(0, 1));   // G3 loss
  assert.equal(m.unattributed_seats, 1);                   // G3 remote seat without a client report
  assert.deepEqual(m.duel.first_player_win_rate, r(1, 2)); // G1 first player 0 won; G3 first player 0 lost
});

test('per-player filter restricts W/L and card observations', () => {
  const m = computeMetrics(prod(), fx.catalog, { player: 'u:uA' });
  assert.equal(m.eligible_games, 1);
  assert.deepEqual(m.players['u:uA'].win_rate, r(1, 1));
  assert.deepEqual(m.cards['2'].win_with, r(1, 1));
});

test('draft pick rate is offer-normalised, counting a card once per offer', () => {
  const m = computeMetrics(prod(), fx.catalog);
  // D1 picks: [2,3,4]->2, [2,2,3]->3, [4,1]->4. D2 is env dev (excluded).
  assert.deepEqual(m.cards['2'].pick_rate, r(1, 2));
  assert.equal(m.cards['2'].offered_copies, 3);
  assert.deepEqual(m.cards['3'].pick_rate, r(1, 2));
  assert.deepEqual(m.cards['4'].pick_rate, r(1, 2));
  assert.deepEqual(m.cards['1'].pick_rate, r(0, 1));
  assert.deepEqual(m.cards['5'].pick_rate, r(0, 0));       // never offered: undefined (null)
  assert.equal(m.cards['5'].pick_rate.rate, null);
  assert.equal(m.cards['4'].avg_pick_position, 3);
  assert.deepEqual(m.cards['3'].reward_pick_rate, r(1, 1)); // reward offers [2,3] -> 3
  assert.deepEqual(m.cards['2'].reward_pick_rate, r(0, 1));
});

test('starting-deck inclusion over player-game snapshots, main and extra apart', () => {
  const m = computeMetrics(prod(), fx.catalog);
  assert.equal(m.player_game_observations, 4);              // G1 x2, G3 x2
  assert.deepEqual(m.cards['1'].main.inclusion_rate, r(4, 4));
  assert.equal(m.cards['1'].main.copies, 12);
  assert.deepEqual(m.cards['2'].main.inclusion_rate, r(2, 4));
  assert.equal(m.cards['2'].main.copies, 3);
  assert.equal(m.cards['2'].main.avg_copies_when_included, 1.5);
  assert.deepEqual(m.cards['4'].extra.inclusion_rate, r(1, 4));
  assert.deepEqual(m.cards['4'].main.inclusion_rate, r(0, 4));
  assert.deepEqual(m.cards['5'].main.inclusion_rate, r(0, 4)); // zero-use catalog card listed
});

test('plays, activations and draw conversion by opportunity', () => {
  const m = computeMetrics(prod(), fx.catalog);
  const c2 = m.cards['2'];
  assert.equal(c2.plays, 3);                                 // G1: 1 normal + 1 special, G3: 1 normal
  assert.deepEqual(c2.plays_by_kind, { normal_summon: 2, special_effect: 1 });
  assert.equal(c2.games_played_in, 2);
  assert.equal(c2.activations, 3);
  // Draw opportunities: G1 o1 played, G1 o2 exited, G3 o1 played; G3 o2 is a retrieval (not a draw).
  assert.deepEqual(c2.draw_conversion, r(2, 3));
  assert.deepEqual(c2.raw_hand_plays_per_draw, r(3, 3));
  assert.deepEqual(c2.drawn_never_played_rate, r(1, 3));
  assert.deepEqual(m.cards['3'].draw_conversion, r(0, 1));
});

test('card win rate and win rate by exact copy count including n = 0', () => {
  const m = computeMetrics(prod(), fx.catalog);
  // Decisive player-games: G1s0 win {1:3,2:2,4:1}, G1s1 loss {1:3,3:1}, G3s0 loss {1:3,2:1}, G3s1 win {1:3}.
  assert.deepEqual(m.cards['2'].win_with, r(1, 2));
  assert.deepEqual(m.cards['2'].by_copies['2'], r(1, 1));
  assert.deepEqual(m.cards['2'].by_copies['1'], r(0, 1));
  assert.deepEqual(m.cards['2'].by_copies['0'], r(1, 2));
  assert.deepEqual(m.cards['1'].by_copies['3'], r(2, 4));
  assert.deepEqual(m.cards['3'].by_copies['1'], r(0, 1));
  assert.deepEqual(m.cards['3'].by_copies['0'], r(2, 3));
  assert.deepEqual(m.cards['5'].by_copies['0'], r(2, 4));
  assert.deepEqual(m.cards['5'].win_with, r(0, 0));
});

test('a later agreeing report upgrades provisional to verified without a second result', () => {
  const before = computeMetrics(prod(), fx.catalog);
  const env = prod([...fx.submissions, fx.lateAgreeG3]);
  assert.equal(env.games.G3.status, 'verified');
  const after = computeMetrics(env, fx.catalog);
  assert.equal(after.eligible_games, before.eligible_games);
  assert.deepEqual(after.cards['2'].win_with, before.cards['2'].win_with);
  assert.deepEqual(after.players['u:uD'].win_rate, r(1, 1));  // remote seat now attributed
  assert.equal(after.unattributed_seats, 0);
});

test('a later conflicting report removes the provisional contribution on rebuild', () => {
  const env = prod([...fx.submissions, fx.lateConflictG3]);
  assert.equal(env.games.G3.status, 'conflicted');
  const m = computeMetrics(env, fx.catalog);
  assert.equal(m.eligible_games, 1);
  assert.equal(m.players['u:uC'], undefined);
  assert.deepEqual(m.cards['2'].win_with, r(1, 1));
});

test('bot and hot-seat duels are included only when asked for', () => {
  const m = computeMetrics(prod(), fx.catalog, { modes: ['bot'], statuses: ['local'] });
  assert.equal(m.eligible_games, 1);
  assert.deepEqual(m.players['u:uA'].win_rate, r(1, 1));
  assert.equal(m.players.bot, undefined);
});

test('client report from the host uid never corroborates', () => {
  const self = fx.sub('uC', 'gclient_G3', 'gclient', 'production', 'lan', JSON.parse(fx.lateAgreeG3.data.body));
  const env = prod([...fx.submissions, self]);
  assert.equal(env.games.G3.status, 'provisional');
  assert.equal(env.health.self_corroboration, 1);
});
