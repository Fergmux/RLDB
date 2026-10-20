// Game-length and turn-time metrics (schema v2, owner feedback C2) and v1/v2 compatibility.
//   cd firebase && node --test tools/test/timing.test.js
// Expected values are derived by hand in the comments.
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { reconcileAll, deckKey } = require('../lib/reconcile');
const { computeMetrics, summary, histogram } = require('../lib/metrics');
const fx = require('../fixtures/basic');

const human = (seat) => ({ seat, kind: 'human', link: seat === 0 ? 'profile' : 'remote', participant_id: seat === 0 ? 'pp_h' : null });
const botP = { seat: 1, kind: 'bot', link: 'bot', participant_id: 'bot' };
const flagsNet = { tutorial: false, bot: false, local: false, network: true };
const flagsBot = { tutorial: false, bot: true, local: true, network: false };

function v2Game(gid, { mode = 'lan', activeMs, turnTimes, first = 0, decks, parts }) {
  const turnMs = [0, 0];
  for (const [, seat, ms] of turnTimes) turnMs[seat] += ms;
  return { kind: 'game', ids: { game_id: gid, series_id: 's2' }, flags: mode === 'bot' ? flagsBot : flagsNet,
    reporter: { role: 'host', covers_seats: [0, 1] },
    game: { game_id: gid, series_id: 's2', duel_index: 1, outcome: 'completed', decisive: true, winner: 0,
      turns: turnTimes.length, final_hp: [5, 0], first_player: first, reason: 'lethal', active_ms: activeMs,
      ended_at: 1760000200000, turn_times: turnTimes, turn_ms: turnMs, turn_times_truncated: 0, clock: 'host_wall' },
    participants: parts || [human(0), human(1)], decks, counters: [{}, {}], opportunities: [], events: [], completeness: { events: true } };
}

const deckP = (name) => ({ main: { 1: 3 }, extra: {}, source: 'prebuilt', base_source: 'prebuilt', name });
const deckC = { main: { 2: 3 }, extra: {}, source: 'custom', base_source: 'custom', name: '' };

function v2sub(uid, gid, mode, body) {
  const s = fx.sub(uid, `game_${gid}`, 'game', 'production', mode, body);
  s.data.schema_version = 2;
  return s;
}

// T1 (lan, provisional): turns 1 s0 40 s, 2 s1 20 s, 3 s0 60 s; 2 min game; seat 0 Moving Ocean, seat 1 custom.
// T2 (lan): turns 1 s1 10 s, 2 s0 30 s; first player seat 1; 1 min game; both Moving Ocean.
// T3 (bot): turns 1 s0 50 s, 2 bot 2 s; 6 min game.
const T1 = v2Game('T1', { activeMs: 120000, turnTimes: [[1, 0, 40000], [2, 1, 20000], [3, 0, 60000]], decks: [deckP('Moving Ocean'), deckC] });
const T2 = v2Game('T2', { activeMs: 60000, first: 1, turnTimes: [[1, 1, 10000], [2, 0, 30000]], decks: [deckP('Moving Ocean'), deckP('Moving Ocean')] });
const T3 = v2Game('T3', { mode: 'bot', activeMs: 360000, turnTimes: [[1, 0, 50000], [2, 1, 2000]], decks: [deckC, deckC], parts: [human(0), botP] });
const subs = [...fx.submissions, v2sub('uA', 'T1', 'lan', T1), v2sub('uA', 'T2', 'lan', T2), v2sub('uA', 'T3', 'bot', T3)];
const all = () => reconcileAll(subs).byEnv.production;
const ALL = { modes: ['lan', 'steam', 'bot'], statuses: ['verified', 'provisional', 'local'] };

test('schema v2 records are accepted beside v1, other versions rejected', () => {
  const r = reconcileAll(subs);
  assert.equal(r.byEnv.production.games.T1.status, 'provisional');
  assert.deepEqual(r.byEnv.production.games.T1.turn_ms, [100000, 20000]);
  assert.equal(r.byEnv.production.games.T1.timed_turns, 3);
  assert.equal(r.byEnv.production.games.G1.turn_ms, null);        // v1: no turn times, not zero
  const v3 = v2sub('uA', 'T9', 'lan', v2Game('T9', { activeMs: 1, turnTimes: [], decks: [deckC, deckC] }));
  v3.data.schema_version = 3;
  assert.equal(reconcileAll([v3]).rejected.schema_version, 1);
});

test('malformed v2 timing fields are rejected, never crash the run', () => {
  const bad = (mut) => { const b = JSON.parse(JSON.stringify(T1)); mut(b); return reconcileAll([v2sub('uA', 'T1', 'lan', b)]); };
  assert.equal(bad((b) => { b.game.turn_times = [[1, 2, 5]]; }).rejected.schema_game, 1);               // seat 2
  assert.equal(bad((b) => { b.game.turn_times = [[1, 0, -5]]; }).rejected.schema_game, 1);
  assert.equal(bad((b) => { b.game.turn_times = [[1, 0, 1e12]]; }).rejected.schema_game, 1);            // beyond a day
  assert.equal(bad((b) => { b.game.turn_times = 'x'; }).rejected.schema_game, 1);
  assert.equal(bad((b) => { b.game.turn_times = new Array(2001).fill([1, 0, 1]); }).rejected.schema_game, 1);
  assert.equal(bad((b) => { b.game.turn_ms = [1]; }).rejected.schema_game, 1);
  assert.equal(bad((b) => { b.decks[0].name = { x: 1 }; }).rejected.schema_game, 1);
});

test('deck keys: structure decks by name, otherwise the source', () => {
  assert.equal(deckKey(deckP('Moving Ocean')), 'prebuilt:Moving Ocean');
  assert.equal(deckKey(deckP("Rotmaw's Doom")), "prebuilt:Rotmaw's Doom");
  assert.equal(deckKey(deckC), 'custom');
  assert.equal(deckKey({ source: 'draft+series_changes', base_source: 'draft' }), 'draft');
  assert.equal(deckKey({ source: 'prebuilt' }), 'prebuilt');                  // v1
  assert.equal(deckKey({ name: '<script>' , source: 'prebuilt' }), 'prebuilt');
  assert.equal(deckKey(null), 'unknown');
  assert.deepEqual(all().games.T1.decks, ['prebuilt:Moving Ocean', 'custom']);
});

test('summary and histogram arithmetic', () => {
  assert.deepEqual(summary([30, 10, 20, 40]), { n: 4, mean_ms: 25, median_ms: 25, p10_ms: 13, p90_ms: 37, min_ms: 10, max_ms: 40 });
  assert.deepEqual(summary([]), { n: 0, mean_ms: null, median_ms: null, p10_ms: null, p90_ms: null, min_ms: null, max_ms: null });
  const h = histogram([0, 9, 10, 25, 999], 10, 2);
  assert.deepEqual(h, [{ lo_ms: 0, hi_ms: 10, n: 2 }, { lo_ms: 10, hi_ms: 20, n: 1 }, { lo_ms: 20, hi_ms: null, n: 2 }]);
});

test('game length: averages and distribution over timed duels, by mode and deck', () => {
  const t = computeMetrics(all(), fx.catalog, ALL).timing;
  // Eligible timed: G1 (600 s, v1 verified lan), G3 (600 s, v1 provisional), G5 (600 s, v1 bot local), T1 120 s, T2 60 s, T3 360 s.
  assert.equal(t.games_timed, 6);
  assert.equal(t.game_length.summary.n, 6);
  assert.equal(t.game_length.summary.mean_ms, (600000 * 3 + 120000 + 60000 + 360000) / 6);
  assert.equal(t.game_length.summary.min_ms, 60000);
  assert.equal(t.game_length.by_mode.bot.n, 2);                    // G5, T3
  assert.equal(t.game_length.by_mode.lan.n, 4);
  // Moving Ocean: T1, T2 (counted once per duel even with both seats on it).
  assert.equal(t.game_length.by_deck['prebuilt:Moving Ocean'].n, 2);
  assert.equal(t.game_length.by_deck['prebuilt:Moving Ocean'].mean_ms, 90000);
  // 2-minute buckets: 60 s -> [0, 2 min), 120 s -> [2, 4), 360 s -> [6, 8), 600 s x3 -> [10, 12).
  const b = Object.fromEntries(t.game_length.histogram.filter((x) => x.n).map((x) => [x.lo_ms, x.n]));
  assert.deepEqual(b, { 0: 1, 120000: 1, 360000: 1, 600000: 3 });
});

test('turn time: per turn, by seat kind, turn number, order, mode and deck', () => {
  const t = computeMetrics(all(), fx.catalog, ALL).timing;
  assert.equal(t.games_with_turn_times, 3);                       // v1 duels are left out
  assert.equal(t.turn_observations, 7);
  const h = t.turn_time.human;
  // Human turns: 40, 20, 60 (T1), 10, 30 (T2), 50 (T3) -> 6, mean 35 s, median 35 s.
  assert.equal(h.summary.n, 6);
  assert.equal(h.summary.mean_ms, 35000);
  assert.equal(h.summary.median_ms, 35000);
  assert.equal(t.turn_time.bot.summary.n, 1);
  assert.equal(t.turn_time.bot.summary.mean_ms, 2000);
  // By turn number (humans): turn 1 = 40, 10, 50; turn 2 = 20, 30; turn 3 = 60.
  assert.deepEqual(h.by_turn_number.map((x) => [x.turn, x.n, x.mean_ms]), [[1, 3, 100000 / 3], [2, 2, 25000], [3, 1, 60000]]);
  // First player: T1 s0 (40, 60), T2 s1 (10), T3 s0 (50) -> 4, mean 40 s. Second: T1 20, T2 30 -> mean 25 s.
  assert.equal(h.by_order.first.n, 4);
  assert.equal(h.by_order.first.mean_ms, 40000);
  assert.equal(h.by_order.second.mean_ms, 25000);
  assert.equal(t.turn_time.by_mode.bot.n, 1);                     // the human turn of the bot duel
  assert.equal(t.turn_time.by_mode.lan.n, 5);
  // By deck (humans): Moving Ocean T1 s0 40, 60 + T2 both 10, 30 -> 4 turns, mean 35 s; custom T1 s1 20 + T3 s0 50.
  assert.equal(t.turn_time.by_deck['prebuilt:Moving Ocean'].n, 4);
  assert.equal(t.turn_time.by_deck['prebuilt:Moving Ocean'].mean_ms, 35000);
  assert.equal(t.turn_time.by_deck.custom.mean_ms, 35000);
  // 10 s buckets for all turns: 2 s -> 0, 10 s -> 1, 20 -> 2, 30 -> 3, 40 -> 4, 50 -> 5, 60 -> 6.
  assert.deepEqual(t.turn_time.all.histogram.slice(0, 7).map((x) => x.n), [1, 1, 1, 1, 1, 1, 1]);
});

test('the deck filter narrows duels and the seats counted', () => {
  const m = computeMetrics(all(), fx.catalog, { ...ALL, deck: 'custom' });
  assert.equal(m.eligible_games, 2);                              // T1, T3
  // Human turns on a custom deck: T1 s1 20 s, T3 s0 50 s.
  assert.equal(m.timing.turn_time.human.summary.n, 2);
  assert.equal(m.timing.turn_time.human.summary.mean_ms, 35000);
  assert.ok(m.deck_keys.includes('prebuilt:Moving Ocean'));
});

test('large turn numbers are grouped at the cap', () => {
  const tt = Array.from({ length: 40 }, (_, i) => [i + 1, i % 2, 1000]);
  const g = v2Game('T8', { activeMs: 40000, turnTimes: tt, decks: [deckC, deckC] });
  const env = reconcileAll([v2sub('uA', 'T8', 'lan', g)]).byEnv.production;
  const rows = computeMetrics(env, fx.catalog, ALL).timing.turn_time.all.by_turn_number;
  assert.equal(rows[rows.length - 1].turn, 30);
  assert.equal(rows[rows.length - 1].grouped, true);
  assert.equal(rows[rows.length - 1].n, 11);                       // turns 30..40
});
