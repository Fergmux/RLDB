// Deterministic telemetry fixture (schema v1) with hand-computed expected values; see
// firebase/tools/test/metrics.test.js. Catalog: 1 basic unit, 2 unit, 3 spell, 4 fusion, 5 trap
// (5 is never offered, drafted or decked, so "least" lists can include zero).
//
// production, lan:
//   G1 host uA (seat 0) + client uB (seat 1), agree, seat 0 wins      -> verified
//   G2 host uA + client uB, disagree on winner                        -> conflicted (excluded)
//   G3 host uC only, seat 1 (remote, unattributed) wins               -> provisional
//   G4 host uA, abandoned                                             -> abandoned (no W/L)
// production, bot: G5 host uA                                         -> local (excluded by default)
// test, lan: G6 (a copy of G1)                                        -> other environment
'use strict';
const HASH = 'c'.repeat(64);

function sub(uid, id, kind, env, mode, body, created = 1760000000000) {
  return { uid, id, received_at: created + 500, data: {
    schema_version: 1, kind, env, build: '0.9.0', content_hash: HASH, mode, uid, created_at: created, seq: 1,
    body: JSON.stringify(body) } };
}

const flagsNet = { tutorial: false, bot: false, local: false, network: true };
const flagsBot = { tutorial: false, bot: true, local: true, network: false };
const pHost = { seat: 0, kind: 'human', link: 'profile', participant_id: 'pp_host' };
const pRemote = { seat: 1, kind: 'human', link: 'remote', participant_id: null };

function deck(main, extra = {}) { return { main, extra }; }

function c(plays, kinds, acts = 0) {
  return { draws: 0, hand_entries: 0, draw_opps: 0, draw_opps_played: 0, hand_plays: 0, plays, plays_by_kind: kinds,
    activations: acts, activations_by_kind: acts ? { 'ability:resolved': acts } : {}, special_summons: 0 };
}

function gameBody(gid, { winner, turns, hp, decks, counters, opps, outcome = 'completed', reason = 'lethal', flags = flagsNet, parts = [pHost, pRemote], first = 0 }) {
  return { kind: 'game', ids: { game_id: gid, series_id: 's1' }, flags, reporter: { role: 'host', covers_seats: [0, 1] },
    game: { game_id: gid, series_id: 's1', duel_index: 1, outcome, decisive: outcome === 'completed' && winner >= 0,
      winner, turns, final_hp: hp, first_player: first, reason, active_ms: 600000, ended_at: 1760000100000 },
    participants: parts, decks, counters, opportunities: opps, events: [], completeness: { events: true } };
}

function clientBody(gid, { winner, turns, hp, first = 0, deckMain }) {
  return { kind: 'gclient', ids: { game_id: gid, series_id: 's1' }, flags: flagsNet, reporter: { role: 'client', covers_seats: [1] },
    gclient: { game_id: gid, series_id: 's1', duel_index: 1, seat: 1, outcome: 'completed', winner, turns, final_hp: hp,
      first_player: first, deck: { main: deckMain, extra: {} }, participant: { seat: 1, link: 'profile', participant_id: 'pp_client' } } };
}

const g1 = gameBody('G1', {
  winner: 0, turns: 9, hp: [14, 0],
  decks: [deck({ 1: 3, 2: 2 }, { 4: 1 }), deck({ 1: 3, 3: 1 })],
  counters: [{ 2: c(2, { normal_summon: 1, special_effect: 1 }, 3) }, {}],
  // [token, seat, def, uid, reason, turn, outcome, exit_turn]
  opps: [['o1', 0, 2, 11, 'draw_turn', 1, 'played', 1], ['o2', 0, 2, 12, 'draw_turn', 1, 'exited', 1],
    ['o3', 1, 3, 13, 'draw_turn', 2, 'exited', 2]],
});
const g2 = gameBody('G2', {
  winner: 0, turns: 5, hp: [3, 0], decks: [deck({ 2: 9 }), deck({ 3: 9 })],
  counters: [{ 2: c(9, { normal_summon: 9 }) }, {}], opps: [],
});
const g3 = gameBody('G3', {
  winner: 1, turns: 11, hp: [0, 7], decks: [deck({ 1: 3, 2: 1 }), deck({ 1: 3 })],
  counters: [{ 2: c(1, { normal_summon: 1 }) }, {}],
  opps: [['o1', 0, 2, 21, 'draw_turn', 1, 'played', 1], ['o2', 0, 2, 21, 'retrieve_spent', 3, 'played', 3]],
});
const g4 = gameBody('G4', { winner: -1, turns: 2, hp: [60, 60], decks: [deck({ 2: 1 }), deck({ 2: 1 })], counters: [{}, {}], opps: [], outcome: 'abandoned', reason: 'abandoned' });
const g5 = gameBody('G5', { winner: 0, turns: 4, hp: [5, 0], decks: [deck({ 5: 1 }), deck({ 5: 1 })], counters: [{}, {}], opps: [],
  flags: flagsBot, parts: [pHost, { seat: 1, kind: 'bot', link: 'bot', participant_id: 'bot' }] });

const draft = (id, picks) => ({ kind: 'draft', ids: { draft_id: id, series_id: 's1' }, flags: flagsNet,
  draft: { draft_id: id, series_id: 's1', seat: 0, status: 'complete', picks } });

const pick = (n, offered, selected) => {
  const counts = {};
  for (const o of offered) counts[o] = (counts[o] || 0) + 1;
  return { n, category: 'unit', offered, offered_counts: counts, selected, selected_count: 1, status: 'picked' };
};

const reward = { kind: 'reward', flags: flagsNet, reward: { series_id: 's1', seat: 0, status: 'complete',
  actions: [{ kind: 'type', category: 'unit', offered: [2, 3] }, { kind: 'add', selected: 3 }, { kind: 'finish' }] } };

const submissions = [
  sub('uA', 'game_G1', 'game', 'production', 'lan', g1),
  sub('uB', 'gclient_G1', 'gclient', 'production', 'lan', clientBody('G1', { winner: 0, turns: 9, hp: [14, 0], deckMain: { 1: 3, 3: 1 } })),
  sub('uA', 'game_G2', 'game', 'production', 'lan', g2),
  sub('uB', 'gclient_G2', 'gclient', 'production', 'lan', clientBody('G2', { winner: 1, turns: 5, hp: [3, 0], deckMain: { 3: 9 } })),
  sub('uC', 'game_G3', 'game', 'production', 'lan', g3),
  sub('uA', 'game_G4', 'game', 'production', 'lan', g4),
  sub('uA', 'game_G5', 'game', 'production', 'bot', g5),
  sub('uA', 'game_G6', 'game', 'test', 'lan', { ...g1, ids: { game_id: 'G6' }, game: { ...g1.game, game_id: 'G6' } }),
  sub('uA', 'draft_D1', 'draft', 'production', 'lan', draft('D1', [pick(1, [2, 3, 4], 2), pick(2, [2, 2, 3], 3), pick(3, [4, 1], 4)])),
  sub('uA', 'draft_D2', 'draft', 'dev', 'lan', draft('D2', [pick(1, [5], 5)])),
  sub('uA', 'reward_R1', 'reward', 'production', 'lan', reward),
  sub('uA', 'session_S1', 'session', 'production', 'none', { kind: 'session', session: { session_id: 'S1' } }),
  sub('uB', 'session_S2', 'session', 'production', 'none', { kind: 'session', session: { session_id: 'S2' } }),
  // Rejected: spoofed body uid, unparsable body, a connectivity probe.
  { uid: 'uX', id: 'game_bad', data: { ...sub('uX', 'game_bad', 'game', 'production', 'lan', g1).data, uid: 'uA' } },
  { uid: 'uX', id: 'game_bad2', data: { ...sub('uX', 'game_bad2', 'game', 'production', 'lan', g1).data, body: '{oops' } },
  sub('uX', 'game_probe1', 'game', 'test', 'none', { kind: 'game', probe: true }),
];

const lateAgreeG3 = sub('uD', 'gclient_G3', 'gclient', 'production', 'lan', clientBody('G3', { winner: 1, turns: 11, hp: [0, 7], deckMain: { 1: 3 } }));
const lateConflictG3 = sub('uD', 'gclient_G3', 'gclient', 'production', 'lan', clientBody('G3', { winner: 0, turns: 11, hp: [0, 7], deckMain: { 1: 3 } }));

const catalog = [{ id: 1, category: 'basic_unit' }, { id: 2, category: 'unit' }, { id: 3, category: 'spell' }, { id: 4, category: 'fusion' }, { id: 5, category: 'trap' }];

module.exports = { submissions, lateAgreeG3, lateConflictG3, catalog, sub };
